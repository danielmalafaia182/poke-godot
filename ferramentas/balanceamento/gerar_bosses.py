#!/usr/bin/env python3
"""Bosses (classe 3, ciclo 3): escreve a seção "bosses" de dados/balanceamento.json.

Fonte do que existe (A, snapshot game/bossCatalog.json): 87 bosses com chave, nome, categoria (Especiais, Mystery
Dungeons, Terror, Lendary Beasts, Raids), nível e os nomes dos drops; o cliente (C) mostra o requisito de nível, a entrada
por token, a derrota que perde o token, o Auto Boss (lutas em sequência, só fora de hunt, para na derrota) e o Altar
(sacrifica um Shiny Card para enfrentar um shiny lendário; captura muito rara). O servidor não mostra HP, golpes, chances
nem custos: aqui ficam desenhados para o ritmo da campanha (nível do boss = requisito do treinador, 200–625).

Espécie do boss: a espécie cujo nome aparece no nome ou na chave do boss (a mais longa); sem match, uma espécie da
categoria (escolha fixa abaixo). HP = HP de combate × `hp_mult` da categoria (é um boss: um só Pokémon contra o time).

Uso: python -I ferramentas/balanceamento/gerar_bosses.py
"""
import json
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SNAP = os.path.join(RAIZ, "poke har/extraido/snapshot_2026-11-09/game/bossCatalog.json")
CATEGORIA = {
    # entrada (token, qtd), hp_mult, recarga entre lutas (s)
    "Especiais": {"entrada": None, "hp_mult": 6, "recarga_s": 600},
    "Mystery Dungeons": {"entrada": ["Boss Token", 1], "hp_mult": 8, "recarga_s": 60},
    "Terror": {"entrada": ["Boss Token", 3], "hp_mult": 10, "recarga_s": 60},
    "Lendary Beasts": {"entrada": ["Terror Token", 1], "hp_mult": 12, "recarga_s": 60},
    "Raids": {"entrada": ["Beast Orb", 2], "hp_mult": 16, "recarga_s": 60},
}
CHANCE = {  # chance por luta vencida, quantidade min–max
    "Boss Token": [0.6, 1, 2], "Terror Token": [0.5, 1, 1], "Beast Orb": [0.4, 1, 1], "Raid Coin": [0.5, 1, 3],
    "Rare Candy": [0.3, 1, 2], "Heart Scale": [0.4, 1, 3], "Shiny Stone": [0.08, 1, 1], "Mystery Shard": [0.5, 1, 3],
    "Dungeon Chest": [0.2, 1, 1], "Legendary Chest": [0.15, 1, 1], "Mega Stone": [0.05, 1, 1],
}
PADRAO_ESPECIE = {"Especiais": "Gengar", "Mystery Dungeons": "Dragonite", "Terror": "Tyranitar", "Lendary Beasts": "Raikou", "Raids": "Metagross"}


def main():
    cat = json.load(open(SNAP, encoding="utf-8"))
    esp = json.load(open(os.path.join(RAIZ, "dados/gerados/especies.json"), encoding="utf-8"))
    esp = esp if isinstance(esp, list) else list(esp.values())
    por_nome = {}
    for e in esp:
        if e["id"] <= 493:
            por_nome[e["nome"].lower()] = e["id"]
    nomes = sorted(por_nome, key=len, reverse=True)
    lista = []
    sem_match = []
    for b in cat:
        alvo = (b["name"] + " " + b["key"].replace("_", " ")).lower()
        alvo = re.sub(r"[^a-z. ]", " ", alvo)
        sid = next((por_nome[n] for n in nomes if re.search(r"\b" + re.escape(n) + r"\b", alvo)), None)
        if sid is None:
            sid = por_nome[PADRAO_ESPECIE[b["category"]].lower()]
            sem_match.append(b["key"])
        c = CATEGORIA[b["category"]]
        lista.append({"key": b["key"], "nome": b["name"], "categoria": b["category"], "nivel": int(b["level"]), "speciesId": sid,
                      "shiny": "shiny" in alvo, "entrada": c["entrada"], "hp_mult": c["hp_mult"], "recarga_s": c["recarga_s"],
                      "drops": [{"nome": n, "chance": CHANCE.get(n, [0.2, 1, 1])[0], "min": CHANCE.get(n, [0.2, 1, 1])[1], "max": CHANCE.get(n, [0.2, 1, 1])[2]} for n in b["drops"]]})
    p = os.path.join(RAIZ, "dados/balanceamento.json")
    bal = json.load(open(p, encoding="utf-8"))
    bal["bosses"] = {
        "lista": {"valor": lista, "motivo": "87 bosses do snapshot (A: nome, categoria, nível, drops); espécie, entrada, HP e chances desenhados (ferramentas/balanceamento/gerar_bosses.py)"},
        "iv_boss": {"valor": 25, "motivo": "boss é mais forte que o selvagem médio"},
        "quality_boss": {"valor": 1.3, "motivo": "boss é mais forte que o selvagem médio"},
        "cadencia_boss_ms": {"valor": 2000, "motivo": "ritmo de um selvagem (A: ~2000 ms)"},
        "fator_dano_boss": {"valor": 1.2, "motivo": "o boss bate um pouco mais que um treinador (o selvagem tem ×1,8, A)"},
        "baus": {"valor": {"Dungeon Chest": {"ouro": [20000, 60000], "pedras": 1}, "Legendary Chest": {"ouro": [100000, 250000], "pedras": 2, "rare_candy": 2}},
                 "motivo": "o baú abre na hora: ouro e pedras de evolução sorteadas (o conteúdo do original não foi gravado)"},
        "altar_chance_captura": {"valor": 0.03, "motivo": "C: 'A captura é muito rara'; 3% por vitória no altar"},
        "altar_especies": {"valor": ["Raikou", "Entei", "Suicune"], "motivo": "o shiny lendário do altar sai entre os três das Lendary Beasts do catálogo"},
        "altar_nivel": {"valor": 500, "motivo": "nível do shiny lendário do altar (o das Lendary Beasts do catálogo vai de 425 a 525)"},
        "auto_max_lutas": {"valor": 50, "motivo": "teto da fila do Auto Boss"},
    }
    bal["combate"]["card_chance_shiny"] = {"valor": 0.1, "motivo": "C: Derrote shinies selvagens — eles podem dropar o Card da espécie; 10% por shiny abatido (o Card leva ao Altar dos bosses)"}
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(bal, ensure_ascii=False, indent=2) + "\n")
    print(len(lista), "bosses;", len(sem_match), "sem espécie no nome:", sem_match[:20])


if __name__ == "__main__":
    main()
