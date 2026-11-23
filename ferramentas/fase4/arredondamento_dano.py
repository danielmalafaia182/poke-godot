#!/usr/bin/env python3
"""round × floor no dano e a forma do fator aleatório, pela verossimilhança da DISTRIBUIÇÃO dos valores.

O `ajustar_dano.py` só confere se cada golpe cabe no envelope [aleatório 0,85; 1,00], e o envelope não separa round de
floor: a faixa contínua desconhecida da defesa do selvagem absorve o meio ponto. Aqui, para cada indivíduo × golpe do
aliado (≥ 20 golpes, aliado nível ≥ 5, stats do aliado conhecidos), varre a defesa do selvagem e calcula, sob cada
modelo, P(valor k) = medida dos r em [0,85; 1,00] com f(r·X) = k; soma o log da verossimilhança máxima por grupo.
Modelos: arredondamento {round, floor} × aleatório {contínuo, 16 inteiros 85..100}.

Resultado em 23/11/2026 (`dados/relatorios/arredondamento_dano_2026-11-23.md`):
  - round × floor: EMPATE (fases 3/4: 3.479 golpes, logL −15.955,5 × −15.958,0; gravação livre: 38.417 golpes,
    −229.828,6 × −229.835,9). Com o atacante no nível ≥ 20 o dano é grande e meio ponto não aparece.
  - Aleatório CONTÍNUO (A): 16 degraus inteiros perdem por ~9.800 (fases 3/4) e ~89.500 (livre) de logL.
Fecha o arredondamento: aliado nível 5–15 na hunt rattata ou geodude por ~30 min (dano 5–20, muitas repetições).

Uso: python -I ferramentas/fase4/arredondamento_dano.py [--livre] [--md saida.md]
  --livre  usa a gravação livre (poke har/gravacoes/livre/), separada por sessão num diretório temporário
"""
import argparse
import glob
import json
import math
import os
import re
import sys
import tempfile
from collections import defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ajustar_dano as A  # noqa: E402

R = A.R
EPS = 1e-4
RS = [x / 100.0 for x in range(85, 101)]
MODELOS = [("round", False), ("floor", False), ("round", True), ("floor", True)]
TIPOS = ('"type":"field"', '"field-init"', '"poke-delta"', '"pokes-chunk"', '"type":"pokes"', '"field-kill"', '"catch-result"')


def prob(k, X, arr, disc, piso):
    def f(v):
        return max(piso, math.floor(v + 0.5) if arr == "round" else math.floor(v))
    if disc:
        return sum(1 for r in RS if f(r * X) == k) / 16.0
    if X <= 0:
        return 1.0 if k == piso else 0.0
    lo, hi = (k - 0.5, k + 0.5) if arr == "round" else (k, k + 1)
    if k == piso:
        lo = -1e18
    a, b = max(0.85, lo / X), min(1.0, hi / X)
    return max(0.0, b - a) / 0.15


def separar_livre(destino):
    """Junta as exportações da gravação livre sem repetir linha e escreve um arquivo por sessão (só os tipos usados)."""
    vistos, saidas = set(), {}
    for arq in sorted(glob.glob(os.path.join(RAIZ, "poke har", "gravacoes", "livre", "*.jsonl"))):
        for linha in open(arq, encoding="utf-8", errors="replace"):
            if not any(t in linha for t in TIPOS):
                continue
            h = hash(linha)
            if h in vistos:
                continue
            vistos.add(h)
            try:
                s = re.sub(r"[^0-9A-Za-z_-]", "_", json.loads(linha).get("sessao", "x"))
            except Exception:
                continue
            if s not in saidas:
                saidas[s] = open(os.path.join(destino, "livre_%s.jsonl" % s), "w", encoding="utf-8")
            saidas[s].write(linha)
    for f in saidas.values():
        f.close()
    return sorted(glob.glob(os.path.join(destino, "*.jsonl")))


