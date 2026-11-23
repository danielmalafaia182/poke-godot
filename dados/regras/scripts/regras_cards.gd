@tool
class_name RegrasCards
extends Resource
## RegrasCards — cards.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Geral")
## peso de cada raridade no sorteio do Poke Card Pack (o original não mostra): a comum é ~60% e as hiper-raras ~1
## em 2000 · origem E (desenhada por nós) · evidência: comentário em `sim/servico_cards.gd`
@export var pesos_raridade: Dictionary = {
"classic_collection": 0.4,
"common": 60.0,
"double_rare": 4.0,
"futuristic_rare": 0.05,
"illustration_rare": 2.5,
"mega_hyper_rare": 0.05,
"pikachu_rare": 1.0,
"rare": 8.0,
"special_illustration_rare": 1.0,
"ultra_rare": 3.0,
"uncommon": 20.0
}
