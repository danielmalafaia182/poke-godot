extends RefCounted
const UI: Script=preload("res://estilo_ui_fiel.gd")
static var _cache: Dictionary={}
static func fundo(tipo: String) -> StyleBoxTexture:
	if _cache.has(tipo): return _cache[tipo]
	var svg: String
	if tipo=="card":
		svg='<svg xmlns="http://www.w3.org/2000/svg" width="340" height="250"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#101a26"/><stop offset=".58" stop-color="#122828"/><stop offset="1" stop-color="#282210"/></linearGradient><radialGradient id="a" cx=".92" cy="0" r=".8"><stop stop-color="#0ac8b9" stop-opacity=".1"/><stop offset="1" stop-color="#0ac8b9" stop-opacity="0"/></radialGradient></defs><rect x=".5" y=".5" width="339" height="249" rx="10" fill="url(#g)" stroke="#9c7a34"/><rect x="1" y="1" width="338" height="248" rx="10" fill="url(#a)"/></svg>'
	else:
		var borda: String="8a713e" if tipo=="rare" else "3a4658"
		svg='<svg xmlns="http://www.w3.org/2000/svg" width="256" height="64"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#1e2835" stop-opacity=".5"/><stop offset="1" stop-color="#0b111a" stop-opacity=".6"/></linearGradient></defs><rect x=".5" y=".5" width="255" height="63" rx="8" fill="url(#g)" stroke="#%s"/>%s</svg>' % [borda,'<path d="M3 8v48" stroke="#ff4d42" stroke-width="3"/>' if tipo=="xp" else ""]
	var estilo: StyleBoxTexture=StyleBoxTexture.new()
	estilo.texture=UI.icone_svg(svg)
	estilo.set_texture_margin_all(11 if tipo=="card" else 9)
	estilo.set_content_margin_all(0)
	if tipo!="card":
		estilo.content_margin_left=8
		estilo.content_margin_right=8
		estilo.content_margin_top=6 if tipo=="xp" else 3
		estilo.content_margin_bottom=6 if tipo=="xp" else 3
	if tipo in ["item","rare"]:
		estilo.content_margin_left=4
		estilo.content_margin_right=7
	_cache[tipo]=estilo
	return estilo
static func margem(no: Control, esquerda: int, cima: int, direita: int, baixo: int) -> MarginContainer:
	var m: MarginContainer=MarginContainer.new()
	m.add_theme_constant_override("margin_left",esquerda)
	m.add_theme_constant_override("margin_top",cima)
	m.add_theme_constant_override("margin_right",direita)
	m.add_theme_constant_override("margin_bottom",baixo)
	m.mouse_filter=Control.MOUSE_FILTER_IGNORE
	m.add_child(no)
	return m
static func icone(textura: Texture2D, tamanho: int) -> TextureRect:
	var imagem: TextureRect=TextureRect.new()
	imagem.texture=textura
	imagem.custom_minimum_size=Vector2(tamanho,tamanho)
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return imagem
