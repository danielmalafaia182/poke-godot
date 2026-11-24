@tool
class_name RegrasEconomia
extends Resource
## RegrasEconomia — loja, Nurse Joy, depot e evolução.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Capacidade")
## BOX da conta VIP (A); sem VIP não medido, vale o mesmo para não punir quem joga offline · origem E (desenhada
## por nós) · evidência: comentário em `sim/servico_cidade.gd`
@export_range(0.0, 30000.0, 0.0001, "or_greater")  var capacidade_box: float = 3000.0

## o original não mostrou teto (89 pilhas sem aviso); 200 é folgado e evita lista infinita · origem E (desenhada
## por nós) · evidência: comentário em `sim/servico_cidade.gd`
@export_range(0.0, 2000.0, 0.0001, "or_greater")  var capacidade_depot_pilhas: float = 200.0

@export_group("Evolucao")
## C: "Only works in Cerulean — the button is locked during a hunt" Evolução · origem C (replicada do cliente sem
## confirmação no servidor) · evidência: comentário em `sim/servico_cidade.gd`
@export var evolucao_cidade: String = "cerulean"

## A: G3 Geodude (hunt < 40) 1 pedra, livre 19/11 Graveler (40+) 4; C: "Species from Lv.40+ hunts require 4 stones
## total"; até 39: 1 de cada · origem A (observada (referência declarada, não auditada pelo catálogo)) ·
## evidência: G3
@export_range(0, 400, 1, "or_greater")  var evolucao_nivel_alto: int = 40

## C: sem pedra "goes back to Lv.1" · origem C (replicada do cliente sem confirmação no servidor) · evidência:
## comentário em `sim/servico_cidade.gd`
@export_range(0, 10, 1, "or_greater")  var evolucao_nivel_reset: int = 1

## A: Graveler → Golem (hunt 40+) = 4 Rock Stones (livre 19/11); C: "4 stones total — split equally across combos"
## (a divisão entre tipos não foi vista) · origem A (observada (referência declarada, não auditada pelo catálogo))
## · evidência: comentário em `sim/servico_cidade.gd`
@export_range(0, 40, 1, "or_greater")  var evolucao_pedras_total_alto: int = 4

@export_group("Venda")
## Compra de item: priceGold > 0 do items.json (C: a tela mostra "Preço: priceGold"; hoje só as 5 poções). Venda:
## npcPrice (C: "Mark paga: npcPrice"), só para as categorias que o Mark compra (abaixo). C: a lista de venda do
## Mark só aceita item com npcPrice > 0 e fora das categorias heal/revive/stone, salvo os ids 205 e 206 (Revive e
## Max Revive, aposentados: "Venda ao Mark pelo mesmo valor que você pagou"). Poções e pedras não são vendáveis; o
## npcPrice delas (50, 150, …) não é preço de venda. · origem C (replicada do cliente sem confirmação no servidor)
## · evidência: items.json
@export var venda_categorias_excluidas: Array = ["heal", "revive", "stone"]

## exceções da regra acima, itens 205 e 206 (C) · origem C (replicada do cliente sem confirmação no servidor) ·
## evidência: comentário em `sim/servico_cidade.gd`
@export var venda_excecoes_ids: Array = [205, 206]

## A (G1): Pokémon vendido pelo sellValue da espécie (valorVenda), sem depender de nível, Quality ou IV: 2
## Blastoise Lv.1 (Q 1,014 / IV 124 e Q 1,273 / IV 61) → 18000 cada; o sellValue que o servidor manda é o da
## espécie em 399/399 Pokémon da lista (níveis 1 a 425). · origem A (observada (referência declarada, não auditada
## pelo catálogo)) · evidência: G1
@export var venda_pokemon: String = "valorVenda"

## E (proteção): nunca vender acima do preço de compra. Com a regra acima nenhum item do catálogo chega nele. ·
## origem E (desenhada por nós) · evidência: comentário em `sim/servico_cidade.gd`
@export var venda_teto_preco_compra: bool = true

