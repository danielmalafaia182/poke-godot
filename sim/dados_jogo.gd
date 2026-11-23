extends RefCounted
## Catálogo lido de dados/gerados/ (gerado pelo importador a partir do snapshot; nunca editado à mão).

const Fontes := preload("res://sim/fontes.gd")

var especies: Dictionary = {}   # id -> espécie (dicionário do especies.json)
var itens: Dictionary = {}      # id -> item
var hunts: Dictionary = {}      # slug -> hunt
var lote3: Dictionary = {}     # helds e TMs do cliente (C; dados/gerados/lote3.json, ferramentas/importador/extrair_lote3.py)
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
	if FileAccess.file_exists(base + "lote3.json"):
		var l3 = Fontes.ler_json(base + "lote3.json")
		if l3 is Dictionary:
			d.lote3 = l3
	if FileAccess.file_exists(base + "shiny.json"):
		var sh = Fontes.ler_json(base + "shiny.json")
		if sh is Dictionary:
			for k in sh:
				d.shiny[int(k)] = sh[k]
	aplicar_alteracoes(d, preload("res://sim/regras_jogo.gd").alteracoes())
	return d


static func aplicar_alteracoes(d, alt) -> void:
	## Game Master: AlteracoesTabelas do perfil por cima das tabelas importadas (sem alteração, nada muda).
	if alt == null:
		return
	for a in alt.especies:
		var e: Dictionary = d.especies.get(int(a.get("id", -1)), {})
		if not e.is_empty():
			e[String(a["campo"])] = a["valor"]
	for a in alt.loot:
		var e: Dictionary = d.especies.get(int(a.get("especie", -1)), {})
		for l in e.get("loot", []):
			if l.get("itemId") != null and int(l["itemId"]) == int(a.get("itemId", -2)):
				l[String(a["campo"])] = a["valor"]
	for a in alt.hunts:
		var h: Dictionary = d.hunts.get(String(a.get("id", "")), {})
		if not h.is_empty():
			h[String(a["campo"])] = a["valor"]
	for a in alt.itens:
		var it: Dictionary = d.itens.get(int(a.get("id", -1)), {})
		if not it.is_empty():
			it[String(a["campo"])] = a["valor"]


func especie(id: int) -> Dictionary:
	return especies.get(id, {})


func item_por_nome(nome: String) -> Dictionary:
	for i in itens.values():
		if String(i.get("nome", "")) == nome:
			return i
	return {}
