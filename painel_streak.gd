extends Control
## Streak Points (fase 4, lote 2). Só desenha e manda comandos: contas e custos vêm de sim/servico_jogador.gd
## (EstadoJogo.streak_info / gastar_streak). C: 1 ponto a cada 1000 abates; n-ésimo ponto custa 25.000 × n de ouro;
## cada ponto vai para uma trilha (EXP, Loot, Shiny) com +0,1%.

const ESTILO: Script = preload("res://estilo_hud_original.gd")
var janela: PanelContainer
var corpo: VBoxContainer
var aviso := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hide())
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	janela.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func abrir() -> void:
	aviso = ""
	show()
	atualizar()


func _ajustar() -> void:
	janela.size = Vector2(420, 260).max(janela.get_combined_minimum_size())
	janela.position = (size - janela.size) * 0.5


func _rotulo(t: String, cor: Color = Color("f0e6d2")) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corpo.add_child(l)


func atualizar() -> void:
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	var ej: Node = get_node("/root/EstadoJogo")
	var s: Dictionary = ej.streak_info()
	var cab := HBoxContainer.new()
	corpo.add_child(cab)
	var t := Label.new()
	t.text = "Streak Points"
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	var x := Button.new()
	x.text = "×"
	x.pressed.connect(hide)
	cab.add_child(x)
	_rotulo("Abates: %d · disponíveis: %d · gastos: %d" % [int(s["totalKills"]), int(s["available"]), int(s["spent"])])
	_rotulo("Próximo ponto em %d abates · próximo custa 💲%d" % [int(s["toNext"]), int(s["nextCost"])], Color("b9c3cf"))
	for trilha in ["exp", "loot", "shiny"]:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s: %d ponto(s), +%.1f%%" % [trilha.to_upper(), int(s["tracks"][trilha]), float(s["bonusPct"][trilha])]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var b := Button.new()
		b.name = "Investir_" + trilha
		b.text = "+ Investir (💲%d)" % int(s["nextCost"])
		b.disabled = not bool(s["canBuy"])
		b.pressed.connect(func() -> void:
			var erro: String = ej.gastar_streak(trilha)
			aviso = erro if not erro.is_empty() else "Ponto investido em %s (+0,1%%)." % trilha.to_upper()
			atualizar())
		h.add_child(b)
		corpo.add_child(h)
	var mais: Array = []
	for k in (s.get("kills", []) as Array).slice(0, 5):
		mais.append("%s %d" % [String(k["name"]), int(k["kills"])])
	if not mais.is_empty():
		_rotulo("Mais abatidos: " + " · ".join(mais), Color("b9c3cf"))
	_rotulo("Shiny: o jogo offline ainda não tem shiny (o ponto fica guardado).", Color("8a96a3"))
	if not aviso.is_empty():
		_rotulo(aviso, Color("f0c040"))
	_ajustar()
	call_deferred("_ajustar")
