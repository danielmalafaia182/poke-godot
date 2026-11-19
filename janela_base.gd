extends Control
## Janela modal simples (fundo escurecido, moldura do HUD original, título, corpo com rolagem e Fechar), para as
## janelas do ciclo 2 (Hunt Analyzer, Gerenciamento de Captura, Log de Capturas, Perfil, Tutorial). Só desenha: quem
## herda monta o corpo em `montar()`.

const ESTILO: Script = preload("res://estilo_hud_original.gd")
const T := preload("res://textos.gd")
var janela: PanelContainer
var titulo: Label
var abas: HBoxContainer
var corpo: VBoxContainer
var rolagem: ScrollContainer
var tamanho := Vector2(560, 480)
var aba := ""


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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	janela.add_child(col)
	var cab := HBoxContainer.new()
	col.add_child(cab)
	titulo = Label.new()
	titulo.add_theme_color_override("font_color", Color("f0c040"))
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(titulo)
	var x := Button.new()
	x.name = "Fechar"
	x.text = "✕"
	x.tooltip_text = T.t("common.close", {}, "Fechar")
	x.pressed.connect(hide)
	cab.add_child(x)
	abas = HBoxContainer.new()
	abas.add_theme_constant_override("separation", 4)
	col.add_child(abas)
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(rolagem)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 6)
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func abrir() -> void:
	show()
	atualizar()


func _ajustar() -> void:
	var t := Vector2(minf(tamanho.x, size.x - 32), minf(tamanho.y, size.y - 32))
	janela.size = t
	janela.position = (size - t) * 0.5


func limpar() -> void:
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	for c in abas.get_children():
		abas.remove_child(c)
		c.queue_free()


func atualizar() -> void:
	limpar()
	montar()
	_ajustar()


func montar() -> void:
	pass


func rotulo(t: String, cor: Color = Color("f0e6d2"), tam: int = 0, pai: Control = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", cor)
	if tam > 0:
		l.add_theme_font_size_override("font_size", tam)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(pai if pai != null else corpo).add_child(l)
	return l


func linha(esq: String, dir: String, cor_dir: Color = Color.WHITE) -> void:
	var h := HBoxContainer.new()
	corpo.add_child(h)
	var a := rotulo(esq, Color("c8b89a"), 0, h)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := rotulo(dir, cor_dir, 0, h)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func botao_aba(chave: String, texto: String) -> void:
	var b := Button.new()
	b.name = "Aba_" + chave
	b.text = texto
	b.toggle_mode = true
	b.button_pressed = aba == chave
	b.pressed.connect(func() -> void:
		aba = chave
		atualizar())
	abas.add_child(b)


func botao(texto: String, acao: Callable, nome: String = "", pai: Control = null) -> Button:
	var b := Button.new()
	b.text = texto
	if nome != "":
		b.name = nome
	b.pressed.connect(acao)
	(pai if pai != null else corpo).add_child(b)
	return b


static func n(v: float) -> String:
	## 1234567 → "1.234.567" (negativo com sinal)
	var neg := v < 0
	var s := str(absi(int(round(v))))
	var r := ""
	while s.length() > 3:
		r = "." + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + r


static func duracao(seg: int) -> String:
	var h := seg / 3600
	var m := (seg % 3600) / 60
	var s := seg % 60
	return "%dh %02dmin" % [h, m] if h > 0 else "%dmin %02ds" % [m, s]
