#!/usr/bin/env python3
"""Tabela espécie → cadáver a partir das gravações (fonte A). Gera dados/corpos_observados.json (não editar à mão).

O cliente original não sabe qual cadáver cada espécie deixa: o servidor manda o id em `field.corpses[{row,col,corpse}]`
e o cliente só desenha (corpses.json + atlas). Aqui cada cadáver é ligado ao selvagem morto naquele tile no mesmo field.
Separado por shiny (A: Rhydon shiny deixa 31489, o normal 2858). Uso:
  python ferramentas/gravador/extrair_cadaveres.py "poke har/gravacoes/*.jsonl" "*.jsonl" [--saida dados/corpos_observados.json]
"""
import argparse
import json
import os
import sys
from collections import Counter, defaultdict

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
from gerar_protocolo import expandir, ler_logs  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--saida", default=os.path.join(RAIZ, "dados", "corpos_observados.json"))
    a = ap.parse_args()
    arquivos = expandir(a.logs)
    vistos = defaultdict(Counter)
    for d, m, _ in ler_logs(arquivos):
        if d != "in" or m.get("type") != "field":
            continue
        mortos = {(x["row"], x["col"]): x for x in m.get("mobs", []) if x.get("dead")}
        for c in m.get("corpses", []):
            x = mortos.get((c["row"], c["col"]))
            if x:
                vistos[(int(x["speciesId"]), bool(x.get("shiny", False)))][int(c["corpse"])] += 1
    normal, shiny, conflitos = {}, {}, {}
    for (sid, sh), cont in sorted(vistos.items()):
        corpo, n = cont.most_common(1)[0]
        (shiny if sh else normal)[str(sid)] = corpo
        if len(cont) > 1:
            conflitos["%d%s" % (sid, "*" if sh else "")] = dict(cont)
    saida = {"formato": "poke-corpos-observados-v1",
             "nota": "Gerado por ferramentas/gravador/extrair_cadaveres.py (fonte A). speciesId -> id do cadáver em "
                     "game/corpses/corpses.json. Espécie ausente = nunca vista morrendo nas gravações.",
             "fontes": [os.path.basename(f) for f in arquivos], "normal": normal, "shiny": shiny, "conflitos": conflitos}
    with open(a.saida, "w", encoding="utf-8", newline="\n") as f:
        json.dump(saida, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(json.dumps({"normal": normal, "shiny": shiny, "conflitos": conflitos}))


if __name__ == "__main__":
    main()
