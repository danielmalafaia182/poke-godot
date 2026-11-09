extends Node2D

# Alterações desta versão:
# - Carrega collision.json.
# - Registra células existentes e bloqueadas no piso selecionado.
# - Implementa celula_transitavel().
# - Mantém o desenho do chão e dos objetos.
# - Mantém o primeiro frame de cada peça e a ordenação inicial.
# - Ainda não modifica movimento, respawn ou colisões físicas.

const TAMANHO_TILE: float = 32.0

var texturas: Dictionary[String, Texture2D] = {}

# Novo: identificadores de peças que bloqueiam movimento.
var pecas_bloqueadoras: Dictionary[int, bool] = {}

# Novo: coordenadas da grade do piso selecionado.
var celulas_existentes: Dictionary[Vector2i, bool] = {}
var celulas_bloqueadas: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	# Novo: carrega os bloqueios extraídos do original.
	var colisoes: Dictionary = carregar_json(
		"res://dados/mapas/collision.json"
	)

	if not colisoes.get("blocking") is Array:
		push_error("O arquivo de colisões não possui o array 'blocking'.")
		return

	for identificador in colisoes["blocking"]:
		pecas_bloqueadoras[int(identificador)] = true

	var caminho: String = "res://dados/mapas/geodude.json"
	var dados: Dictionary = carregar_json(caminho)

	if dados.is_empty():
		return

	if dados.get("format", "") != "stonegy-map-compact-v1":
		push_error("Formato de mapa não suportado.")
		return

	if not dados.get("tiles") is Array:
		push_error("O mapa deve possuir um array chamado 'tiles'.")
		return

	if not dados.get("_meta") is Dictionary:
		push_error("O mapa não possui metadados válidos.")
		return

	if not dados["_meta"].has("groundZ"):
		push_error("Os metadados não informam o piso da caça.")
		return

	var tiles: Array = dados["tiles"]

	if tiles.is_empty():
		push_warning("O mapa não possui registros em 'tiles'.")
		return

	var piso: int = int(dados["_meta"]["groundZ"])

	var caminho_manifesto: String = (
		"res://dados/mapas/map-items-06563563679b.json"
	)
	var manifesto: Dictionary = carregar_json(caminho_manifesto)

	if manifesto.is_empty():
		return

	if not manifesto.get("assets") is Dictionary:
		push_error("O manifesto deve possuir um dicionário 'assets'.")
		return

	if not manifesto.get("categories") is Dictionary:
		push_error("O manifesto não possui categorias válidas.")
		return

	if not manifesto["categories"].get("map-items") is Dictionary:
		push_error("A categoria 'map-items' não foi encontrada.")
		return

	if not manifesto["categories"]["map-items"].get("pages") is Array:
		push_error("A categoria 'map-items' não possui páginas válidas.")
		return

	# Filtra os registros do piso antes de ordenar.
	var registros_ordenados: Array = []

	for registro in tiles:
		if not registro is Array:
			push_error("O mapa contém um registro que não é Array.")
			return

		if registro.size() < 5:
			push_error("O mapa contém um registro com campos insuficientes.")
			return

		if int(registro[2]) != piso:
			continue

		if not registro[4] is Array:
			push_error("A lista de objetos de uma célula é inválida.")
			return

		# Novo: valida a estrutura usada na classificação e no desenho.
		for objeto in registro[4]:
			if not objeto is Array:
				push_error("A célula contém um objeto que não é Array.")
				return

			if objeto.is_empty():
				push_error("A célula contém um objeto sem identificador.")
				return

		registros_ordenados.append(registro)

	registros_ordenados.sort_custom(
		func(a: Array, b: Array) -> bool:
			if int(a[1]) == int(b[1]):
				return int(a[0]) < int(b[0])
			return int(a[1]) < int(b[1])
	)

	# Novo: classifica as células pela regra de bloqueio do cliente original.
	for registro in registros_ordenados:
		var celula: Vector2i = Vector2i(
			int(registro[0]),
			int(registro[1])
		)

		celulas_existentes[celula] = true

		var bloqueada: bool = pecas_bloqueadoras.has(
			int(registro[3])
		)

		for objeto in registro[4]:
			if pecas_bloqueadoras.has(int(objeto[0])):
				bloqueada = true
				break

		if bloqueada:
			celulas_bloqueadas[celula] = true

	var camada_chao: Node2D = Node2D.new()
	camada_chao.name = "Chao"
	add_child(camada_chao)

	var camada_objetos: Node2D = Node2D.new()
	camada_objetos.name = "Objetos"
	add_child(camada_objetos)

	var recortes: Dictionary[String, AtlasTexture] = {}
	var identificadores_ausentes: Dictionary = {}

	var quantidade_desenhada: int = 0
	var quantidade_objetos: int = 0
	var quantidade_objetos_desenhados: int = 0

	# Desenha o chão, compartilhando os recortes.
	for registro in registros_ordenados:
		if int(registro[3]) == 0:
			continue

		var identificador: String = str(int(registro[3]))

		if not recortes.has(identificador):
			recortes[identificador] = obter_recorte(
				manifesto,
				identificador
			)

		var recorte: AtlasTexture = recortes[identificador]

		if recorte == null:
			identificadores_ausentes[identificador] = true
			continue

		var peca: Dictionary = manifesto["assets"][identificador]
		var novo_sprite: Sprite2D = criar_sprite(
			recorte,
			peca,
			registro
		)

		camada_chao.add_child(novo_sprite)
		quantidade_desenhada += 1

	print("Recortes consultados (chão apenas): ", recortes.size())

	# Desenha os objetos na ordem inicial das células e das listas.
	for registro in registros_ordenados:
		for objeto in registro[4]:
			quantidade_objetos += 1

			var identificador: String = str(int(objeto[0]))

			if not recortes.has(identificador):
				recortes[identificador] = obter_recorte(
					manifesto,
					identificador
				)

			var recorte: AtlasTexture = recortes[identificador]

			if recorte == null:
				identificadores_ausentes[identificador] = true
				continue

			var peca: Dictionary = manifesto["assets"][identificador]
			var novo_sprite: Sprite2D = criar_sprite(
				recorte,
				peca,
				registro
			)

			camada_objetos.add_child(novo_sprite)
			quantidade_objetos_desenhados += 1

	print("Peças bloqueadoras carregadas: ", pecas_bloqueadoras.size())
	print("Formato do mapa: ", dados["format"])
	print("Registros totais: ", tiles.size())
	print("Primeiro registro: ", tiles[0])
	print("Piso da caça: ", piso)
	print("Registros no piso da caça: ", registros_ordenados.size())
	print("Registros de chão desenhados: ", quantidade_desenhada)
	print("Total de objetos: ", quantidade_objetos)
	print("Objetos desenhados: ", quantidade_objetos_desenhados)
	print("Identificadores sem recorte: ", identificadores_ausentes.keys())
	print("Recortes consultados: ", recortes.size())
	print("Páginas de textura consultadas: ", texturas.size())

	# Novo: diagnóstico das células para a próxima etapa de navegação.
	print("Células existentes: ", celulas_existentes.size())
	print("Células bloqueadas: ", celulas_bloqueadas.size())
	print(
		"Células sem bloqueio: ",
		celulas_existentes.size() - celulas_bloqueadas.size()
	)


