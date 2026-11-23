@tool
class_name RegrasBosses
extends Resource
## RegrasBosses — bosses.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Altar")
## C: 'A captura é muito rara'; 3% por vitória no altar · unidade: fração 0–1 · origem C (replicada do cliente sem
## confirmação no servidor) · evidência: comentário em `sim/servico_bosses.gd`
@export_range(0.0, 1.0, 0.0001)  var altar_chance_captura: float = 0.03

## o shiny lendário do altar sai entre os três das Lendary Beasts do catálogo · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_bosses.gd`
@export var altar_especies: Array = ["Raikou", "Entei", "Suicune"]

## nível do shiny lendário do altar (o das Lendary Beasts do catálogo vai de 425 a 525) · origem E (desenhada por
## nós) · evidência: comentário em `sim/servico_bosses.gd`
@export_range(0.0, 5000.0, 0.0001, "or_greater")  var altar_nivel: float = 500.0

@export_group("Geral")
## teto da fila do Auto Boss · origem E (desenhada por nós) · evidência: comentário em `sim/servico_bosses.gd`
@export_range(0.0, 500.0, 0.0001, "or_greater")  var auto_max_lutas: float = 50.0

## o baú abre na hora: ouro e pedras de evolução sorteadas (o conteúdo do original não foi gravado) · origem E
## (desenhada por nós) · evidência: comentário em `sim/servico_bosses.gd`
@export var baus: Dictionary = {
"Dungeon Chest": {
"ouro": [20000.0, 60000.0],
"pedras": 1.0
},
"Legendary Chest": {
"ouro": [100000.0, 250000.0],
"pedras": 2.0,
"rare_candy": 2.0
}
}

## ritmo de um selvagem (A: ~2000 ms) · unidade: milissegundos · origem A (comprovada contra o original) ·
## evidência: comentário em `sim/servico_bosses.gd`
@export_range(0.0, 20000.0, 0.0001, "or_greater")  var cadencia_boss_ms: float = 2000.0

## o boss bate um pouco mais que um treinador (o selvagem tem ×1,8, A) · unidade: multiplicador · origem E
## (desenhada por nós) · evidência: comentário em `sim/servico_bosses.gd`
@export_range(0.0, 12.0, 0.0001, "or_greater")  var fator_dano_boss: float = 1.2

## lutas guardadas no histórico de bosses · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_bosses.gd`
@export_range(0, 300, 1, "or_greater")  var historico_max: int = 30

## boss é mais forte que o selvagem médio · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_bosses.gd`
@export_range(0.0, 250.0, 0.0001, "or_greater")  var iv_boss: float = 25.0

