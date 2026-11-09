class_name PlacaInteracao
extends Control
const UI: Script = preload("res://estilo_ui_fiel.gd")
const FONTE: Script = preload("res://fonte_mundo.gd")
var nome: TextureRect
var botao: Button
static var _estilos: Dictionary = {}
func configurar(titulo: String, acao: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1 # Acima do mundo, abaixo do HUD e dos modais na mesma Interface.
	nome = TextureRect.new()
	nome.texture = FONTE.texto(titulo)
	nome.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	nome.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nome)
	botao = Button.new()
	botao.text = acao
	botao.add_theme_font_override("font",UI.FORTE)
	botao.add_theme_font_size_override("font_size",10)
	for estado in ["font_color","font_hover_color","font_pressed_color"]:
		botao.add_theme_color_override(estado,Color("1a1206"))
	botao.add_theme_stylebox_override("normal",_estilo(false))
	botao.add_theme_stylebox_override("hover",_estilo(true))
	botao.add_theme_stylebox_override("pressed",_estilo(false))
	botao.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	botao.custom_minimum_size = Vector2(ceilf(UI.FORTE.get_string_size(acao,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x)+18,20)
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(botao)
	var largura: float = maxf(nome.texture.get_width(),botao.custom_minimum_size.x)
	size = Vector2(largura,39)
	nome.size = nome.texture.get_size()
	nome.position = Vector2(floorf((largura-nome.size.x)*0.5),0)
	botao.size = botao.custom_minimum_size
	botao.position = Vector2(floorf((largura-botao.size.x)*0.5),19)
func posicionar(ancora: Vector2) -> void:
	# field-plate: tileToView -46px; transform translate(-50%,-100%).
	position = (ancora-Vector2(size.x*0.5,46+size.y)).round()
static func _estilo(hover: bool) -> StyleBoxTexture:
	var chave: String = str(hover)
	if not _estilos.has(chave):
		var estilo: StyleBoxTexture = StyleBoxTexture.new()
		var topo: String = "f1d99e" if hover else "e6cd8e"
		var fundo: String = "d6b35d" if hover else "c8a24e"
		estilo.texture = UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="24"><defs><linearGradient id="g" x2="0" y2="1"><stop stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient></defs><rect x=".5" y=".5" width="95" height="23" rx="6" fill="url(#g)" stroke="#6a5223"/></svg>' % [topo,fundo])
		estilo.set_texture_margin_all(7)
		estilo.content_margin_left = 8
		estilo.content_margin_right = 8
		estilo.content_margin_top = 2
		estilo.content_margin_bottom = 2
		_estilos[chave] = estilo
	return _estilos[chave]
