extends "res://cenario_caca.gd"

# A colisão pertence somente ao piso do personagem. Telhados são visuais.
const PECAS_INVISIVEIS: Array[int] = [7124, 1510, 8274, 46638, 46639, 46620, 46621, 1511, 1024]
var piso_chao: int = 7
var piso_minimo: int = 7
var primeiro_piso_visivel: int = 7
var pisos: Dictionary = {}
var indice_tiles: Dictionary = {}
var motivos_bloqueio: Dictionary = {}
var deslocamentos: Dictionary = {}
var elevacoes: Dictionary = {}
var centro_mapa: Vector2i = Vector2i.ZERO
var ultima_celula_visual: Vector2i = Vector2i(999999, 999999)
var pecas_ocultadas: int = 0
var recortes_ausentes: Dictionary = {}

func _ready() -> void:
	var dados: Dictionary = carregar_json("res://dados/mapas/cerulean_cidade.json")
	var manifesto: Dictionary = carregar_json("res://dados/mapas/map-items-06563563679b.json")
	var colisao: Dictionary = carregar_json("res://dados/mapas/collision.json")
	var offsets: Dictionary = carregar_json("res://dados/mapas/cidade_offsets.json")
	if dados.is_empty() or manifesto.is_empty() or colisao.is_empty():
		return
	deslocamentos = offsets.get("disp", {})
	elevacoes = offsets.get("elev", {})
	piso_chao = int(dados["_meta"]["groundZ"])
	piso_minimo = piso_chao
	var centro: Array = dados["_meta"].get("center", [0, 0])
	centro_mapa = Vector2i(int(centro[0]), int(centro[1]))
	for id in colisao.get("blocking", []):
		pecas_bloqueadoras[int(id)] = true
	var por_piso: Dictionary = {}
	for registro in dados["tiles"]:
		var piso: int = int(registro[2])
		piso_minimo = mini(piso_minimo, piso)
		indice_tiles[Vector3i(int(registro[0]), int(registro[1]), piso)] = registro
		if not por_piso.has(piso):
			por_piso[piso] = []
		por_piso[piso].append(registro)
		if piso != piso_chao:
			continue
		var celula: Vector2i = Vector2i(int(registro[0]), int(registro[1]))
		celulas_existentes[celula] = true
		var bloqueadores: Array[int] = []
		if pecas_bloqueadoras.has(int(registro[3])):
			bloqueadores.append(int(registro[3]))
		for objeto in registro[4]:
			if pecas_bloqueadoras.has(int(objeto[0])):
				bloqueadores.append(int(objeto[0]))
		if not bloqueadores.is_empty():
			celulas_bloqueadas[celula] = true
			motivos_bloqueio[celula] = bloqueadores
	var recortes: Dictionary = {}
	for piso in range(piso_chao, piso_minimo - 1, -1):
		var camada: Node2D = Node2D.new()
		camada.name = "Piso_" + str(piso)
		# Projeção do andar utilizada no cliente de referência.
		camada.position = Vector2.ONE * float(piso - piso_chao) * TAMANHO_TILE
		camada.z_index = (piso_chao - piso) * 2
		camada.y_sort_enabled = true
		add_child(camada)
		pisos[piso] = camada
		var registros: Array = por_piso.get(piso, [])
		registros.sort_custom(func(a: Array, b: Array) -> bool:
			return a[0] < b[0] if a[1] == b[1] else a[1] < b[1]
		)
		for registro in registros:
			_desenhar_peca(int(registro[3]), registro, camada, manifesto, recortes, true, 0.0)
			var elevacao: float = float(elevacoes.get(str(int(registro[3])), 0))
			for objeto in registro[4]:
				var id: int = int(objeto[0])
				_desenhar_peca(id, registro, camada, manifesto, recortes, false, elevacao)
				if not PECAS_INVISIVEIS.has(id):
					elevacao = minf(32.0, elevacao + float(elevacoes.get(str(id), 0)))
	primeiro_piso_visivel = piso_minimo
	print("Cerulean: células=", celulas_existentes.size(), "; bloqueadas=", celulas_bloqueadas.size(), "; peças técnicas ocultadas=", pecas_ocultadas, "; recortes ausentes=", recortes_ausentes.keys())

