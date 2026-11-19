extends "res://janela_base.gd"
## Todos os Shinys (C: window.allPokes; textos do pacote original): as 190 espécies com forma shiny do cliente
## (dados/gerados/shiny.json, SHINY_BY_DEX), por tier, com busca e a marca das que você já capturou shiny.

const PONTE := preload("res://ponte_cidade.gd")
const Fontes := preload("res://sim/fontes.gd")
var busca := ""


func _ready() -> void:
	tamanho = Vector2(640, 600)
	super._ready()


func lista() -> Dictionary:
	## tier -> [{id, nome, capturado}]
	var t = Fontes.ler_json(Fontes.pasta_dados() + "/gerados/shiny.json")
	var ej: Node = get_node("/root/EstadoJogo")
	var tem := {}
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk != null and pk.especie != null and pk.shiny:
			tem[String(pk.especie.nome)] = true
	for e in ej.log_capturas:
		if bool(e.get("shiny", false)):
			tem[String(e.get("especie", ""))] = true
	var r := {}
	if not t is Dictionary:
		return r
	for k in t:
		var nome := String(PONTE.dados().especie(int(k)).get("nome", "#" + str(k)))
		var tier := String(t[k].get("tier", "?"))
		if not r.has(tier):
			r[tier] = []
		r[tier].append({"id": int(k), "nome": nome, "capturado": tem.has(nome)})
	for tier in r:
		r[tier].sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return r


func montar() -> void:
	titulo.text = T.t("window.allPokes.title", {}, "Todos os Shinys")
	var l := lista()
	var n := 0
	for tier in l:
		n += (l[tier] as Array).size()
	rotulo(T.t("window.allPokes.total", {"count": n}), Color("c8b89a"))
	var campo := LineEdit.new()
	campo.name = "Busca"
	campo.placeholder_text = T.t("window.allPokes.searchPlaceholder")
	campo.text = busca
	campo.text_submitted.connect(func(t: String) -> void:
		busca = t
		atualizar())
	corpo.add_child(campo)
	var tiers := l.keys()
	tiers.sort()
	var algum := false
	for tier in tiers:
		var itens: Array = (l[tier] as Array).filter(func(e): return busca == "" or String(e["nome"]).to_lower().find(busca.to_lower()) >= 0)
		if itens.is_empty():
			continue
		algum = true
		rotulo("Tier %s · %s" % [tier, T.t("window.allPokes.tierCount", {"n": itens.size()})], Color("f0c040"))
		var grade := GridContainer.new()
		grade.columns = 4
		corpo.add_child(grade)
		for e in itens:
			var lb := rotulo(("✓ " if bool(e["capturado"]) else "") + T.t("window.allPokes.shinyName", {"name": String(e["nome"])}), Color("ffe080") if bool(e["capturado"]) else Color("c8b89a"), 0, grade)
			lb.name = "S_%d" % int(e["id"])
			lb.custom_minimum_size.x = 145
	if not algum:
		rotulo(T.t("window.allPokes.empty"), Color("c8b89a"))
