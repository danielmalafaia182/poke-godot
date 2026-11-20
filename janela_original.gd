extends Control
## Janela com a identidade visual do original (ciclo 4, item 8; C: a moldura das janelas do cliente — `.pf-window`: fundo
## #101823→#090e15, borda #9c7a34, cabeça hexagonal com trilhos dourados e joias turquesa, título em Cinzel dourado e ×).
## Usada pelos itens do dock que não têm janela própria no jogo offline: mostra o ícone do item, o nome do original
## (hud.world.menu.*), um texto e, quando há algo a fazer offline, um botão (Sair do jogo, Modo Soneca…).

const T := preload("res://textos.gd")
const BARLOW: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const BARLOW_B: Font = preload("res://assets/interface/fiel/barlow_bold.ttf")
const CINZEL: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const LARGURA := 400.0
const REF := 1880.0

var janela: PanelContainer
var titulo: Label
var icone: TextureRect
var texto: RichTextLabel
var acao: Button
var chave := ""
var _acao_cb: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veu := ColorRect.new()
	veu.color = Color("02060eb8")
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hide())
	add_child(veu)
	janela = PanelContainer.new()
	janela.name = "Janela"
	var s := StyleBoxFlat.new()
	s.bg_color = Color("0d141c")
	s.border_color = Color("9c7a34")
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_bottom = 2
	s.corner_radius_bottom_left = 12; s.corner_radius_bottom_right = 12
	s.shadow_color = Color(0, 0, 0, 0.72)
	s.shadow_size = 22
	janela.add_theme_stylebox_override("panel", s)
	add_child(janela)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	janela.add_child(col)
	var cab := Control.new()
	cab.custom_minimum_size = Vector2(LARGURA - 4, 44)
	cab.draw.connect(func() -> void:
		var w := cab.size.x
		var h := cab.size.y
		var k := 14.0
		var pts := PackedVector2Array([Vector2(k, 0), Vector2(w - k, 0), Vector2(w, k), Vector2(w, h - k), Vector2(w - k, h),
			Vector2(k, h), Vector2(0, h - k), Vector2(0, k)])
		cab.draw_colored_polygon(pts, Color("08101a"))
		cab.draw_line(Vector2(40, 1), Vector2(w - 40, 1), Color("f4e2a8"), 2.0)
		cab.draw_line(Vector2(40, h - 1), Vector2(w - 40, h - 1), Color("7e5f28"), 2.0)
		cab.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("9c7a34"), 1.5)
		for x in [0.0, w]:
			var cc := Vector2(x, h * 0.5)
			var g := PackedVector2Array([cc + Vector2(0, -7), cc + Vector2(7, 0), cc + Vector2(0, 7), cc + Vector2(-7, 0)])
			cab.draw_colored_polygon(g, Color("0ac8b9"))
			cab.draw_polyline(g + PackedVector2Array([g[0]]), Color("7fe6dd"), 1.0))
	col.add_child(cab)
	titulo = Label.new()
	titulo.name = "Titulo"
	var fv := FontVariation.new()
	fv.base_font = CINZEL
	fv.spacing_glyph = 2
	titulo.add_theme_font_override("font", fv)
	titulo.add_theme_font_size_override("font_size", 15)
	titulo.add_theme_color_override("font_color", Color("ddc082"))
	titulo.position = Vector2(46, 11)
	cab.add_child(titulo)
	var x := Button.new()
	x.name = "Fechar"
	x.text = "×"
	x.flat = true
	x.add_theme_font_size_override("font_size", 20)
	x.add_theme_color_override("font_color", Color("9aa6b3"))
	x.add_theme_color_override("font_hover_color", Color("e2756b"))
	x.position = Vector2(LARGURA - 4 - 50, 6)
	x.pressed.connect(hide)
	cab.add_child(x)
	var mg := MarginContainer.new()
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mg.add_theme_constant_override(k, 18)
	col.add_child(mg)
	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 12)
	mg.add_child(corpo)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 14)
	corpo.add_child(linha)
	icone = TextureRect.new()
	icone.custom_minimum_size = Vector2(48, 48)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	linha.add_child(icone)
	texto = RichTextLabel.new()
	texto.name = "Texto"
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.custom_minimum_size.x = LARGURA - 4 - 36 - 48 - 14   # largura fixa: sem ela o texto quebra a cada letra
	texto.add_theme_font_override("normal_font", BARLOW)
	texto.add_theme_font_override("bold_font", BARLOW_B)
	texto.add_theme_font_size_override("normal_font_size", 13)
	texto.add_theme_font_size_override("bold_font_size", 13)
	texto.add_theme_color_override("default_color", Color("b9c3cf"))
	linha.add_child(texto)
	acao = Button.new()   # C: .npc-dlg-btn (dourado)
	acao.name = "Acao"
	acao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	acao.add_theme_font_override("font", BARLOW_B)
	acao.add_theme_font_size_override("font_size", 14)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		acao.add_theme_color_override(c, Color("1a1206"))
	for estado in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("d7b76e") if estado == "normal" else Color("e6cd8e")
		sb.border_color = Color("6a5223")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 9; sb.content_margin_bottom = 9
		acao.add_theme_stylebox_override(estado, sb)
	acao.pressed.connect(func() -> void:
		if _acao_cb.is_valid():
			_acao_cb.call())
	corpo.add_child(acao)
	resized.connect(_ajustar)
	hide()


func abrir(k: String, nome: String, tex: Texture2D, corpo_bbcode: String, rotulo_acao: String = "", cb: Callable = Callable()) -> void:
	chave = k
	titulo.text = nome.to_upper()
	icone.texture = tex
	texto.text = corpo_bbcode
	acao.visible = rotulo_acao != ""
	acao.text = rotulo_acao
	_acao_cb = cb
	show()
	_ajustar()


func _ajustar() -> void:
	if janela == null:
		return
	var f := maxf(0.5, size.x / REF)
	janela.scale = Vector2(f, f)
	janela.size = Vector2(LARGURA, 0)
	janela.reset_size()
	janela.size.x = LARGURA
	janela.position = ((size - janela.size * f) * 0.5).round()
