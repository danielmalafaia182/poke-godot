#!/usr/bin/env python3
"""Escolha de alvo do herói nas gravações (A): mais próximo em Chebyshev × mais próximo pelo caminho.

Para cada troca de `targetSlot` num field (novo alvo não nulo, herói vivo), com as posições desse field:
  - candidatos = selvagens vivos e fora do respawn;
  - Chebyshev: distância em linha reta do herói ao selvagem;
  - caminho: tempo mínimo na grade do field-init (passo reto 600 ms, diagonal 1000 ms: medidos, A) até qualquer tile
    livre a Chebyshev ≤ 1 do selvagem (0 se já encostado); os outros selvagens não bloqueiam (F, aproximação);
  - acerto de cada critério = o alvo escolhido está entre os empatados no menor valor.
Conta à parte os casos em que os dois critérios discordam (os que decidem). Sem caminho = infinito.

Uso: python -I ferramentas/gravador/medir_alvo.py <gravações...> [--slug X] [--detalhe]
"""
import argparse
import heapq
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402

RETO, DIAG = 600, 1000
INF = float("inf")


def cheb(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def campo(grade, origem):
    rows, cols = len(grade), len(grade[0])
    dist = {origem: 0}
    fila = [(0, origem)]
    while fila:
        d, (r, c) = heapq.heappop(fila)
        if d > dist.get((r, c), INF):
            continue
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if not dr and not dc:
                    continue
                nr, nc = r + dr, c + dc
                if 0 <= nr < rows and 0 <= nc < cols and grade[nr][nc]:
                    nd = d + (DIAG if dr and dc else RETO)
                    if nd < dist.get((nr, nc), INF):
                        dist[(nr, nc)] = nd
                        heapq.heappush(fila, (nd, (nr, nc)))
    return dist


def tempo_ate(dist, grade, heroi, mob):
    if cheb(heroi, mob) <= 1:
        return 0
    melhor = INF
    for dr in (-1, 0, 1):
        for dc in (-1, 0, 1):
            t = (mob[0] + dr, mob[1] + dc)
            if t != mob and t in dist:
                melhor = min(melhor, dist[t])
    return melhor


def medir(caminhos, slug_filtro=None, detalhe=False):
    por_slug = defaultdict(Counter)
    grade, slug, ant_alvo = None, None, None
    for d, m, fonte in ler_logs(caminhos):
        if d != "in":
            continue
        t = m.get("type")
        if t == "field-init":
            grade, slug, ant_alvo = m.get("grid"), m.get("slug"), None
            continue
        if t != "field" or grade is None or (slug_filtro and slug != slug_filtro):
            continue
        alvo = m.get("targetSlot")
        if m.get("fainted") or alvo is None or alvo == ant_alvo:
            ant_alvo = alvo
            continue
        ant_alvo = alvo
        h = (m["hero"]["row"], m["hero"]["col"])
        cand = {x["slot"]: (x["row"], x["col"]) for x in m["mobs"] if not x["dead"] and not x.get("respawning")}
        if alvo not in cand or len(cand) < 2:
            continue
        dist = campo(grade, h)
        ch = {s: cheb(h, p) for s, p in cand.items()}
        tp = {s: tempo_ate(dist, grade, h, p) for s, p in cand.items()}
        ok_ch = ch[alvo] == min(ch.values())
        ok_tp = tp[alvo] == min(tp.values())
        c = por_slug[slug]
        c["trocas"] += 1
        c["cheb"] += ok_ch
        c["caminho"] += ok_tp
        cheb_set = {s for s in ch if ch[s] == min(ch.values())}
        tp_set = {s for s in tp if tp[s] == min(tp.values())}
        if cheb_set != tp_set:
            c["discordam"] += 1
            c["discordam_cheb"] += ok_ch
            c["discordam_caminho"] += ok_tp
            if detalhe:
                print(f"  {slug} {os.path.basename(fonte) if isinstance(fonte, str) else fonte} seq {m.get('seq')}: alvo {alvo} "
                      f"cheb {ch[alvo]} (mín {min(ch.values())}) caminho {tp[alvo]} (mín {min(tp.values())})")
    return por_slug


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gravacoes", nargs="+")
    ap.add_argument("--slug")
    ap.add_argument("--detalhe", action="store_true")
    a = ap.parse_args()
    r = medir(a.gravacoes, a.slug, a.detalhe)
    tot = Counter()
    print("| Hunt | Trocas | Chebyshev acerta | Caminho acerta | Discordam | Chebyshev nelas | Caminho nelas |")
    print("| --- | --- | --- | --- | --- | --- | --- |")
    for s, c in sorted(r.items(), key=lambda kv: -kv[1]["trocas"]):
        tot.update(c)
        print(f"| {s} | {c['trocas']} | {c['cheb']} | {c['caminho']} | {c['discordam']} | {c['discordam_cheb']} | {c['discordam_caminho']} |")
    print(f"| **total** | {tot['trocas']} | {tot['cheb']} | {tot['caminho']} | {tot['discordam']} | {tot['discordam_cheb']} | {tot['discordam_caminho']} |")


if __name__ == "__main__":
    main()
