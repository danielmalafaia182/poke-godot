extends Control
## Janela de evolução (fase 4, lote 1), como a do original (C): mostra destino, pedras exigidas × possuídas e os dois
## caminhos — "Evoluir com pedras" (mantém o nível) e "Evoluir sem pedras" (grátis, volta ao Lv.1); com mais de um
## destino (Eevee), escolhe o ramo antes. Regras e receita vêm do serviço (_ej().info_evolucao / evoluir_pokemon).

const ESTILO: Script = preload("res://estilo_hud_original.gd")
var janela: PanelContainer
var corpo: VBoxContainer
var pokemon: DadosPokemon
var destino: int = -1
var resultado: String = ""


static func abrir_para(arvore: SceneTree, alvo: DadosPokemon) -> Control:
	## Reaproveita a janela da cena atual (cidade) ou cria uma.
	var cena := arvore.current_scene
	if cena == null:
		return null
	var pai: Node = cena.get_node_or_null("Interface")
	if pai == null:
		pai = cena
	var painel: Control = pai.get_node_or_null("PainelEvolucao")
	if painel == null:
		painel = load("res://painel_evolucao.gd").new()
		painel.name = "PainelEvolucao"
		pai.add_child(painel)
	painel.abrir(alvo)
	return painel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tema := Theme.new()
	tema.default_font = preload("res://assets/interface/depot/barlow_semibold.ttf")
	tema.default_font_size = 13
	theme = tema
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide())
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	janela.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func abrir(alvo: DadosPokemon) -> void:
	pokemon = alvo
	destino = -1
	resultado = ""
	show()
	atualizar()


func _ajustar() -> void:
	janela.size = Vector2(420, 200).max(janela.get_combined_minimum_size())
	janela.position = (size - janela.size) * 0.5


func _rotulo(texto: String, cor: Color = Color("f0e6d2")) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	corpo.add_child(l)
	return l


func atualizar() -> void:
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	var cab := HBoxContainer.new()
	corpo.add_child(cab)
	var t := Label.new()
	t.text = "Evoluir"
	t.add_theme_font_override("font", preload("res://assets/interface/depot/cinzel.ttf"))
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	var x := Button.new()
	x.text = "×"
	x.pressed.connect(hide)
	cab.add_child(x)
	var info: Dictionary = _ej().info_evolucao(pokemon, destino)
	if info.get("type") == "error" or info.has("reason"):
		_rotulo(String(info.get("message", info.get("reason", ""))), Color("ff8c7a"))
		_ajustar()
		return
	if info.has("branches") and destino < 0:
		_rotulo("Escolha a evolução — cada pedra leva a um Pokémon diferente:")
		for br in info["branches"]:
			var b := Button.new()
			var pedras := ", ".join(br["stones"].map(func(s): return "%d× %s (%d)" % [int(s["need"]), s["name"], int(s["have"])]))
			b.text = "%s — %s%s" % [br["destName"], pedras, "" if br["canEvolve"] else "  🔒 Lv.%d" % int(br["needLevel"])]
			var id := int(br["destId"])
			b.pressed.connect(func() -> void:
				destino = id
				atualizar())
			corpo.add_child(b)
		_ajustar()
		return
	_rotulo("%s Lv.%d → %s" % [info["name"], int(info["level"]), info["destName"]])
	if not bool(info["canEvolve"]):
		_rotulo("🔒 Precisa do nível %d (faltam %d)." % [int(info["needLevel"]), int(info["needLevel"]) - int(info["level"])], Color("ff8c7a"))
	for s in info["stones"]:
		_rotulo("%d× %s — você tem %d" % [int(s["need"]), s["name"], int(s["have"])], Color("8bf07a") if int(s["have"]) >= int(s["need"]) else Color("ff8c7a"))
	_rotulo("Evoluir com pedra mantém o nível. Sem pedra, a evolução é grátis, mas o Pokémon volta ao Lv.1.", Color("b9c3cf"))
	var com := Button.new()
	com.name = "ComPedras"
	com.text = "Evoluir com pedras (mantém Lv.%d)" % int(info["keepLevel"])
	com.disabled = not bool(info["canEvolve"]) or not bool(info["hasStones"])
	com.pressed.connect(func() -> void: _evoluir(true))
	corpo.add_child(com)
	if not bool(info.get("itemOnly", false)):
		var sem := Button.new()
		sem.name = "SemPedras"
		sem.text = "Evoluir sem pedras (volta ao Lv.%d)" % int(info["resetLevel"])
		sem.disabled = not bool(info["canEvolve"])
		sem.pressed.connect(func() -> void: _evoluir(false))
		corpo.add_child(sem)
	if not resultado.is_empty():
		_rotulo(resultado, Color("ff8c7a"))
	_ajustar()
	call_deferred("_ajustar")


func _evoluir(com_pedra: bool) -> void:
	resultado = _ej().evoluir_pokemon(pokemon, com_pedra, destino)
	if resultado.is_empty():
		hide()
	else:
		atualizar()


func _ej() -> Node:
	return get_node("/root/EstadoJogo")
