// ==UserScript==
// @name         Gravador WS — Poke Idle World
// @namespace    poke-idle-godot
// @version      1.3
// @description  Grava as mensagens do jogo e as respostas de /api/game/* (sem token, URL de conexão ou cabeçalhos).
// @match        https://poke.idleworld.online/play*
// @run-at       document-start
// @grant        none
// ==/UserScript==
/*
 * Dois jeitos de usar:
 *  A) Tampermonkey/Violentmonkey: instalar este arquivo. Grava desde o carregamento da página.
 *  B) Colar no console (F12) com o jogo aberto. Ele se conecta ao WebSocket já aberto
 *     na próxima mensagem que o cliente enviar (o jogo envia algo a cada ~4 s).
 * Guarda só o corpo das mensagens, com horário local. Não guarda URL, token, cookies.
 * Mensagens de chat/DM de outros jogadores são descartadas por padrão.
 * v1.1: grava também o corpo das respostas GET/POST de /api/game/* (ex.: used-balls = investimento de captura
 * por espécie; pokes do painel do time), com dir "rest". Guarda caminho, parâmetros (sem os que parecem credencial), status e corpo.
 * v1.2: se outra versão do gravador já estiver ativa na página, avisa (a antiga não grava REST) em vez de sair calada;
 * a linha meta __open leva versaoGravador 3 e restHook, para conferir no arquivo que o gancho REST estava ligado.
 * v1.3 (gravação livre): exporta sozinho, sem precisar lembrar.
 *   - A cada 2 h, baixa só o que é novo desde a última exportação: poke_livre_<data>_<hora>.jsonl.
 *   - Ao fechar ou recarregar a aba, tenta baixar o que ainda não foi exportado (o navegador pode bloquear downloads no
 *     fechamento).
 *   - Por isso, ao abrir o jogo de novo, o que ficou sem exportar é baixado logo no começo. Nada se perde; uma linha
 *     repetida entre dois arquivos é descartada pelo ferramentas/gravador/segmentar.py.
 *   - Os registros já exportados com mais de 3 dias são apagados do navegador.
 *   - Na 1ª exportação automática, o Chrome pode perguntar se o site pode baixar vários arquivos: permita.
 *   Ponha os arquivos em poke har/gravacoes/livre/ (ou aponte a pasta de downloads do navegador para lá).
 * Painel no canto inferior esquerdo: pausar, exportar novos, exportar sessão, tudo, limpar.
 */
