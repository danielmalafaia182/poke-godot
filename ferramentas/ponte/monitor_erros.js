// Monitor de erros da página para o teste de aceitação da ponte (injetado pela ponte no início do /play).
// Junta em window.__ponteErros: console.error/console.warn, erros não tratados, promessas rejeitadas e
// recursos que responderam >= 400 (lidos do Resource Timing). Não altera nada do jogo.
(function () {
  'use strict';
  const erros = [];
  const W = window;
  function add(tipo, texto) { erros.push({ t: Date.now(), tipo, texto: String(texto).slice(0, 500) }); }
  for (const nivel of ['error', 'warn']) {
    const orig = console[nivel];
    console[nivel] = function (...a) {
      try { add('console.' + nivel, a.map(x => (x && x.stack) || (typeof x === 'object' ? JSON.stringify(x) : x)).join(' ')); } catch (e) { }
      return orig.apply(this, a);
    };
  }
  W.addEventListener('error', e => add('window.error', (e.message || '') + ' ' + (e.filename || '') + ':' + (e.lineno || '')
    + (e.target && e.target !== W && e.target.src ? ' recurso ' + e.target.src : '')), true);
  W.addEventListener('unhandledrejection', e => add('unhandledrejection', (e.reason && (e.reason.stack || e.reason.message)) || e.reason));
  W.__ponteErros = {
    lista: erros,
    recursos: () => performance.getEntriesByType('resource').filter(r => r.responseStatus >= 400)
      .map(r => r.responseStatus + ' ' + r.name.replace(location.origin, '')),
    resumo: () => ({ erros: erros.length, porTipo: erros.reduce((m, e) => (m[e.tipo] = (m[e.tipo] || 0) + 1, m), {}),
      recursosFalhos: [...new Set(W.__ponteErros.recursos())] }),
  };
})();