## 87 bosses do snapshot (A: nome, categoria, nível, drops); espécie, entrada, HP e chances desenhados
## (ferramentas/balanceamento/gerar_bosses.py); ciclo 6: TM Disk Piece e AoE TM Disk Piece a 2% em todo boss (C:
## 2% nos dois bosses do catálogo do cliente) · origem A (comprovada contra o original) · evidência:
## ferramentas/balanceamento/gerar_bosses.py
@export var lista: Array = [{
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "aerodactyl2",
"nivel": 300.0,
"nome": "Ancient Aero",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 142.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "cruel",
"nivel": 300.0,
"nome": "Giant Cruel",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "ghost",
"nivel": 200.0,
"nome": "Lavender Town Ghost",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "hisuian_electrode",
"nivel": 300.0,
"nome": "Hisuian Electrode",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 101.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mecha_shiny_marowak",
"nivel": 300.0,
"nome": "Mecha Shiny Marowak",
"recarga_s": 600.0,
"shiny": true,
"speciesId": 105.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mecha_shiny_mime",
"nivel": 300.0,
"nome": "Mecha Shiny Mime",
"recarga_s": 600.0,
"shiny": true,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mega_alakazam",
"nivel": 300.0,
"nome": "Mega Alakazam",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 65.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "megaVenusaurHP",
"nivel": 300.0,
"nome": "Mega Venusaur",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 3.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "outfit_4_",
"nivel": 300.0,
"nome": "Outfit 4",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "overqwil",
"nivel": 300.0,
"nome": "Overqwil",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "boss_mewtwo_main",
"nivel": 325.0,
"nome": "Boss Mewtwo Main",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 150.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "clone_blastoise",
"nivel": 325.0,
"nome": "Clone Blastoise",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 9.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "cyber_porygon",
"nivel": 325.0,
"nome": "Cyber Porygon",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 137.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mecha_shiny_farfetch",
"nivel": 325.0,
"nome": "Mecha Shiny Farfetch",
"recarga_s": 600.0,
"shiny": true,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "megaManectricHP",
"nivel": 325.0,
"nome": "Mega Manectric",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 310.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mega_tyranitar",
"nivel": 325.0,
"nome": "Mega Tyranitar",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "outfit_5_",
"nivel": 325.0,
"nome": "Outfit 5",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "outfit_66_",
"nivel": 325.0,
"nome": "Outfit 66",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "raichu_halloween",
"nivel": 325.0,
"nome": "Raichu Halloween",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 26.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "raticate",
"nivel": 325.0,
"nome": "Raticate",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 20.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "theRedGyarados",
"nivel": 325.0,
"nome": "The Red Gyarados",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 130.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "ursaluna",
"nivel": 325.0,
"nome": "Ursaluna",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_ariana",
"nivel": 350.0,
"nome": "Ariana",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "charizardValentines",
"nivel": 350.0,
"nome": "Charizard Valentines",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 6.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "clone_charizard",
"nivel": 350.0,
"nome": "Clone Charizard",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 6.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_cyber_porygon",
"nivel": 350.0,
"nome": "Cyber Porygon",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 137.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_dark_celebi",
"nivel": 350.0,
"nome": "Dark Celebi",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 251.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "dragonSky",
"nivel": 350.0,
"nome": "Dragon Sky",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_dream_boss",
"nivel": 350.0,
"nome": "Dream Boss",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "fight-the-bite_meowth",
"nivel": 350.0,
"nome": "Fight-the-bite Meowth",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 52.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "gengar_johto",
"nivel": 350.0,
"nome": "Gengar Johto",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "hisuian_arcanine",
"nivel": 350.0,
"nome": "Hisuian Arcanine",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 59.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "hisuian_typhlosion",
"nivel": 350.0,
"nome": "Hisuian Typhlosion",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 157.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "kleavor",
"nivel": 350.0,
"nome": "Kleavor",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mecha_shiny_raichu",
"nivel": 350.0,
"nome": "Mecha Shiny Raichu",
"recarga_s": 600.0,
"shiny": true,
"speciesId": 26.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mega_blastoise",
"nivel": 350.0,
"nome": "Mega Blastoise",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 9.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "megaSteelixHP",
"nivel": 350.0,
"nome": "Mega Steelix",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 208.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mew15th",
"nivel": 350.0,
"nome": "Mew15th",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 151.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "slowbro",
"nivel": 350.0,
"nome": "Slowbro",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 80.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "sneasler",
"nivel": 350.0,
"nome": "Sneasler",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "steelix",
"nivel": 350.0,
"nome": "Steelix",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 208.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_tyranitar",
"nivel": 350.0,
"nome": "Tyranitar",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "venusaurHalloween",
"nivel": 350.0,
"nome": "Venusaur Halloween",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 3.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_dragonair",
"nivel": 375.0,
"nome": "Dragonair",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 148.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "megaCharizardHP",
"nivel": 375.0,
"nome": "Mega Charizard",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 6.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "megaMachampHP",
"nivel": 375.0,
"nome": "Mega Machamp",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 68.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "mewtwo15th",
"nivel": 375.0,
"nome": "Mewtwo15th",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 150.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "ancientTemple",
"nivel": 400.0,
"nome": "Ancient Temple",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "bowstoiseEaster",
"nivel": 400.0,
"nome": "Bowstoise Easter",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_celebi_dragon",
"nivel": 400.0,
"nome": "Celebi Dragon",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 251.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "clone_venusaur",
"nivel": 400.0,
"nome": "Clone Venusaur",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 3.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "megaCharizardyHP",
"nivel": 400.0,
"nome": "Mega Charizardy",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "megaGengarHP",
"nivel": 400.0,
"nome": "Mega Gengar",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "noctu",
"nivel": 400.0,
"nome": "Noctu",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 94.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_noctu_boss",
"nivel": 400.0,
"nome": "Noctu Boss",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Especiais",
"drops": [{
"chance": 0.6,
"max": 2.0,
"min": 1.0,
"nome": "Boss Token"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.4,
"max": 3.0,
"min": 1.0,
"nome": "Heart Scale"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": null,
"hp_mult": 6.0,
"key": "slowking",
"nivel": 400.0,
"nome": "Slowking",
"recarga_s": 600.0,
"shiny": false,
"speciesId": 199.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_celebi_wood_dragon",
"nivel": 425.0,
"nome": "Celebi Wood Dragon",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 251.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_dorabelle",
"nivel": 425.0,
"nome": "Dorabelle",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_iron_masked_marauder",
"nivel": 425.0,
"nome": "Iron Masked Marauder",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_magcargo",
"nivel": 425.0,
"nome": "Magcargo",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 219.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_mystery_mamoswine",
"nivel": 425.0,
"nome": "Mystery Mamoswine",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_mystery_muchmoney",
"nivel": 425.0,
"nome": "Mystery Muchmoney",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Lendary Beasts",
"drops": [{
"chance": 0.4,
"max": 1.0,
"min": 1.0,
"nome": "Beast Orb"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Terror Token", 1.0],
"hp_mult": 12.0,
"key": "beasts_raikou",
"nivel": 425.0,
"nome": "Raikou",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 243.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_rocket_ambush",
"nivel": 425.0,
"nome": "Rocket Ambush",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Lendary Beasts",
"drops": [{
"chance": 0.4,
"max": 1.0,
"min": 1.0,
"nome": "Beast Orb"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Terror Token", 1.0],
"hp_mult": 12.0,
"key": "beasts_shiny_raikou",
"nivel": 425.0,
"nome": "Shiny Raikou",
"recarga_s": 60.0,
"shiny": true,
"speciesId": 243.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_archer",
"nivel": 450.0,
"nome": "Archer",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_celebi_dungeon",
"nivel": 450.0,
"nome": "Celebi Dungeon",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 251.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_marauder",
"nivel": 450.0,
"nome": "Marauder",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_mecha_marauder",
"nivel": 450.0,
"nome": "Mecha Marauder",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Raids",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Raid Coin"
}, {
"chance": 0.05,
"max": 1.0,
"min": 1.0,
"nome": "Mega Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Beast Orb", 2.0],
"hp_mult": 16.0,
"key": "raids_metagross",
"nivel": 450.0,
"nome": "Metagross",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 376.0
}, {
"categoria": "Mystery Dungeons",
"drops": [{
"chance": 0.5,
"max": 3.0,
"min": 1.0,
"nome": "Mystery Shard"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.2,
"max": 1.0,
"min": 1.0,
"nome": "Dungeon Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 1.0],
"hp_mult": 8.0,
"key": "mystery_proton",
"nivel": 450.0,
"nome": "Proton",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 149.0
}, {
"categoria": "Lendary Beasts",
"drops": [{
"chance": 0.4,
"max": 1.0,
"min": 1.0,
"nome": "Beast Orb"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Terror Token", 1.0],
"hp_mult": 12.0,
"key": "beasts_entei",
"nivel": 475.0,
"nome": "Entei",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 244.0
}, {
"categoria": "Lendary Beasts",
"drops": [{
"chance": 0.4,
"max": 1.0,
"min": 1.0,
"nome": "Beast Orb"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Terror Token", 1.0],
"hp_mult": 12.0,
"key": "beasts_shiny_entei",
"nivel": 475.0,
"nome": "Shiny Entei",
"recarga_s": 60.0,
"shiny": true,
"speciesId": 244.0
}, {
"categoria": "Lendary Beasts",
"drops": [{
"chance": 0.4,
"max": 1.0,
"min": 1.0,
"nome": "Beast Orb"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Terror Token", 1.0],
"hp_mult": 12.0,
"key": "beasts_shiny_suicune",
"nivel": 500.0,
"nome": "Shiny Suicune",
"recarga_s": 60.0,
"shiny": true,
"speciesId": 245.0
}, {
"categoria": "Lendary Beasts",
"drops": [{
"chance": 0.4,
"max": 1.0,
"min": 1.0,
"nome": "Beast Orb"
}, {
"chance": 0.3,
"max": 2.0,
"min": 1.0,
"nome": "Rare Candy"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Terror Token", 1.0],
"hp_mult": 12.0,
"key": "beasts_suicune",
"nivel": 500.0,
"nome": "Suicune",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 245.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_gyakkyo",
"nivel": 525.0,
"nome": "Gyakkyo",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_raito",
"nivel": 550.0,
"nome": "Raito",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_riza",
"nivel": 550.0,
"nome": "Riza",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_seishin_yurei",
"nivel": 550.0,
"nome": "Seishin Yurei",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_yurei",
"nivel": 550.0,
"nome": "Yurei",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_kame",
"nivel": 575.0,
"nome": "Kame",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_unknown",
"nivel": 575.0,
"nome": "Unknown",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_kairiki",
"nivel": 600.0,
"nome": "Kairiki",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_ptera",
"nivel": 600.0,
"nome": "Ptera",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_seishin",
"nivel": 600.0,
"nome": "Seishin",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_gama",
"nivel": 625.0,
"nome": "Gama",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}, {
"categoria": "Terror",
"drops": [{
"chance": 0.5,
"max": 1.0,
"min": 1.0,
"nome": "Terror Token"
}, {
"chance": 0.08,
"max": 1.0,
"min": 1.0,
"nome": "Shiny Stone"
}, {
"chance": 0.15,
"max": 1.0,
"min": 1.0,
"nome": "Legendary Chest"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "TM Disk Piece"
}, {
"chance": 0.02,
"max": 1.0,
"min": 1.0,
"nome": "AoE TM Disk Piece"
}],
"entrada": ["Boss Token", 3.0],
"hp_mult": 10.0,
"key": "terror_kitsune",
"nivel": 625.0,
"nome": "Kitsune",
"recarga_s": 60.0,
"shiny": false,
"speciesId": 248.0
}]

## boss é mais forte que o selvagem médio · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_bosses.gd`
@export_range(0.0, 13.0, 0.0001, "or_greater")  var quality_boss: float = 1.3
