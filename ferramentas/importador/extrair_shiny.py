#!/usr/bin/env python3
"""Tabela de shiny do cliente original (C, chunk 0fllz2m_ktm3s.js, export SHINY_BY_DEX): por espécie, o looktype do sprite
shiny, o tier, o ícone e o cadáver (quando há). Só as espécies da tabela têm forma shiny (`hasShinyForm`).
Saída determinística: dados/gerados/shiny.json. Uso: python -I ferramentas/importador/extrair_shiny.py
"""
import json, os, re, sys
RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CHUNK = os.path.join(RAIZ, "poke-local", "public", "_next", "static", "chunks", "0fllz2m_ktm3s.js")


def main():
    s = open(CHUNK, encoding="utf-8").read()
    i = s.index('"SHINY_BY_DEX",0,o,"hasShinyForm"')
    j = s.rfind("let o={", 0, i)
    k = s.index("};", j)
    corpo = s[j + 6:k + 1]
    js = re.sub(r"([{,])(\w+):", r'\1"\2":', corpo)
    tab = json.loads(js)
    out = {str(int(k)): {"looktype": v.get("looktype"), "tier": v.get("tier"), "icone": v.get("iconId"), "cadaver": v.get("corpse")}
           for k, v in sorted(tab.items(), key=lambda kv: int(kv[0]))}
    os.makedirs(os.path.join(RAIZ, "dados", "gerados"), exist_ok=True)
    with open(os.path.join(RAIZ, "dados", "gerados", "shiny.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    from collections import Counter
    print(len(out), "espécies com shiny; tiers:", dict(sorted(Counter(v["tier"] for v in out.values()).items())))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
