extends Node2D

# Novo: efeito visual independente do Pokémon.
# Continua existindo mesmo quando o alvo é capturado e escondido.
var imagem: Sprite2D
var texto_dano: Label
var recorte: AtlasTexture

var tamanho_quadro: Vector2i
var quantidade_quadros: int = 0
var duracao_quadro: float = 0.0
var tempo: float = 0.0
var quadro_atual: int = -1
var configurado: bool = false

# Novo: duração do indicador encontrada no cliente original.
const DURACAO_TEXTO: float = 0.95

# Novo: deslocamento visual adotado para o nosso indicador.
const SUBIDA_TEXTO: float = 28.0
const POSICAO_TEXTO: Vector2 = Vector2(-70.0, -52.0)


func configurar(
	textura: Texture2D,
	novo_tamanho_quadro: Vector2i,
	nova_quantidade_quadros: int,
	nova_duracao_quadro: float,
	escala_efeito: float,
	dano: int,
	cor_dano: Color
) -> void:
	if textura == null:
		push_error("Não foi possível carregar a textura do impacto.")
		queue_free()
		return

	if (
		nova_quantidade_quadros <= 0
		or nova_duracao_quadro <= 0.0
		or novo_tamanho_quadro.x <= 0
		or novo_tamanho_quadro.y <= 0
	):
		push_error("Configuração inválida dos quadros do impacto.")
		queue_free()
		return

	# Novo: valida o spritesheet vertical antes de fazer os recortes.
	if (
		textura.get_width() != novo_tamanho_quadro.x
		or textura.get_height() != (
			novo_tamanho_quadro.y * nova_quantidade_quadros
		)
	):
		push_error("A imagem do impacto não corresponde aos recortes esperados.")
		queue_free()
		return

	tamanho_quadro = novo_tamanho_quadro
	quantidade_quadros = nova_quantidade_quadros
	duracao_quadro = nova_duracao_quadro

	# Novo: mantém os efeitos acima dos personagens e do cenário.
	z_index = 100

	recorte = AtlasTexture.new()
	recorte.atlas = textura

	imagem = Sprite2D.new()
	imagem.centered = true
	imagem.texture = recorte
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.scale = Vector2.ONE * escala_efeito
	add_child(imagem)

	texto_dano = Label.new()
	texto_dano.text = "-" + str(dano)
	texto_dano.position = POSICAO_TEXTO
	texto_dano.size = Vector2(140.0, 32.0)
	texto_dano.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_dano.mouse_filter = Control.MOUSE_FILTER_IGNORE

	texto_dano.add_theme_font_size_override("font_size", 20)
	texto_dano.add_theme_color_override("font_color", cor_dano)
	texto_dano.add_theme_color_override("font_outline_color", Color.BLACK)
	texto_dano.add_theme_constant_override("outline_size", 4)

	add_child(texto_dano)

	tempo = 0.0
	configurado = true
	_aplicar_quadro(0)


func _process(delta: float) -> void:
	if not configurado:
		return

	tempo += delta

	var indice: int = floori(tempo / duracao_quadro)

	if indice < quantidade_quadros:
		_aplicar_quadro(indice)
	else:
		imagem.hide()

	# Novo: número sobe e desaparece progressivamente.
	# A trajetória e as cores são escolhas visuais do protótipo.
	var progresso: float = clampf(
		tempo / DURACAO_TEXTO,
		0.0,
		1.0
	)

	texto_dano.position = (
		POSICAO_TEXTO + Vector2(0.0, -SUBIDA_TEXTO * progresso)
	)

	# Mantém a leitura nítida no início e reduz a opacidade no final.
	texto_dano.modulate.a = 1.0 - clampf(
		(progresso - 0.55) / 0.45,
		0.0,
		1.0
	)

	var duracao_total: float = maxf(
		DURACAO_TEXTO,
		float(quantidade_quadros) * duracao_quadro
	)

	if tempo >= duracao_total:
		queue_free()


func _aplicar_quadro(indice: int) -> void:
	if indice == quadro_atual:
		return

	quadro_atual = indice

	# Novo: avança no eixo Y porque o spritesheet é vertical.
	recorte.region = Rect2(
		0.0,
		float(indice * tamanho_quadro.y),
		float(tamanho_quadro.x),
		float(tamanho_quadro.y)
	)
