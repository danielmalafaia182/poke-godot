@tool
class_name AlteracoesTabelas
extends Resource
## Alterações sobre as tabelas importadas (dados/gerados/*.json, que nunca são editadas à mão), aplicadas por cima ao
## carregar (sim/dados_jogo.gd). Fica em dados/regras/<perfil>/alteracoes.tres (ou user://regras/<perfil>/). Bosses e
## ginásios são editáveis direto em RegrasBosses.lista e RegrasGinasios (Resources de regras).
## Cada item é um dicionário; o Game Master (aba Tabelas) monta e mostra o valor original ao lado.

## Espécies: {"id": speciesId, "campo": "xpAbate" | "precoNpc" | "valorVenda" | "raridade" | "nivelHunt", "valor": novo}.
## xpAbate = XP base por abate (A: experience da espécie); precoNpc = preço da espécie no medidor de captura (A).
@export var especies: Array[Dictionary] = []

## Loot de uma espécie: {"especie": speciesId, "itemId": id, "campo": "chanceBruta" | "min" | "max", "valor": novo}.
## chanceBruta em 1/100.000 por abate (A: creatures.json).
@export var loot: Array[Dictionary] = []

## Hunts: {"id": slug, "campo": "nivel", "valor": novo} (nível dos selvagens e o exigido do treinador, C).
@export var hunts: Array[Dictionary] = []

## Itens: {"id": itemId, "campo": "precoNpc" | "precoGold" | "cura", "valor": novo} (preços A: items.json).
@export var itens: Array[Dictionary] = []


func vazio() -> bool:
	return especies.is_empty() and loot.is_empty() and hunts.is_empty() and itens.is_empty()
