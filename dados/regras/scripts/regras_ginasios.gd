@tool
class_name RegrasGinasios
extends Resource
## RegrasGinasios — ginásios.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Ginasios")
## ginásios vistos no gym-global (A) · origem A (comprovada contra o original) · evidência: comentário em
## `sim/servico_ginasios.gd`
@export var ginasios_conhecidos: Dictionary = {
"cerulean": {
"tipo": "WATER"
},
"mahogany": {
"lider_npc": "Pryce",
"tipo": "ICE"
},
"pewter": {
"tipo": "ROCK"
},
"spikemuth": {
"lider_npc": "Piers",
"tipo": "DARK"
}
}

## C (a 2ª região é Johto no texto; a lista vem do servidor) · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_ginasios.gd`
@export var ginasios_por_regiao: Dictionary = {
"kanto": 8,
"outra": 10
}

## C · origem C (replicada do cliente sem confirmação no servidor) · evidência: comentário em
## `sim/servico_ginasios.gd`
@export_range(0, 180, 1, "or_greater")  var ginasios_total: int = 18

@export_group("Geral")
## o líder ataca no ritmo de um selvagem (A: ~2000 ms); o jogador no do aliado (A: 1600 ms) · unidade:
## milissegundos · origem A (comprovada contra o original) · evidência: comentário em `sim/servico_ginasios.gd`
@export_range(0.0, 20000.0, 0.0001, "or_greater")  var cadencia_lider_ms: float = 2000.0

## o líder não tem o ×1,8 do selvagem (é um treinador; o ×1,8 é medido só em selvagem) · unidade: multiplicador ·
## origem E (desenhada por nós) · evidência: comentário em `sim/servico_ginasios.gd`
@export_range(0.0, 10.0, 0.0001, "or_greater")  var fator_dano_lider: float = 1.0

## C: "A badge LASTS 48h" · unidade: segundos · origem C (replicada do cliente sem confirmação no servidor) ·
## evidência: comentário em `sim/servico_ginasios.gd`
@export_range(0, 1728000, 1, "or_greater")  var insignia_duracao_s: int = 172800

## IV dos Pokémon do líder: um pouco acima do médio (16,5) para a luta pedir preparo · origem E (desenhada por
## nós) · evidência: comentário em `sim/servico_ginasios.gd`
@export_range(0.0, 200.0, 0.0001, "or_greater")  var iv_lider: float = 20.0

