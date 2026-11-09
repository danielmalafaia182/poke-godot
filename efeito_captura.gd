extends Node2D

# Alteração: nomes dos spritesheets associados aos IDs originais.
# Master Ball não está incluída nesta etapa.
const PREFIXOS_BOLAS: Dictionary[int, String] = {
	1: "pokeball",
	2: "greatball",
	3: "superball",
	4: "ultraball",
	6: "idleball",
	7: "idleball_gold"
}

const PASTA_CAPTURA: String = "res://assets/efeitos/captura/"

const DURACAO_LANCAMENTO: float = 0.320
const DURACAO_QUADRO: float = 0.075
const TAMANHO_LANCAMENTO: int = 32
const TAMANHO_QUADRO: Vector2i = Vector2i(64, 96)

const QUADROS_SUCESSO: int = 60
const QUADROS_FALHA: int = 44

# Coluna e linha para cada direção de lançamento.
const RECORTES_DIRECAO: Array[Vector2i] = [
	Vector2i(2, 1),
	Vector2i(2, 2),
	Vector2i(1, 2),
	Vector2i(0, 2),
	Vector2i(0, 1),
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0)
]

# Alteração: texturas carregadas conforme a bola utilizada.
var textura_lancamento: Texture2D
var textura_resultado: Texture2D

var bola: Sprite2D
var texto: Label
var recorte: AtlasTexture

var ponto_inicial: Vector2
var ponto_final: Vector2

var captura_sucesso: bool = false
var nome_pokemon: String = ""
var configurado: bool = false

var tempo: float = 0.0
var quantidade_quadros: int = 0
var quadro_atual: int = -1
var resultado_iniciado: bool = false
var texto_exibido: bool = false
var mostrar_texto_resultado: bool = false


func configurar(
	origem_global: Vector2,
	destino_global: Vector2,
	sucesso: bool,
	nome: String,
	bola_id: int
) -> void:
	if configurado:
		return

	captura_sucesso = sucesso
	nome_pokemon = nome

	# Novo: resolve os arquivos da bola recebida no evento.
	if not _carregar_texturas(bola_id):
		queue_free()
		return

	quantidade_quadros = (
		QUADROS_SUCESSO if captura_sucesso else QUADROS_FALHA
	)

	if (
		textura_lancamento.get_width() < 96
		or textura_lancamento.get_height() < 96
	):
		push_error(
			"Spritesheet de lançamento inválido para a bola "
			+ str(bola_id)
			+ ". Use o arquivo da pasta throw."
		)
		queue_free()
		return

	if (
		textura_resultado.get_width() != TAMANHO_QUADRO.x
		or textura_resultado.get_height() < (
			TAMANHO_QUADRO.y * quantidade_quadros
		)
	):
		push_error(
			"Spritesheet de resultado inválido para a bola "
			+ str(bola_id)
			+ ". Esperada largura 64 e altura mínima "
			+ str(TAMANHO_QUADRO.y * quantidade_quadros)
			+ "."
		)
		queue_free()
		return

	z_index = 110

	ponto_inicial = to_local(origem_global)
	ponto_final = to_local(destino_global)

	recorte = AtlasTexture.new()

	bola = Sprite2D.new()
	bola.texture = recorte
	bola.centered = false
	bola.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bola)

	texto = Label.new()
	texto.size = Vector2(240.0, 32.0)
	texto.position = ponto_final + Vector2(-120.0, -72.0)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_font_size_override("font_size", 16)
	texto.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)
	texto.add_theme_constant_override("outline_size", 4)
	texto.hide()
	add_child(texto)

	_preparar_lancamento()

	tempo = 0.0
	configurado = true


# Novo: carrega somente os recursos necessários à tentativa.
func _carregar_texturas(bola_id: int) -> bool:
	if not PREFIXOS_BOLAS.has(bola_id):
		push_error(
			"Animação ainda não configurada para a bola "
			+ str(bola_id)
			+ "."
		)
		return false

	var prefixo: String = PREFIXOS_BOLAS[bola_id]

	var caminho_lancamento: String = (
		PASTA_CAPTURA + "throw/" + prefixo + ".png"
	)

	var sufixo: String = (
		"_catch.png" if captura_sucesso else "_broke.png"
	)

	var caminho_resultado: String = (
		PASTA_CAPTURA + prefixo + sufixo
	)

	if not ResourceLoader.exists(caminho_lancamento):
		push_error("Arquivo de lançamento ausente: " + caminho_lancamento)
		return false

	if not ResourceLoader.exists(caminho_resultado):
		push_error("Arquivo de captura ausente: " + caminho_resultado)
		return false

	textura_lancamento = load(caminho_lancamento) as Texture2D
	textura_resultado = load(caminho_resultado) as Texture2D

	if textura_lancamento == null or textura_resultado == null:
		push_error("Não foi possível carregar as texturas da bola.")
		return false

	return true


func _preparar_lancamento() -> void:
	var diferenca: Vector2 = ponto_final - ponto_inicial

	var indice_direcao: int = posmod(
		roundi(diferenca.angle() / (PI / 4.0)),
		8
	)

	var celula: Vector2i = RECORTES_DIRECAO[indice_direcao]

	recorte.atlas = textura_lancamento
	recorte.region = Rect2(
		float(celula.x * TAMANHO_LANCAMENTO),
		float(celula.y * TAMANHO_LANCAMENTO),
		float(TAMANHO_LANCAMENTO),
		float(TAMANHO_LANCAMENTO)
	)

	bola.offset = Vector2(
		-float(TAMANHO_LANCAMENTO) * 0.5,
		-float(TAMANHO_LANCAMENTO) * 0.72
	)

	bola.position = ponto_inicial


func _process(delta: float) -> void:
	if not configurado:
		return

	tempo += delta

	if tempo < DURACAO_LANCAMENTO:
		var progresso: float = tempo / DURACAO_LANCAMENTO

		bola.position = ponto_inicial.lerp(
			ponto_final,
			progresso
		)
		return

	if not resultado_iniciado:
		_iniciar_resultado()

	var tempo_resultado: float = tempo - DURACAO_LANCAMENTO
	var indice: int = floori(tempo_resultado / DURACAO_QUADRO)

	if indice >= quantidade_quadros:
		queue_free()
		return

	_aplicar_quadro(indice)

	var duracao_resultado: float = (
		float(quantidade_quadros) * DURACAO_QUADRO
	)

	if (
		not texto_exibido
		and tempo_resultado >= duracao_resultado - 0.65
	):
		_mostrar_resultado()


func _iniciar_resultado() -> void:
	resultado_iniciado = true
	bola.position = ponto_final
	recorte.atlas = textura_resultado

	bola.offset = Vector2(
		-float(TAMANHO_QUADRO.x) * 0.5,
		-float(TAMANHO_QUADRO.y) * 0.72
	)


func _aplicar_quadro(indice: int) -> void:
	if indice == quadro_atual:
		return

	quadro_atual = indice

	recorte.region = Rect2(
		0.0,
		float(indice * TAMANHO_QUADRO.y),
		float(TAMANHO_QUADRO.x),
		float(TAMANHO_QUADRO.y)
	)


func _mostrar_resultado() -> void:
	texto_exibido = true
	if not mostrar_texto_resultado: return

	if captura_sucesso:
		texto.text = nome_pokemon + " capturado!"
		texto.add_theme_color_override(
			"font_color",
			Color(0.4, 1.0, 0.5)
		)
	else:
		texto.text = "A captura falhou!"
		texto.add_theme_color_override(
			"font_color",
			Color(1.0, 0.45, 0.45)
		)

	texto.show()
