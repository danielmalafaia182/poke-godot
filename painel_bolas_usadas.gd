extends "res://janela_base.gd"
## Gerenciamento de Captura (C: window.usedBalls; textos do pacote original). Desenha o medidor de captura por espécie
## (EstadoJogo.medidor_captura, o mesmo da sim: C /api/game/used-balls; A goldSpent = ouro desde a última captura):
## tentativas desde a última captura (zera ao capturar), tentativas totais (nunca zera), ouro gasto e se já capturou.

const PONTE := preload("res://ponte_cidade.gd")
var busca := ""


func _ready() -> void:
	tamanho = Vector2(980, 660)   # A: no vídeo o Gerenciamento de Captura ocupa ~980 × 660 px de 1880
	aba = "normal"
	super._ready()


func linhas() -> Array:
	## [{id, nome, shiny, recentes, total, gasto, capturado}] ordenadas por tentativas totais.
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var donos := {}
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk != null and pk.especie != null:
			donos["%s|%s" % [String(pk.especie.nome), str(pk.shiny)]] = true
	for e in ej.log_capturas:
		donos["%s|%s" % [String(e.get("especie", "")), str(bool(e.get("shiny", false)))]] = true
	var r: Array = []
	for k in ej.medidor_captura:
		var ks := String(k)
		var shiny := ks.ends_with("s")
		var id := int(ks.trim_suffix("s"))
		var m: Dictionary = ej.medidor_captura[k]
		var nome := String(dados.especie(id).get("nome", "#%d" % id))
		r.append({"id": id, "nome": nome, "shiny": shiny, "recentes": int(m.get("tentativas", 0)), "total": int(m.get("total", 0)),
			"gasto": int(m.get("gasto", 0)), "preco": int(dados.especie(id).get("precoNpc", 0)), "capturado": donos.has("%s|%s" % [nome, str(shiny)])})
	r.sort_custom(func(a, b): return int(a["total"]) > int(b["total"]) or (int(a["total"]) == int(b["total"]) and String(a["nome"]) < String(b["nome"])))
	return r


func montar() -> void:
	titulo.text = T.t("window.usedBalls.title", {}, "Gerenciamento de Captura")
	botao_aba("normal", T.t("window.usedBalls.tabBalls"))
	botao_aba("shiny", T.t("window.usedBalls.tabShiny"))
	var campo := LineEdit.new()
	campo.name = "Busca"
	campo.placeholder_text = T.t("window.usedBalls.searchPlaceholder")
	campo.text = busca
	campo.text_changed.connect(func(t: String) -> void:
		busca = t
		_preencher())
	corpo.add_child(campo)
	var lista := VBoxContainer.new()
	lista.name = "Lista"
	corpo.add_child(lista)
	_preencher()


func _preencher() -> void:
	var lista: VBoxContainer = corpo.get_node_or_null("Lista")
	if lista == null:
		return
	for c in lista.get_children():
		lista.remove_child(c)
		c.queue_free()
	var cab := HBoxContainer.new()
	lista.add_child(cab)
	for par in [[T.t("window.usedBalls.colName"), 200], [T.t("window.usedBalls.recentAttempts"), 130], [T.t("window.usedBalls.totalAttempts"), 120], ["$", 90]]:
		var l := rotulo(String(par[0]), Color("f0c040"), 0, cab)
		l.custom_minimum_size.x = int(par[1])
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	cab.get_child(1).tooltip_text = T.t("window.usedBalls.recentAttemptsTip")
	cab.get_child(1).mouse_filter = Control.MOUSE_FILTER_STOP
	cab.get_child(2).tooltip_text = T.t("window.usedBalls.totalAttemptsTip")
	cab.get_child(2).mouse_filter = Control.MOUSE_FILTER_STOP
	var achou := false
	for e in linhas():
		if bool(e["shiny"]) != (aba == "shiny"):
			continue
		if busca != "" and String(e["nome"]).to_lower().find(busca.to_lower()) < 0 and str(int(e["id"])) != busca:
			continue
		achou = true
		var h := HBoxContainer.new()
		h.name = "L_%d%s" % [int(e["id"]), "s" if bool(e["shiny"]) else ""]
		lista.add_child(h)
		var nome := rotulo(("✨ " if bool(e["shiny"]) else "") + String(e["nome"]), Color.WHITE, 0, h)
		nome.custom_minimum_size.x = 200
		nome.tooltip_text = T.t("window.usedBalls.alreadyCaught") if bool(e["capturado"]) else T.t("window.usedBalls.notCaught")
		nome.mouse_filter = Control.MOUSE_FILTER_STOP
		if bool(e["capturado"]):
			nome.text += "  ✓"
		for par in [[str(int(e["recentes"])), 130], [str(int(e["total"])), 120], [n(e["gasto"]), 90]]:
			var l := rotulo(String(par[0]), Color("c8b89a"), 0, h)
			l.custom_minimum_size.x = int(par[1])
		h.get_child(3).tooltip_text = T.t("window.usedBalls.priceSpentTip", {"price": n(e["preco"]), "spent": n(e["gasto"])})
		h.get_child(3).mouse_filter = Control.MOUSE_FILTER_STOP
	if not achou:
		rotulo(T.t("window.usedBalls.emptyShiny") if aba == "shiny" else T.t("window.usedBalls.emptyCaptures"), Color("c8b89a"), 0, lista)
