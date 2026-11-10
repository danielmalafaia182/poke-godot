#!/usr/bin/env python3
"""Tabela espécie → cadáver alimentada pelas gravações (fonte A): dados/corpos_por_especie.json.

Não existe padrão que ligue espécie e cadáver nos dados públicos: creatures.json não tem campo de cadáver, a ordem dos
ids em game/corpses/corpses.json não segue a Pokédex nem o looktype, o cliente original só desenha o id que o servidor
manda em `field.corpses[{row,col,corpse}]` e o hunt.py do poke-local usa um id fixo (2989). Os cadáveres são o próprio
Pokémon desmaiado, então o vínculo é por espécie, mas só o servidor o conhece.

Cada cadáver de um `field` é ligado ao selvagem morto naquele tile no mesmo field (speciesId e shiny). A ferramenta é
INCREMENTAL: soma as observações das gravações novas ao arquivo existente; cada gravação entra uma vez (sha256 do
arquivo guardado em "fontes"). Não editar o JSON à mão; rode de novo com as gravações.

Uso:
  python -I ferramentas/gravador/atualizar_corpos.py                       # todas as gravações conhecidas
  python -I ferramentas/gravador/atualizar_corpos.py caminho/nova.jsonl    # só as dadas (somadas ao que já existe)
Saída (por espécie): {"corpo": id mais visto, "n": aparições em fields (um cadáver aparece em vários fields), "contagem": {id: n}}; "shiny" à parte; "conflitos"
lista espécies vistas com mais de um id.
"""
import argparse
import hashlib
import json
import os
import sys
from collections import Counter, defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
from gerar_protocolo import expandir, ler_logs  # noqa: E402

PADRAO = [os.path.join(RAIZ, "poke har", "gravacoes", "*.jsonl"), os.path.join(RAIZ, "*.jsonl")]
FORMATO = "poke-corpos-por-especie-v1"


def sha(caminho):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def observar(arquivo):
    """{(speciesId, shiny): Counter(corpse)} de uma gravação."""
    vistos = defaultdict(Counter)
    for d, m, _ in ler_logs([arquivo]):
        if d != "in" or m.get("type") != "field":
            continue
        mortos = {(x["row"], x["col"]): x for x in m.get("mobs", []) if x.get("dead")}
        for c in m.get("corpses", []) or []:
            x = mortos.get((c.get("row"), c.get("col")))
            if x and c.get("corpse") is not None:
                vistos[(int(x["speciesId"]), bool(x.get("shiny", False)))][int(c["corpse"])] += 1
    return vistos


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="*")
    ap.add_argument("--saida", default=os.path.join(RAIZ, "dados", "corpos_por_especie.json"))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    atual = {"formato": FORMATO, "fontes": {}, "normal": {}, "shiny": {}}
    if os.path.exists(a.saida):
        with open(a.saida, encoding="utf-8") as f:
            atual = json.load(f)
    contagens = defaultdict(Counter)
    for grupo, sh in (("normal", False), ("shiny", True)):
        for sid, e in atual.get(grupo, {}).items():
            for corpo, n in e.get("contagem", {}).items():
                contagens[(int(sid), sh)][int(corpo)] += int(n)
    fontes = dict(atual.get("fontes", {}))
    novas, repetidas = [], []
    for arq in expandir(a.logs or PADRAO):
        h = sha(arq)
        if h in fontes.values():
            repetidas.append(os.path.basename(arq))
            continue
        for k, c in observar(arq).items():
            contagens[k].update(c)
        fontes[os.path.basename(arq)] = h
        novas.append(os.path.basename(arq))
    saida = {"formato": FORMATO,
             "nota": "Gerado por ferramentas/gravador/atualizar_corpos.py (fonte A: field.corpses das gravações, ligado ao "
                     "selvagem morto no tile). speciesId -> id em game/corpses/corpses.json. Espécie ausente nunca foi vista "
                     "morrendo; a simulação usa então o normal (shiny, F) ou o genérico (corpse 0, E).",
             "fontes": dict(sorted(fontes.items())), "normal": {}, "shiny": {}, "conflitos": {}}
    for (sid, sh), cont in sorted(contagens.items()):
        corpo, _ = cont.most_common(1)[0]
        saida["shiny" if sh else "normal"][str(sid)] = {"corpo": corpo, "n": sum(cont.values()),
                                                         "contagem": {str(k): v for k, v in sorted(cont.items())}}
        if len(cont) > 1:
            saida["conflitos"]["%d%s" % (sid, "*" if sh else "")] = {str(k): v for k, v in sorted(cont.items())}
    with open(a.saida, "w", encoding="utf-8", newline="\n") as f:
        json.dump(saida, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(json.dumps({"novas": novas, "ja_somadas": repetidas, "especies_normal": len(saida["normal"]),
                      "especies_shiny": len(saida["shiny"]), "conflitos": saida["conflitos"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
