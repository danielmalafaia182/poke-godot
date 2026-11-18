#!/usr/bin/env python3
"""Dano em nível 1–4 contra o Rattata nível 1 (A: G11, geodude-10min, geodeude-2) — variantes de fórmula (F).

Grupos (golpes do aliado no Rattata da hunt `rattata`, todos com maxHp 120):
  Vulpix (Q 1,72; SpA base 50; Ember, poder 40, especial, STAB) nos níveis 1, 2, 3 — G11
  Geodude (Q 1,137; Atk base 80; Tackle, poder 50, físico, sem STAB) nos níveis 1, 2, 3, 4 — geodude-10min, geodeude-2
Golpes do Rattata no aliado (Tackle 50, STAB, ×1,8): no Vulpix nível 1 e 2 (G11).
O IV do atacante é varrido (1..32) dentro do que os stats exibidos permitem; a defesa do Rattata é UMA para todos os
indivíduos e os dois tipos de golpe (Def = SpD base 35; A: a defesa é comum, ver CLAUDE.md), varrida de 0,20 a 2,00.
Um golpe é explicado se cabe no que a variante produz com o aleatório 0,85–1,00.

Variantes:
  atual   round(K·r), A contínuo do aliado, piso 3 no ataque do aliado (a sim hoje, e+A3)
  x2      2 × round(K·r) no nível 1 do aliado (A: só valores pares no nível 1), A contínuo, sem piso
  x2exib  x2 com o A exibido (inteiro)
  exib    round(K·r) com o A exibido, sem piso
K = (2L/5 + 2) · poder · A / D / 50 · STAB.

Uso: python -I ferramentas/fase4/ajuste_nivel1.py [--md saida.md]
"""
import argparse
import math
import sys

G11 = {1: {14: 31, 16: 57}, 2: {11: 38, 12: 50}, 3: {18: 4, 19: 25, 20: 23, 21: 29, 22: 8}}
GEO = {1: {6: 62, 8: 106}, 2: {8: 9, 9: 85, 10: 27}, 3: {9: 2, 12: 5, 13: 12, 14: 15}, 4: {20: 50, 21: 36, 22: 40, 23: 33}}
VUL_EXIB = {1: 2, 2: 3, 3: 5}
GEO_EXIB = {1: 1, 2: 3, 3: 4, 4: 6}
RAT_EM_VULPIX = {1: {5: 39}, 2: {7: 41}}   # Tackle do Rattata no Vulpix (A, G11)
VUL_DEF_EXIB = {1: 1, 2: 2}


def jsr(x):
    return math.floor(x + 0.5)


def cont(nivel, base, iv, q):
    return nivel / 100.0 * (base + 2 * iv) * q ** 0.8


def faixa(K, mult=1.0, depois=1.0):
    """Valores possíveis com r em [0,85; 1,00] (passos finos)."""
    vals = set()
    for i in range(0, 151):
        r = 0.85 + 0.15 * i / 150
        v = jsr(K * r)
        if depois != 1.0:
            v = jsr(v * depois)
        vals.add(int(v * mult))
    return vals


def K(nivel, poder, a, d, stab):
    return (2 * nivel / 5 + 2) * poder * a / d / 50 * stab


def explica(var, d, iv_v, iv_g):
    ok = tot = 0
    for grupo, base, q, poder, stab, exib, iv in ((G11, 50, 1.72, 40, 1.5, VUL_EXIB, iv_v), (GEO, 80, 1.137, 50, 1.0, GEO_EXIB, iv_g)):
        for nv, obs in grupo.items():
            a = cont(nv, base, iv, q)
            if jsr(a) != exib[nv]:
                return -1, 0          # IV incompatível com o stat exibido
            if var in ("x2exib", "exib"):
                a = exib[nv]
            if var == "atual":
                a = max(a, 3.0)
            mult = 2.0 if var in ("x2", "x2exib") and nv == 1 else 1.0
            pos = faixa(K(nv, poder, a, d, stab), mult)
            for v, n in obs.items():
                tot += n
                ok += n if v in pos else 0
    return ok, tot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--md")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    linhas = ["| Variante | Melhor defesa comum do Rattata nível 1 | IV SpA Vulpix | IV Atk Geodude | Golpes explicados |", "| --- | --- | --- | --- | --- |"]
    for var in ("atual", "x2", "x2exib", "exib"):
        melhor = (-1, None)
        for i in range(20, 201):
            d = i / 100
            for iv_v in range(1, 33):
                for iv_g in range(1, 33):
                    ok, tot = explica(var, d, iv_v, iv_g)
                    if ok > melhor[0]:
                        melhor = (ok, (d, iv_v, iv_g, tot))
        ok, (d, iv_v, iv_g, tot) = melhor
        linhas.append(f"| {var} | {d:.2f} | {iv_v} | {iv_g} | {ok}/{tot} ({100 * ok / tot:.1f}%) |")
    # Rattata no Vulpix: ataque comum do Rattata, defesa contínua do Vulpix (IV de Def varrido)
    linhas += ["", "Tackle do Rattata nível 1 no Vulpix (A comum, ×1,8 depois do arredondamento ou junto):", "",
               "| ×1,8 | Melhor ataque comum | IV Def Vulpix | Golpes explicados |", "| --- | --- | --- | --- |"]
    for depois in (True, False):
        melhor = (-1, None)
        for i in range(20, 401):
            atk = i / 100
            for iv in range(1, 33):
                if any(jsr(cont(nv, 40, iv, 1.72)) != VUL_DEF_EXIB[nv] for nv in VUL_DEF_EXIB):
                    continue
                ok = tot = 0
                for nv, obs in RAT_EM_VULPIX.items():
                    dd = cont(nv, 40, iv, 1.72)
                    k = K(1, 50, atk, dd, 1.5)
                    pos = faixa(k, 1.0, 1.8) if depois else faixa(k * 1.8)
                    for v, n in obs.items():
                        tot += n
                        ok += n if v in pos else 0
                if ok > melhor[0]:
                    melhor = (ok, (atk, iv, tot))
        ok, (atk, iv, tot) = melhor
        linhas.append(f"| {'depois' if depois else 'junto'} | {atk:.2f} | {iv} | {ok}/{tot} |")
    txt = "\n".join(linhas)
    print(txt)
    if a.md:
        open(a.md, "w", encoding="utf-8", newline="\n").write(txt + "\n")


if __name__ == "__main__":
    main()
