// Referência das sombras (fonte C): roda o código ORIGINAL do cliente — buildTile/placeSprite/frameIndexFor/markLowCover
// (como referencia_desenho.js) mais makeShadow, syncShadow, feetBaseY e as funções de luz sb/sj — com um Sprite falso que
// imita o PixiJS (width/height mudam a escala; anchor, scale, skew, position). Registra cada sombra de sprite do mapa e
// a luz do mapa, e a sombra de uma criatura de exemplo.
// Uso: node referencia_sombras.js <chunk.js> <snapshot/game> <slug> <saida.json>
const fs = require("fs");
const [, , chunkPath, gameDir, slug, saida] = process.argv;
const src = fs.readFileSync(chunkPath, "utf8");

function metodo(nome) {
  const re = new RegExp(String.raw`[}\s;,]` + nome + String.raw`\(`);
  const m = re.exec(src);
  if (!m) throw new Error("método não encontrado: " + nome);
  let i = m.index + 1;
  let j = src.indexOf("{", i);
  let prof = 0, k = j;
  for (; k < src.length; k++) {
    const c = src[k];
    if (c === "{") prof++;
    else if (c === "}") { prof--; if (prof === 0) break; }
    else if (c === '"' || c === "'" || c === "`") {
      const q = c; k++;
      while (k < src.length && src[k] !== q) { if (src[k] === "\\") k++; k++; }
    }
  }
  return src.slice(i, k + 1);
}
function constante(nome) {
  const m = new RegExp(String.raw`[,;\s]` + nome + String.raw`=(new Set\(\[[^\]]*\]\))`).exec(src);
  if (!m) throw new Error("constante não encontrada: " + nome);
  return m[1];
}
function trecho(re) {
  const m = re.exec(src);
  if (!m) throw new Error("trecho não encontrado: " + re);
  return m[0];
}
// luz: sf, sg, sb, sj (literais do chunk)
const luz = [
  trecho(/sf=\{longitude:[^}]*\}/), trecho(/sg=\{"rock-tunnel":\{[^}]*\},"mt-moon":\{[^}]*\}\}/),
  trecho(/function sb\(e\)\{let s=e\?sg\[e\]:void 0;return s\?\{\.\.\.sf,\.\.\.s\}:sf\}/), trecho(/function sj\(e\)\{let s=[\s\S]*?soft:Math\.max\(0,e\.soft\)\}\}/),
].map((t, i) => (i < 2 ? "const " + t + ";" : t)).join("\n");
const fontes = ["buildTile", "placeSprite", "frameIndexFor", "markLowCover", "makeShadow", "syncShadow", "feetBaseY"].map(metodo);
const helpers = `
const sv=${constante("sv")};
const su=${constante("su")};
const sx=(e,s)=>(e+s)*4096+4*e;
function sw(e,s,t=0,a=0,n=0,i=32){return{x:e-Math.round(t/i),y:s-Math.round((a+n)/i)}}
${luz}
`;
// PixiJS falso: só o que makeShadow/syncShadow/placeSprite usam
class Ponto { constructor(x = 0, y = 0) { this.x = x; this.y = y; } set(x, y) { this.x = x; this.y = y === undefined ? x : y; } }
class SpriteFalso {
  constructor(tex) { this.texture = tex; this.x = 0; this.y = 0; this.zIndex = 0; this.alpha = 1; this.visible = true; this.tint = 0xffffff;
    this.anchor = new Ponto(0, 0); this.scale = new Ponto(1, 1); this.skew = new Ponto(0, 0); this.position = this; }
  set(x, y) { this.x = x; this.y = y; }
  get width() { return Math.abs(this.scale.x) * this.texture.w; } set width(v) { this.scale.x = v / this.texture.w; }
  get height() { return Math.abs(this.scale.y) * this.texture.h; } set height(v) { this.scale.y = v / this.texture.h; }
}
const $ = { Sprite: SpriteFalso };
const classe = `(function(){ ${helpers}
  class Desenhista {
    constructor(d){ Object.assign(this,d); this.animated=[]; this.lowCoverZ=new Map(); this.shadowsOn=true; }
    texForFrame(f){ return {w:f.w, h:f.h, get width(){return this.w}, get height(){return this.h}, f}; }
    ${fontes.join("\n    ")}
  }
  return {Desenhista, sb, sj}; })()`;
const { Desenhista, sb, sj } = eval(classe);

const ler = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const versao = ler(`${gameDir}/asset-packs/version.json`).version;
const man = ler(`${gameDir}/asset-packs/categories/map-items-${versao}.json`);
const dro = ler(`${gameDir}/draworder.json`), off = ler(`${gameDir}/offsets.json`), col = ler(`${gameDir}/collision.json`);
const mapa = ler(`${gameDir}/maps/${slug}.json`);
const light = sj(sb(slug));
const d = new Desenhista({
  assets: man.assets, light,
  topItems: new Set(dro.top ?? []), bottomItems: new Set(dro.bottom ?? []), borderItems: new Set(dro.borders ?? []),
  dispItems: new Map(Object.entries(off.disp ?? {}).map(([e, s]) => [Number(e), s])),
  elevItems: new Map(Object.entries(off.elev ?? {}).map(([e, s]) => [Number(e), s])),
  blockingItems: new Set(col.blocking ?? []),
  mapCenter: mapa._meta?.center ?? [0, 0],
  floors: new Map(), shadowLayers: new Map(),
});
const tiles = mapa.tiles.slice().sort((e, s) => s[2] - e[2] || e[1] - s[1] || e[0] - s[0]);
const zs = [...new Set(tiles.map(t => t[2]))];
const sombras = [];
let zAtual = 0;
for (const z of zs) {
  d.floors.set(z, { addChild() {} });
  d.shadowLayers.set(z, { addChild(s) { s.__z = z; } });
}
// guarda o sprite dono de cada sombra (makeShadow original + registro)
const mk = d.makeShadow.bind(d);
d.makeShadow = (h, layer) => { const s = mk(h, layer); s.__dono = h; sombras.push(s); return s; };
for (const t of tiles) d.buildTile(t, [], undefined);
const reg = sombras.map(s => [s.__dono.__a.id, s.__dono.__fi, s.__z, s.__dono.x, s.__dono.y, s.__dono.zIndex,
  s.x, s.y, s.anchor.x, s.anchor.y, s.scale.x, s.scale.y, s.skew.x, s.alpha, s.tint]);
// criatura de exemplo (syncCreatures: anchor (.5, 1 − 11,52/h), posição no centro do tile; escala 1)
const tex = { w: 64, h: 64, get width() { return 64; }, get height() { return 64; } };
const cri = new SpriteFalso(tex); cri.anchor.set(0.5, 1 - 11.52 / 64); cri.position.set(32 * 10 + 16, 32 * 7 + 16);
const sc = d.makeShadow(cri, { addChild() {} });
d.syncShadow(cri, d.feetBaseY(cri));
const criatura = [sc.x, sc.y, sc.anchor.x, sc.anchor.y, sc.scale.x, sc.scale.y, sc.skew.x, sc.alpha];
fs.writeFileSync(saida, JSON.stringify({ slug, luz: light, sombras: reg.length, registro: reg, criatura }));
console.log(JSON.stringify({ slug, luz: light, sombras: reg.length }));
