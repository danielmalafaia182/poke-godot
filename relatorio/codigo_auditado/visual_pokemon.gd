extends RefCounted
# Alterações visuais da cidade: Novo recorte de retrato por limites de transparência, preservando os sprites originais.

# Novo: catálogo visual compartilhado para as duas espécies disponíveis no projeto.
# Não altera atributos nem sorteios. Novas espécies exigem cadastrar seu spritesheet.
const LARVITAR: Texture2D = preload("res://assets/pokemon/larvitar/outfits-male-400-00-9bea9479fb83.webp")
const GEODUDE: Texture2D = preload("res://assets/pokemon/geodude/outfits-male-196-00-bfa20f0b6fde.webp")

static var importados: Dictionary = {}
static func obter(nome: String) -> Dictionary:
	if importados.is_empty(): importados=JSON.parse_string(FileAccess.get_file_as_string("res://dados/importados/visuais.json"))
	if importados.has(nome):
		var registro: Dictionary=importados[nome]
		var tamanho: int=int(registro["frames"][0]["rect"][2])
		return {"textura":load(registro["frames"][0]["arquivo"]),"tamanho":tamanho,"quadros":int(registro["quadros"]),"offset":Vector2(-16,-16) if tamanho>32 else Vector2(0,-10),"recortes_originais":registro["frames"]}
	match nome.to_lower():
		"larvitar":
			return {"textura": LARVITAR, "tamanho": 32, "passo": 34, "quadros": 4, "offset": Vector2(0,-10)}
		"geodude":
			return {"textura": GEODUDE, "tamanho": 64, "passo": 66, "quadros": 3, "offset": Vector2(-16,-16)}
	return {}

static func recortar(nome: String) -> Array[AtlasTexture]:
	var resultado: Array[AtlasTexture] = []
	var dados: Dictionary = obter(nome)
	if dados.is_empty():
		return resultado
	if dados.has("recortes_originais"):
		for frame in dados["recortes_originais"]:
			var atlas: AtlasTexture=AtlasTexture.new()
			atlas.atlas=load(frame["arquivo"])
			var r: Array=frame["rect"]
			atlas.region=Rect2(r[0],r[1],r[2],r[3])
			resultado.append(atlas)
		return resultado
	for indice in range(int(dados["quadros"]) * 4):
		var recorte: AtlasTexture = AtlasTexture.new()
		recorte.atlas = dados["textura"]
		recorte.region = Rect2(2 + indice * int(dados["passo"]), 2, dados["tamanho"], dados["tamanho"])
		resultado.append(recorte)
	return resultado

# Novo: recorta somente a margem transparente; não redesenha nem altera o spritesheet.
static func centralizar_retrato(textura: Texture2D) -> Texture2D:
	if textura == null:
		return textura
	var imagem: Image = textura.get_image()
	if imagem == null or imagem.is_empty():
		return textura
	var usado: Rect2i = imagem.get_used_rect()
	if not usado.has_area():
		return textura
	var recorte: AtlasTexture = AtlasTexture.new()
	if textura is AtlasTexture:
		recorte.atlas = textura.atlas
		recorte.region = Rect2(textura.region.position+Vector2(usado.position),Vector2(usado.size))
	else:
		recorte.atlas = textura
		recorte.region = Rect2(usado)
	return recorte

# Retratos de interface usam a direção sul (índice 2), independentemente
# da orientação do líder no mundo. Cache mantém os recortes reutilizáveis.
static var _frentes: Dictionary = {}
static func quadros_frente(nome: String) -> Array[Texture2D]:
	var chave: String = nome.to_lower()
	if _frentes.has(chave):
		return _frentes[chave]
	var dados: Dictionary = obter(nome)
	var resultado: Array[Texture2D] = []
	if dados.is_empty():
		return resultado
	var todos: Array[AtlasTexture] = recortar(nome)
	var quantidade: int = int(dados["quadros"])
	for i in range(quantidade):
		resultado.append(centralizar_retrato(todos[quantidade*2+i]))
	_frentes[chave] = resultado
	return resultado

static func retrato_frente(nome: String) -> Texture2D:
	var quadros: Array[Texture2D] = quadros_frente(nome)
	return quadros[0] if not quadros.is_empty() else null

# Redução de ícones preserva a contribuição dos pixels claros de 1px dos olhos.
# Não altera o spritesheet ou os retratos maiores do TEAM/HUD.
static var _icones_reduzidos: Dictionary={}
static func icone_reduzido(nome: String, largura: int) -> Texture2D:
	var chave: String=nome.to_lower()+str(largura)
	if _icones_reduzidos.has(chave): return _icones_reduzidos[chave]
	var textura: Texture2D=retrato_frente(nome)
	if textura==null: return null
	var imagem: Image=textura.get_image()
	if imagem.is_compressed(): imagem.decompress()
	var escala: float=minf(1.0,float(largura)/float(maxi(imagem.get_width(),imagem.get_height())))
	imagem.resize(maxi(1,roundi(imagem.get_width()*escala)),maxi(1,roundi(imagem.get_height()*escala)),Image.INTERPOLATE_LANCZOS)
	_icones_reduzidos[chave]=ImageTexture.create_from_image(imagem)
	return _icones_reduzidos[chave]
