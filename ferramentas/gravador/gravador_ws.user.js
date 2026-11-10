// ==UserScript==
// @name         Gravador WS — Poke Idle World
// @namespace    poke-idle-godot
// @version      1.2
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
 * Painel no canto inferior esquerdo: pausar, exportar JSONL, limpar.
 */
(function () {
  'use strict';
  const W = typeof unsafeWindow !== 'undefined' ? unsafeWindow : window;
  const VERSAO = 3;
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
    fila.push({ sessao: SESSAO, t: Date.now(), dir, tipo, dados });
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
  async function exportar(soEsta) {
    const msgs = await lerTudo(soEsta ? SESSAO : null);
    const linhas = msgs.map(m => JSON.stringify({ sessao: m.sessao, t: m.t, dir: m.dir, msg: (() => { try { return JSON.parse(m.dados); } catch { return m.dados; } })() }));
    const blob = new Blob([linhas.join('\n') + '\n'], { type: 'application/x-ndjson' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `poke_ws_${soEsta ? SESSAO : 'todas'}.jsonl`;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 30000);
  }
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
      '<button id="pg-p">pausar</button> <button id="pg-e">exportar sessão</button> <button id="pg-a">tudo</button> <button id="pg-l">limpar</button> <button id="pg-x">×</button>';
    document.body.appendChild(painel);
    painel.querySelector('#pg-p').onclick = e => { pausado = !pausado; e.target.textContent = pausado ? 'retomar' : 'pausar'; painel.querySelector('b').textContent = pausado ? '❚❚ PAUSA' : '● REC WS'; };
    painel.querySelector('#pg-e').onclick = () => exportar(true);
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
  }
  if (document.body) montar(); else document.addEventListener('DOMContentLoaded', montar);

  W.__pokeGravador = { versao: VERSAO, exportar, lerTudo, sessao: SESSAO, mostrar: () => { if (painel) painel.style.display = 'block'; } };
})();
