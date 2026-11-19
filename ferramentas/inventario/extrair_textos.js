// Extrai os textos (i18n) do cliente original: o chunk 3vooh2axx98am.js registra 3 módulos com JSON.parse('...') —
// en, pt-BR e es. Saída: JSON {idioma: árvore de chaves}. Uso: node ferramentas/inventario/extrair_textos.js <chunk.js> <saida.json>
'use strict';
const fs = require('fs');
const [, , chunk, saida] = process.argv;
const src = fs.readFileSync(chunk, 'utf8');
globalThis.TURBOPACK = [];
new Function(src)();
const mods = [];
for (const entrada of globalThis.TURBOPACK) {
  for (const x of entrada) {
    if (typeof x === 'function') {
      const a = { exports: {} };
      try { x({}, a, {}); } catch (e) { continue; }
      if (a.exports && typeof a.exports === 'object' && a.exports.window) mods.push(a.exports);
    }
  }
}
const idioma = m => ({ Loja: 'pt', Shop: 'en', Tienda: 'es' }[(m.shop || {}).title] || 'desconhecido');
const out = {};
for (const m of mods) out[idioma(m)] = m;
fs.writeFileSync(saida, JSON.stringify(out, null, 1));
console.log('idiomas:', Object.keys(out).join(', '), 'chaves de topo:', Object.keys(mods[0] || {}).length);
