extends RefCounted
# Alterações visuais da cidade: Nova textura de cápsula com gradiente para barras arredondadas.

# Novo: medidas/cores extraídas de .phud, .phud-mon, .sbar e .game-dock no CSS.
# Godot usa uma textura de nove regiões para preservar as bordas ao redimensionar.
static func moldura() -> StyleBoxTexture:
	var imagem: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		var t: float = float(y) / 127.0
		var fundo: Color = Color("0a1018e6").lerp(Color("060b12ed"), t)
		var borda: Color = Color("c4a566").lerp(Color("87704c"), t)
		for x in range(128):
			var limite: int = mini(mini(x, 127-x), mini(y,127-y))
			var cor: Color = borda if limite < 2 else fundo
			if limite == 4:
				cor = Color("9975304d")
			imagem.set_pixel(x, y, cor)
	var estilo: StyleBoxTexture = StyleBoxTexture.new()
	estilo.texture = ImageTexture.create_from_image(imagem)
	estilo.set_texture_margin_all(6.0)
	estilo.content_margin_left = 11.0
	estilo.content_margin_right = 11.0
	estilo.content_margin_top = 10.0
	estilo.content_margin_bottom = 11.0
	return estilo

static func plano(fundo: Color, borda: Color, raio: int = 6) -> StyleBoxFlat:
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = fundo
	estilo.border_color = borda
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(raio)
	return estilo

static func barra() -> StyleBoxTexture:
	var gradiente: Gradient = Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.45, 0.55, 1.0])
	gradiente.colors = PackedColorArray([Color("8bf07a"),Color("4ec24a"),Color("319a34"),Color("217a26")])
	var textura: GradientTexture2D = GradientTexture2D.new()
	textura.gradient = gradiente
	textura.width = 4
	textura.height = 32
	textura.fill_from = Vector2(0,0)
	textura.fill_to = Vector2(0,1)
	var estilo: StyleBoxTexture = StyleBoxTexture.new()
	estilo.texture = textura
	return estilo

# Novo: textura de nove regiões com pontas arredondadas e brilho vertical.
static func capsula(experiencia: bool, altura: int) -> StyleBoxTexture:
	var h: int = maxi(4,altura)
	var w: int = h*2
	var imagem: Image = Image.create(w,h,false,Image.FORMAT_RGBA8)
	var claro: Color = Color("ffe680") if experiencia else Color("8bf07a")
	var escuro: Color = Color("c8901a") if experiencia else Color("217a26")
	var raio: float = float(h)*0.5
	for y in range(h):
		var cor: Color = claro.lerp(escuro,float(y)/float(h-1))
		for x in range(w):
			var centro_x: float = clampf(float(x)+0.5,raio,float(w)-raio)
			var distancia: float = Vector2(float(x)+0.5-centro_x,float(y)+0.5-raio).length()
			var pixel: Color = cor
			pixel.a = clampf(raio+0.5-distancia,0.0,1.0)
			imagem.set_pixel(x,y,pixel)
	var estilo: StyleBoxTexture = StyleBoxTexture.new()
	estilo.texture = ImageTexture.create_from_image(imagem)
	estilo.texture_margin_left = raio
	estilo.texture_margin_right = raio
	return estilo
