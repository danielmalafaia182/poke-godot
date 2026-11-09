extends RefCounted

const UI: Script = preload("res://estilo_ui_fiel.gd")
const TIPOS: Script = preload("res://tipos_pokemon.gd")
const NOME: Font = preload("res://assets/interface/fiel/cinzel_extrabold.ttf")
static var _fichas: Dictionary = {}
static func janela() -> StyleBoxTexture:
	var estilo: StyleBoxTexture = StyleBoxTexture.new()
	estilo.texture = preload("res://assets/interface/fiel/team_janela.svg")
	estilo.set_texture_margin_all(12)
	estilo.set_content_margin_all(2)
	return estilo
static func ficha(cor: Color) -> StyleBoxTexture:
	var chave: String = cor.to_html()
	if _fichas.has(chave):
		return _fichas[chave]
	var borda: String = Color("766846").lerp(cor,0.60).to_html(false)
	var direita: String = Color("090f17").lerp(cor,0.26).to_html(false)
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="160"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2=".8"><stop stop-color="#0b151e"/><stop offset=".55" stop-color="#090f17"/><stop offset="1" stop-color="#%s"/></linearGradient></defs><rect x=".5" y=".5" width="255" height="159" rx="12" fill="url(#g)" stroke="#%s"/></svg>' % [direita,borda]
	var estilo: StyleBoxTexture = StyleBoxTexture.new()
	estilo.texture = UI.icone_svg(svg)
	estilo.set_texture_margin_all(12)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 14
	estilo.content_margin_bottom = 14
	_fichas[chave] = estilo
	return estilo
static func cor_atributo(proporcao: float) -> Color:
	# Mesmas faixas do componente TEAM do cliente.
	if proporcao<0.2: return Color("f34444")
	if proporcao<0.4: return Color("ff7f0f")
	if proporcao<0.6: return Color("ffdd57")
	if proporcao<0.8: return Color("a0e515")
	if proporcao<0.95: return Color("23cd5e")
	return Color("00c2b8")
static func selo(cor: Color, _escuro: bool = false) -> StyleBoxFlat:
	var estilo: StyleBoxFlat = UI.caixa(cor,cor.darkened(0.4),9,6)
	estilo.content_margin_top = 2
	estilo.content_margin_bottom = 2
	estilo.shadow_color = Color(cor.r,cor.g,cor.b,0.18)
	estilo.shadow_size = 3
	return estilo
static func qualidade(valor: float) -> Dictionary:
	# qualityInfo do cliente original; apenas apresentação.
	if valor>=4: return {"nome":"Divina","cor":Color("dbefff")}
	if valor>=3: return {"nome":"Anciã","cor":Color("b8860b")}
	if valor>=2: return {"nome":"Mítica","cor":Color("6a0dad")}
	if valor>=1.7: return {"nome":"Lendária","cor":Color("ff8c3c")}
	if valor>=1.5: return {"nome":"Épica","cor":Color("f0c040")}
	if valor>=1.3: return {"nome":"Rara","cor":Color("b06cff")}
	if valor>=1.1: return {"nome":"Incomum","cor":Color("7fd4ff")}
	if valor>=1: return {"nome":"Comum","cor":Color("63d873")}
	return {"nome":"Fraca","cor":Color("9aa6b3")}

static var _fundo_retrato: Texture2D
static func fundo_retrato() -> Texture2D:
	if _fundo_retrato==null:
		_fundo_retrato = UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120"><defs><radialGradient id="r" cx=".5" cy=".32" r=".8"><stop stop-color="#1e2c3c"/><stop offset="1" stop-color="#080e16"/></radialGradient></defs><rect width="120" height="120" rx="10" fill="url(#r)"/></svg>')
	return _fundo_retrato
