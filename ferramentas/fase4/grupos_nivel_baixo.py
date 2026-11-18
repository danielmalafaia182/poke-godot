#!/usr/bin/env python3
"""Golpes de nível baixo agrupados por (atacante, nível do atacante, golpe, defensor, nível do defensor) — A.

Para cada gravação: o líder (pokes.list / pokes-chunk / poke-delta com leader) e o nível dele no instante; os golpes do
aliado nos selvagens e dos selvagens no aliado (só com um selvagem encostado). Guarda os stats exibidos, quality e
ivTotal do aliado. Saída: JSON com os grupos e o conjunto de valores observados (para `ajuste_nivel1.py`).

Uso: python -I ferramentas/fase4/grupos_nivel_baixo.py <gravações...> --json saida.json [--nivel_max 4]
"""
import argparse
import json
import os
import sys
from collections import Counter, defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402


def cheb(a, b):
    return max(abs(a["row"] - b["row"]), abs(a["col"] - b["col"]))


def coletar(caminho, nivel_max):
    pokes = {}
    lider = None
    nivel_hunt = None
    grupos = defaultdict(Counter)
    meta = {}
    for d, m, _ in ler_logs([caminho]):
        if d != "in":
            continue
        t = m.get("type")
        if t in ("pokes", "pokes-chunk"):
            for p in m.get("list", m.get("pokes", [])):
                pokes[p["id"]] = p
                if p.get("leader"):
                    lider = p["id"]
            continue
        if t == "poke-delta":
            p = m["poke"]
            if p["id"] in pokes or p.get("team"):
                pokes[p["id"]] = p
                if p.get("leader"):
                    lider = p["id"]
            continue
        if t == "field-init":
            nivel_hunt = None
            continue
        if t != "field" or lider is None:
            continue
        al = pokes[lider]
        h = m["hero"]
        adj = [x for x in m["mobs"] if not x["dead"] and cheb(x, h) <= 1]
        for hit in m.get("hits", []):
            if hit["slot"] >= 0:
                x = next((y for y in m["mobs"] if y["slot"] == hit["slot"]), None)
                if not x:
                    continue
                k = ("aliado", al["speciesId"], al["level"], hit.get("move"), x["speciesId"], x["maxHp"])
            elif len(adj) == 1:
                x = adj[0]
                k = ("selvagem", x["speciesId"], x["maxHp"], hit.get("move"), al["speciesId"], al["level"])
            else:
                continue
            if (k[0] == "aliado" and al["level"] <= nivel_max) or (k[0] == "selvagem" and al["level"] <= nivel_max):
                grupos[k][hit["amount"]] += 1
                meta[str(k)] = {"aliado": {"speciesId": al["speciesId"], "name": al.get("name"), "level": al["level"],
                                           "stats": al.get("stats"), "quality": al.get("quality"), "ivTotal": al.get("ivTotal")},
                                "eff": hit.get("eff"), "type": hit.get("type")}
    return [{"gravacao": os.path.basename(caminho), "lado": k[0], "chave": list(k), "valores": dict(sorted(v.items())),
             "n": sum(v.values()), **meta[str(k)]} for k, v in grupos.items()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+")
    ap.add_argument("--json", required=True)
    ap.add_argument("--nivel_max", type=int, default=4)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    todos = []
    for c in a.arquivos:
        todos += coletar(c, a.nivel_max)
    with open(a.json, "w", encoding="utf-8", newline="\n") as f:
        json.dump(todos, f, ensure_ascii=False, indent=1)
    for g in todos:
        if g["n"] >= 3:
            print(g["gravacao"], g["lado"], g["chave"], g["n"], g["valores"], "| aliado", g["aliado"]["name"], g["aliado"]["level"],
                  g["aliado"]["stats"], g["aliado"]["quality"], g["aliado"]["ivTotal"], "eff", g["eff"])


if __name__ == "__main__":
    main()