func _desenhar_peca(id: int, registro: Array, camada: Node2D, manifesto: Dictionary, recortes: Dictionary, chao: bool, elevacao: float) -> void:
	if id == 0:
		return
	if PECAS_INVISIVEIS.has(id):
		pecas_ocultadas += 1
		return
	var chave: String = str(id)
	var peca: Dictionary = manifesto["assets"].get(chave, {})
	if peca.is_empty():
		recortes_ausentes[chave] = true
		return
	var px: int = maxi(1, int(peca.get("patternX", 1)))
	var py: int = maxi(1, int(peca.get("patternY", 1)))
	var anim: int = maxi(1, int(peca.get("animLen", 1)))
	var indice: int = (posmod(centro_mapa.y + int(registro[1]), py) * px + posmod(centro_mapa.x + int(registro[0]), px)) * anim
	if indice >= peca["frames"].size():
		indice = 0
	var cache: String = chave + ":" + str(indice)
	if not recortes.has(cache):
		var recorte: AtlasTexture = obter_recorte(manifesto, chave)
		if recorte != null:
			var quadro: Dictionary = peca["frames"][indice]
			# Padrões podem estar em outra página do atlas.
			for pagina in manifesto["categories"]["map-items"]["pages"]:
				if int(pagina["index"]) == int(quadro["page"]):
					var arquivo: String = "res://assets/cenarios/map-items/" + str(pagina["image"]).get_file()
					if not texturas.has(arquivo):
						texturas[arquivo] = load(arquivo) as Texture2D
					recorte.atlas = texturas[arquivo]
					break
			recorte.region = Rect2(quadro["x"], quadro["y"], quadro["w"], quadro["h"])
		recortes[cache] = recorte
	var textura: AtlasTexture = recortes[cache]
	if textura == null:
		recortes_ausentes[chave] = true
		return
	var sprite: Sprite2D = criar_sprite(textura, peca, registro)
	var deslocamento: Array = deslocamentos.get(chave, [0, 0])
	var posicao_visual: Vector2 = sprite.position - Vector2(float(deslocamento[0]), float(deslocamento[1]) + elevacao)
	# Ordena pelo pé da célula sem alterar o recorte ou a posição desenhada.
	sprite.position = Vector2(float(registro[0]) * 32.0 + 16.0, float(registro[1]) * 32.0 + 16.0)
	sprite.offset = (posicao_visual - sprite.position) / sprite.scale
	sprite.z_index = -1 if chao or bool(peca.get("isGround", false)) else 0
	camada.add_child(sprite)

func adicionar_treinador(treinador: Node2D) -> void:
	pisos[piso_chao].add_child(treinador)

func atualizar_cobertura(posicao_local: Vector2, imediato: bool = false) -> void:
	var celula: Vector2i = Vector2i(roundi((posicao_local.x - 16.0) / 32.0), roundi((posicao_local.y - 16.0) / 32.0))
	if not imediato and celula == ultima_celula_visual:
		return
	ultima_celula_visual = celula
	primeiro_piso_visivel = piso_minimo
	for piso in range(piso_chao - 1, piso_minimo - 1, -1):
		var distancia: int = piso_chao - piso
		var registro: Array = indice_tiles.get(Vector3i(celula.x + distancia, celula.y + distancia, piso), [])
		if not registro.is_empty() and int(registro[3]) != 0:
			primeiro_piso_visivel = piso + 1
			break
	if imediato:
		for piso in pisos:
			pisos[piso].modulate.a = 1.0 if int(piso) >= primeiro_piso_visivel else 0.0

func _process(delta: float) -> void:
	for piso in pisos:
		var camada: Node2D = pisos[piso]
		var alvo: float = 1.0 if int(piso) >= primeiro_piso_visivel else 0.0
		camada.modulate.a = move_toward(camada.modulate.a, alvo, delta / 0.18)
		camada.visible = camada.modulate.a > 0.001
