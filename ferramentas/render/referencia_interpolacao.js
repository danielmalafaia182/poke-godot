// Referência de interpolação (fonte C): roda as funções ORIGINAIS do cliente (d$, dI, dE, dM, dS, dk, dy, dC, dL, dT,
// db, dv e o ajuste de relógio dc/dm/dh), extraídas literalmente do chunk 0gx72gz9qjk5j.js, sobre os fields de uma
// gravação real. Para o herói e cada selvagem: dT a cada field (no instante de chegada t do gravador) e dE amostrado
// a cada 50 ms até o próximo field. Saída: JSON com os eventos de entrada e as posições, para o teste do porte.
// Uso: node referencia_interpolacao.js <chunk.js> <gravação.jsonl> <máx fields> <saída.json>
const fs = require("fs");
const [, , chunkPath, gravPath, maxFields, saida] = process.argv;
const src = fs.readFileSync(chunkPath, "utf8");

function funcao(nome) {
  const i = src.indexOf("function " + nome + "(");
  if (i < 0) throw new Error("função não encontrada: " + nome);
  let k = src.indexOf("{", i), prof = 0;
  for (; k < src.length; k++) {
    if (src[k] === "{") prof++;
    else if (src[k] === "}") { prof--; if (prof === 0) break; }
  }
  return src.slice(i, k + 1);
}
function seta(nome) {
  const m = new RegExp(String.raw`[,;\s]` + nome + String.raw`=(\(e,s\)=>[^;]*?)(?=,d[a-zA-Z$]=|;)`).exec(src);
  if (!m) throw new Error("seta não encontrada: " + nome);
  return "const " + nome + "=" + m[1] + ";";
}
const relogioOrig = "let s=Date.now()-e;if(!dm||Math.abs(s-dc)>2e3){dc=s,dm=!0;return}dc=.85*dc+.15000000000000002*s";
if (!src.includes(relogioOrig)) throw new Error("trecho do relógio mudou no chunk");
const codigo = `
let dc=0, dm=false; let AGORA=0; const Date={now:()=>AGORA};
function ajustar(e){ ${relogioOrig} }
${seta("db")}
${["d$", "dI", "dE", "dM", "dS", "dk", "dy", "dC", "dL", "dT", "dv", "dh"].map(funcao).join("\n")}
({ajustar, dT, dE, setAgora:(t)=>{AGORA=t}})`;
const api = eval(codigo);

const linhas = fs.readFileSync(gravPath, "utf8").split("\n");
const fields = [];
let init = null;
for (const l of linhas) {
  if (!l.trim()) continue;
  let o; try { o = JSON.parse(l); } catch { continue; }
  if (!o.msg || o.dir !== "in") continue;
  if (o.msg.type === "field-init" && !init) init = o.msg;
  if (o.msg.type === "field" && init) { fields.push({ t: o.t, m: o.msg }); if (fields.length >= +maxFields) break; }
}
const estados = {}; const amostras = []; const entradas = [];
for (let k = 0; k < fields.length; k++) {
  const { t, m } = fields[k];
  api.setAgora(t);
  api.ajustar(m.serverNow);
  const atores = [["heroi", m.hero, init.heroStepMs]].concat(m.mobs.map(x => ["mob" + x.slot, x, init.mobStepMs]));
  for (const [id, a, passo] of atores) {
    estados[id] = api.dT(estados[id] ?? null, a, passo, t, false);
  }
  entradas.push({ t, serverNow: m.serverNow, atores: atores.map(([id, a, passo]) => [id, a.row, a.col, a.walkFrom ?? null, a.stepStartAt ?? 0, passo]) });
  const fim = k + 1 < fields.length ? fields[k + 1].t : t + 400;
  for (let u = t; u < fim; u += 50) {
    for (const id of Object.keys(estados)) {
      const p = api.dE(estados[id], u);
      amostras.push([k, id, u, p.row, p.col]);
    }
  }
}
fs.writeFileSync(saida, JSON.stringify({ entradas, amostras }));
console.log(JSON.stringify({ fields: fields.length, amostras: amostras.length }));
