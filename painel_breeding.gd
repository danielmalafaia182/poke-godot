extends "res://janela_base.gd"
## Centro de Breeding (ciclo 8; sim/servico_breeding.gd). Pelo cliente (C, window.breeding.*): Par reprodutor escolhido na
## box, caminho com feromônio (Δ cheio) ou livre (Δ ~20× menor), dobro de pedras (5% de +1 no IV), Criar Ovo (consome os
## pais), incubadora com os ovos e as derrotas que faltam.

var pai_a := ""
var pai_b := ""
var caminho := "feromonio"
var dobro := false
var aviso := ""


func _ready() -> void:
	tamanho = Vector2(860, 640)
	super._ready()


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func montar() -> void:
	titulo.text = T.t("window.breeding.title", {}, "Centro de Breeding")
	rotulo(T.t("window.breeding.subtitle"), Color("c8b89a"))
	var ej := _ej()
	var ovos: Array = ej.breeding.get("ovos", [])
	rotulo("Incubadora: %d/%d · %s" % [ovos.size(), int(ej.servico_breeding().p.slots), T.t("window.breeding.incHint")], Color("9fc0e8"))
	var d = preload("res://ponte_cidade.gd").dados()
	for o in ovos:
		rotulo("🥚 %s · Quality %.3f%s · faltam %d derrotas" % [String(d.especie(int(o["speciesId"])).get("nome", "?")), float(o["quality"]),
			" ✨" if bool(o["shiny"]) else "", int(o["faltam"])], Color("f0e6d2"))
	rotulo(T.t("window.breeding.pairTitle") + " — " + T.t("window.breeding.boxTitle"), Color("f0c040"), 15)
	var grade := HFlowContainer.new()
	corpo.add_child(grade)
	var lista: Array = ej.pokemons_capturados.duplicate()
	lista.sort_custom(func(x, y): return String(x.especie.nome) < String(y.especie.nome) or (String(x.especie.nome) == String(y.especie.nome) and x.qualidade > y.qualidade))
	for pk in lista:
		if String(pk.especie.nome) == "Ditto":
			continue
		var b := Button.new()
		b.name = "Pai_" + pk.id_persistente
		b.toggle_mode = true
		b.button_pressed = pk.id_persistente in [pai_a, pai_b]
		b.text = "%s%s Lv%d · Q %.3f" % ["✨" if pk.shiny else "", pk.especie.nome, pk.nivel, pk.qualidade]
		b.pressed.connect(func() -> void:
			if pk.id_persistente == pai_a:
				pai_a = ""
			elif pk.id_persistente == pai_b:
				pai_b = ""
			elif pai_a == "":
				pai_a = pk.id_persistente
			else:
				pai_b = pk.id_persistente
			atualizar())
		grade.add_child(b)
	var opc := HBoxContainer.new()
	corpo.add_child(opc)
	for par in [["feromonio", T.t("window.breeding.pathPherHint")], ["livre", T.t("window.breeding.pathFreeHint")]]:
		var c := CheckBox.new()
		c.name = "Caminho_" + String(par[0])
		c.text = ("Strange Pheromone · " if par[0] == "feromonio" else "Livre · ") + String(par[1])
		c.button_pressed = caminho == String(par[0])
		c.toggled.connect(func(v: bool) -> void:
			if v:
				caminho = String(par[0])
				atualizar())
		opc.add_child(c)
	var dc := CheckBox.new()
	dc.name = "Dobro"
	dc.text = T.t("window.breeding.doubleStonesHint")
	dc.tooltip_text = T.t("window.breeding.doubleStonesTip")
	dc.button_pressed = dobro
	dc.toggled.connect(func(v: bool) -> void: dobro = v)
	corpo.add_child(dc)
	var criar := Button.new()
	criar.name = "CriarOvo"
	criar.text = T.t("window.breeding.createEgg")
	criar.disabled = pai_a == "" or pai_b == ""
	criar.tooltip_text = T.t("window.breeding.consumeHint")
	criar.pressed.connect(func() -> void:
		var r: Dictionary = ej.breed(pai_a, pai_b, caminho, dobro)
		aviso = String(r["erro"]) if r.has("erro") else T.t("window.breeding.eggAdded")
		if not r.has("erro"):
			pai_a = ""
			pai_b = ""
		atualizar())
	corpo.add_child(criar)
	if aviso != "":
		rotulo(aviso, Color("f0c040"))
