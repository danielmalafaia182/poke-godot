extends RefCounted

# Medidas e cores do CSS .phud / .ah-modal / .cap-chip extraído do cliente.
# Fontes são os arquivos do cliente, com Cinzel instanciado em peso 700.
const TEXTO: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const FORTE: Font = preload("res://assets/interface/fiel/barlow_bold.ttf")
const TITULO: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const BASE: Script = preload("res://estilo_hud_original.gd")
static var _circulos: Dictionary = {}
static var _barras: Dictionary = {}

static func caixa(fundo: Color, borda: Color, raio: int = 8, margem: int = 8) -> StyleBoxFlat:
	var estilo: StyleBoxFlat = BASE.plano(fundo, borda, raio)
	estilo.set_content_margin_all(margem)
	return estilo

static func texto(rotulo: String, tamanho: int = 11, cor: Color = Color("b9c3ce"), forte: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = rotulo
	label.add_theme_font_override("font", FORTE if forte else TEXTO)
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", cor)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func circulo(cor_tipo: Color) -> Texture2D:
	var chave: String = cor_tipo.to_html()
	if _circulos.has(chave):
		return _circulos[chave]
	var imagem: Image = Image.create(80,80,false,Image.FORMAT_RGBA8)
	for y in range(80):
		for x in range(80):
			var p: Vector2 = Vector2(x+0.5,y+0.5)
			var distancia: float = p.distance_to(Vector2(40,40))
			var cobertura: float = clampf(40.0-distancia,0.0,1.0)
			if cobertura <= 0.0:
				continue
			var t: float = clampf(p.distance_to(Vector2(40,26))/58.0,0,1)
			var cor: Color = Color("1e2c3c").lerp(Color("080e16"),t)
			if distancia > 36.0:
				cor = cor.lerp(cor_tipo,clampf(distancia-36.0,0,1))
			cor.a = cobertura
			imagem.set_pixel(x,y,cor)
	_circulos[chave] = ImageTexture.create_from_image(imagem)
	return _circulos[chave]

static func capsula(tipo: String, altura: int) -> StyleBoxTexture:
	var chave: String = "%s/%d" % [tipo, altura]
	if _barras.has(chave):
		return _barras[chave]
	var cores: Array[Color]
	match tipo:
		"xp": cores = [Color("ffe680"),Color("ffcf3a"),Color("f0b71e"),Color("c8901a")]
		"baixo": cores = [Color("ffcf7a"),Color("f0a53a"),Color("e79931"),Color("c87e1e")]
		"critico": cores = [Color("ff9a8a"),Color("e5533a"),Color("cf4931"),Color("a82a1e")]
		"fundo": cores = [Color("0a0f16"),Color("0e151e"),Color("111922"),Color("131c26")]
		_: cores = [Color("8bf07a"),Color("4ec24a"),Color("319a34"),Color("217a26")]
	var h: int = maxi(4,altura)
	var imagem: Image = Image.create(h*2,h,false,Image.FORMAT_RGBA8)
	var raio: float = h/2.0
	for y in range(h):
		var t: float = float(y)/maxi(1,h-1)
		var cor: Color = cores[0].lerp(cores[1],minf(1,t/0.45)) if t<=0.45 else (cores[1].lerp(cores[2],(t-0.45)/0.1) if t<=0.55 else cores[2].lerp(cores[3],(t-0.55)/0.45))
		for x in range(h*2):
			var centro: float = clampf(x+0.5,raio,h*2.0-raio)
			var pixel: Color = cor
			pixel.a = clampf(raio+0.5-Vector2(x+0.5-centro,y+0.5-raio).length(),0,1)
			imagem.set_pixel(x,y,pixel)
	var estilo: StyleBoxTexture = StyleBoxTexture.new()
	estilo.texture = ImageTexture.create_from_image(imagem)
	estilo.texture_margin_left = raio
	estilo.texture_margin_right = raio
	_barras[chave] = estilo
	return estilo

static func icone_svg(conteudo: String) -> Texture2D:
	var imagem: Image = Image.new()
	imagem.load_svg_from_string(conteudo)
	return ImageTexture.create_from_image(imagem)
