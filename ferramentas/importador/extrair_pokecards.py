#!/usr/bin/env python3
"""Pokécards (A, snapshot game/pokecards.json) → dados/gerados/pokecards.json: os 3 sets e as 430 cartas (id, set, num,
name, rarity), como o jogo lê em sim/servico_cards.gd. Determinístico; não editar o gerado à mão.
Uso: python -I ferramentas/importador/extrair_pokecards.py [pasta do snapshot]
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
snap = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "poke har/extraido/snapshot_2026-11-09")
d = json.load(open(os.path.join(snap, "game/pokecards.json"), encoding="utf-8"))
saida = {"_fonte": "snapshot game/pokecards.json (A), versão %s" % d.get("version"),
         "sets": d["sets"], "cards": [{k: c[k] for k in ("id", "set", "num", "name", "rarity")} for c in d["cards"]]}
with open(os.path.join(RAIZ, "dados/gerados/pokecards.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(saida, f, ensure_ascii=False, indent=1, sort_keys=True)
    f.write("\n")
print(len(saida["sets"]), "sets,", len(saida["cards"]), "cartas")
