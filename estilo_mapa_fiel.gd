extends RefCounted
const UI: Script=preload("res://estilo_ui_fiel.gd")
static var _circulos: Dictionary={}
static func circulo(habilitado: bool, hover: bool) -> Texture2D:
	var chave: String=str(habilitado)+str(hover)
	if _circulos.has(chave): return _circulos[chave]
	var cor: String="f0e0b0" if hover else ("7fe6dd" if habilitado else "c8aa6e")
	var svg: String='<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><defs><radialGradient id="b" cx=".5" cy=".35" r=".8"><stop stop-color="#1e2c3c"/><stop offset="1" stop-color="#080e16"/></radialGradient><radialGradient id="g"><stop offset=".65" stop-color="#%s" stop-opacity=".25"/><stop offset="1" stop-color="#%s" stop-opacity="0"/></radialGradient></defs><circle cx="32" cy="32" r="32" fill="url(#g)"/><circle cx="32" cy="32" r="27" fill="none" stroke="#000" stroke-opacity=".5" stroke-width="4"/><circle cx="32" cy="32" r="26" fill="url(#b)" stroke="#%s" stroke-width="2"/></svg>' % [cor,cor,cor]
	_circulos[chave]=UI.icone_svg(svg)
	return _circulos[chave]
static func botao() -> StyleBoxFlat:
	return UI.caixa(Color("111d29"),Color("99753099"),7,4)
static func janela() -> StyleBoxFlat:
	var e: StyleBoxFlat=UI.caixa(Color("0c191e"),Color("9c7a34"),10,0)
	e.set_border_width_all(2)
	e.corner_radius_top_left=0
	e.corner_radius_top_right=0
	e.shadow_color=Color("00000099")
	e.shadow_size=20
	return e
