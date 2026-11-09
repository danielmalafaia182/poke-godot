extends RefCounted
# Mesmo atlas e algoritmo e8 do cliente: preserva pixels pretos do contorno,
# colore os pixels claros e usa os avanços de cada caractere, sem suavização.
const ATLAS: Texture2D = preload("res://assets/interface/fiel/verdana-11px-rounded_cp1252.png")
static var _metricas: Dictionary = {}
static var _cache: Dictionary[String,Texture2D] = {}
static func texto(nome: String, cor: Color = Color("ffe08a")) -> Texture2D:
	var chave: String = nome+"/"+cor.to_html()
	if _cache.has(chave): return _cache[chave]
	if _metricas.is_empty():
		_metricas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/interface/fiel/verdana-11px-rounded.json"))
	var largura: int = 0
	var avancos: Array[int] = []
	for i in range(nome.length()):
		var avanco: int = int(_metricas["widths"].get(str(nome.unicode_at(i)),_metricas.get("spaceWidth",4)))
		avancos.append(avanco)
		largura += avanco
	var imagem: Image = Image.create(maxi(1,largura),int(_metricas["height"]),false,Image.FORMAT_RGBA8)
	var atlas: Image = ATLAS.get_image()
	if atlas.is_compressed(): atlas.decompress()
	atlas.convert(Image.FORMAT_RGBA8)
	var x: int = 0
	var colunas: int = floori(float(_metricas["texW"])/float(_metricas["glyphW"]))
	for i in range(nome.length()):
		var indice: int = nome.unicode_at(i)-int(_metricas["firstGlyph"])
		if indice>=0 and indice<colunas*floori(float(_metricas["texH"])/float(_metricas["glyphH"])):
			var regiao: Rect2i = Rect2i((indice%colunas)*int(_metricas["glyphW"]),floori(float(indice)/float(colunas))*int(_metricas["glyphH"]),avancos[i],int(_metricas["glyphH"]))
			imagem.blit_rect(atlas,regiao,Vector2i(x,0))
		x += avancos[i]
	for y in range(imagem.get_height()):
		for px in range(imagem.get_width()):
			var pixel: Color = imagem.get_pixel(px,y)
			if pixel.a>0 and (pixel.r>=48.0/255 or pixel.g>=48.0/255 or pixel.b>=48.0/255):
				imagem.set_pixel(px,y,Color(pixel.r*cor.r,pixel.g*cor.g,pixel.b*cor.b,pixel.a))
	_cache[chave] = ImageTexture.create_from_image(imagem)
	return _cache[chave]
