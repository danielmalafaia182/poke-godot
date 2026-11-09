// Referência de desenho do mapa (fonte C): roda o código ORIGINAL do cliente (buildTile, placeSprite, frameIndexFor,
// markLowCover), extraído literalmente do chunk 0gx72gz9qjk5j.js por casamento de chaves, em modo HD (sem "bake"
// de chunks: todo sprite sai com seu zIndex exato). Só o PixiJS é trocado por um registrador de sprites.
// Uso: node referencia_desenho.js <chunk.js> <snapshot/game> <slug> <saida.json>
const fs = require("fs");
const [, , chunkPath, gameDir, slug, saida] = process.argv;
const src = fs.readFileSync(chunkPath, "utf8");

function metodo(nome) {
  // acha "nome(" como método de classe e devolve "nome(args){corpo}" com chaves balanceadas
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
    else if (c === '"' || c === "'" || c === "`") { // pula strings
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
const fontes = ["buildTile", "placeSprite", "frameIndexFor", "markLowCover"].map(metodo);
// helpers globais do chunk usados por buildTile
const helpers = `
const sv=${constante("sv")};
const su=${constante("su")};
const sx=(e,s)=>(e+s)*4096+4*e;
function sw(e,s,t=0,a=0,n=0,i=32){return{x:e-Math.round(t/i),y:s-Math.round((a+n)/i)}}
`;
const sxOrig = /sx=\(e,s\)=>\(e\+s\)\*4096\+4\*e/.test(src);
const swOrig = src.includes("function sw(e,s,t=0,a=0,n=0,i=32){return{x:e-Math.round(t/i),y:s-Math.round((a+n)/i)}}");
if (!sxOrig || !swOrig) throw new Error("sx/sw mudaram no chunk: revise os helpers");

// Pixi trocado por registrador
const $ = { Sprite: class { constructor(tex) { this.tex = tex; this.x = 0; this.y = 0; this.zIndex = 0; } } };
const classe = `(function(){ ${helpers}
  class Desenhista {
    constructor(d){ Object.assign(this,d); this.registro=[]; this.animated=[]; this.lowCoverZ=new Map(); }
    texForFrame(f){ return f; }
    makeShadow(h){ return {sombra:true}; }
    syncShadow(){}
    ${fontes.join("\n    ")}
  }
  return Desenhista; })()`;
const Desenhista = eval(classe);

const ler = (p) => JSON.parse(fs.readFileSync(p, "utf8"));
const versao = ler(`${gameDir}/asset-packs/version.json`).version;
const man = ler(`${gameDir}/asset-packs/categories/map-items-${versao}.json`);
const dro = ler(`${gameDir}/draworder.json`), off = ler(`${gameDir}/offsets.json`), col = ler(`${gameDir}/collision.json`);
const mapa = ler(`${gameDir}/maps/${slug}.json`);
const d = new Desenhista({
  assets: man.assets,
  topItems: new Set(dro.top ?? []), bottomItems: new Set(dro.bottom ?? []), borderItems: new Set(dro.borders ?? []),
  dispItems: new Map(Object.entries(off.disp ?? {}).map(([e, s]) => [Number(e), s])),
  elevItems: new Map(Object.entries(off.elev ?? {}).map(([e, s]) => [Number(e), s])),
  blockingItems: new Set(col.blocking ?? []),
  mapCenter: mapa._meta?.center ?? [0, 0],
  floors: new Map(), shadowLayers: new Map(),
});
const tiles = mapa.tiles.slice().sort((e, s) => s[2] - e[2] || e[1] - s[1] || e[0] - s[0]); // mesma ordem do buildWorld
const zs = [...new Set(tiles.map(t => t[2]))];
const out = [];
for (const z of zs) {
  const piso = { z, addChild(spr) { out.push([spr.tex === undefined ? -1 : 0, z, spr]); } };
  d.floors.set(z, piso);
  d.shadowLayers.set(z, { addChild() {} });
}
// placeSprite registra (id do asset no sprite via __a)
for (const t of tiles) d.buildTile(t, [], undefined);
const reg = out.map(([_, z, s]) => [s.__a.id, s.__fi, z, s.x, s.y, s.zIndex]);
const low = [...d.lowCoverZ.entries()];
fs.writeFileSync(saida, JSON.stringify({ slug, versao, sprites: reg.length, registro: reg, lowCoverZ: low }));
console.log(JSON.stringify({ slug, sprites: reg.length, lowCover: low.length, animados: d.animated.length }));