## 18 ginásios do cliente (C) com tipos A/B; times, níveis e desbloqueio desenhados para o ritmo da campanha
## (ferramentas/balanceamento/gerar_ginasios.py) · origem E (desenhada por nós) · evidência:
## ferramentas/balanceamento/gerar_ginasios.py
@export var lista: Array = [{
"id": "pewter",
"insignia": "Boulder Badge",
"lider": "Brock",
"nivel_treinador": 10.0,
"regiao": "kanto",
"time": [{
"nivel": 6.0,
"speciesId": 76.0
}, {
"nivel": 6.0,
"speciesId": 213.0
}, {
"nivel": 8.0,
"speciesId": 142.0
}],
"tipo": "ROCK"
}, {
"id": "cerulean",
"insignia": "Cascade Badge",
"lider": "Misty",
"nivel_treinador": 20.0,
"regiao": "kanto",
"time": [{
"nivel": 13.0,
"speciesId": 131.0
}, {
"nivel": 13.0,
"speciesId": 230.0
}, {
"nivel": 16.0,
"speciesId": 130.0
}],
"tipo": "WATER"
}, {
"id": "vermilion",
"insignia": "Thunder Badge",
"lider": "Lt. Surge",
"nivel_treinador": 30.0,
"regiao": "kanto",
"time": [{
"nivel": 20.0,
"speciesId": 26.0
}, {
"nivel": 20.0,
"speciesId": 125.0
}, {
"nivel": 24.0,
"speciesId": 181.0
}],
"tipo": "ELECTRIC"
}, {
"id": "celadon",
"insignia": "Rainbow Badge",
"lider": "Erika",
"nivel_treinador": 45.0,
"regiao": "kanto",
"time": [{
"nivel": 29.0,
"speciesId": 45.0
}, {
"nivel": 29.0,
"speciesId": 103.0
}, {
"nivel": 29.0,
"speciesId": 154.0
}, {
"nivel": 36.0,
"speciesId": 3.0
}],
"tipo": "GRASS"
}, {
"id": "fuchsia",
"insignia": "Soul Badge",
"lider": "Koga",
"nivel_treinador": 60.0,
"regiao": "kanto",
"time": [{
"nivel": 39.0,
"speciesId": 31.0
}, {
"nivel": 39.0,
"speciesId": 73.0
}, {
"nivel": 39.0,
"speciesId": 3.0
}, {
"nivel": 48.0,
"speciesId": 169.0
}],
"tipo": "POISON"
}, {
"id": "saffron",
"insignia": "Marsh Badge",
"lider": "Sabrina",
"nivel_treinador": 80.0,
"regiao": "kanto",
"time": [{
"nivel": 52.0,
"speciesId": 80.0
}, {
"nivel": 52.0,
"speciesId": 65.0
}, {
"nivel": 52.0,
"speciesId": 121.0
}, {
"nivel": 64.0,
"speciesId": 103.0
}],
"tipo": "PSYCHIC"
}, {
"id": "cinnabar",
"insignia": "Volcano Badge",
"lider": "Blaine",
"nivel_treinador": 100.0,
"regiao": "kanto",
"time": [{
"nivel": 65.0,
"speciesId": 78.0
}, {
"nivel": 65.0,
"speciesId": 38.0
}, {
"nivel": 65.0,
"speciesId": 157.0
}, {
"nivel": 65.0,
"speciesId": 6.0
}, {
"nivel": 80.0,
"speciesId": 59.0
}],
"tipo": "FIRE"
}, {
"id": "viridian",
"insignia": "Earth Badge",
"lider": "Giovanni",
"nivel_treinador": 130.0,
"regiao": "kanto",
"time": [{
"nivel": 84.0,
"speciesId": 76.0
}, {
"nivel": 84.0,
"speciesId": 232.0
}, {
"nivel": 84.0,
"speciesId": 34.0
}, {
"nivel": 84.0,
"speciesId": 31.0
}, {
"nivel": 104.0,
"speciesId": 208.0
}],
"tipo": "GROUND"
}, {
"id": "violet",
"insignia": "Zephyr Badge",
"lider": "Falkner",
"nivel_treinador": 160.0,
"regiao": "johto",
"time": [{
"nivel": 104.0,
"speciesId": 123.0
}, {
"nivel": 104.0,
"speciesId": 142.0
}, {
"nivel": 104.0,
"speciesId": 6.0
}, {
"nivel": 104.0,
"speciesId": 169.0
}, {
"nivel": 128.0,
"speciesId": 130.0
}],
"tipo": "FLYING"
}, {
"id": "azalea",
"insignia": "Hive Badge",
"lider": "Bugsy",
"nivel_treinador": 190.0,
"regiao": "johto",
"time": [{
"nivel": 124.0,
"speciesId": 214.0
}, {
"nivel": 124.0,
"speciesId": 212.0
}, {
"nivel": 124.0,
"speciesId": 127.0
}, {
"nivel": 124.0,
"speciesId": 123.0
}, {
"nivel": 152.0,
"speciesId": 213.0
}],
"tipo": "BUG"
}, {
"id": "goldenrod",
"insignia": "Plain Badge",
"lider": "Whitney",
"nivel_treinador": 220.0,
"regiao": "johto",
"time": [{
"nivel": 143.0,
"speciesId": 241.0
}, {
"nivel": 143.0,
"speciesId": 128.0
}, {
"nivel": 143.0,
"speciesId": 115.0
}, {
"nivel": 143.0,
"speciesId": 217.0
}, {
"nivel": 176.0,
"speciesId": 143.0
}],
"tipo": "NORMAL"
}, {
"id": "ecruteak",
"insignia": "Fog Badge",
"lider": "Morty",
"nivel_treinador": 260.0,
"regiao": "johto",
"time": [{
"nivel": 169.0,
"speciesId": 92.0
}, {
"nivel": 169.0,
"speciesId": 93.0
}, {
"nivel": 169.0,
"speciesId": 200.0
}, {
"nivel": 208.0,
"speciesId": 94.0
}],
"tipo": "GHOST"
}, {
"id": "cianwood",
"insignia": "Storm Badge",
"lider": "Chuck",
"nivel_treinador": 300.0,
"regiao": "johto",
"time": [{
"nivel": 195.0,
"speciesId": 107.0
}, {
"nivel": 195.0,
"speciesId": 106.0
}, {
"nivel": 195.0,
"speciesId": 57.0
}, {
"nivel": 195.0,
"speciesId": 214.0
}, {
"nivel": 195.0,
"speciesId": 68.0
}, {
"nivel": 240.0,
"speciesId": 62.0
}],
"tipo": "FIGHTING"
}, {
"id": "olivine",
"insignia": "Mineral Badge",
"lider": "Jasmine",
"nivel_treinador": 340.0,
"regiao": "johto",
"time": [{
"nivel": 221.0,
"speciesId": 81.0
}, {
"nivel": 221.0,
"speciesId": 227.0
}, {
"nivel": 221.0,
"speciesId": 205.0
}, {
"nivel": 221.0,
"speciesId": 82.0
}, {
"nivel": 221.0,
"speciesId": 212.0
}, {
"nivel": 272.0,
"speciesId": 208.0
}],
"tipo": "STEEL"
}, {
"id": "mahogany",
"insignia": "Glacier Badge",
"lider": "Pryce",
"nivel_treinador": 390.0,
"regiao": "johto",
"time": [{
"nivel": 254.0,
"speciesId": 215.0
}, {
"nivel": 254.0,
"speciesId": 221.0
}, {
"nivel": 254.0,
"speciesId": 124.0
}, {
"nivel": 254.0,
"speciesId": 87.0
}, {
"nivel": 254.0,
"speciesId": 91.0
}, {
"nivel": 312.0,
"speciesId": 131.0
}],
"tipo": "ICE"
}, {
"id": "blackthorn",
"insignia": "Rising Badge",
"lider": "Clair",
"nivel_treinador": 440.0,
"regiao": "johto",
"time": [{
"nivel": 286.0,
"speciesId": 147.0
}, {
"nivel": 286.0,
"speciesId": 148.0
}, {
"nivel": 352.0,
"speciesId": 230.0
}],
"tipo": "DRAGON"
}, {
"id": "spikemuth",
"insignia": "Dark Badge",
"lider": "Piers",
"nivel_treinador": 500.0,
"regiao": "galar",
"time": [{
"nivel": 325.0,
"speciesId": 228.0
}, {
"nivel": 325.0,
"speciesId": 215.0
}, {
"nivel": 400.0,
"speciesId": 229.0
}],
"tipo": "DARK"
}, {
"id": "laverre",
"insignia": "Fairy Badge",
"lider": "Valerie",
"nivel_treinador": 560.0,
"regiao": "kalos",
"time": [{
"nivel": 364.0,
"speciesId": 176.0
}, {
"nivel": 364.0,
"speciesId": 184.0
}, {
"nivel": 364.0,
"speciesId": 40.0
}, {
"nivel": 364.0,
"speciesId": 210.0
}, {
"nivel": 364.0,
"speciesId": 122.0
}, {
"nivel": 448.0,
"speciesId": 36.0
}],
"tipo": "FAIRY"
}]

## teto da luta (10 min de luta simulada); passou, perde · unidade: segundos · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_ginasios.gd`
@export_range(0.0, 6000.0, 0.0001, "or_greater")  var luta_max_s: float = 600.0

## Quality dos Pokémon do líder: acima da média do sorteio (≈1,0) · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_ginasios.gd`
@export_range(0.0, 11.5, 0.0001, "or_greater")  var quality_lider: float = 1.15

## depois de perder, 60 s até poder desafiar de novo (o cliente mostra cooldownMs; valor do servidor não gravado)
## · unidade: segundos · origem E (desenhada por nós) · evidência: comentário em `sim/servico_ginasios.gd`
@export_range(0.0, 600.0, 0.0001, "or_greater")  var recarga_derrota_s: float = 60.0
