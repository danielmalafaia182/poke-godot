#!/usr/bin/env python3
"""Tabela de preços de NPC (compra no Mark × venda ao Mark) como a simulação usa, com conferência da importação.

Lê dados/gerados/itens.json (o que a sim usa) e o items.json cru do snapshot, confere campo a campo
(npcPrice → precoNpc, priceGold → precoGold, mesma unidade: ouro inteiro) e aplica a regra de venda de
sim/servico_cidade.gd: o Mark só compra item com npcPrice > 0 fora das categorias heal/revive/stone, salvo os ids
205 e 206 (C: conjuntos iV/iK do cliente original), com teto no preço de compra (E, proteção).
Bolas: preço de compra pelo balls.catalog gravado (A); o Mark não compra bolas (a lista de venda é de itens, C).

Uso: python -I ferramentas/importador/relatorio_precos.py [--saida dados/relatorios/precos_npc.md]
"""
import argparse
import json
import os
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SNAP = os.environ.get("POKE_SNAPSHOT", os.path.join(RAIZ, "poke har", "extraido", "snapshot_2026-11-09"))
EXCLUIDAS = {"heal", "revive", "stone"}
EXCECOES = {205, 206}
BOLAS = [  # A: balls.catalog (gravações da fase 3)
    (1, "Poké Ball", 5, True), (2, "Great Ball", 20, True), (3, "Super Ball", 50, True), (4, "Ultra Ball", 130, True),
    (6, "Idle Ball", 400, False), (7, "Golden Idle Ball", 400, False), (5, "Master Ball", 0, False)]


def venda_sim(it):
    if it.get("categoria") in EXCLUIDAS and int(it["id"]) not in EXCECOES:
        return 0
    v = int(it.get("precoNpc", 0))
    if int(it.get("precoGold", 0)) > 0:
        v = min(v, int(it["precoGold"]))
    return max(0, v)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", default=os.path.join(RAIZ, "dados", "relatorios", "precos_npc.md"))
    a = ap.parse_args()
    gerados = {int(x["id"]): x for x in json.load(open(os.path.join(RAIZ, "dados", "gerados", "itens.json"), encoding="utf-8"))}
    cru = json.load(open(os.path.join(SNAP, "game", "items.json"), encoding="utf-8"))["items"]
    cru = {int(x["id"]): x for x in (cru.values() if isinstance(cru, dict) else cru)}
    divergencias = []
    for i, c in cru.items():
        g = gerados.get(i)
        if g is None:
            divergencias.append("%d ausente no gerado" % i)
            continue
        if int(c.get("npcPrice", 0)) != int(g.get("precoNpc", 0)):
            divergencias.append("%d npcPrice %s × precoNpc %s" % (i, c.get("npcPrice"), g.get("precoNpc")))
        if int(c.get("priceGold", 0) or 0) != int(g.get("precoGold", 0) or 0):
            divergencias.append("%d priceGold %s × precoGold %s" % (i, c.get("priceGold"), g.get("precoGold")))
        if c.get("category") != g.get("categoria"):
            divergencias.append("%d category %s × categoria %s" % (i, c.get("category"), g.get("categoria")))
    linhas = []
    marcados = []
    bruto_inverso = []
    for i in sorted(gerados):
        it = gerados[i]
        compra = int(it.get("precoGold", 0) or 0)
        npc = int(it.get("precoNpc", 0))
        venda = venda_sim(it)
        if compra <= 0 and venda <= 0 and npc <= 0:
            continue
        supera = compra > 0 and venda > compra
        if supera:
            marcados.append(i)
        if compra > 0 and npc > compra:
            bruto_inverso.append(i)
        motivo = ""
        if venda == 0 and npc > 0:
            motivo = "Mark não compra (%s)" % it.get("categoria")
        if compra > 0 and npc > compra:
            motivo += "; no cru npcPrice > compra (%d > %d), não usado" % (npc, compra)
        linhas.append("| %d | %s | %s | %s | %d | %d | %s | %s |" % (
            i, it["nome"], it.get("categoria", ""), compra if compra > 0 else "—", npc, venda,
            "**SIM**" if supera else "", motivo))
    vendaveis = sum(1 for i in gerados if venda_sim(gerados[i]) > 0)
    os.makedirs(os.path.dirname(a.saida), exist_ok=True)
    with open(a.saida, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Preços de NPC: compra no Mark × venda ao Mark (como a simulação usa)\n\n")
        f.write("Gerado por `ferramentas/importador/relatorio_precos.py` a partir de `dados/gerados/itens.json` (não editar à mão).\n\n")
        f.write("## Leitura dos campos\n\n")
        f.write("- `items.json` do snapshot: `npcPrice` = o que o Mark **paga** (C: a dica do item mostra \"Mark paga: npcPrice\"), "
                "`priceGold` = preço de **compra** (C: \"Preço: priceGold\"; A: bolas com o mesmo campo no `balls.catalog`). "
                "Unidade: ouro inteiro nos dois.\n")
        f.write("- Importação: `npcPrice → precoNpc`, `priceGold → precoGold`, `category → categoria`. Conferência campo a campo "
                "contra o snapshot cru: **%s**.\n" % ("0 divergências" if not divergencias else "%d divergências: %s" % (len(divergencias), "; ".join(divergencias[:20]))))
        f.write("- Venda (C, lista de venda do Mark no cliente): só item com `npcPrice > 0` e categoria fora de "
                "heal/revive/stone, salvo os ids 205 e 206 (Revive e Max Revive aposentados). O teto \"venda ≤ compra\" (E) "
                "fica só como proteção.\n")
        f.write("- Os únicos itens com `npcPrice > priceGold` no catálogo são %s (as poções): o npcPrice delas não é preço de venda, "
                "porque o Mark não compra poções. **Não era erro de importação** (os campos estão nos nomes e na unidade certos); "
                "o erro estava na regra de venda do lote 1, que tratava poções como vendáveis (com o teto). Corrigido em "
                "`sim/servico_cidade.gd`.\n\n" % ", ".join(str(i) for i in bruto_inverso))
        f.write("## Resumo\n\n- Itens com preço (compra ou npcPrice): %d. Vendáveis ao Mark: %d. Compráveis: %d (poções) + 4 bolas.\n"
                "- **Itens em que a venda supera a compra: %d** %s\n\n" % (
                    len(linhas), vendaveis, sum(1 for i in gerados if int(gerados[i].get("precoGold", 0) or 0) > 0),
                    len(marcados), ("(" + ", ".join(map(str, marcados)) + ")") if marcados else "(nenhum)"))
        f.write("## Bolas (A: balls.catalog)\n\n| id | bola | compra | o Mark compra? |\n|---|---|---|---|\n")
        for bid, nome, preco, compravel in BOLAS:
            f.write("| %d | %s | %s | não |\n" % (bid, nome, preco if compravel else "não vende (buyable false)"))
        f.write("\n## Itens\n\n| id | item | categoria | compra (priceGold) | npcPrice (cru) | venda que a sim usa | venda > compra? | obs. |\n"
                "|---|---|---|---|---|---|---|---|\n")
        f.write("\n".join(linhas) + "\n")
    print("ok:", a.saida, "linhas", len(linhas), "vendáveis", vendaveis, "marcados", marcados, "divergências", len(divergencias))
    return 0


if __name__ == "__main__":
    sys.exit(main())
