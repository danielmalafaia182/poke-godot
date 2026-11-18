#!/usr/bin/env python3
"""Movimento real × sim (escopo de 18/11, item 5): as grandezas do desvio conhecido, com as mesmas ferramentas dos dois lados.

Casos (A = gravações reais; sim = 3 sementes × 30 min do estado inicial de cada gravação, com `visao_meia_altura` 7 e 13):
  rhydon-1h (Venusaur, luta ~3 s), M1/M2 (Kangaskhan, luta ~22 s), M3 (Rhydon, Golem, 1 golpe).
Grandezas: chegadas de não-alvos por minuto, adjacentes por field, perseguindo por field (medir_movimento.py, caixa 13×13),
ms por tile do herói andando e do selvagem perseguindo (analisar_gravacao.py, as do diferencial).
As saídas da sim saem de testes/rodar_sim.gd em saida_testes/mov/<estado>_v<7|13>_s<1..3>.jsonl.

Uso: python -I ferramentas/fase4/comparar_movimento.py [--md dados/relatorios/movimento_<data>.md]
"""
import argparse
import glob
import io
import os
import statistics
import sys
from contextlib import redirect_stdout

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "gravador"))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
import medir_movimento  # noqa: E402
import comparar_sim  # noqa: E402

GRAV = os.path.join(RAIZ, "poke har", "gravacoes")
CASOS = [
    ("rhydon-1h (Venusaur, luta curta)", ["rhydon-1h.jsonl"], "rhydon", 112, "rhydon_venusaur_1h"),
    ("M1 (Kangaskhan, luta longa)", ["fase3/M1.jsonl"], "kangaskhan", 115, "kangaskhan_venusaur_m2"),
    ("M2 (Kangaskhan, luta longa)", ["fase3/M2.jsonl"], "kangaskhan", 115, "kangaskhan_venusaur_m2"),
    ("M3 (Rhydon, Golem, 1 golpe)", ["fase3/M3.jsonl"], "rhydon", 112, "rhydon_golem_m3"),
]


def grandezas(arquivos, slug, especie):
    medir_movimento.VISAO_X, medir_movimento.VISAO_Y = 13, 13
    r = medir_movimento.resumo(arquivos, slug)
    with redirect_stdout(io.StringIO()):
        a = comparar_sim.resumo(comparar_sim.coletar(arquivos, slug, especie))
    return {"chegadas": r["chegadas_nao_alvo_por_min"], "adjacentes": r["adjacentes_por_field"]["media"],
            "perseguindo": r["perseguindo_por_field"]["media"], "heroi_ms_tile": round(a["heroi_ms_tile"]), "mob_ms_tile": round(a["mob_ms_tile"])}


def faixa(vals):
    vals = [v for v in vals if v is not None]
    if not vals:
        return "—"
    return f"{statistics.mean(vals):.2f} ({min(vals):.2f}–{max(vals):.2f})" if max(vals) < 50 else f"{statistics.mean(vals):.0f} ({min(vals):.0f}–{max(vals):.0f})"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--md")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    nomes = [("chegadas", "Chegadas de não-alvos / min"), ("adjacentes", "Adjacentes por field"), ("perseguindo", "Perseguindo por field"),
             ("heroi_ms_tile", "Herói: ms por tile"), ("mob_ms_tile", "Selvagem: ms por tile perseguindo")]
    linhas = ["| Caso | Grandeza | Real | Sim 7 (3 sementes) | Sim 13 (3 sementes) |", "| --- | --- | --- | --- | --- |"]
    for titulo, arqs, slug, especie, estado in CASOS:
        real = grandezas([os.path.join(GRAV, x) for x in arqs], slug, especie)
        sims = {}
        for v in (7, 13):
            fs = sorted(glob.glob(os.path.join(RAIZ, "saida_testes", "mov", f"{estado}_v{v}_s*.jsonl")))
            sims[v] = [grandezas([f], slug, especie) for f in fs]
        for k, nome in nomes:
            rv = real[k]
            linhas.append(f"| {titulo} | {nome} | {rv if rv is not None else '—'} | {faixa([s[k] for s in sims[7]])} | {faixa([s[k] for s in sims[13]])} |")
    txt = "\n".join(linhas)
    print(txt)
    if a.md:
        with open(a.md, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt + "\n")


if __name__ == "__main__":
    main()
