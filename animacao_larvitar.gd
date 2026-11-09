extends Sprite2D

@export var spritesheet: Texture2D
@export var duracao_quadro: float = 0.15

# Novo: Larvitar usa quatro quadros; Geodude usa três.
var quadros_por_direcao: int = 4
var recortes: Array[AtlasTexture] = []
var direcao: int = 2
var quadro: int = 0
var tempo_animacao: float = 0.0
var animacao_pronta: bool = false

@onready var controlador: Node2D = get_parent() as Node2D


func _ready() -> void:
	call_deferred("_iniciar_animacao")


func _iniciar_animacao() -> void:
	animacao_pronta=false
	quadro=0
	tempo_animacao=0.0
	if controlador == null:
		push_error("ImagemAliado precisa ter um controlador Node2D como pai.")
		return
	# Alteração: nome do arquivo/export preservados para manter a cena existente.
	# O aliado selecionado determina a página e o número de quadros por direção.
	var pokemon: DadosPokemon = controlador.get("pokemon_aliado")
	if pokemon == null or pokemon.especie == null or duracao_quadro <= 0.0:
		return
	var dados: Dictionary = preload("res://visual_pokemon.gd").obter(pokemon.especie.nome)
	if dados.is_empty():
		push_error("Aliado sem animação cadastrada: " + pokemon.especie.nome)
		return
	spritesheet = dados["textura"]
	quadros_por_direcao = int(dados["quadros"])
	recortes = preload("res://visual_pokemon.gd").recortar(pokemon.especie.nome)
	offset = dados["offset"] if pokemon.especie.nome.to_lower() == "geodude" else Vector2.ZERO
	hframes = 1
	vframes = 1
	region_enabled = false
	centered = true
	flip_h = false
	flip_v = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animacao_pronta = true
	_aplicar_quadro()


func _process(delta: float) -> void:
	if not animacao_pronta:
		return
	var andando: bool = bool(controlador.get("aproximando"))
	if not andando:
		quadro = 0
		tempo_animacao = 0.0
		_aplicar_quadro()
		return
	_atualizar_direcao()
	tempo_animacao += delta
	while tempo_animacao >= duracao_quadro:
		tempo_animacao -= duracao_quadro
		quadro = (quadro + 1) % quadros_por_direcao
	_aplicar_quadro()


func _atualizar_direcao() -> void:
	var caminho_atual: Array = controlador.get("caminho")
	var indice_atual: int = int(controlador.get("indice_caminho"))
	if indice_atual < 0 or indice_atual >= caminho_atual.size():
		return
	var celula: Vector2i = caminho_atual[indice_atual]
	var destino: Vector2 = controlador.call(
		"celula_para_posicao",
		celula
	)
	var deslocamento: Vector2 = destino - global_position
	if deslocamento.length_squared() < 0.0001:
		return
	if absf(deslocamento.x) > absf(deslocamento.y):
		direcao = 1 if deslocamento.x > 0.0 else 3
	else:
		direcao = 2 if deslocamento.y > 0.0 else 0


func _aplicar_quadro() -> void:
	texture = recortes[direcao * quadros_por_direcao + quadro]
