extends Control
## Janela modal das janelas do ciclo 2 (Hunt Analyzer, Gerenciamento de Captura, Log de Capturas, Pokédex, Todos os Shinys,
## Ginásios, Bosses, Álbum, Visual). Só desenha: quem herda monta o corpo em `montar()`.
## Ciclo 4 (item 8): a moldura das janelas do original (C: `.win-overlay`, `.win-window` e a cabeça hexagonal das janelas
## do cliente — trilhos dourados, joias turquesa nas pontas, título centralizado em Cinzel, × à direita —; A: o vídeo,
## quadro 25_bolas_usadas/v2_00272): fundo escuro, borda dourada, abas em pílula (a ativa com borda dourada).
## Medidas em px da tela de 1880 do original.

const ESTILO: Script = preload("res://estilo_hud_original.gd")
const T := preload("res://textos.gd")
const CINZEL: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const BARLOW: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const BARLOW_B: Font = preload("res://assets/interface/fiel/barlow_bold.ttf")
const REF := 1880.0
var janela: PanelContainer
var titulo: Label
var abas: HBoxContainer
var corpo: VBoxContainer
var rolagem: ScrollContainer
var tamanho := Vector2(560, 480)
var aba := ""
var _cab: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sombra := ColorRect.new()   # C: .win-overlay #0009
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hide())
	janela = PanelContainer.new()
	janela.name = "Janela"
	var sj := StyleBoxFlat.new()
	sj.bg_color = Color("0d141c")
	sj.border_color = Color("9c7a34")
	sj.border_width_left = 2
	sj.border_width_right = 2
	sj.border_width_bottom = 2
	sj.corner_radius_bottom_left = 10
	sj.corner_radius_bottom_right = 10
	sj.shadow_color = Color(0, 0, 0, 0.7)
	sj.shadow_size = 20
	janela.add_theme_stylebox_override("panel", sj)
	add_child(janela)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	janela.add_child(col)
	_cab = Control.new()
	_cab.name = "Cabeca"
	_cab.custom_minimum_size = Vector2(0, 44)
	_cab.draw.connect(_desenhar_cabeca)
	col.add_child(_cab)
	titulo = Label.new()
	titulo.name = "Titulo"
	var fv := FontVariation.new()
	fv.base_font = CINZEL
	fv.spacing_glyph = 1
	titulo.add_theme_font_override("font", fv)
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color("e8d7b0"))
	titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cab.add_child(titulo)
	var x := Button.new()
	x.name = "Fechar"
	x.text = "×"
	x.flat = true
	x.tooltip_text = T.t("common.close", {}, "Fechar")
	x.add_theme_font_size_override("font_size", 22)
	x.add_theme_color_override("font_color", Color("9aa6b3"))
	x.add_theme_color_override("font_hover_color", Color("e2756b"))
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -50
	x.offset_right = -16
	x.offset_top = 4
	x.offset_bottom = 40
	x.pressed.connect(hide)
	_cab.add_child(x)
	var mg := MarginContainer.new()   # C: .win-body padding 14 16 16
	mg.add_theme_constant_override("margin_left", 16)
	mg.add_theme_constant_override("margin_right", 16)
	mg.add_theme_constant_override("margin_top", 12)
	mg.add_theme_constant_override("margin_bottom", 16)
	mg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mg)
	var dentro := VBoxContainer.new()
	dentro.add_theme_constant_override("separation", 10)
	mg.add_child(dentro)
	abas = HBoxContainer.new()
	abas.name = "Abas"
	abas.alignment = BoxContainer.ALIGNMENT_CENTER
	abas.add_theme_constant_override("separation", 8)
	dentro.add_child(abas)
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dentro.add_child(rolagem)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 6)
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(corpo)
	var tema := Theme.new()
	tema.default_font = BARLOW
	tema.default_font_size = 13
	janela.theme = tema
	resized.connect(_ajustar)
	hide()


func _desenhar_cabeca() -> void:
	## C: cabeça hexagonal escura, trilhos dourados em cima e embaixo, joias turquesa nas duas pontas.
	var w := _cab.size.x
	var h := _cab.size.y
	var k := 14.0
	var pts := PackedVector2Array([Vector2(k, 0), Vector2(w - k, 0), Vector2(w, k), Vector2(w, h - k), Vector2(w - k, h),
		Vector2(k, h), Vector2(0, h - k), Vector2(0, k)])
	_cab.draw_colored_polygon(pts, Color("08101a"))
	_cab.draw_line(Vector2(40, 1), Vector2(w - 40, 1), Color("f4e2a8"), 2.0)
	_cab.draw_line(Vector2(40, 4), Vector2(w - 40, 4), Color("d8b871"), 1.0)
	_cab.draw_line(Vector2(40, h - 1), Vector2(w - 40, h - 1), Color("7e5f28"), 2.0)
	_cab.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("9c7a34"), 1.5)
	for px in [0.0, w]:
		var cc := Vector2(px, h * 0.5)
		var g := PackedVector2Array([cc + Vector2(0, -7), cc + Vector2(7, 0), cc + Vector2(0, 7), cc + Vector2(-7, 0)])
		_cab.draw_colored_polygon(g, Color("0ac8b9"))
		_cab.draw_polyline(g + PackedVector2Array([g[0]]), Color("7fe6dd"), 1.0)


func abrir() -> void:
	show()
	atualizar()


func _ajustar() -> void:
	var f := maxf(0.5, size.x / REF)
	var t := Vector2(minf(tamanho.x, size.x / f - 32), minf(tamanho.y, size.y / f - 32))
	janela.scale = Vector2(f, f)
	janela.size = t
	janela.position = ((size - t * f) * 0.5).round()
	if _cab != null:
		_cab.queue_redraw()


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
	## C: abas em pílula (a ativa: fundo escuro, borda dourada, texto creme; as outras: borda apagada).
	var b := Button.new()
	b.name = "Aba_" + chave
	b.text = texto
	b.toggle_mode = true
	b.button_pressed = aba == chave
	var on := aba == chave
	b.add_theme_font_override("font", BARLOW_B)
	b.add_theme_font_size_override("font_size", 12)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color("f0e6d2") if on else Color("aab6c3"))
	for estado in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("161d26") if on else Color("0f151d")
		sb.border_color = Color("c8aa6e") if on else (Color("6a5a3a") if estado.begins_with("hover") else Color("3a4656"))
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(999)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		b.add_theme_stylebox_override(estado, sb)
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
