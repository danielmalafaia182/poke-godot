#!/usr/bin/env python3
"""Fase 4 (15/11): a defesa do selvagem no dano depende do indivíduo? Para cada gravação × espécie selvagem × golpe do
aliado, acha o intervalo de defesa contínua que explica TODOS os golpes de cada indivíduo (fórmula da sim, variante e,
com o piso de ataque do aliado) e cruza os intervalos dos indivíduos. Intervalo comum não vazio = um valor só serve para
todos; vazio = os indivíduos diferem de verdade.

Uso: python -I ferramentas/fase4/stat_comum.py [--piso_ataque 3]
"""
import argparse
import glob
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ajustar_dano as AD   # noqa: E402

R = AD.R


def intervalo(am, g, nivel, a, stab, eff, piso_a):
    """Menor e maior D (contínua) que põem todos os danos `am` no envelope [0,85; 1,00]."""
    a = max(a, piso_a)
    k0 = (2.0 * nivel / 5.0 + 2.0) * g["poder"] * a / 50.0 * (1.5 if stab else 1.0) * eff
    lo, hi = 0.0, float("inf")
    for amt in am:
        if amt <= 2:
            continue   # no piso não informa
        # round(k0/D × r) = amt com r em [0,85; 1] ⇒ k0/D × 1 ≥ amt − 0,5 e k0/D × 0,85 ≤ amt + 0,5 (aprox. do round)
        hi = min(hi, k0 / (amt - 0.5))
        lo = max(lo, k0 * 0.85 / (amt + 0.5))
    return lo, hi


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--piso_ataque", type=float, default=3.0)
    a = ap.parse_args()
    especies = {e["id"]: e for e in R.carregar(os.path.join(AD.RAIZ, "dados", "gerados", "especies.json"))}
    base = os.path.join(AD.RAIZ, "poke har", "gravacoes")
    arquivos = sorted(set(glob.glob(os.path.join(base, "*.jsonl")) + glob.glob(os.path.join(base, "fase3", "*.jsonl"))
                          + glob.glob(os.path.join(base, "fase 4", "*.jsonl"))))
    arquivos = [x for x in arquivos if "gravacoes_unicas" not in x]
    grupos = defaultdict(list)   # (arquivo, espécie, golpe, nível do aliado) -> [(lo, hi, n)]
    for f in arquivos:
        for (arq, hk, slot, sid), e in AD.coletar(f).items():
            esp = especies.get(sid)
            if not esp:
                continue
            por = defaultdict(list)
            for golpe, tipo, eff, amt, h in e["aliado"]:
                por[(golpe, tipo, eff, h["level"], h["speciesId"], h["stats"]["atk"], h["stats"]["spAtk"])].append(amt)
            for (golpe, tipo, eff, nivel, sid_h, atk, spa), am in por.items():
                esp_h = especies.get(sid_h)
                g = next((x for x in (esp_h or {}).get("golpes", []) if x["nome"] == golpe), None)
                if not g or int(g.get("poder", 0)) <= 0 or eff == 0:
                    continue
                especial = g["categoria"] == "SPECIAL"
                lo, hi = intervalo(am, g, nivel, spa if especial else atk, tipo in esp_h["tipos"], eff, a.piso_ataque)
                if lo < hi and len([x for x in am if x > 2]) >= 2:
                    grupos[(arq, esp["nome"], golpe, nivel)].append((lo, hi, len(am)))
    print("| gravação | selvagem | golpe | nível do aliado | indivíduos | intervalo comum de D | menor janela | maior janela |")
    print("|---|---|---|---|---|---|---|---|")
    for k, v in sorted(grupos.items()):
        if len(v) < 3:
            continue
        lo = max(x[0] for x in v)
        hi = min(x[1] for x in v)
        larg = sorted(x[1] - x[0] for x in v)
        comum = "%.3f–%.3f" % (lo, hi) if lo <= hi else "**vazio** (%.3f > %.3f)" % (lo, hi)
        print("| %s | %s | %s | %s | %d | %s | %.3f | %.3f |" % (k[0], k[1], k[2], k[3], len(v), comum, larg[0], larg[-1]))


if __name__ == "__main__":
    main()