@export_group("Geral")
## A: mensagem balls.catalog (gravações): priceGold, buyable, catchRate HP depois de evoluir: mantém a fração da
## vida (E; o original não foi gravado). Loja · origem A (observada (referência declarada, não auditada pelo
## catálogo)) · evidência: comentário em `sim/servico_cidade.gd`
@export var bolas_catalogo: Array = [{
"bound": false,
"buyable": true,
"catchRate": 1,
"id": 1,
"infinite": false,
"name": "Poké Ball",
"priceGold": 5
}, {
"bound": false,
"buyable": true,
"catchRate": 2,
"id": 2,
"infinite": false,
"name": "Great Ball",
"priceGold": 20
}, {
"bound": false,
"buyable": true,
"catchRate": 3,
"id": 3,
"infinite": false,
"name": "Super Ball",
"priceGold": 50
}, {
"bound": false,
"buyable": true,
"catchRate": 4,
"id": 4,
"infinite": false,
"name": "Ultra Ball",
"priceGold": 130
}, {
"bound": false,
"buyable": false,
"catchRate": 5,
"id": 6,
"infinite": false,
"name": "Idle Ball",
"priceGold": 400
}, {
"bound": true,
"buyable": false,
"catchRate": 5,
"id": 7,
"infinite": true,
"name": "Golden Idle Ball",
"priceGold": 400
}, {
"bound": false,
"buyable": false,
"catchRate": 255,
"id": 5,
"infinite": false,
"name": "Master Ball",
"priceGold": 0
}]

## decisão do usuário (ciclo 5): a casa à direita da porta do Pokémon Center fica transitável; no original ela é
## bloqueada pela peça invisível 8274 (A, collision.json) · origem E (desenhada por nós) · no jogo original: a
## casa (−2,−4) bloqueada pela peça 8274 (A/C) · evidência: collision.json
@export var casas_liberadas: Array = [[-2.0, -4.0]]

## C: "Your team only carries 6 — the rest rest here" Depot · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_cidade.gd`
@export_range(0, 60, 1, "or_greater")  var limite_time: int = 6

## F: receita = pedra do tipo principal da espécie de origem + pedra de cada tipo que a evolução GANHA. Bate com
## os dois exemplos do guia (C): Ivysaur → Venusaur = 4× Leaf (nenhum tipo novo); Charmeleon → Charizard = 2× Fire
## + 2× Feather (ganha Flying). A receita real vem do servidor (o cliente só mostra), por isso é hipótese. A: só o
## tipo PRINCIPAL da origem (G3: Geodude Rocha/Terra pediu 1 Rock Stone, não Rock + Earth) e 4 de um tipo só sem
## tipo novo (livre 19/11: Graveler → Golem). Falta o tipo ganho: abrir a janela de evolução (GET /api/game/evolve
## traz a receita sem evoluir) do Magikarp (prevê Water + Feather) e do Pupitar (2 Rock + 2 Darkness). Tipo →
## pedra (F, nomes das pedras do items.json; Ghost → Darkness e Normal/Fairy → Heart por falta de pedra própria).
## · origem F (em aberto) · evidência: G3, items.json
@export var pedra_por_tipo: Dictionary = {
"BUG": "Cocoon Stone",
"DARK": "Darkness Stone",
"DRAGON": "Crystal Stone",
"ELECTRIC": "Thunder Stone",
"FAIRY": "Heart Stone",
"FIGHTING": "Punch Stone",
"FIRE": "Fire Stone",
"FLYING": "Feather Stone",
"GHOST": "Darkness Stone",
"GRASS": "Leaf Stone",
"GROUND": "Earth Stone",
"ICE": "Ice Stone",
"NORMAL": "Heart Stone",
"POISON": "Venom Stone",
"PSYCHIC": "Enigma Stone",
"ROCK": "Rock Stone",
"STEEL": "Metal Stone",
"WATER": "Water Stone"
}

## limite de sanidade por operação de compra · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_cidade.gd`
@export_range(0.0, 1000000.0, 0.0001, "or_greater")  var qtd_max_por_compra: float = 100000.0

## C: "Eevee is a special case (its own stone system)"; os ramos (cada pedra leva a um Pokémon) seguem o canon
## (B/F). O caminho sem pedra vai para o destino do creatures.json (Vaporeon, A/C). · origem F (em aberto) ·
## evidência: creatures.json
@export var ramos_eevee: Dictionary = {
"134": "Water Stone",
"135": "Thunder Stone",
"136": "Fire Stone",
"196": "Enigma Stone",
"197": "Darkness Stone",
"470": "Leaf Stone",
"471": "Ice Stone",
"700": "Heart Stone"
}

## o inicial não vai para a BOX: o jogador nunca fica sem o Pokémon do começo · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_cidade.gd`
@export var starter_no_time: bool = true
