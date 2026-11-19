#!/usr/bin/env python3
"""O alvo do herói anda até ele de fora da caixa de perseguição? (revisão do ciclo 1, A)

Pares de fields consecutivos (Δseq = 2) por aba (`sessao`). Para cada selvagem vivo FORA da caixa |dx| ≤ 13 e |dy| ≤ 13 do
herói (a borda medida, A), conta se ele se aproximou do herói (Chebyshev menor), ficou parado ou se afastou, separando o
alvo do herói (targetSlot) dos outros. Se o alvo se aproxima e os outros ficam parados, o alvo vem ao encontro (H4).
Também com a caixa 13×7 (a da sim), para ver o que a sim tem fora da visão.

Uso: python -I ferramentas/gravador/medir_alvo_fora.py <gravações ou pastas...>
"""
import sys, os
from collections import Counter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import segmentar as SG


def cheb(a, b):
    return max(abs(a["row"] - b["row"]), abs(a["col"] - b["col"]))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    fs = SG.arquivos_de(sys.argv[1:])
    res = {(caixa, quem): Counter() for caixa in ("13x13", "13x7") for quem in ("alvo", "outros")}
    ant = {}
    for sess, d, m in SG.linhas_dedup(fs):
        if d != "in" or m.get("type") not in ("field", "field-init"):
            continue
        if m["type"] == "field-init":
            ant.pop(sess, None)
            continue
        a = ant.get(sess)
        ant[sess] = m
        if not a or m["seq"] - a["seq"] != 2 or a.get("fainted"):
            continue
        hp, h = a["hero"], m["hero"]
        pa = {x["slot"]: x for x in a["mobs"]}
        for x in m["mobs"]:
            p = pa.get(x["slot"])
            if not p or p["dead"] or x["dead"]:
                continue
            dx, dy = abs(p["col"] - hp["col"]), abs(p["row"] - hp["row"])
            quem = "alvo" if x["slot"] == a.get("targetSlot") else "outros"
            mov = "parado" if (p["row"], p["col"]) == (x["row"], x["col"]) else ("aproximou" if cheb(x, hp) < cheb(p, hp) else "outro")
            if dx > 13 or dy > 13:
                res[("13x13", quem)][mov] += 1
            if dx > 13 or dy > 7:
                res[("13x7", quem)][mov] += 1
    print("| Fora da caixa | Quem | Pares | Aproximou | Parado | Outro movimento |")
    print("| --- | --- | --- | --- | --- | --- |")
    for (caixa, quem), c in res.items():
        n = sum(c.values())
        print(f"| {caixa} | {quem} | {n} | {c['aproximou']} ({100 * c['aproximou'] / max(1, n):.1f}%) | {c['parado']} | {c['outro']} |")


if __name__ == "__main__":
    main()