(function () {
  'use strict';
  const W = typeof unsafeWindow !== 'undefined' ? unsafeWindow : window;
  const VERSAO = 4;
  const INTERVALO_AUTO_MS = 2 * 60 * 60 * 1000;     // exportação automática a cada 2 h
  const GUARDAR_DIAS = 3;                            // registros já exportados ficam 3 dias no navegador
  const MEMORIA_MAX = 20 * 1024 * 1024;              // cópia em memória para o download ao fechar a aba (até ~20 MB)
  const MARCA = 'poke_gravador_marca';               // id do último registro exportado (localStorage)
  const ULTIMA = 'poke_gravador_ultima_exportacao';
  if (W.__pokeGravador) {
    if ((W.__pokeGravador.versao || 0) < VERSAO) {
      alert('Gravador WS: uma versão antiga já está ativa nesta página e NÃO grava as respostas REST (used-balls). ' +
            'Desative a antiga no Tampermonkey (ou feche a aba), recarregue a página e cole/ative esta versão.');
    }
    W.__pokeGravador.mostrar(); return;
  }

  const DESCARTAR = new Set(['chat', 'dm', 'chat-delete', 'dm-inbox']);
  const SESSAO = new Date().toISOString().replace(/[:.]/g, '-');
  const REST_OK = /^\/api\/game\//;          // só dados de jogo; nada de /api/auth
  const REST_NAO = /^\/api\/game\/(chat|dm|friends|messages|mail)/;
  let pausado = false, total = 0, porTipo = {};
  const fila = [];
  let memoria = [], memoriaBytes = 0, memoriaCheia = false;   // linhas ainda não exportadas (para o fechamento da aba)
  const lerLS = (k, d) => { try { const v = localStorage.getItem(k); return v === null ? d : Number(v); } catch { return d; } };
  const gravarLS = (k, v) => { try { localStorage.setItem(k, String(v)); } catch { } };

  // ---------- IndexedDB ----------
  let db = null;
  const abrir = new Promise((ok, erro) => {
    const r = indexedDB.open('poke_gravador', 1);
    r.onupgradeneeded = () => {
      const s = r.result.createObjectStore('msgs', { keyPath: 'id', autoIncrement: true });
      s.createIndex('sessao', 'sessao');
    };
    r.onsuccess = () => { db = r.result; ok(db); };
    r.onerror = () => erro(r.error);
  });
  async function descarregar() {
    if (!fila.length) return;
    await abrir;
    const lote = fila.splice(0, fila.length);
    const tx = db.transaction('msgs', 'readwrite');
    const s = tx.objectStore('msgs');
    for (const m of lote) s.add(m);
  }
  setInterval(() => { descarregar().catch(() => {}); }, 1000);

  function registrar(dir, dados) {
    if (pausado || typeof dados !== 'string') return;
    let tipo = '?';
    try { tipo = JSON.parse(dados).type ?? '?'; } catch { /* binário ou texto livre */ }
    if (DESCARTAR.has(tipo)) return;
    const reg = { sessao: SESSAO, t: Date.now(), dir, tipo, dados };
    fila.push(reg);
    if (!memoriaCheia) {
      const l = linha(reg);
      memoria.push(l); memoriaBytes += l.length;
      if (memoriaBytes > MEMORIA_MAX) { memoria = []; memoriaBytes = 0; memoriaCheia = true; }   // fica só a recuperação
    }
    total++; porTipo[tipo] = (porTipo[tipo] || 0) + 1;
    if (total % 25 === 0) atualizar();
  }

  // ---------- ganchos ----------
  const ligados = new WeakSet();
  function ligar(ws) {
    if (ligados.has(ws)) return;
    ligados.add(ws);
    ws.addEventListener('message', ev => registrar('in', ev.data));
    ws.addEventListener('close', ev => registrar('meta', JSON.stringify({ type: '__close', code: ev.code })));
    registrar('meta', JSON.stringify({ type: '__open', versaoGravador: VERSAO, restHook: restLigado, ua: navigator.userAgent }));
  }
  const Original = W.WebSocket;
  const envioOriginal = Original.prototype.send;
  Original.prototype.send = function (d) {
    try { ligar(this); registrar('out', d); } catch { /* nunca quebrar o jogo */ }
    return envioOriginal.apply(this, arguments);
  };
  function Embrulho(url, protocolos) {
    const ws = protocolos !== undefined ? new Original(url, protocolos) : new Original(url);
    try { ligar(ws); } catch { }
    return ws;
  }
  Embrulho.prototype = Original.prototype;
  for (const k of ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED']) Embrulho[k] = Original[k];
  W.WebSocket = Embrulho;

  // ---------- respostas REST de /api/game/* ----------
  const fetchOriginal = W.fetch;
  let restLigado = false;
  if (fetchOriginal) {
    restLigado = true;
    W.fetch = function (entrada, opcoes) {
      const p = fetchOriginal.apply(this, arguments);
      try {
        const url = new URL(typeof entrada === 'string' ? entrada : entrada.url, location.href);
        if (url.origin === location.origin && REST_OK.test(url.pathname) && !REST_NAO.test(url.pathname)) {
          const metodo = ((opcoes && opcoes.method) || (entrada && entrada.method) || 'GET').toUpperCase();
          p.then(r => r.clone().text().then(corpo => {
            let dados; try { dados = JSON.parse(corpo); } catch { dados = corpo.slice(0, 200000); }
            const consulta = {};
            for (const [k, v] of url.searchParams) if (!/token|auth|key|secret|senha|pass/i.test(k)) consulta[k] = v;
            registrar('rest', JSON.stringify({ type: '__rest', metodo, caminho: url.pathname, consulta, status: r.status, corpo: dados }));
          })).catch(() => {});
        }
      } catch { /* nunca quebrar o jogo */ }
      return p;
    };
  }

  // ---------- exportação ----------
  async function lerTudo(sessao) {
    await descarregar(); await abrir;
    return new Promise((ok, erro) => {
      const out = [];
      const s = db.transaction('msgs').objectStore('msgs');
      const req = sessao ? s.index('sessao').openCursor(IDBKeyRange.only(sessao)) : s.openCursor();
      req.onsuccess = () => { const c = req.result; if (c) { out.push(c.value); c.continue(); } else ok(out); };
      req.onerror = () => erro(req.error);
    });
  }
  function linha(m) {
    return JSON.stringify({ sessao: m.sessao, t: m.t, dir: m.dir, msg: (() => { try { return JSON.parse(m.dados); } catch { return m.dados; } })() });
  }
  function baixar(linhas, nome) {
    const blob = new Blob([linhas.join('\n') + '\n'], { type: 'application/x-ndjson' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = nome;
    (document.body || document.documentElement).appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 60000);
  }
  function carimbo() {
    const d = new Date(), z = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${z(d.getMonth() + 1)}-${z(d.getDate())}_${z(d.getHours())}-${z(d.getMinutes())}`;
  }
  async function exportar(soEsta) {
    const msgs = await lerTudo(soEsta ? SESSAO : null);
    baixar(msgs.map(linha), `poke_ws_${soEsta ? SESSAO : 'todas'}.jsonl`);
  }
  // Exporta os registros com id > marca: os novos desde a última exportação, desta aba ou de uma aba fechada antes.
  let exportando = false;
  async function exportarNovos(motivo) {
    if (exportando) return 0;                 // uma exportação por vez (a verificação de 1 min não duplica arquivos)
    exportando = true;
    try { return await exportarNovos_(motivo); } finally { exportando = false; }
  }
  async function exportarNovos_(motivo) {
    await descarregar(); await abrir;
    const marca = lerLS(MARCA, 0);
    const novos = await new Promise((ok, erro) => {
      const out = [];
      const req = db.transaction('msgs').objectStore('msgs').openCursor(IDBKeyRange.lowerBound(marca, true));
      req.onsuccess = () => { const c = req.result; if (c) { out.push(c.value); c.continue(); } else ok(out); };
      req.onerror = () => erro(req.error);
    });
    if (!novos.length) return 0;
    baixar(novos.map(linha), `poke_livre_${carimbo()}${motivo === 'recuperacao' ? '_recuperado' : ''}.jsonl`);
    gravarLS(MARCA, novos[novos.length - 1].id);
    gravarLS(ULTIMA, Date.now());
    memoria = []; memoriaBytes = 0; memoriaCheia = false;
    limparAntigos().catch(() => {});
    atualizar();
    return novos.length;
  }
  async function limparAntigos() {
    const marca = lerLS(MARCA, 0), limite = Date.now() - GUARDAR_DIAS * 86400000;
    await abrir;
    const req = db.transaction('msgs', 'readwrite').objectStore('msgs').openCursor(IDBKeyRange.upperBound(marca));
    req.onsuccess = () => { const c = req.result; if (c) { if (c.value.t < limite) c.delete(); c.continue(); } };
  }
  // Automático: ao abrir (o que ficou de uma aba fechada), a cada 2 h, e ao fechar a aba (melhor esforço, da memória).
  setTimeout(() => { exportarNovos('recuperacao').catch(() => {}); }, 15000);
  setInterval(() => {
    if (Date.now() - lerLS(ULTIMA, 0) >= INTERVALO_AUTO_MS) exportarNovos('auto').catch(() => {});
  }, 60000);
  if (!lerLS(ULTIMA, 0)) gravarLS(ULTIMA, Date.now());
  let saiu = false;
  function aoSair() {
    if (saiu || !memoria.length) return;
    saiu = true;
    try { baixar(memoria, `poke_livre_${carimbo()}_ao_fechar.jsonl`); } catch { }
  }
  W.addEventListener('pagehide', aoSair);
  W.addEventListener('beforeunload', aoSair);
  async function limpar() {
    if (!confirm('Apagar todas as gravações guardadas neste navegador?')) return;
    await abrir;
    db.transaction('msgs', 'readwrite').objectStore('msgs').clear();
    total = 0; porTipo = {}; atualizar();
  }

  // ---------- painel ----------
  let painel = null;
  function montar() {
    painel = document.createElement('div');
    painel.style.cssText = 'position:fixed;left:8px;bottom:8px;z-index:2147483647;background:#111d;color:#fff;font:11px/1.35 monospace;padding:6px 8px;border-radius:6px;max-width:260px';
    painel.innerHTML = '<b>● REC WS</b> <span id="pg-n">0</span> msgs<div id="pg-t" style="opacity:.75"></div>' +
      '<div id="pg-auto" style="opacity:.75"></div>' +
      '<button id="pg-p">pausar</button> <button id="pg-n2">exportar novos</button> <button id="pg-e">sessão</button> <button id="pg-a">tudo</button> <button id="pg-l">limpar</button> <button id="pg-x">×</button>';
    document.body.appendChild(painel);
    painel.querySelector('#pg-p').onclick = e => { pausado = !pausado; e.target.textContent = pausado ? 'retomar' : 'pausar'; painel.querySelector('b').textContent = pausado ? '❚❚ PAUSA' : '● REC WS'; };
    painel.querySelector('#pg-e').onclick = () => exportar(true);
    painel.querySelector('#pg-n2').onclick = () => exportarNovos('manual');
    setInterval(atualizar, 30000);
    painel.querySelector('#pg-a').onclick = () => exportar(false);
    painel.querySelector('#pg-l').onclick = () => limpar();
    painel.querySelector('#pg-x').onclick = () => { painel.style.display = 'none'; };
    atualizar();
  }
  function atualizar() {
    if (!painel) return;
    painel.querySelector('#pg-n').textContent = total;
    const top = Object.entries(porTipo).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([k, v]) => `${k}:${v}`).join(' ');
    painel.querySelector('#pg-t').textContent = top;
    const falta = Math.max(0, INTERVALO_AUTO_MS - (Date.now() - lerLS(ULTIMA, Date.now())));
    painel.querySelector('#pg-auto').textContent = `auto: próxima em ${Math.round(falta / 60000)} min` + (memoriaCheia ? ' · ao fechar: só na próxima abertura' : '');
  }
  if (document.body) montar(); else document.addEventListener('DOMContentLoaded', montar);

  W.__pokeGravador = { versao: VERSAO, exportar, exportarNovos, lerTudo, sessao: SESSAO, mostrar: () => { if (painel) painel.style.display = 'block'; } };
})();
