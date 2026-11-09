extends RefCounted
# Estilos locais: preserva a identidade dos demais painéis e os dados do jogo.
const UI: Script = preload("res://estilo_ui_fiel.gd")
static var _cache: Dictionary = {}
static func gradiente(chave: String, topo: String, fundo: String, borda: String, raio: int) -> StyleBoxTexture:
	if _cache.has(chave): return _cache[chave]
	var estilo: StyleBoxTexture = StyleBoxTexture.new()
	estilo.texture=UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="64"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient></defs><rect x=".5" y=".5" width="255" height="63" rx="%d" fill="url(#g)" stroke="#%s"/></svg>' % [topo,fundo,raio,borda])
	estilo.set_texture_margin_all(raio+1)
	_cache[chave]=estilo
	return estilo
static func cartao(lider: bool, hover: bool = false) -> StyleBoxTexture:
	return gradiente("cartao"+str(lider)+str(hover),"192733" if hover else "14212c","0a121b","c8aa6e" if lider or hover else "35414e",10)
static func aplicar_auto_helper(botao: Button) -> void:
	botao.text=""
	botao.icon=null
	botao.focus_mode=Control.FOCUS_NONE
	botao.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	botao.tooltip_text="Auto-Helper"
	botao.add_theme_stylebox_override("normal",gradiente("helper","121c29","0a121c","665537",10))
	botao.add_theme_stylebox_override("hover",gradiente("helper_hover","1a2939","101b27","b79a57",10))
	botao.add_theme_stylebox_override("pressed",gradiente("helper_pressed","0a121c","121c29","997530",10))
	botao.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	var centro: CenterContainer=CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter=Control.MOUSE_FILTER_IGNORE
	botao.add_child(centro)
	var linha: HBoxContainer=HBoxContainer.new()
	linha.add_theme_constant_override("separation",5)
	linha.mouse_filter=Control.MOUSE_FILTER_IGNORE
	centro.add_child(linha)
	var icone: TextureRect=TextureRect.new()
	icone.texture=preload("res://assets/interface/hud/icon_config.png")
	icone.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.custom_minimum_size=Vector2(12,12)
	icone.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icone.mouse_filter=Control.MOUSE_FILTER_IGNORE
	linha.add_child(icone)
	linha.add_child(UI.texto("Auto-Helper",13,Color("f0e6d2"),true))
