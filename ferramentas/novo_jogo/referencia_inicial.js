// Referência (C): o sorteio de IV e Quality do inicial do cliente original (chunk 0fllz2m_ktm3s.js, getParty / rollGrowthSet /
// rollQuality), copiado sem mudança de lógica, para conferir o porte em sim/servico_novo_jogo.gd.
// Uso: node ferramentas/novo_jogo/referencia_inicial.js "Nome:1" "Ash:4" ...
const r = [[.8,.9,5],[.9,1,5],[1,1.1,34.03846],[1.1,1.2,20],[1.2,1.3,10],[1.3,1.4,10],[1.4,1.5,10],[1.5,1.6,5],[1.7,1.8,.67308],[1.8,1.8,.28846]];
function c(e){let o=100*e();for(let[t,i,c]of r){if(o<c){if(t===i)return t;return Math.floor((t+e()*(i-t))*1e3)/1e3}o-=c}return 1}
function n(e){return 1+Math.floor(32*e())}
function l(e){return{hp:n(e),atk:n(e),def:n(e),spAtk:n(e),spDef:n(e),speed:n(e)}}
function gen(e){let t,i=(t=(function(e){let o=0x6a09e667^e.length;for(let t=0;t<e.length;t++)o=(o=Math.imul(o^e.charCodeAt(t),0xcc9e2d51))<<13|o>>>19;return()=>(o=Math.imul((o=Math.imul(o^o>>>16,0x85ebca6b))^o>>>13,0xc2b2ae35),(o^=o>>>16)>>>0)})(e)(),()=>{t|=0;let e=Math.imul((t=t+0x6d2b79f5|0)^t>>>15,1|t);return(((e=e+Math.imul(e^e>>>7,61|e)^e)^e>>>14)>>>0)/0x100000000});return{growth:l(i),quality:c(i)}}
const out = {};
for (const s of process.argv.slice(2)) out[s] = gen(s);
console.log(JSON.stringify(out));