def avaliar(arqs):
    especies = {e["id"]: e for e in R.carregar(os.path.join(RAIZ, "dados", "gerados", "especies.json"))}
    hunts = {h["slug"]: h for h in R.carregar(os.path.join(RAIZ, "dados", "gerados", "hunts.json"))}
    ind = {}
    for f in arqs:
        ind.update(A.coletar(f))
    tot = defaultdict(float)
    por_faixa = defaultdict(lambda: defaultdict(float))
    venc = defaultdict(int)
    n_grupos = n_golpes = 0
    for k, e in ind.items():
        esp, hunt = especies.get(k[3]), hunts.get(e["slug"])
        if not esp or not hunt:
            continue
        nivel_s = int(hunt["nivel"])
        pares = R.pares_hp(esp["base"]["hp"], nivel_s, e["maxHp"])
        if not pares:
            continue
        qs = sorted({q for _, q, _ in pares})
        grupos = defaultdict(list)
        for golpe, tipo, eff, amt, h in e["aliado"]:
            grupos[(golpe, tipo, eff, h["level"], h["stats"]["atk"], h["stats"]["spAtk"])].append((amt, h))
        for (golpe, tipo, eff, lvl, _, _), am in grupos.items():
            if len(am) < 20 or eff == 0 or lvl <= 4:
                continue
            esp_h = especies.get(am[0][1]["speciesId"])
            g = next((x for x in esp_h["golpes"] if x["nome"] == golpe), None) if esp_h else None
            if not g or int(g.get("poder", 0)) <= 0:
                continue
            especial = g["categoria"] == "SPECIAL"
            a = am[0][1]["stats"]["spAtk" if especial else "atk"]
            chave = "spDef" if especial else "def"
            lo, hi = R.faixa_continua(esp["base"][chave], nivel_s, qs, chave)
            mods = (1.5 if tipo in esp_h["tipos"] else 1.0) * eff
            valores = [x[0] for x in am]
            if max(valores) < 4:
                continue
            melhores = {}
            for i in range(601):
                d = lo + (hi - lo) * i / 600.0
                X = (2.0 * lvl / 5.0 + 2.0) * g["poder"] * a / max(1e-9, d) / 50.0 * mods
                for m in MODELOS:
                    ll = sum(math.log(max(EPS, prob(v, X, m[0], m[1], 2))) for v in valores)
                    if m not in melhores or ll > melhores[m]:
                        melhores[m] = ll
            n_grupos += 1
            n_golpes += len(valores)
            fx = A.faixa_de(lvl)
            for m in MODELOS:
                tot[m] += melhores[m]
                por_faixa[fx][m] += melhores[m]
            for disc in (False, True):
                dr = melhores[("round", disc)] - melhores[("floor", disc)]
                venc[(disc, "round" if dr > 2 else ("floor" if dr < -2 else "empate"))] += 1
    return n_grupos, n_golpes, tot, por_faixa, venc


def texto(titulo, n_grupos, n_golpes, tot, por_faixa, venc):
    nome = lambda m: "%s, aleatório %s" % (m[0], "16 inteiros" if m[1] else "contínuo")  # noqa: E731
    L = ["## " + titulo, "", "%d grupos (indivíduo × golpe, ≥ 20 golpes, aliado nível ≥ 5), %d golpes." % (n_grupos, n_golpes), "",
         "| Modelo | logL |", "| --- | --- |"]
    L += ["| %s | %.1f |" % (nome(m), tot[m]) for m in MODELOS]
    L += ["", "| Faixa do aliado | " + " | ".join(nome(m) for m in MODELOS) + " |", "|---|" + "---|" * len(MODELOS)]
    for fx in sorted(por_faixa, key=lambda s: int(s.split("–")[0])):
        L.append("| %s | %s |" % (fx, " | ".join("%.1f" % por_faixa[fx][m] for m in MODELOS)))
    L += ["", "Grupos em que round ou floor vence por mais de 2 de logL: contínuo — round %d, floor %d, empate %d; 16 inteiros — "
          "round %d, floor %d, empate %d." % (venc[(False, "round")], venc[(False, "floor")], venc[(False, "empate")],
                                               venc[(True, "round")], venc[(True, "floor")], venc[(True, "empate")]), ""]
    return L


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--livre", action="store_true")
    ap.add_argument("--md")
    a = ap.parse_args()
    if a.livre:
        with tempfile.TemporaryDirectory() as tmp:
            L = texto("Gravação livre (18–20/11, por sessão)", *avaliar(separar_livre(tmp)))
    else:
        base = os.path.join(RAIZ, "poke har", "gravacoes")
        arqs = sorted(set(glob.glob(os.path.join(base, "*.jsonl")) + glob.glob(os.path.join(base, "fase3", "*.jsonl"))
                          + glob.glob(os.path.join(base, "fase 4", "*.jsonl"))))
        L = texto("Gravações das fases 3 e 4", *avaliar([x for x in arqs if "gravacoes_unicas" not in x]))
    md = "\n".join(L) + "\n"
    print(md)
    if a.md:
        os.makedirs(os.path.dirname(os.path.abspath(a.md)), exist_ok=True)
        open(a.md, "a", encoding="utf-8", newline="\n").write(md)


if __name__ == "__main__":
    main()
