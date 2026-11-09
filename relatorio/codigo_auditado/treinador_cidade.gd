extends Node2D

# Novo: cada deslocamento real alimenta a trilha do seguidor, sem mudar navegação.
signal trecho_percorrido(origem: Vector2, destino_trecho: Vector2)

# Novo: movimento por células; mantém os inputs existentes e evita atravessar paredes.
# O traje base vem do original. Recoloração personalizada não é aplicada nesta etapa.
const TEXTURA: Texture2D = preload("res://assets/interface/cidade/treinador.webp")
@export var velocidade_movimento: float = 120.0
var cenario: Node2D
var imagem: Sprite2D
var quadros: Array[AtlasTexture] = []
var celula: Vector2i
var destino: Vector2
var andando: bool = false
var direcao: int = 2
var tempo: float = 0.0

func iniciar(cenario_cidade: Node2D) -> void:
	cenario = cenario_cidade
	z_index = 0
	imagem = Sprite2D.new()
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Os pés ficam no centro da célula; a imagem se estende para cima.
	imagem.offset = Vector2(0.0, -10.0)
	add_child(imagem)
	var manifesto: Dictionary = cenario.carregar_json("res://assets/interface/cidade/treinador.json")
	for sentido in range(1, 5):
		for quadro in range(1, 4):
			var chave: String = "/assets/outfits/male/159/%d_1_1_%d.png" % [quadro, sentido]
			var frame: Dictionary = manifesto["assets"][chave]["frames"][0]
			var recorte: AtlasTexture = AtlasTexture.new()
			recorte.atlas = TEXTURA
			recorte.region = Rect2(frame["x"], frame["y"], frame["w"], frame["h"])
			quadros.append(recorte)
	# Novo: encontra a célula livre mais próxima da praça; não nasce num telhado.
	var menor: float = INF
	for candidata in cenario.celulas_existentes:
		if not cenario.celula_transitavel(candidata):
			continue
		var distancia: float = Vector2(candidata).distance_squared_to(Vector2(-1, 2))
		if distancia < menor:
			menor = distancia
			celula = candidata
	if menor == INF:
		push_error("Cerulean não possui uma célula livre para o treinador.")
		return
	if EstadoJogo.posicao_cidade_definida and cenario.celula_transitavel(EstadoJogo.celula_cidade_salva):
		celula = EstadoJogo.celula_cidade_salva
		direcao = EstadoJogo.direcao_cidade_salva
	position = Vector2(celula) * 32.0 + Vector2(16.0, 16.0)
	destino = position
	imagem.texture = quadros[direcao * 3]
	EstadoJogo.registrar_posicao_cidade(celula, direcao)

# Usa o tempo restante ao terminar uma célula, sem pausas entre passos.
func atualizar(delta: float, entrada_habilitada: bool) -> void:
	if quadros.is_empty() or velocidade_movimento <= 0.0:
		return
	var restante: float = velocidade_movimento * delta
	var houve_movimento: bool = false
	while restante > 0.0001:
		if not andando:
			if not entrada_habilitada:
				break
			var eixo: Vector2 = Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")
			var passo: Vector2i = Vector2i.ZERO
			if absf(eixo.x) > absf(eixo.y):
				passo.x = 1 if eixo.x > 0.0 else -1
			elif eixo.y != 0.0:
				passo.y = 1 if eixo.y > 0.0 else -1
			if passo == Vector2i.ZERO:
				break
			# Duas teclas: se o eixo prioritário estiver bloqueado,
			# tenta o outro eixo, sem cortar diagonalmente paredes.
			if not cenario.celula_transitavel(celula + passo) and eixo.x != 0.0 and eixo.y != 0.0:
				var alternativa: Vector2i = Vector2i(int(signf(eixo.x)), 0) if passo.y != 0 else Vector2i(0, int(signf(eixo.y)))
				if cenario.celula_transitavel(celula + alternativa):
					passo = alternativa
			direcao = 1 if passo.x > 0 else (3 if passo.x < 0 else (2 if passo.y > 0 else 0))
			if not cenario.celula_transitavel(celula + passo):
				break
			celula += passo
			destino = Vector2(celula) * 32.0 + Vector2(16.0, 16.0)
			andando = true
		var distancia: float = position.distance_to(destino)
		var deslocamento: float = minf(restante, distancia)
		var origem_trecho: Vector2 = position
		position = position.move_toward(destino, deslocamento)
		if deslocamento > 0.0:
			trecho_percorrido.emit(origem_trecho, position)
		restante -= deslocamento
		houve_movimento = houve_movimento or deslocamento > 0.0
		andando = not position.is_equal_approx(destino)
		if not andando:
			EstadoJogo.registrar_posicao_cidade(celula, direcao)
		if andando:
			break
	if houve_movimento:
		tempo += delta
	else:
		tempo = 0.0
	if not andando:
		EstadoJogo.registrar_posicao_cidade(celula, direcao)
	var quadro: int = int(tempo / 0.15) % 3 if houve_movimento else 0
	imagem.texture = quadros[direcao * 3 + quadro]
