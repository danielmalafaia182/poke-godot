#!/usr/bin/env python3
"""Compara dois snapshots (ou dois creatures.json / items.json) e escreve um relatório legível.

Uso:
  python3 diff_snapshots.py ANTIGO NOVO --saida DIFF.md
ANTIGO/NOVO podem ser pastas de snapshot (usa game/creatures.json e game/items.json)
ou arquivos creatures.json soltos. Só biblioteca padrão.
"""
import argparse, json, os, sys

CAMPOS_ESPECIE = ["name", "looktype", "type1", "type2", "rarity", "baseHp", "baseAtk", "baseDef",
                  "baseSpAtk", "baseSpDef", "baseSpeed", "huntLevel", "evolvesToId", "evolveLevel",
                  "priceNpc", "sellValue", "experience", "area", "captureBase"]


def carregar(caminho):
    if os.path.isdir(caminho):
        cr = os.path.join(caminho, "game", "creatures.json")
        it = os.path.join(caminho, "game", "items.json")
    else:
        cr, it = caminho, None
    criaturas = {c["pokeId"]: c for c in json.load(open(cr, encoding="utf-8"))["creatures"]}
    itens = {}
    if it and os.path.exists(it):
        itens = {i["id"]: i for i in json.load(open(it, encoding="utf-8"))["items"]}
    return criaturas, itens


def mapa_golpes(c):
    return {a["name"]: (a.get("type"), a.get("category"), a.get("power"), a.get("cooldownMs"), a.get("learnLevel"))
            for a in c.get("attacks", [])}


def mapa_loot(c):
    return {l["name"]: (l.get("chance"), l.get("minCount"), l.get("maxCount")) for l in c.get("loot", [])}


def diff_dict(a, b):
    mud = []
    for k in sorted(set(a) | set(b)):
        if k not in a: mud.append(f"+ {k}: {b[k]}")
        elif k not in b: mud.append(f"- {k}: {a[k]}")
        elif a[k] != b[k]: mud.append(f"~ {k}: {a[k]} → {b[k]}")
    return mud


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("antigo"); ap.add_argument("novo")
    ap.add_argument("--saida", required=True)
    ap.add_argument("--json", help="também grava o diff estruturado")
    a = ap.parse_args()
    ca, ia = carregar(a.antigo)
    cn, inn = carregar(a.novo)

    novas = sorted(set(cn) - set(ca)); removidas = sorted(set(ca) - set(cn))
    mudadas = {}
    for pid in sorted(set(ca) & set(cn)):
        x, y = ca[pid], cn[pid]
        linhas = []
        for k in CAMPOS_ESPECIE:
            if x.get(k) != y.get(k):
                linhas.append(f"~ {k}: {x.get(k)} → {y.get(k)}")
        g = diff_dict(mapa_golpes(x), mapa_golpes(y))
        l = diff_dict(mapa_loot(x), mapa_loot(y))
        if g: linhas += ["golpes " + s for s in g]
        if l: linhas += ["loot " + s for s in l]
        if linhas:
            mudadas[pid] = linhas
    itens_mud = {}
    if ia and inn:
        for iid in sorted(set(ia) | set(inn)):
            d = diff_dict(ia.get(iid, {}), inn.get(iid, {}))
            if d: itens_mud[iid] = d

    L = [f"# Diff de snapshot", "", f"- Antigo: `{a.antigo}` ({len(ca)} criaturas)",
         f"- Novo: `{a.novo}` ({len(cn)} criaturas)", "",
         f"Espécies novas: {len(novas)} · removidas: {len(removidas)} · alteradas: {len(mudadas)} · itens alterados: {len(itens_mud)}", ""]
    if novas:
        L += ["## Espécies novas", ""] + [f"- {p} {cn[p]['name']}" for p in novas] + [""]
    if removidas:
        L += ["## Espécies removidas", ""] + [f"- {p} {ca[p]['name']}" for p in removidas] + [""]
    if mudadas:
        L += ["## Espécies alteradas", ""]
        for p, linhas in mudadas.items():
            L.append(f"### {p} {cn[p]['name']}")
            L += [f"    {s}" for s in linhas] + [""]
    if itens_mud:
        L += ["## Itens alterados", ""]
        for iid, linhas in itens_mud.items():
            nome = (inn.get(iid) or ia.get(iid))["name"]
            L.append(f"### {iid} {nome}")
            L += [f"    {s}" for s in linhas] + [""]
    open(a.saida, "w", encoding="utf-8").write("\n".join(L) + "\n")
    if a.json:
        json.dump({"novas": novas, "removidas": removidas, "alteradas": mudadas, "itens": itens_mud},
                  open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"novas={len(novas)} removidas={len(removidas)} alteradas={len(mudadas)} itens={len(itens_mud)}")


if __name__ == "__main__":
    sys.exit(main())
