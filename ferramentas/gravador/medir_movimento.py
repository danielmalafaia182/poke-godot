#!/usr/bin/env python3
"""Investigação de movimento (fase 1, item aberto): mede nas gravações (A) e na simulação o comportamento espacial.

Por field (só a hunt pedida, herói vivo):
  1. adjacentes: quantos selvagens vivos estão a Chebyshev ≤ 1 do herói;
  2. na visão: quantos vivos estão dentro da área de visão (±13 colunas, ±13 linhas: borda medida, A; antes ±7);
     perseguindo: quantos desses, fora do alcance (Chebyshev > 1), se moveram para mais perto do herói desde o field
     anterior (só pares com Δseq = 2);
  3. coleira: selvagens vivos FORA da visão — fração que se move por intervalo de 400 ms e, quando se move, se
     aproxima do próprio spawn (posição em que reaparece depois de morrer) ou se afasta; distância ao spawn;
  4. caminho do herói até o alvo: de cada troca de alvo até o primeiro field lutando — tiles andados (soma de
     Chebyshev entre fields), Chebyshev inicial até o alvo e a razão entre os dois (1,0 = caminho reto).
Uso: python medir_movimento.py gravação.jsonl [...] [--slug rhydon] [--json saída.json]
"""
import argparse
import json
import os
import statistics
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402

VISAO_X, VISAO_Y = 13, 13   # A desde 10/11/2026 (perseguição até 13 nos dois eixos); antes 13, 7


def cheb(a, b):
    return max(abs(a["row"] - b["row"]), abs(a["col"] - b["col"]))


def na_visao(x, h):
    return abs(x["col"] - h["col"]) <= VISAO_X and abs(x["row"] - h["row"]) <= VISAO_Y


def medir(caminhos, slug):
    adj, visao, persegue = Counter(), Counter(), Counter()
    fora = Counter()            # "parado" | "aproxima_spawn" | "afasta_spawn" | "lateral"
    dist_spawn_fora = []
    caminhos_heroi = []         # (tiles andados, chebyshev inicial, ms)
    spawn = {}
    atual, ant = None, None
    busca = None                # [tiles, cheb0, t0, alvo]
    for d, m, _ in ler_logs(caminhos):
        if d != "in":
            continue
        t = m["type"]
        if t == "field-init":
            atual, ant, busca = m.get("slug"), None, None
            continue
        if t != "field" or atual != slug:
            continue
        if m.get("fainted") or m.get("heroHp", 1) <= 0:
            ant = None
            continue
        h = m["hero"]
        vivos = [x for x in m["mobs"] if not x["dead"]]
        adj[sum(1 for x in vivos if cheb(x, h) <= 1)] += 1
        dentro = [x for x in vivos if na_visao(x, h)]
        visao[len(dentro)] += 1
        consecutivo = ant is not None and m["seq"] - ant["seq"] == 2
        pa = {x["slot"]: x for x in ant["mobs"]} if ant else {}
        if ant:
            for x in m["mobs"]:
                p = pa.get(x["slot"])
                if p and p["dead"] and not x["dead"]:
                    spawn[x["slot"]] = (x["row"], x["col"])   # reapareceu aqui
        if consecutivo:
            hp = ant["hero"]
            n = 0
            for x in dentro:
                p = pa.get(x["slot"])
                if p and not p["dead"] and cheb(x, h) > 1 and cheb(x, h) < cheb(p, hp):
                    n += 1
            persegue[n] += 1
            for x in vivos:
                p = pa.get(x["slot"])
                if not p or p["dead"] or na_visao(p, hp) or x["slot"] not in spawn:
                    continue
                s = {"row": spawn[x["slot"]][0], "col": spawn[x["slot"]][1]}
                d0, d1 = cheb(p, s), cheb(x, s)
                dist_spawn_fora.append(d0)
                if (p["row"], p["col"]) == (x["row"], x["col"]):
                    fora["parado"] += 1
                elif d1 < d0:
                    fora["aproxima_spawn"] += 1
                elif d1 > d0:
                    fora["afasta_spawn"] += 1
                else:
                    fora["lateral"] += 1
        # caminho do herói até o alvo
        alvo = next((x for x in m["mobs"] if x["slot"] == m.get("targetSlot") and not x["dead"]), None)
        if busca and (alvo is None or alvo["slot"] != busca[3]):
            busca = None
        if alvo and busca is None and not m.get("fighting") and cheb(alvo, h) > 1:
            busca = [0, cheb(alvo, h), m["serverNow"], alvo["slot"], (h["row"], h["col"])]
        elif busca and ant:
            busca[0] += max(abs(h["row"] - ant["hero"]["row"]), abs(h["col"] - ant["hero"]["col"]))
            if m.get("fighting"):
                if busca[0] > 0:
                    caminhos_heroi.append((busca[0], busca[1], m["serverNow"] - busca[2]))
                busca = None
        ant = m
    return adj, visao, persegue, fora, dist_spawn_fora, caminhos_heroi


def dist(c):
    tot = sum(c.values())
    return {"n": tot, "media": round(sum(k * v for k, v in c.items()) / tot, 3) if tot else None,
            "distribuicao": {k: round(v / tot, 3) for k, v in sorted(c.items())}}


def resumo(caminhos, slug):
    adj, visao, persegue, fora, dsp, cam = medir(caminhos, slug)
    tf = sum(fora.values())
    r = {"adjacentes_por_field": dist(adj), "na_visao_por_field": dist(visao),
         "perseguindo_por_field": dist(persegue),
         "fora_da_visao": {"intervalos": tf, **({k: round(v / tf, 3) for k, v in fora.items()} if tf else {}),
                           "dist_spawn_mediana": statistics.median(dsp) if dsp else None,
                           "dist_spawn_p90": sorted(dsp)[int(0.9 * len(dsp))] if dsp else None},
         "caminho_heroi": {"n": len(cam)}}
    if cam:
        razoes = sorted(a / b for a, b, _ in cam if b)
        r["caminho_heroi"].update({
            "tiles_mediana": statistics.median(a for a, _, _ in cam),
            "cheb_inicial_mediana": statistics.median(b for _, b, _ in cam),
            "razao_tiles_por_cheb_mediana": round(statistics.median(razoes), 3),
            "razao_p90": round(razoes[int(0.9 * len(razoes))], 3),
            "ms_mediana": statistics.median(t for _, _, t in cam),
            "ms_por_tile_mediana": round(statistics.median(t / a for a, _, t in cam), 1)})
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+")
    ap.add_argument("--slug", default="rhydon")
    ap.add_argument("--visao", default="13x13", help="meias-larguras da caixa de visão, colunas x linhas (A: 13x13; antes 13x7)")
    ap.add_argument("--json")
    a = ap.parse_args()
    global VISAO_X, VISAO_Y
    VISAO_X, VISAO_Y = (int(v) for v in a.visao.lower().split("x"))
    sys.stdout.reconfigure(encoding="utf-8")
    r = resumo(a.arquivos, a.slug)
    print(json.dumps(r, ensure_ascii=False, indent=1))
    if a.json:
        with open(a.json, "w", encoding="utf-8", newline="\n") as f:
            json.dump(r, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
