#!/usr/bin/env python3
"""Lote 3 (ciclo 6): tabelas de held items e TMs do cliente original (C) → dados/gerados/lote3.json (determinístico).

Fontes (chunks do poke-local):
  0wl3dp5-44hi8.js  HELD_ITEMS {itemId: {family, tier, value}}, HELD_SLOT, HELD_LABEL, HELD_IMPLEMENTED,
                    HELD_MACHINE_OFFERS {basic: {cost, tiers}, premium: …}
  0fllz2m_ktm3s.js  TM_ITEM_TYPE {itemId: TIPO|AOE}, TM_STAGE_EXEMPT (Set de speciesId), TM_MOVES {TIPO: {name, power,
                    cooldownMs, type, category, aoeBox, minTargets…}}
  textos (pokepedia.tms.how4): "trocando 10 peças por 1 disco"; peças: 59194 TM Disk Piece, 40530 AoE TM Disk Piece.
Uso: python -I ferramentas/importador/extrair_lote3.py
"""
import json
import os
import re

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CH = os.path.join(RAIZ, "poke-local", "public", "_next", "static", "chunks")


def objeto_js(txt, inicio):
    """Lê o literal {…} que começa em `inicio` e devolve (dict, fim). Aceita chaves sem aspas, números e strings."""
    n = 0
    i = inicio
    while True:
        c = txt[i]
        if c == '"':
            i = txt.index('"', i + 1)
        elif c == "{":
            n += 1
        elif c == "}":
            n -= 1
            if n == 0:
                break
        i += 1
    s = txt[inicio:i + 1]
    s = re.sub(r'([{,])\s*([A-Za-z_][A-Za-z0-9_]*|\d+)\s*:', r'\1"\2":', s)
    s = s.replace("!0", "true").replace("!1", "false")
    return json.loads(s), i + 1


def depois(txt, marca):
    i = txt.index(marca)
    return objeto_js(txt, txt.index("{", i + len(marca) - 1))[0]


def main():
    a = open(os.path.join(CH, "0wl3dp5-44hi8.js"), encoding="utf-8").read()
    b = open(os.path.join(CH, "0fllz2m_ktm3s.js"), encoding="utf-8").read()
    # HELD_ITEMS: o objeto `a={12345:{family:"…",tier:…,value:…},…}` logo antes de ",r={ATTACK:\"X\"…"
    fim = a.index(',r={ATTACK:"X"')
    k = [m.start() for m in re.finditer(r'=\{\d+:\{family:', a[:fim])][-1] + 1
    helds, _ = objeto_js(a, k)
    slot, _ = objeto_js(a, fim + 3)
    label, _ = objeto_js(a, a.index('i={ATTACK:"X-Attack"', fim) + 2)
    impl = re.search(r'TM_STAGE_EXEMPT;let n=new Set\(\[([^\]]*)\]\)', a).group(1)
    ofertas, _ = objeto_js(a, a.index("l={basic:") + 2)
    t = b.index('"TM_ITEM_TYPE",0,o')
    j = b.rfind('"use strict";let o=', 0, t)
    tm_tipo, fim_o = objeto_js(b, j + len('"use strict";let o='))
    exempt = re.search(r'\{[^}]*"AOE"\},t=new Set\(\[([^\]]*)\]\)', b[j:t]).group(1)
    tm_golpes, _ = objeto_js(b, b.index("i={NORMAL:", j) + 2)
    saida = {
        "_fonte": "C: chunks 0wl3dp5-44hi8.js (HELD_*) e 0fllz2m_ktm3s.js (TM_*) do cliente original; textos pokepedia.tms.how4",
        "helds": {str(k): v for k, v in sorted(helds.items(), key=lambda kv: int(kv[0]))},
        "held_slot": slot,
        "held_nome": label,
        "held_ativos": [x.strip().strip('"') for x in impl.split(",") if x.strip()],
        "held_maquina": ofertas,
        "held_token_id": 13115,
        "tm_tipo_item": {str(k): v for k, v in sorted(tm_tipo.items(), key=lambda kv: int(kv[0]))},
        "tm_estagio_isento": sorted(int(x) for x in exempt.split(",") if x.strip()),
        "tm_golpes": tm_golpes,
        "tm_pecas_por_disco": 10,
        "tm_peca_id": 59194,
        "tm_peca_aoe_id": 40530,
    }
    destino = os.path.join(RAIZ, "dados", "gerados", "lote3.json")
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        json.dump(saida, f, ensure_ascii=False, indent=1, sort_keys=True)
    print("helds %d, discos %d, golpes %d, isentos %d -> %s" % (len(saida["helds"]), len(saida["tm_tipo_item"]), len(tm_golpes),
                                                             len(saida["tm_estagio_isento"]), destino))


if __name__ == "__main__":
    main()
