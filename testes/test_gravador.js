// Gravador v1.3 (gravação livre) no Node, com o navegador simulado: IndexedDB mínimo em memória, WebSocket, fetch,
// localStorage, Blob/URL e o <a download>. Relógio falso (Date.now, setTimeout, setInterval) para andar horas.
// Confere: recuperação ao abrir, exportação automática a cada 2 h só com o que é novo, download ao fechar a aba, e que
// a união dos arquivos tem todas as mensagens (repetidas só onde é esperado).
// Uso: node testes/test_gravador.js
'use strict';
const fs = require('fs');
const path = require('path');
const codigo = fs.readFileSync(path.join(__dirname, '..', 'ferramentas', 'gravador', 'gravador_ws.user.js'), 'utf8');

let falhas = 0, total = 0;
function checar(ok, nome, det) { total++; if (!ok) falhas++; console.log((ok ? 'OK    ' : 'FALHA ') + nome + (det ? `  (${det})` : '')); }

// ---------- relógio falso ----------
let agora = Date.UTC(2026, 10, 18, 12, 0, 0);
let timers = [];
let idT = 0;
function setTimeoutF(fn, ms) { timers.push({ id: ++idT, quando: agora + ms, fn, rep: 0 }); return idT; }
function setIntervalF(fn, ms) { timers.push({ id: ++idT, quando: agora + ms, fn, rep: ms }); return idT; }
async function andar(ms) {
  const fim = agora + ms;
  for (;;) {
    timers.sort((a, b) => a.quando - b.quando);
    const t = timers[0];
    if (!t || t.quando > fim) break;
    agora = t.quando;
    if (t.rep) t.quando += t.rep; else timers.shift();
    t.fn();
    await new Promise(r => setImmediate(r));
    await new Promise(r => setImmediate(r));
  }
  agora = fim;
  for (let i = 0; i < 5; i++) await new Promise(r => setImmediate(r));
}

// ---------- IndexedDB mínimo (persistente entre "abas") ----------
const banco = { registros: [], prox: 1 };
function req(f) { const r = {}; Promise.resolve().then(() => { try { r.result = f(); r.onsuccess && r.onsuccess(); } catch (e) { r.error = e; r.onerror && r.onerror(); } }); return r; }
function cursorReq(lista, aoValor) {
  const r = {}; let i = 0;
  const passo = () => Promise.resolve().then(() => {
    if (i < lista.length) { const v = lista[i++]; r.result = { value: v, continue: passo, delete: () => aoValor && aoValor(v) }; }
    else r.result = null;
    r.onsuccess && r.onsuccess();
  });
  passo(); return r;
}
function faixa(range) { return banco.registros.filter(x => (range.lo === undefined || (range.loOpen ? x.id > range.lo : x.id >= range.lo)) && (range.hi === undefined || x.id <= range.hi)); }
const store = {
  add(m) { banco.registros.push({ ...m, id: banco.prox++ }); },
  clear() { banco.registros = []; },
  openCursor(range) { return cursorReq(range ? faixa(range) : banco.registros.slice(), v => { banco.registros = banco.registros.filter(x => x !== v); }); },
  index() { return { openCursor: range => cursorReq(banco.registros.filter(x => x.sessao === range.only)) }; },
  createIndex() { },
};
const indexedDB = { open() { const r = {}; setImmediate(() => { r.result = { transaction: () => ({ objectStore: () => store }), createObjectStore: () => store }; r.onupgradeneeded && r.onupgradeneeded(); r.onsuccess && r.onsuccess(); }); return r; } };
const IDBKeyRange = { lowerBound: (v, aberto) => ({ lo: v, loOpen: aberto }), upperBound: v => ({ hi: v }), only: v => ({ only: v }) };

// ---------- uma "aba" ----------
const ls = {};
let baixados = [];
function novaAba() {
  const ouvintes = {};
  const doc = {
    body: { appendChild() { } }, documentElement: { appendChild() { } }, addEventListener() { },
    createElement(t) {
      if (t === 'a') return { click() { baixados.push({ nome: this.download, texto: this.href.texto }); }, remove() { } };
      return { style: {}, querySelector: () => ({ style: {}, set textContent(v) { }, set onclick(v) { } }), set innerHTML(v) { } };
    },
  };
  class WSFalso { constructor() { this.l = {}; } addEventListener(k, f) { (this.l[k] = this.l[k] || []).push(f); } send() { } chegar(d) { (this.l.message || []).forEach(f => f({ data: d })); } }
  const W = {
    WebSocket: WSFalso, fetch: null, addEventListener: (k, f) => { (ouvintes[k] = ouvintes[k] || []).push(f); },
    disparar: k => (ouvintes[k] || []).forEach(f => f()),
  };
  const ctx = {
    unsafeWindow: W, window: W, document: doc, indexedDB, IDBKeyRange, navigator: { userAgent: 'teste' }, alert() { },
    localStorage: { getItem: k => (k in ls ? ls[k] : null), setItem: (k, v) => { ls[k] = String(v); } },
    Blob: class { constructor(p) { this.texto = p.join(''); } }, URL: Object.assign(function () { }, { createObjectURL: b => ({ texto: b.texto }), revokeObjectURL() { } }),
    setTimeout: setTimeoutF, setInterval: setIntervalF, Date: { now: () => agora }, location: { href: 'https://x/play', origin: 'https://x' },
  };
  ctx.Date = Object.assign(function (...a) { return a.length ? new Date(...a) : new Date(agora); }, { now: () => agora, UTC: Date.UTC });
  new Function(...Object.keys(ctx), codigo)(...Object.values(ctx));
  const ws = new W.WebSocket('wss://x');
  return { W, ws, mandar(i) { ws.chegar(JSON.stringify({ type: 'field', seq: i })); } };
}

