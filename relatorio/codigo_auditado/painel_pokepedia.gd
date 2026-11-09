extends Control

# Novo: consulta local dos dados originais para as duas espécies atuais.
# Não equipa golpes, não aplica dano nem altera nível/XP/estoque.
const CATALOGO: Script = preload("res://catalogo_golpes.gd")
const ESTILO: Script = preload("res://estilo_hud_original.gd")
var janela: PanelContainer
var nome_especie: OptionButton
var nivel: SpinBox
var alvo: OptionButton
var somente: CheckButton
var lista: VBoxContainer
var contador: Label
var rolagem: ScrollContainer
var bloqueio: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tema: Theme = Theme.new()
	tema.default_font = preload("res://assets/interface/depot/barlow_semibold.ttf")
	tema.default_font_size = 13
	theme = tema
	var sombra: ColorRect = ColorRect.new()
	sombra.color = Color(0,0,0,0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide()
	)
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel",ESTILO.moldura())
	add_child(janela)
	var corpo: VBoxContainer = VBoxContainer.new()
	corpo.add_theme_constant_override("separation",10)
	janela.add_child(corpo)
	var cabecalho: HBoxContainer = HBoxContainer.new()
	corpo.add_child(cabecalho)
	var titulo: Label = _texto("POKEPEDIA · GOLPES",18,Color("e8cd8d"))
	titulo.add_theme_font_override("font",preload("res://assets/interface/depot/cinzel.ttf"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	var fechar: Button = Button.new()
	fechar.text = "×"
	fechar.pressed.connect(hide)
	cabecalho.add_child(fechar)
	corpo.add_child(_texto("Base local: Larvitar e Geodude. Consulta sem alterar seu Pokémon.",12,Color("9aa6b3")))
	var filtros: HBoxContainer = HBoxContainer.new()
	corpo.add_child(filtros)
	nome_especie = OptionButton.new()
	nome_especie.add_item("Larvitar")
	nome_especie.add_item("Geodude")
	filtros.add_child(nome_especie)
	filtros.add_child(_texto("Nível:"))
	nivel = SpinBox.new()
	nivel.min_value = 1
	nivel.max_value = 100000
	nivel.value = 1
	nivel.custom_minimum_size.x = 90
	filtros.add_child(nivel)
	filtros.add_child(_texto("Contra:"))
	alvo = OptionButton.new()
	alvo.add_item("Larvitar")
	alvo.add_item("Geodude")
	filtros.add_child(alvo)
	somente = CheckButton.new()
	somente.text = "Só disponíveis"
	filtros.add_child(somente)
	contador = _texto("")
	corpo.add_child(contador)
	var aviso: Label = _texto("Power é a potência do golpe. O multiplicador compara apenas os tipos.",11,Color("c8aa6e"))
	corpo.add_child(aviso)
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_child(rolagem)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation",8)
	rolagem.add_child(lista)
	nome_especie.item_selected.connect(func(_i: int) -> void: atualizar())
	nivel.value_changed.connect(func(_valor: float) -> void: atualizar())
	alvo.item_selected.connect(func(_i: int) -> void: atualizar())
	somente.toggled.connect(func(_ativo: bool) -> void: atualizar())
	resized.connect(_ajustar)
	hide()

func _texto(texto: String, tamanho: int = 13, cor: Color = Color("f0e6d2")) -> Label:
	var label: Label = Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size",tamanho)
	label.add_theme_color_override("font_color",cor)
	return label

func abrir() -> void:
	var pokemon: DadosPokemon = EstadoJogo.obter_lider()
	bloqueio = true
	nome_especie.select(0 if pokemon.especie.nome == "Larvitar" else 1)
	nivel.value = pokemon.nivel
	bloqueio = false
	show()
	atualizar()
	_ajustar()

func atualizar() -> void:
	if bloqueio:
		return
	for filho in lista.get_children():
		lista.remove_child(filho)
		filho.queue_free()
	var nome: String = nome_especie.get_item_text(nome_especie.selected)
	var dados_alvo: Dictionary = CATALOGO.obter(alvo.get_item_text(alvo.selected))
	var todos: Array[Dictionary] = CATALOGO.listar(nome,int(nivel.value))
	var disponiveis: int = CATALOGO.listar(nome,int(nivel.value),true).size()
	contador.text = "%s · %d disponíveis / %d golpes cadastrados" % [nome,disponiveis,todos.size()]
	for golpe in todos:
		if somente.button_pressed and not golpe["disponivel"]:
			continue
		var cartao: PanelContainer = PanelContainer.new()
		var estilo: StyleBoxFlat = ESTILO.plano(Color("13251f") if golpe["disponivel"] else Color("101a24"),Color("526a43") if golpe["disponivel"] else Color("34414c"),6)
		estilo.content_margin_left = 10
		estilo.content_margin_right = 10
		estilo.content_margin_top = 8
		estilo.content_margin_bottom = 8
		cartao.add_theme_stylebox_override("panel",estilo)
		lista.add_child(cartao)
		var coluna: VBoxContainer = VBoxContainer.new()
		cartao.add_child(coluna)
		var linha: HBoxContainer = HBoxContainer.new()
		coluna.add_child(linha)
		var tipo: TextureRect = TextureRect.new()
		tipo.texture = load("res://assets/interface/tipos/" + str(golpe["type"]).to_lower() + ".png")
		tipo.custom_minimum_size = Vector2(22,22)
		tipo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tipo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		linha.add_child(tipo)
		var titulo: Label = _texto(golpe["name"],16)
		titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(titulo)
		linha.add_child(_texto("Disponível" if golpe["disponivel"] else "Aprende no Lv.%d" % int(golpe["learnLevel"]),12,Color("8bf07a") if golpe["disponivel"] else Color("8a93a0")))
		var fator: float = CATALOGO.efetividade(golpe["type"],dados_alvo["type1"],dados_alvo.get("type2",""))
		coluna.add_child(_texto("%s · %s · Power %d · CD %.1fs · Lv.%d" % [golpe["type"],"Físico" if golpe["category"] == "PHYSICAL" else "Especial",int(golpe["power"]),float(golpe["cooldownMs"])/1000.0,int(golpe["learnLevel"])],12))
		coluna.add_child(_texto("Contra %s: ×%s%s" % [dados_alvo["name"],str(fator)," · Imune" if fator == 0.0 else ""],11,Color("c8aa6e")))
	rolagem.scroll_vertical = 0

func _ajustar() -> void:
	var base: Vector2 = Vector2(760,540).max(janela.get_combined_minimum_size())
	var escala: float = minf(1.0,minf((size.x-32)/base.x,(size.y-32)/base.y))
	janela.size = base
	janela.scale = Vector2.ONE * maxf(0.3,escala)
	janela.position = (size-janela.size*janela.scale)*0.5