# Novo: verifica existência e ausência de bloqueio.
# Recebe coordenadas da grade, não posições em pixels.
# Ainda não verifica limites da caça nem conectividade com o aliado.
func celula_transitavel(celula: Vector2i) -> bool:
	return (
		celulas_existentes.has(celula)
		and not celulas_bloqueadas.has(celula)
	)


# Lê um JSON cujo conteúdo principal deve ser um Dictionary.
func carregar_json(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		push_error("Arquivo não encontrado: " + caminho)
		return {}

	var conteudo: String = FileAccess.get_file_as_string(caminho)
	var json: JSON = JSON.new()
	var erro: Error = json.parse(conteudo)

	if erro != OK:
		push_error(
			"Erro ao interpretar " + caminho
			+ " na linha " + str(json.get_error_line())
			+ ": " + json.get_error_message()
		)
		return {}

	if not json.data is Dictionary:
		push_error("O conteúdo deve ser um Dictionary: " + caminho)
		return {}

	return json.data


# Compartilha configuração e alinhamento básico de chão e objetos.
func criar_sprite(
	recorte: AtlasTexture,
	peca: Dictionary,
	registro: Array
) -> Sprite2D:
	var largura: float = float(peca["width"])
	var altura: float = float(peca["height"])

	var novo_sprite: Sprite2D = Sprite2D.new()
	novo_sprite.texture = recorte
	novo_sprite.centered = false
	novo_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	novo_sprite.scale = Vector2(
		largura / recorte.region.size.x,
		altura / recorte.region.size.y
	)

	# Alinha o canto inferior direito da imagem ao da célula.
	# Deslocamentos específicos e elevação ainda não são aplicados.
	novo_sprite.position = Vector2(
		float(registro[0]) * TAMANHO_TILE - (largura - TAMANHO_TILE),
		float(registro[1]) * TAMANHO_TILE - (altura - TAMANHO_TILE)
	)

	return novo_sprite


# Resolve o primeiro frame da peça.
# Retorna null quando a peça ou a imagem não pode ser utilizada.
func obter_recorte(
	manifesto: Dictionary,
	identificador: String
) -> AtlasTexture:
	if not manifesto["assets"].get(identificador) is Dictionary:
		push_error("Peça não encontrada ou inválida: " + identificador)
		return null

	var peca: Dictionary = manifesto["assets"][identificador]

	if (
		float(peca.get("width", 0)) <= 0.0
		or float(peca.get("height", 0)) <= 0.0
	):
		push_error("Dimensões inválidas na peça: " + identificador)
		return null

	if not peca.get("frames") is Array:
		push_error("A peça não possui um array de frames: " + identificador)
		return null

	if peca["frames"].is_empty():
		push_error("A peça não possui frames: " + identificador)
		return null

	if not peca["frames"][0] is Dictionary:
		push_error("Primeiro frame inválido: " + identificador)
		return null

	var primeiro_frame: Dictionary = peca["frames"][0]

	for campo in ["page", "x", "y", "w", "h"]:
		if not primeiro_frame.has(campo):
			push_error(
				"Campo ausente no frame da peça "
				+ identificador + ": " + campo
			)
			return null

	if (
		float(primeiro_frame["w"]) <= 0.0
		or float(primeiro_frame["h"]) <= 0.0
	):
		push_error("O recorte possui tamanho inválido: " + identificador)
		return null

	var pagina_procurada: int = int(primeiro_frame["page"])
	var caminho_textura: String = ""
	var lista_paginas: Array = (
		manifesto["categories"]["map-items"]["pages"]
	)

	for pagina in lista_paginas:
		if not pagina is Dictionary:
			continue

		if not pagina.has("index") or not pagina.has("image"):
			continue

		if int(pagina["index"]) == pagina_procurada:
			var nome_arquivo: String = str(pagina["image"]).get_file()
			caminho_textura = (
				"res://assets/cenarios/map-items/" + nome_arquivo
			)
			break

	if caminho_textura.is_empty():
		push_error(
			"Página " + str(pagina_procurada)
			+ " não encontrada para a peça " + identificador
		)
		return null

	if not texturas.has(caminho_textura):
		texturas[caminho_textura] = load(caminho_textura) as Texture2D

	var textura: Texture2D = texturas[caminho_textura]

	if textura == null:
		push_error("Não foi possível carregar: " + caminho_textura)
		return null

	var recorte: AtlasTexture = AtlasTexture.new()
	recorte.atlas = textura
	recorte.region = Rect2(
		float(primeiro_frame["x"]),
		float(primeiro_frame["y"]),
		float(primeiro_frame["w"]),
		float(primeiro_frame["h"])
	)

	return recorte