function linhasDe(arqs) { return arqs.flatMap(a => a.texto.split('\n').filter(Boolean).map(l => JSON.parse(l))); }

(async () => {
  // aba 1: 3 h jogando, 1 mensagem por segundo nos campos "seq"
  let aba = novaAba();
  let seq = 0;
  for (let h = 0; h < 3 * 3600; h += 60) { for (let i = 0; i < 60; i++) aba.mandar(seq++); await andar(60000); }
  const autos = baixados.filter(b => /^poke_livre_\d/.test(b.nome) && !/recuperado|fechar/.test(b.nome));
  checar(autos.length === 1, 'exportação automática depois de 2 h (1 em 3 h)', baixados.map(b => b.nome).join(', '));
  const nAuto = linhasDe(autos).filter(x => x.dir === 'in').length;
  checar(nAuto >= 7100 && nAuto <= 7300, 'a exportação das 2 h leva as ~7200 mensagens até ali', String(nAuto));
  // fecha a aba: baixa o que falta da memória
  aba.W.disparar('pagehide');
  const fechar = baixados.filter(b => /_ao_fechar/.test(b.nome));
  checar(fechar.length === 1, 'ao fechar a aba: download do que não foi exportado', fechar.map(b => b.nome).join(''));
  const nFechar = linhasDe(fechar).filter(x => x.dir === 'in').length;
  const nIni = linhasDe(baixados.filter(b => /_recuperado/.test(b.nome))).filter(x => x.dir === 'in').length;
  checar(nIni + nAuto + nFechar === seq, 'recuperação do começo + auto + fechamento = todas as mensagens da aba, sem repetir', `${nIni} + ${nAuto} + ${nFechar} de ${seq}`);
  // aba 2 (navegador bloqueou o download no fechamento? a recuperação baixa de novo o que ficou sem marca)
  const antes = baixados.length;
  aba = novaAba();
  await andar(20000);
  const rec = baixados.slice(antes).filter(b => /_recuperado/.test(b.nome));
  checar(rec.length === 1, 'ao abrir de novo: recuperação do que ficou sem exportar', rec.map(b => b.nome).join(''));
  const todas = new Set(linhasDe(baixados).filter(x => x.dir === 'in').map(x => x.msg.seq));
  checar(todas.size === seq, 'a união dos arquivos tem todas as mensagens', `${todas.size} de ${seq}`);
  const marca = Number(ls.poke_gravador_marca);
  checar(marca === banco.registros[banco.registros.length - 1].id, 'a marca aponta para o último registro exportado');
  // mais 2 h na aba 2: a exportação seguinte só leva o novo
  const antes2 = baixados.length;
  let novos = 0;
  for (let h = 0; h < 2 * 3600 + 120; h += 60) { for (let i = 0; i < 60; i++) { aba.mandar(seq++); novos++; } await andar(60000); }
  const auto2 = baixados.slice(antes2).filter(b => /^poke_livre_\d/.test(b.nome) && !/recuperado|fechar/.test(b.nome));
  const n2 = linhasDe(auto2).filter(x => x.dir === 'in').length;
  checar(auto2.length === 1 && n2 <= novos && n2 >= novos - 200, 'na aba 2, a exportação de 2 h leva só o que é novo', `${n2} de ${novos} novos`);
  // registros exportados com mais de 3 dias saem do navegador
  await andar(4 * 86400000);
  aba.mandar(seq++);
  await andar(2 * 3600000 + 60000);
  const velhos = banco.registros.filter(x => x.t < agora - 3 * 86400000).length;
  checar(velhos === 0, 'registros já exportados com mais de 3 dias são apagados', String(velhos));
  console.log(`RESULTADO: ${total - falhas}/${total}`);
  process.exit(falhas ? 1 : 0);
})();
