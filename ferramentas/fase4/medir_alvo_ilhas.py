#!/usr/bin/env python3
"""Alvo do herói quando só sobram selvagens inalcançáveis (parâmetro `alvo_so_alcancavel`, F).

Com a grade do field-init de cada SESSÃO (as gravações livres têm duas contas gravando juntas: a grade de uma não vale
para os fields da outra), calcula a ilha do herói (8-conexa) e, em cada field, os selvagens vivos alcançáveis (algum
tile livre a Chebyshev ≤ 1 dele na ilha do herói). Conta:
  com_inalcancavel_vivo  fields com algum vivo inalcançável
  alvo_inalcancavel      targetSlot aponta para um inalcançável
  so_inalcancaveis       nenhum vivo alcançável e algum inalcançável — o único caso em que o parâmetro decide:
    so_inal_alvo_nulo    targetSlot nulo (= alvo_so_alcancavel true)
    so_inal_alvo_inal    targetSlot num inalcançável (= false)
    so_inal_outro        targetSlot num slot morto/respawnando

Resultado em 23/11/2026 (todas as gravações, 193.466 fields): o caso nunca aparece (só 23 fields com um inalcançável
vivo, na geodude-10min, nunca alvo). Fecha com uma gravação de hunt com spawn isolado: togepi (4 de 15), horsea (3),
goldeen (2) — `testes/diag_ilhas.gd` lista as 31 hunts com spawn em outra ilha.

Uso: python -I ferramentas/fase4/medir_alvo_ilhas.py [pasta das gravações]
"""
import glob
import json
import os
import sys
from collections import Counter, deque

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def ilha(grid, r0, c0):
    R, C = len(grid), len(grid[0])
    vis = {(r0, c0)}
    q = deque([(r0, c0)])
    while q:
        r, c = q.popleft()
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                rr, cc = r + dr, c + dc
                if (dr or dc) and 0 <= rr < R and 0 <= cc < C and grid[rr][cc] and (rr, cc) not in vis:
                    vis.add((rr, cc))
                    q.append((rr, cc))
    return vis


def alcanca(isl, r, c):
    return any((r + dr, c + dc) in isl for dr in (-1, 0, 1) for dc in (-1, 0, 1))


def medir(arq):
    est = {}
    c = Counter()
    with open(arq, encoding="utf-8", errors="replace") as f:
        for linha in f:
            if '"field-init"' not in linha and '"type":"field"' not in linha:
                continue
            try:
                reg = json.loads(linha)
                m = reg["msg"]
            except Exception:
                continue
            if not isinstance(m, dict):
                continue
            se = est.setdefault(reg.get("sessao", ""), {"grid": None, "isl": None, "slug": None})
            if m.get("type") == "field-init":
                se.update(grid=m.get("grid"), isl=None, slug=m.get("slug"))
                continue
            grid, isl = se["grid"], se["isl"]
            if m.get("type") != "field" or grid is None or not m.get("hero"):
                continue
            h = m["hero"]
            if isl is None or (h["row"], h["col"]) not in isl:
                if not (0 <= h["row"] < len(grid) and 0 <= h["col"] < len(grid[0])):
                    continue
                isl = se["isl"] = ilha(grid, h["row"], h["col"])
            vivos = [x for x in m.get("mobs", []) if not x.get("dead") and not x.get("respawning")]
            if not vivos:
                continue
            alc = {x["slot"] for x in vivos if alcanca(isl, x["row"], x["col"])}
            inal = {x["slot"] for x in vivos} - alc
            ts = m.get("targetSlot")
            c["fields"] += 1
            if inal:
                c["com_inalcancavel_vivo"] += 1
            if ts in inal:
                c["alvo_inalcancavel"] += 1
            if inal and not alc:
                c["so_inalcancaveis"] += 1
                c["slug:%s" % se["slug"]] += 1
                c["so_inal_alvo_nulo" if ts in (None, -1) else ("so_inal_alvo_inal" if ts in inal else "so_inal_outro")] += 1
    return c


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    base = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "poke har", "gravacoes")
    tot = Counter()
    for arq in sorted(glob.glob(os.path.join(base, "**", "*.jsonl"), recursive=True)):
        if "gravacoes_unicas" in arq:
            continue
        c = medir(arq)
        if c["com_inalcancavel_vivo"]:
            print(os.path.relpath(arq, base), dict(c))
        tot.update(c)
    print("TOTAL", dict(tot))


if __name__ == "__main__":
    main()
