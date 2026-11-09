// Paleta de cores de outfit do cliente ORIGINAL (getOutfitColor, chunk 0wl3dp5-44hi8.js), extraída literalmente e
// avaliada para os índices 0..140. Saída: JSON [[r,g,b], ...]. Uso: node referencia_cores.js <chunk.js> <saida.json>
const fs = require("fs");
const [, , chunkPath, saida] = process.argv;
const src = fs.readFileSync(chunkPath, "utf8");
const i = src.indexOf("function h(e){e>=133");
if (i < 0) throw new Error("getOutfitColor não encontrada");
let k = src.indexOf("{", i), prof = 0;
for (; k < src.length; k++) { if (src[k] === "{") prof++; else if (src[k] === "}") { prof--; if (prof === 0) break; } }
const h = eval("(" + src.slice(i, k + 1) + ")");
const r = [];
for (let e = 0; e <= 140; e++) r.push(h(e));
fs.writeFileSync(saida, JSON.stringify(r));
console.log(JSON.stringify({ cores: r.length }));
