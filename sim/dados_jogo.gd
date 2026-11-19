extends RefCounted
## Catálogo lido de dados/gerados/ (gerado pelo importador a partir do snapshot; nunca editado à mão).

const Fontes := preload("res://sim/fontes.gd")

var especies: Dictionary = {}   # id -> espécie (dicionário do especies.json)
var itens: Dictionary = {}      # id -> item
var hunts: Dictionary = {}      # slug -> hunt
var shiny: Dictionary = {}      # speciesId -> {looktype, tier, icone, cadaver} (C: SHINY_BY_DEX; só estas têm forma shiny)


static func carregar() -> RefCounted:
	var d: RefCounted = load("res://sim/dados_jogo.gd").new()
	var base := Fontes.pasta_dados() + "/gerados/"
	for e in Fontes.ler_json(base + "especies.json"):
		d.especies[int(e["id"])] = e
	for i in Fontes.ler_json(base + "itens.json"):
		d.itens[int(i["id"])] = i
	for h in Fontes.ler_json(base + "hunts.json"):
		d.hunts[String(h["slug"])] = h
	if FileAccess.file_exists(base + "shiny.json"):
		var sh = Fontes.ler_json(base + "shiny.json")
		if sh is Dictionary:
			for k in sh:
				d.shiny[int(k)] = sh[k]
	return d


func especie(id: int) -> Dictionary:
	return especies.get(id, {})


func item_por_nome(nome: String) -> Dictionary:
	for i in itens.values():
		if String(i.get("nome", "")) == nome:
			return i
	return {}
