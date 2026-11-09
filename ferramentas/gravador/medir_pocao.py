#!/usr/bin/env python3
"""Mede o gatilho do Auto-Potion nas gravações reais (fonte A).

Para cada `auto-heal`:
  - HP no field imediatamente anterior (heroHp/heroMaxHp) e no seguinte;
  - HP exato no instante da cura quando a cura foi parcial (heal < cura da poção ⇒ HP = maxHp − heal, porque a
    cura é limitada ao que falta — fato A já confirmado);
  - qual poção foi usada e quais havia no inventário (último `inventory` antes da cura);
  - intervalo até a cura anterior na mesma instância: pelo tick (seq do field anterior/seguinte) e pela chegada (t).
Uso: python medir_pocao.py gravacao.jsonl [...] [--json saida.json]
"""
import argparse
import json
import os
import sys
from collections import Counter, defaultdict

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402


def ler_linhas(caminhos):
    """Como ler_logs, mas devolvendo também o instante de chegada t do gravador."""
    vistas = set()
    for c in caminhos:
        for linha in open(c, encoding="utf-8", errors="replace"):
            try:
                o = json.loads(linha)
            except Exception:
                continue
            if not isinstance(o, dict) or "msg" not in o or o.get("dir") != "in":
                continue
            k = (o.get("sessao"), o.get("t"), json.dumps(o["msg"], sort_keys=True))
            if k in vistas:
                continue
            vistas.add(k)
            yield o["t"], o["msg"]


def pocoes():
    itens = json.load(open(os.path.join(RAIZ, "dados", "gerados", "itens.json"), encoding="utf-8"))
    return {i["id"]: i for i in itens if i.get("categoria") == "heal"}


def coletar(caminhos):
    cat = pocoes()
    por_nome = {i["nome"]: i for i in cat.values()}
    curas = []
    ultimo_field, inv, chave = None, {}, None
    pendentes = []               # curas esperando o field seguinte
    for t, m in ler_linhas(caminhos):
        tp = m["type"]
        if tp == "field-init":
            chave, ultimo_field, pendentes = m.get("huntKey"), None, []
        elif tp == "inventory":
            inv = {x["itemId"]: x["quantity"] for x in m["items"] if x["itemId"] in cat}
        elif tp == "field":
            for c in pendentes:
                c["seq_depois"] = m["seq"]
                c["hp_depois"] = m["heroHp"]
                c["max_depois"] = m["heroMaxHp"]
            pendentes = []
            ultimo_field = m
        elif tp == "auto-heal" and ultimo_field is not None:
            p = por_nome.get(m["name"], {})
            f = ultimo_field
            c = {"instancia": chave, "t": t, "heroi": f["heroName"], "max": f["heroMaxHp"], "pocao": m["name"],
                 "cura_pocao": p.get("cura"), "heal": m["heal"], "seq_antes": f["seq"], "hp_antes": f["heroHp"],
                 "inventario": {cat[i]["nome"]: q for i, q in sorted(inv.items()) if q > 0}}
            if p.get("cura") and m["heal"] < p["cura"]:
                c["hp_exato"] = f["heroMaxHp"] - m["heal"]
            curas.append(c)
            pendentes.append(c)
    return curas, cat


def resumir(curas, cat):
    r = {}
    # 1) razão de HP no instante da cura (exata nas curas parciais) por herói/maxHp
    grupos = defaultdict(list)
    for c in curas:
        grupos[(c["heroi"], c["max"])].append(c)
    r["por_heroi"] = {}
    for (h, mx), cs in sorted(grupos.items()):
        exatas = sorted(c["hp_exato"] / mx for c in cs if "hp_exato" in c)
        antes = sorted(c["hp_antes"] / mx for c in cs)
        r["por_heroi"][f"{h} {mx}"] = {
            "curas": len(cs), "pocoes": dict(Counter(c["pocao"] for c in cs)),
            "parciais": len(exatas),
            "razao_exata_max": exatas[-1] if exatas else None, "razao_exata_min": exatas[0] if exatas else None,
            "hp_exato_distintos": sorted(Counter(c["hp_exato"] for c in cs if "hp_exato" in c).items()),
            "razao_field_antes_max": antes[-1], "razao_field_antes_min": antes[0],
        }
    # 2) intervalo mínimo entre curas (mesma instância), em ticks e em ms de chegada
    inter_ticks, inter_t = [], []
    for a, b in zip(curas, curas[1:]):
        if a["instancia"] != b["instancia"]:
            continue
        inter_t.append(b["t"] - a["t"])
        if "seq_depois" in a:
            # a cura b aconteceu depois do field seq_antes(b); a cura a, até o field seq_depois(a)
            inter_ticks.append(b["seq_antes"] - a["seq_depois"])
    r["intervalo_chegada_ms"] = {"n": len(inter_t), "min": min(inter_t) if inter_t else None,
                                 "menores": sorted(inter_t)[:10]}
    r["intervalo_ticks_limite_inferior"] = {"menores": sorted(inter_ticks)[:10]}
    # 3) escolha da poção: tinha poções maiores/menores no inventário?
    escolha = Counter()
    for c in curas:
        tinha = sorted((p["cura"], n) for n, p in ((n, next(i for i in cat.values() if i["nome"] == n)) for n in c["inventario"]))
        falta = c["max"] - c.get("hp_exato", c["hp_antes"])
        escolha[(c["heroi"], c["max"], c["pocao"], tuple(n for _, n in tinha))] += 1
    r["escolha"] = [{"heroi": k[0], "max": k[1], "usou": k[2], "inventario_ordem_cura": list(k[3]), "vezes": v}
                    for k, v in sorted(escolha.items())]
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+")
    ap.add_argument("--json")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    curas, cat = coletar(a.arquivos)
    r = resumir(curas, cat)
    print(json.dumps(r, ensure_ascii=False, indent=1))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"resumo": r, "curas": curas}, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
