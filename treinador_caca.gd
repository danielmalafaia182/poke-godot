extends Node2D

# Novo: apresentação do treinador na caça usando traje e frames já usados na cidade.
# A distância de uma célula é interpolação local; não é uma regra de servidor comprovada.
# Segue os segmentos realmente percorridos pelo aliado, sem atalhos por paredes.
var imagem: Sprite2D
var nome: TextureRect
var controlador: Node2D
var trilha: Array[Vector2] = []
var comprimento: float = 0.0
var anterior: Vector2
var quadros: Array[AtlasTexture] = []
var direcao: int = 2
var tempo: float = 0.0
var indice: int = 0

func iniciar(caca: Node2D) -> void:
	controlador = caca
	global_position = caca.imagem_aliado.global_position
	anterior = global_position
	trilha.append(global_position)
	imagem = Sprite2D.new()
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.offset = Vector2(0,-10)
	add_child(imagem)
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/interface/cidade/treinador.json"))
	var textura: Texture2D = preload("res://assets/interface/cidade/treinador.webp")
	for sentido in range(1,5):
		for quadro in range(1,4):
			var chave: String = "/assets/outfits/male/159/%d_1_1_%d.png" % [quadro,sentido]
			var frame: Dictionary = manifesto["assets"][chave]["frames"][0]
			var recorte: AtlasTexture = AtlasTexture.new()
			recorte.atlas = textura
			recorte.region = Rect2(frame["x"],frame["y"],frame["w"],frame["h"])
			quadros.append(recorte)
	imagem.texture = quadros[6]
	nome=TextureRect.new()
	nome.texture=preload("res://fonte_mundo.gd").texto(EstadoJogo.nome_treinador,Color.WHITE)
	nome.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	nome.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	nome.size=nome.texture.get_size()
	nome.position=Vector2(-floorf(nome.size.x*0.5),-44)
	nome.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(nome)
	controlador.trecho_percorrido.connect(_registrar_trecho)
	# Aparece após abrir espaço, evitando sobreposição inicial.
	hide()

func _registrar_trecho(origem: Vector2, destino: Vector2) -> void:
	if trilha.is_empty():
		trilha.append(origem)
	trilha.append(destino)
	comprimento += origem.distance_to(destino)

func _physics_process(delta: float) -> void:
	if controlador == null or quadros.is_empty():
		return
	var origem: Vector2 = global_position
	while comprimento > 32.0 and trilha.size() >= 2:
		var distancia: float = trilha[0].distance_to(trilha[1])
		if distancia <= 0.00001:
			trilha.pop_front()
			continue
		var passo: float = minf(distancia,comprimento-32.0)
		trilha[0] = trilha[0].move_toward(trilha[1],passo)
		comprimento -= passo
		global_position = trilha[0]
		if passo >= distancia-0.00001:
			trilha.pop_front()
	var deslocamento: Vector2 = global_position-origem
	if deslocamento.length_squared()>0.000001:
		show()
		direcao = (1 if deslocamento.x>0 else 3) if absf(deslocamento.x)>absf(deslocamento.y) else (2 if deslocamento.y>0 else 0)
		tempo += delta
		indice = int(tempo/0.15)%3
	else:
		tempo = 0.0
		indice = 0
	imagem.texture = quadros[direcao*3+indice]
	# Objetos do cenário permanecem na camada existente; ordena treinador/aliado entre si.
	z_index = controlador.imagem_aliado.z_index + (1 if global_position.y>controlador.imagem_aliado.global_position.y else -1)
