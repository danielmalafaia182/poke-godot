extends Sprite2D

var recortes: Array[AtlasTexture] = []
var direcao: int = 2
var quadro: int = 0
var quadros_por_direcao: int = 3
var tempo_animacao: float = 0.0
var duracao_quadro: float = 0.15
var animacao_pronta: bool = false
var controlador: Node2D
var imagem_aliado: Sprite2D
var textura_atual: Texture2D


func configurar(
	nome: String,
	novo_controlador: Node2D,
	novo_aliado: Sprite2D
) -> void:
	animacao_pronta = false
	var visual: Dictionary = preload("res://visual_pokemon.gd").obter(nome)
	if visual.is_empty(): return
	controlador = novo_controlador
	imagem_aliado = novo_aliado
	recortes = preload("res://visual_pokemon.gd").recortar(nome)
	quadros_por_direcao = int(visual["quadros"])
	hframes = 1
	vframes = 1
	region_enabled = false
	centered = true
	flip_h = false
	flip_v = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offset = visual["offset"]
	direcao = randi_range(0, 3)
	quadro = randi_range(0, quadros_por_direcao-1)
	tempo_animacao = randf_range(0.0, duracao_quadro)

	animacao_pronta = true
	_aplicar_quadro()


func _process(delta: float) -> void:
	if not animacao_pronta or not is_visible_in_tree():
		return
	if is_instance_valid(controlador) and is_instance_valid(imagem_aliado):
		var alvo_atual: Variant = controlador.get("imagem_selvagem")
		var aproximando: bool = bool(controlador.get("aproximando"))
		var encerrada: bool = bool(controlador.get("batalha_encerrada"))
		if alvo_atual == self and not aproximando and not encerrada:
			_olhar_para(imagem_aliado.global_position)
	tempo_animacao += delta
	while tempo_animacao >= duracao_quadro:
		tempo_animacao -= duracao_quadro
		quadro = (quadro + 1) % quadros_por_direcao
	_aplicar_quadro()


func _olhar_para(posicao_alvo: Vector2) -> void:
	var diferenca: Vector2 = posicao_alvo - global_position
	if diferenca.length_squared() < 0.0001:
		return
	if absf(diferenca.x) > absf(diferenca.y):
		direcao = 1 if diferenca.x > 0.0 else 3
	else:
		direcao = 2 if diferenca.y > 0.0 else 0


func _aplicar_quadro() -> void:
	texture = recortes[direcao * quadros_por_direcao + quadro]
