/* Coletor de snapshot — Poke Idle World (fase 0)
 * Dois modos: gravar direto numa pasta (Chrome/Edge) ou baixar um ZIP por etapa (qualquer navegador).
 * Uso: colar no console de qualquer página de https://poke.idleworld.online
 * (ou injetar pelo navegador embutido). Aparece um painel no canto; o botão
 * pede uma pasta e grava nela snapshot_AAAA-MM-DD/ com todos os arquivos.
 * Só faz GET de arquivos públicos, em sequência, com pausa entre pedidos.
 * Não lê cookies, token nem dados da conta.
 */
(() => {
  if (window.__pokeColetor) { window.__pokeColetor.mostrar(); return; }
  const PAUSA_MS = 60;
  const ALIAS_MAPA = { cerulean: 'cerulean_novo', pesca: 'cerulean_novo', aero_boss: 'golem' };
  const FIXOS = [
    '/game/creatures.json', '/game/items.json', '/game/bossCatalog.json', '/game/pokecards.json',
    '/game/collision.json', '/game/offsets.json', '/game/draworder.json', '/game/corpses/corpses.json',
    '/game/asset-packs/version.json', '/game/asset-packs/outfits-index.json',
    '/game/maps/arena_pvp.json', '/assets/effects/moves/index.json', '/assets/maps/marker-atlas.json',
    '/fonts/verdana-11px-rounded.json', '/api/game/map-markers',
  ];
  const ETAPAS = ['dados', 'hunts', 'mapas', 'atlas', 'outfits', 'icones'];
  const st = { manifest: [], erros: [], feitos: 0, bytes: 0, etapa: '', inicio: 0, parar: false, raiz: null };
  const dormir = ms => new Promise(r => setTimeout(r, ms));
  const fixPack = u => u.replace(/^\/assets-packs/, '/game/asset-packs');

  // ---------- ZIP mínimo (sem bibliotecas): JSON comprimido com deflate-raw, imagens armazenadas ----------
  const TAB_CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
  const crc32 = u8 => { let c = 0xFFFFFFFF; for (let i = 0; i < u8.length; i++) c = TAB_CRC[(c ^ u8[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; };
  async function deflateRaw(u8) {
    if (typeof CompressionStream === 'undefined') return null;
    const cs = new CompressionStream('deflate-raw');
    const out = new Response(new Blob([u8]).stream().pipeThrough(cs)).arrayBuffer();
    return new Uint8Array(await out);
  }
  class Zip {
    constructor() { this.partes = []; this.central = []; this.offset = 0; this.n = 0; }
    async add(nome, dados) {
      const u8 = dados instanceof Uint8Array ? dados : new Uint8Array(dados);
      const nomeU8 = new TextEncoder().encode(nome);
      const crc = crc32(u8);
      let metodo = 0, corpo = u8;
      if (/\.(json|txt|js|md)$/i.test(nome) || !/\./.test(nome.split('/').pop())) {
        const z = await deflateRaw(u8); if (z && z.length < u8.length) { metodo = 8; corpo = z; }
      }
      const h = new DataView(new ArrayBuffer(30));
      h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint16(6, 0x0800, true); h.setUint16(8, metodo, true);
      h.setUint16(10, 0, true); h.setUint16(12, 0x21, true); h.setUint32(14, crc, true);
      h.setUint32(18, corpo.length, true); h.setUint32(22, u8.length, true); h.setUint16(26, nomeU8.length, true); h.setUint16(28, 0, true);
      this.partes.push(new Uint8Array(h.buffer), nomeU8, corpo);
      const c = new DataView(new ArrayBuffer(46));
      c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true); c.setUint16(8, 0x0800, true); c.setUint16(10, metodo, true);
      c.setUint16(12, 0, true); c.setUint16(14, 0x21, true); c.setUint32(16, crc, true); c.setUint32(20, corpo.length, true); c.setUint32(24, u8.length, true);
      c.setUint16(28, nomeU8.length, true); c.setUint32(42, this.offset, true);
      this.central.push(new Uint8Array(c.buffer), nomeU8);
      this.offset += 30 + nomeU8.length + corpo.length; this.n++;
    }
    blob() {
      const tam = this.central.reduce((a, p) => a + p.length, 0);
      const e = new DataView(new ArrayBuffer(22));
      e.setUint32(0, 0x06054b50, true); e.setUint16(8, this.n, true); e.setUint16(10, this.n, true);
      e.setUint32(12, tam, true); e.setUint32(16, this.offset, true);
      return new Blob([...this.partes, ...this.central, new Uint8Array(e.buffer)], { type: 'application/zip' });
    }
  }
  function baixarBlob(blob, nome) {
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = nome;
    document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 60000);
  }

  // ---------- painel ----------
  const painel = document.createElement('div');
  painel.style.cssText = 'position:fixed;right:12px;bottom:12px;z-index:2147483647;background:#111c;color:#fff;font:12px/1.4 monospace;padding:10px 12px;border-radius:8px;width:340px;box-shadow:0 2px 12px #0008';
  painel.innerHTML = `<b>Coletor Poke Idle — fase 0</b><div id="pc-etapas" style="margin:6px 0"></div>
    <div style="margin:4px 0">outfits: <input id="pc-out" style="width:220px;font:11px monospace" value="3,112,74,19,115,9,76,103,130,111,1,hunt:rhydon,hunt:rattata,id:5759,id:21019" title="pokeIds, hunt:slug, id:outfit, kind:pokemon|shiny|trainer|npc, ou vazio = todos"></div>
    <button id="pc-ir" style="padding:6px 10px;font-weight:bold;cursor:pointer">Escolher pasta e coletar</button>
    <button id="pc-zip" style="padding:6px 10px;margin-top:4px;cursor:pointer">Baixar como ZIPs</button>
    <button id="pc-parar" style="padding:6px 8px;margin-left:6px;cursor:pointer">Parar</button>
    <div id="pc-st" style="margin-top:6px;white-space:pre-wrap">Pronto.</div>`;
  document.body.appendChild(painel);
  const caixas = painel.querySelector('#pc-etapas');
  for (const e of ETAPAS) caixas.insertAdjacentHTML('beforeend',
    `<label style="margin-right:8px"><input type="checkbox" data-etapa="${e}" checked> ${e}</label>`);
  const status = t => { painel.querySelector('#pc-st').textContent = t; };
  const resumo = () => status(`Etapa: ${st.etapa}\nArquivos: ${st.feitos}  ·  ${(st.bytes / 1048576).toFixed(1)} MB\nErros: ${st.erros.length}\nTempo: ${Math.round((Date.now() - st.inicio) / 1000)} s`);

  // ---------- disco ----------
  async function gravar(caminho, dados) {
    if (st.zip) { await st.zip.add(st.prefixo + caminho, typeof dados === 'string' ? new TextEncoder().encode(dados) : dados); return; }
    const partes = caminho.split('/').filter(Boolean);
    let dir = st.raiz;
    for (const p of partes.slice(0, -1)) dir = await dir.getDirectoryHandle(p, { create: true });
    const fh = await dir.getFileHandle(partes.at(-1), { create: true });
    const w = await fh.createWritable();
    await w.write(dados); await w.close();
  }
  async function sha256(buf) {
    const h = await crypto.subtle.digest('SHA-256', buf);
    return [...new Uint8Array(h)].map(x => x.toString(16).padStart(2, '0')).join('');
  }
  const caminhoDe = url => url.replace(/^\//, '').replace(/\?.*$/, '');

  async function baixar(url, caminho, opc = {}) {
    if (st.parar) throw new Error('parado');
    caminho = caminho || caminhoDe(url);
    let ultimo = null;
    for (let t = 0; t < 3; t++) {
      try {
        const r = await fetch(url, { cache: 'no-store', credentials: 'omit' });
        if (r.status === 404 && opc.opcional) {
          st.manifest.push({ url, caminho, status: 404 }); await dormir(PAUSA_MS); return null;
        }
        if (!r.ok) throw new Error('HTTP ' + r.status);
        const buf = await r.arrayBuffer();
        await gravar(caminho, buf);
        st.manifest.push({ url, caminho, status: r.status, bytes: buf.byteLength, sha256: await sha256(buf) });
        st.feitos++; st.bytes += buf.byteLength; resumo();
        await dormir(PAUSA_MS);
        return opc.json ? JSON.parse(new TextDecoder().decode(buf)) : buf;
      } catch (e) { ultimo = e; if (String(e).includes('parado')) throw e; await dormir(500 * (t + 1)); }
    }
    st.erros.push({ url, caminho, erro: String(ultimo) }); st.manifest.push({ url, caminho, status: 'erro', erro: String(ultimo) });
    return null;
  }
  // todas as strings de imagem dentro de um JSON
  function imagens(obj, out = new Set()) {
    if (typeof obj === 'string') { if (/\.(webp|png|gif|jpg)$/i.test(obj)) out.add(obj); }
    else if (Array.isArray(obj)) obj.forEach(v => imagens(v, out));
    else if (obj && typeof obj === 'object') Object.values(obj).forEach(v => imagens(v, out));
    return out;
  }

  // ---------- etapas ----------
  let marcadores = null;
  async function etapaDados() {
    for (const u of FIXOS) {
      const j = await baixar(u, null, { json: u.endsWith('.json') || u.startsWith('/api/') ? true : false });
      if (u === '/api/game/map-markers') marcadores = j;
    }
  }
  async function garantirMarcadores() {
    if (!marcadores) marcadores = await (await fetch('/api/game/map-markers', { cache: 'no-store' })).json();
    return marcadores.hunts.map(h => h.slug);
  }
  async function etapaHunts() {
    const slugs = await garantirMarcadores();
    for (const s of slugs) {
      st.etapa = `hunts ${s}`;
      await baixar(`/api/game/hunt-config?slug=${encodeURIComponent(s)}`, `api/hunt-config/${s}.json`);
      await baixar(`/api/game/city-npcs?slug=${encodeURIComponent(s)}`, `api/city-npcs/${s}.json`, { opcional: true });
    }
  }
  async function etapaMapas() {
    const slugs = await garantirMarcadores();
    const nomes = [...new Set(slugs.map(s => ALIAS_MAPA[s] ?? s))];
    for (const n of nomes) { st.etapa = `mapas ${n}`; await baixar(`/game/maps/${n}.json`, null, { opcional: true }); }
  }
  async function etapaAtlas() {
    const v = await baixar('/game/asset-packs/version.json', null, { json: true });
    const idx = await baixar(fixPack(v.index), null, { json: true });
    await baixar(fixPack(v.manifest), null, { json: true });
    for (const [nome, cat] of Object.entries(idx.categories || {})) {
      const man = await baixar(fixPack(cat.manifest), null, { json: true });
      const imgs = [...imagens(man)];
      for (let i = 0; i < imgs.length; i++) { st.etapa = `atlas ${nome} ${i + 1}/${imgs.length}`; await baixar(fixPack(imgs[i])); }
    }
    // Páginas do atlas de cadáveres (loadCorpses do cliente): o corpses.json vem na etapa de dados, as imagens aqui.
    const cj = await baixar('/game/corpses/corpses.json', null, { json: true });
    const pags = (cj && cj.pages) || [];
    for (let i = 0; i < pags.length; i++) { st.etapa = `cadáveres ${i + 1}/${pags.length}`; await baixar(pags[i]); }
  }
  // Filtro de outfits: lista separada por vírgula com pokeIds (looktype da espécie = id do outfit),
  // hunt:slug (todas as espécies que nascem na hunt), id:N (outfit cru, ex. treinador/NPC),
  // kind:K (pokemon, shiny, trainer, npc, clan, premium, pass, founder, hunt) e npc (= kind:npc).
  // Vazio = todos os outfits (pacote completo).
  async function filtroOutfits(oi) {
    const txt = (painel.querySelector('#pc-out')?.value || '').trim();
    if (!txt) return null;
    const cr = (await (await fetch('/game/creatures.json', { cache: 'no-store', credentials: 'omit' })).json()).creatures;
    const look = new Map(cr.map(c => [c.pokeId, c.looktype]));
    const ids = new Set();
    for (const tok of txt.split(',').map(t => t.trim()).filter(Boolean)) {
      if (tok === 'npc' || tok.startsWith('kind:')) {
        const k = tok === 'npc' ? 'npc' : tok.slice(5);
        for (const o of Object.values(oi.outfits || {})) if (o.kind === k) ids.add(String(o.id));
      }
      else if (tok.startsWith('id:')) ids.add(tok.slice(3));
      else if (tok.startsWith('hunt:')) {
        try {
          const cfg = await (await fetch(`/api/game/hunt-config?slug=${encodeURIComponent(tok.slice(5))}`, { credentials: 'omit' })).json();
          for (const sp of cfg.spawns || []) if (look.has(sp.pokeId)) ids.add(String(look.get(sp.pokeId)));
        } catch { st.erros.push({ erro: 'hunt não encontrada: ' + tok }); }
      } else if (look.has(Number(tok))) ids.add(String(look.get(Number(tok))));
      else st.erros.push({ erro: 'pokeId desconhecido: ' + tok });
    }
    return ids;
  }
  async function etapaOutfits() {
    const oi = await baixar('/game/asset-packs/outfits-index.json?v=2', 'game/asset-packs/outfits-index.json', { json: true });
    const filtro = await filtroOutfits(oi);
    const lista = Object.values(oi.outfits || {}).filter(o => !filtro || filtro.has(String(o.id)));
    st.outfits = { filtro: filtro ? [...filtro].sort() : 'todos', escolhidos: lista.map(o => `${o.id} ${o.name}`) };
    if (st.zip) await st.zip.add(`${st.prefixo}outfits_escolhidos.json`, new TextEncoder().encode(JSON.stringify(st.outfits, null, 1)));
    for (let i = 0; i < lista.length; i++) {
      st.etapa = `outfits ${i + 1}/${lista.length}`;
      const man = await baixar(fixPack(lista[i].manifest), null, { json: true });
      if (man) for (const img of imagens(man)) await baixar(fixPack(img));
    }
  }
  async function etapaIcones() {
    const it = await (await fetch('/game/items.json', { cache: 'no-store' })).json();
    const urls = new Set();
    for (const i of it.items) if (i.icon) urls.add(/^(https?:)?\//.test(i.icon) ? i.icon : `/assets/items/${i.icon}`);
    for (const t of ['bug','dark','dragon','electric','fairy','fighting','fire','flying','ghost','grass','ground','ice','normal','poison','psychic','rock','steel','water']) urls.add(`/assets/types/${t}.png`);
    try {
      const fx = await (await fetch('/assets/effects/moves/index.json')).json();
      for (const s of imagens(fx)) urls.add(s.startsWith('/') ? s : `/assets/effects/moves/${s}`);
    } catch {}
    const lista = [...urls].filter(u => u.startsWith('/'));
    for (let i = 0; i < lista.length; i++) { st.etapa = `icones ${i + 1}/${lista.length}`; await baixar(lista[i], null, { opcional: true }); }
  }
  const FUNCOES = { dados: etapaDados, hunts: etapaHunts, mapas: etapaMapas, atlas: etapaAtlas, outfits: etapaOutfits, icones: etapaIcones };

  async function coletar(modoZip) {
    const escolhidas = [...painel.querySelectorAll('[data-etapa]')].filter(c => c.checked).map(c => c.dataset.etapa);
    const nome = 'snapshot_' + new Date().toISOString().slice(0, 10);
    st.zip = null; st.prefixo = '';
    if (!modoZip) {
      const base = await window.showDirectoryPicker({ mode: 'readwrite', id: 'poke-snapshot' });
      st.raiz = await base.getDirectoryHandle(nome, { create: true });
    } else st.prefixo = nome + '/';
    Object.assign(st, { manifest: [], erros: [], feitos: 0, bytes: 0, inicio: Date.now(), parar: false });
    try {
      for (const e of escolhidas) {
        st.etapa = e; resumo();
        if (modoZip) st.zip = new Zip();
        const antes = st.manifest.length;
        try { await FUNCOES[e](); } finally {
          if (modoZip) {   // um ZIP por etapa, com o pedaço do manifesto dela
            await st.zip.add(`${nome}/manifest_${e}.json`, new TextEncoder().encode(JSON.stringify(st.manifest.slice(antes), null, 1)));
            baixarBlob(st.zip.blob(), `${nome}_${e}.zip`); st.zip = null;
          }
        }
      }
    } catch (e) { st.erros.push({ erro: String(e) }); }
    if (modoZip) st.zip = new Zip();
    const fim = {
      formato: 'poke-snapshot-v1', origem: location.origin, coletadoEm: new Date().toISOString(),
      etapas: escolhidas, outfits: st.outfits || null, arquivos: st.feitos, bytes: st.bytes, erros: st.erros, itens: st.manifest,
    };
    // coleta parcial (ex.: só outfits) não pode sobrescrever o manifest.json do snapshot completo
    const parcial = escolhidas.length < ETAPAS.length;
    const nomeMan = parcial ? `manifest_parcial_${escolhidas.join('-')}_${Date.now()}.json` : 'manifest.json';
    await gravar(nomeMan, JSON.stringify(fim, null, 1));
    if (modoZip) { baixarBlob(st.zip.blob(), `${nome}_${parcial ? 'manifest_parcial' : 'manifest'}.zip`); st.zip = null; }
    st.etapa = st.parar ? 'interrompido' : 'concluído'; resumo();
    window.__pokeColetor.ultimo = { arquivos: st.feitos, bytes: st.bytes, erros: st.erros.length, pasta: nome };
  }
  painel.querySelector('#pc-ir').onclick = () => coletar(false).catch(e => status('Falhou: ' + e + '\nUse "Baixar como ZIPs".'));
  painel.querySelector('#pc-zip').onclick = () => coletar(true).catch(e => status('Falhou: ' + e));
  painel.querySelector('#pc-parar').onclick = () => { st.parar = true; };
  window.__pokeColetor = { st, Zip, mostrar: () => { painel.style.display = 'block'; } };
})();
