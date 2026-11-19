#!/usr/bin/env python3
"""Ginásios (classe 3, ciclo 3): escreve a seção "ginasios" de dados/balanceamento.json.

Fonte do que existe: os 18 ids e as cores (C, cliente `i$`), a ordem Kanto (8) + outra região (10) (C), os tipos de
pewter ROCK, cerulean WATER, mahogany ICE e spikemuth DARK e os líderes NPC Piers e Pryce (A, gym-global). Os outros
tipos e líderes seguem a franquia (B). O servidor não mostra times, níveis nem a regra da luta: isso é desenhado aqui
para o ritmo da campanha (nível de desbloqueio do treinador espalhado de 10 a 560, onde a campanha VIP do ciclo 2 chega
em 400 h) e fica explícito no JSON (o jogo lê o JSON; este script só o gera de novo).

Time: as espécies do tipo da Pokédex normal (id ≤ 493, sem as variantes de hunt) que aparecem em hunts (capturáveis), as de maior soma de stats base, sem lendárias de 600+;
tamanho 3 → 6 conforme o ginásio; nível = desbloqueio × 0,65 (o ás × 0,8): calibrado para um líder sozinho no nível de desbloqueio × 1,15 vencer os
ginásios sem desvantagem de tipo; com desvantagem forte, pede time (sonda no relatório da campanha).

Uso: python -I ferramentas/balanceamento/gerar_ginasios.py
"""
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GINASIOS = [
    # id, região, tipo, líder, insígnia, desbloqueio (nível do treinador), tamanho do time
    ("pewter", "kanto", "ROCK", "Brock", "Boulder Badge", 10, 3),
    ("cerulean", "kanto", "WATER", "Misty", "Cascade Badge", 20, 3),
    ("vermilion", "kanto", "ELECTRIC", "Lt. Surge", "Thunder Badge", 30, 3),
    ("celadon", "kanto", "GRASS", "Erika", "Rainbow Badge", 45, 4),
    ("fuchsia", "kanto", "POISON", "Koga", "Soul Badge", 60, 4),
    ("saffron", "kanto", "PSYCHIC", "Sabrina", "Marsh Badge", 80, 4),
    ("cinnabar", "kanto", "FIRE", "Blaine", "Volcano Badge", 100, 5),
    ("viridian", "kanto", "GROUND", "Giovanni", "Earth Badge", 130, 5),
    ("violet", "johto", "FLYING", "Falkner", "Zephyr Badge", 160, 5),
    ("azalea", "johto", "BUG", "Bugsy", "Hive Badge", 190, 5),
    ("goldenrod", "johto", "NORMAL", "Whitney", "Plain Badge", 220, 5),
    ("ecruteak", "johto", "GHOST", "Morty", "Fog Badge", 260, 6),
    ("cianwood", "johto", "FIGHTING", "Chuck", "Storm Badge", 300, 6),
    ("olivine", "johto", "STEEL", "Jasmine", "Mineral Badge", 340, 6),
    ("mahogany", "johto", "ICE", "Pryce", "Glacier Badge", 390, 6),
    ("blackthorn", "johto", "DRAGON", "Clair", "Rising Badge", 440, 6),
    ("spikemuth", "galar", "DARK", "Piers", "Dark Badge", 500, 6),
    ("laverre", "kalos", "FAIRY", "Valerie", "Fairy Badge", 560, 6),
]
FATOR_NIVEL = 0.65   # o time
FATOR_AS = 0.8       # o ás (último)


def main():
    esp = json.load(open(os.path.join(RAIZ, "dados/gerados/especies.json"), encoding="utf-8"))
    esp = esp if isinstance(esp, list) else list(esp.values())
    hunts = json.load(open(os.path.join(RAIZ, "dados/gerados/hunts.json"), encoding="utf-8"))
    hunts = hunts if isinstance(hunts, list) else list(hunts.values())
    nas_hunts = {s["pokeId"] for h in hunts for s in h.get("spawns", [])}
    lista = []
    for gid, reg, tipo, lider, badge, nivel, tam in GINASIOS:
        cands = [e for e in esp if e["id"] <= 493 and e["id"] in nas_hunts and tipo in e.get("tipos", []) and sum(e["base"].values()) < 600]
        cands.sort(key=lambda e: (-sum(e["base"].values()), e["id"]))
        if len(cands) < 3:
            raise SystemExit(f"{gid}: só {len(cands)} espécies {tipo}")
        tam = min(tam, len(cands))   # tipo com poucas espécies capturáveis: time menor
        time = [c["id"] for c in cands[:tam]][::-1]   # o mais forte por último (o ás)
        nv = max(1, round(nivel * FATOR_NIVEL))
        lista.append({"id": gid, "regiao": reg, "tipo": tipo, "lider": lider, "insignia": badge, "nivel_treinador": nivel,
                      "time": [{"speciesId": s, "nivel": nv if i < len(time) - 1 else max(1, round(nivel * FATOR_AS))} for i, s in enumerate(time)]})
    p = os.path.join(RAIZ, "dados/balanceamento.json")
    b = json.load(open(p, encoding="utf-8"))
    b["ginasios"] = {
        "lista": {"valor": lista, "motivo": "18 ginásios do cliente (C) com tipos A/B; times, níveis e desbloqueio desenhados para o ritmo da campanha (ferramentas/balanceamento/gerar_ginasios.py)"},
        "iv_lider": {"valor": 20, "motivo": "IV dos Pokémon do líder: um pouco acima do médio (16,5) para a luta pedir preparo"},
        "quality_lider": {"valor": 1.15, "motivo": "Quality dos Pokémon do líder: acima da média do sorteio (≈1,0)"},
        "cadencia_lider_ms": {"valor": 2000, "motivo": "o líder ataca no ritmo de um selvagem (A: ~2000 ms); o jogador no do aliado (A: 1600 ms)"},
        "fator_dano_lider": {"valor": 1.0, "motivo": "o líder não tem o ×1,8 do selvagem (é um treinador; o ×1,8 é medido só em selvagem)"},
        "recarga_derrota_s": {"valor": 60, "motivo": "depois de perder, 60 s até poder desafiar de novo (o cliente mostra cooldownMs; valor do servidor não gravado)"},
        "luta_max_s": {"valor": 600, "motivo": "teto da luta (10 min de luta simulada); passou, perde"},
    }
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(b, ensure_ascii=False, indent=2) + "\n")
    for g in lista:
        print(g["id"], g["tipo"], g["nivel_treinador"], [x["speciesId"] for x in g["time"]])


if __name__ == "__main__":
    main()
