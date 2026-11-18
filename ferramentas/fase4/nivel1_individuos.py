#!/usr/bin/env python3
"""Selvagens de nível baixo por indivíduo, com o capturado (G11 e parecidas; A). Não muda a simulação.

Por indivíduo selvagem (huntKey sem ":rN", slot, geração — um capturado volta como outro indivíduo):
  - maxHp e nível da hunt;
  - golpes do aliado nele (dano, golpe, eff) com os stats exibidos do aliado no instante (poke-delta/pokes);
  - golpes dele no aliado, só com UM selvagem encostado (dano, golpe);
  - se foi capturado: o poke-delta do capturado (nível, stats exibidos, quality, ivTotal), casado pelo catch-result
    (row, col) com o selvagem morto naquele tile no field anterior.
Saída: JSON com tudo, para `ajuste_nivel1.py` testar as hipóteses de stat no dano.

Uso: python -I ferramentas/fase4/nivel1_individuos.py <gravação.jsonl> [...] --json saida.json
"""
import argparse
import json
import os
import sys
from collections import defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402


def cheb(a, b):
    return max(abs(a["row"] - b["row"]), abs(a["col"] - b["col"]))


def coletar(caminhos):
    ind = {}
    geracao = defaultdict(int)
    stats_aliado = {}     # id -> stats exibidos (último poke-delta / pokes)
    lider = None
    ultimo_field = None
    hunt = None
    capt_pend = []        # [(chave do indivíduo)] esperando o poke-delta do capturado
    for d, m, _ in ler_logs(caminhos):
        if d != "in":
            continue
        t = m.get("type")
        if t == "field-init":
            hunt = m.get("huntKey", "").split(":r")[0]
            ultimo_field = None
            continue
        if t in ("pokes", "pokes-chunk"):
            for p in m.get("pokes", []):
                stats_aliado[p["id"]] = {"level": p.get("level"), "stats": p.get("stats"), "speciesId": p.get("speciesId"),
                                         "quality": p.get("quality"), "ivTotal": p.get("ivTotal"), "name": p.get("name")}
                if p.get("leader"):
                    lider = p["id"]
            continue
        if t == "poke-delta":
            p = m["poke"]
            if p.get("team") or p.get("leader") or p["id"] in stats_aliado:
                stats_aliado[p["id"]] = {"level": p.get("level"), "stats": p.get("stats"), "speciesId": p.get("speciesId"),
                                         "quality": p.get("quality"), "ivTotal": p.get("ivTotal"), "name": p.get("name")}
                if p.get("leader"):
                    lider = p["id"]
            elif capt_pend and p.get("level") == 1 and not p.get("team"):
                k = capt_pend.pop(0)
                ind[k]["capturado"] = {"level": p.get("level"), "stats": p.get("stats"), "quality": p.get("quality"),
                                       "ivTotal": p.get("ivTotal"), "maxHp": p.get("maxHp"), "speciesId": p.get("speciesId")}
            continue
        if t == "catch-result":
            if m.get("success") and ultimo_field:
                alvo = next((x for x in ultimo_field["mobs"] if x["row"] == m.get("row") and x["col"] == m.get("col")), None)
                if alvo:
                    k = (hunt, alvo["slot"], geracao[(hunt, alvo["slot"])])
                    if k in ind:
                        capt_pend.append(k)
                    geracao[(hunt, alvo["slot"])] += 1
            continue
        if t != "field" or hunt is None:
            continue
        al = stats_aliado.get(lider) if lider else None
        h = m["hero"]
        for x in m["mobs"]:
            k = (hunt, x["slot"], geracao[(hunt, x["slot"])])
            if k not in ind:
                ind[k] = {"hunt": hunt, "slot": x["slot"], "geracao": k[2], "speciesId": x["speciesId"], "maxHp": x["maxHp"],
                          "do_aliado": [], "no_aliado": []}
        vivos_adj = [x for x in m["mobs"] if not x["dead"] and cheb(x, h) <= 1]
        for hit in m.get("hits", []):
            if hit["slot"] >= 0:
                x = next((y for y in m["mobs"] if y["slot"] == hit["slot"]), None)
                if x:
                    k = (hunt, x["slot"], geracao[(hunt, x["slot"])])
                    ind[k]["do_aliado"].append({"amount": hit["amount"], "move": hit.get("move"), "eff": hit.get("eff"),
                                                "type": hit.get("type"), "aliado": al})
            elif len(vivos_adj) == 1:
                x = vivos_adj[0]
                k = (hunt, x["slot"], geracao[(hunt, x["slot"])])
                ind[k]["no_aliado"].append({"amount": hit["amount"], "move": hit.get("move"), "eff": hit.get("eff"),
                                            "type": hit.get("type"), "aliado": al})
        ultimo_field = m
    return [v for v in ind.values() if v["do_aliado"] or v["no_aliado"]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+")
    ap.add_argument("--json", required=True)
    a = ap.parse_args()
    r = coletar(a.arquivos)
    with open(a.json, "w", encoding="utf-8", newline="\n") as f:
        json.dump(r, f, ensure_ascii=False, indent=1)
    cap = sum(1 for x in r if "capturado" in x)
    print(f"{len(r)} indivíduos com golpes; {cap} capturados casados; golpes do aliado {sum(len(x['do_aliado']) for x in r)}, "
          f"no aliado {sum(len(x['no_aliado']) for x in r)}")


if __name__ == "__main__":
    main()
