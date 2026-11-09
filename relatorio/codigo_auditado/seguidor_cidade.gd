extends Node2D

# Alteração: o líder selecionado segue a trilha real, mantendo uma célula de distância.
# Não calcula uma linha reta até o treinador nem altera o estado salvo.
const TEXTURA: Texture2D = preload("res://assets/pokemon/larvitar/outfits-male-400-00-9bea9479fb83.webp")
# Novo: cada seguidor alimenta a trilha do próximo, sem cortar as curvas.
signal trecho_percorrido(origem: Vector2, destino_trecho: Vector2)
var pokemon_seguido: DadosPokemon
var emergindo: bool = false
var celula: Vector2i:
	get:
		return Vector2i(floori(position.x / 32.0), floori(position.y / 32.0))

const DISTANCIA: float = 32.0
var quadros_por_direcao: int = 4
var imagem: Sprite2D
var quadros: Array[AtlasTexture] = []
var trilha: Array[Vector2] = []
var direcao: int = 2
var tempo: float = 0.0
var andando: bool = false

func iniciar(treinador: Node2D, cenario: Node2D, pokemon: DadosPokemon = null, ocupadas: Dictionary = {}) -> void:
	imagem = Sprite2D.new()
	imagem.offset = Vector2(0.0, -10.0)
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(imagem)
	# Alteração: a cidade controla a associação de cada posição ao indivíduo do TEAM.
	definir_pokemon(pokemon)
	direcao = treinador.direcao
	position = treinador.position
	# Novo: começa numa célula livre adjacente, preferindo atrás do treinador.
	var atras: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]
	var candidatas: Array[Vector2i] = [atras[direcao], Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]
	var centro_origem: Vector2 = Vector2(treinador.celula) * 32.0 + Vector2(16,16)
	for passo in candidatas:
		# Novo: origem entre células não gera um trecho deslocado através de paredes.
		if not treinador.position.is_equal_approx(centro_origem):
			break
		if cenario.celula_transitavel(treinador.celula + passo) and not ocupadas.has(treinador.celula + passo):
			position = treinador.position + Vector2(passo) * 32.0
			break
	# Novo: sem vaga adjacente, aguarda oculto no início da trilha e emerge ao andar.
	emergindo = position.is_equal_approx(treinador.position)
	imagem.visible = not emergindo
	trilha.append(position)
	if position != treinador.position:
		trilha.append(treinador.position)
	imagem.texture = quadros[direcao * quadros_por_direcao]
	treinador.trecho_percorrido.connect(_registrar_trecho)

func _registrar_trecho(origem: Vector2, destino: Vector2) -> void:
	if trilha.is_empty():
		trilha.append(position)
	# Novo: todos os trechos são recebidos, inclusive em frames longos e curvas.
	if not trilha[-1].is_equal_approx(origem):
		push_error("Trilha do seguidor perdeu continuidade.")
		return
	if not origem.is_equal_approx(destino):
		trilha.append(destino)

func atualizar(delta: float, velocidade: float) -> void:
	var comprimento: float = 0.0
	for indice in range(1, trilha.size()):
		comprimento += trilha[indice - 1].distance_to(trilha[indice])
	var restante: float = minf(maxf(0.0, comprimento - DISTANCIA), velocidade * delta)
	andando = restante > 0.0001
	while restante > 0.0001 and trilha.size() >= 2:
		var diferenca: Vector2 = trilha[1] - position
		if absf(diferenca.x) > absf(diferenca.y):
			direcao = 1 if diferenca.x > 0.0 else 3
		elif diferenca.y != 0.0:
			direcao = 2 if diferenca.y > 0.0 else 0
		var passo: float = minf(restante, diferenca.length())
		var origem_trecho: Vector2 = position
		position = position.move_toward(trilha[1], passo)
		if passo > 0.0:
			emergindo = false
			imagem.show()
			trecho_percorrido.emit(origem_trecho, position)
		restante -= passo
		if position.is_equal_approx(trilha[1]):
			trilha.pop_front()
		else:
			trilha[0] = position
	if andando:
		tempo += delta
	else:
		tempo = 0.0
	var quadro: int = int(tempo / 0.15) % quadros_por_direcao if andando else 0
	imagem.texture = quadros[direcao * quadros_por_direcao + quadro]

# Novo: troca somente os quadros; preserva posição e trilha ao selecionar o líder.
func definir_pokemon(pokemon: DadosPokemon = null) -> void:
	if pokemon == null:
		pokemon = EstadoJogo.obter_lider()
	if pokemon_seguido == pokemon:
		return
	pokemon_seguido = pokemon
	var dados: Dictionary = preload("res://visual_pokemon.gd").obter(pokemon.especie.nome)
	quadros = preload("res://visual_pokemon.gd").recortar(pokemon.especie.nome)
	quadros_por_direcao = int(dados["quadros"])
	imagem.offset = dados["offset"]
	tempo = 0.0
	imagem.texture = quadros[direcao * quadros_por_direcao]
