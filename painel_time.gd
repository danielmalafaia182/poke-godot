extends PanelContainer
# Alterações visuais da cidade: Painel208px, cabeçalho compacto, fontes menores, menor espaçamento e retratos sem margens transparentes.

# Alteração: composição e medidas baseadas no HUD .phud do cliente original.
# Não inventa nome/nível do treinador, XP ou vida individual ainda não persistidos.
const FONTE: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const TITULO: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const ESTILO: Script = preload("res://estilo_hud_original.gd")
var cartoes: Dictionary[DadosPokemon, CartaoPokemonHud] = {}
var provedor_cooldown: Callable
var lista: VBoxContainer
var cabecalho: Label
var recolher: Button
var icones: Dictionary = {}
var barra_xp_treinador: ProgressBar
var xp_treinador: Label
var localizacao: Label
# Novo: cidade/caça informam a localização sem duplicar o HUD.
var nome_local: String = "Cerulean"
# Novo: perfil local editável enquanto a progressão de conta não existe.
var perfil: ConfirmationDialog
var nick: LineEdit
var nivel_conta: SpinBox

func _ready() -> void:
	position = Vector2(16,16)
	custom_minimum_size = Vector2(208,0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var tema: Theme = Theme.new()
	tema.default_font = FONTE
	tema.default_font_size = 12
	theme = tema
	# Alteração: dimensões compactas aproximadas do painel original no browser.
	var moldura: StyleBoxTexture = ESTILO.moldura()
	moldura.content_margin_left = 9
	moldura.content_margin_right = 9
	moldura.content_margin_top = 8
	moldura.content_margin_bottom = 9
	add_theme_stylebox_override("panel",moldura)
	var conteudo: VBoxContainer = VBoxContainer.new()
	conteudo.add_theme_constant_override("separation",4)
	add_child(conteudo)
	var linha: HBoxContainer = HBoxContainer.new()
	linha.add_theme_constant_override("separation",6)
	conteudo.add_child(linha)
	var emblema: TextureRect = TextureRect.new()
	emblema.texture = preload("res://assets/interface/hud/logo.png")
	emblema.custom_minimum_size = Vector2(27,27)
	emblema.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblema.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	linha.add_child(emblema)
	var treinador: VBoxContainer = VBoxContainer.new()
	treinador.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	treinador.add_theme_constant_override("separation",0)
	linha.add_child(treinador)
	cabecalho = Label.new()
	cabecalho.text = EstadoJogo.nome_treinador.to_upper()
	cabecalho.add_theme_font_override("font",TITULO)
	cabecalho.add_theme_font_size_override("font_size",11)
	cabecalho.add_theme_color_override("font_color",Color("ddc082"))
	cabecalho.clip_text = true
	treinador.add_child(cabecalho)
	localizacao = Label.new()
	localizacao.add_theme_font_size_override("font_size",9)
	localizacao.add_theme_color_override("font_color",Color("8a93a0"))
	treinador.add_child(localizacao)
	barra_xp_treinador=ProgressBar.new()
	barra_xp_treinador.custom_minimum_size.y=5
	barra_xp_treinador.show_percentage=false
	barra_xp_treinador.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fundo: StyleBoxFlat=StyleBoxFlat.new()
	fundo.bg_color=Color("070e14");fundo.set_corner_radius_all(3)
	var cheio: StyleBoxFlat=StyleBoxFlat.new()
	cheio.bg_color=Color("d5ae45");cheio.set_corner_radius_all(3)
	barra_xp_treinador.add_theme_stylebox_override("background",fundo)
	barra_xp_treinador.add_theme_stylebox_override("fill",cheio)
	treinador.add_child(barra_xp_treinador)
	xp_treinador=Label.new()
	xp_treinador.add_theme_font_size_override("font_size",8)
	xp_treinador.add_theme_color_override("font_color",Color("c8ad6e"))
	treinador.add_child(xp_treinador)
	# Linha discreta e espaço do cabeçalho como .phud-head.
	var separador: HSeparator = HSeparator.new()
	var traco: StyleBoxLine = StyleBoxLine.new()
	traco.color = Color("99753047")
	traco.thickness = 1
	separador.add_theme_stylebox_override("separator",traco)
	separador.add_theme_constant_override("separation",4)
	conteudo.add_child(separador)
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation",4)
	conteudo.add_child(lista)
	_criar_perfil()
	# Novo: clique no cabeçalho configura o perfil local, não o TEAM.
	linha.mouse_filter = Control.MOUSE_FILTER_STOP
	linha.tooltip_text = "Clique para configurar o nome do treinador"
	linha.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			nick.text = EstadoJogo.nome_treinador
			nivel_conta.value = EstadoJogo.nivel_treinador
			perfil.popup_centered(Vector2i(330,180))
	)
	for controle in [emblema,treinador,cabecalho,localizacao]:
		controle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	EstadoJogo.perfil_alterado.connect(_atualizar_perfil)
	EstadoJogo.individuo_alterado.connect(_atualizar_individuo)
	EstadoJogo.depot_alterado.connect(atualizar)
	EstadoJogo.lider_alterado.connect(_atualizar_lider)
	atualizar()

func _icone(pokemon: DadosPokemon) -> Texture2D:
	var nome: String = pokemon.especie.nome.to_lower()
	if not icones.has(nome):
		# Todos os retratos do time olham para baixo, como solicitado.
		icones[nome] = preload("res://visual_pokemon.gd").retrato_frente(nome)
		if icones[nome] == null:
			icones[nome] = pokemon.especie.textura
	return icones[nome]

# Reconcilia composição por instância, preservando os cartões sobreviventes.
# Capturas na BOX e transferências de itens não recriam o TEAM.
func atualizar() -> void:
	_atualizar_perfil()
	var membros: Array[DadosPokemon] = EstadoJogo.time_pokemon
	for pokemon in cartoes.keys():
		if not membros.has(pokemon) or cartoes[pokemon].get_meta("especie_exibida","")!=pokemon.especie.nome:
			var removido: CartaoPokemonHud = cartoes[pokemon]
			lista.remove_child(removido)
			removido.queue_free()
			cartoes.erase(pokemon)
	var ordem: int = 0
	for pokemon in membros:
		if pokemon == null or pokemon.especie == null:
			continue
		if not cartoes.has(pokemon):
			var novo: CartaoPokemonHud = CartaoPokemonHud.new()
			lista.add_child(novo)
			novo.configurar(pokemon, _icone(pokemon))
			novo.lider_solicitado.connect(EstadoJogo.selecionar_lider)
			cartoes[pokemon] = novo
			novo.set_meta("especie_exibida",pokemon.especie.nome)
		lista.move_child(cartoes[pokemon], ordem)
		ordem += 1
	_atualizar_lider()
	size = get_combined_minimum_size()

func _atualizar_perfil() -> void:
	cabecalho.text = EstadoJogo.nome_treinador.to_upper()
	localizacao.text = "Level %d · %s" % [EstadoJogo.nivel_treinador,nome_local]
	var progresso: Dictionary=EstadoJogo.perfil.obter_progresso()
	barra_xp_treinador.value=float(progresso["percentual"])
	xp_treinador.text="XP %d / %d" % [progresso["atual"],progresso["necessario"]]
	barra_xp_treinador.tooltip_text="Faltam %d XP para o próximo nível" % (int(progresso["necessario"])-int(progresso["atual"]))

func _atualizar_individuo(pokemon: DadosPokemon) -> void:
	if cartoes.has(pokemon):
		cartoes[pokemon].atualizar_valores()

func _atualizar_lider() -> void:
	for cartao in cartoes.values():
		cartao.atualizar_lider(cartao.pokemon == EstadoJogo.obter_lider())

func _criar_perfil() -> void:
	perfil = ConfirmationDialog.new()
	perfil.title = "Perfil local"
	add_child(perfil)
	var conteudo: VBoxContainer = VBoxContainer.new()
	perfil.add_child(conteudo)
	var legenda: Label = Label.new()
	legenda.text = "Nick e nível deste protótipo offline:"
	conteudo.add_child(legenda)
	nick = LineEdit.new()
	nick.max_length = 32
	nick.placeholder_text = "Nick"
	conteudo.add_child(nick)
	nivel_conta = SpinBox.new()
	nivel_conta.min_value = 1
	nivel_conta.max_value = 100000
	nivel_conta.prefix = "Level "
	nivel_conta.editable=false
	conteudo.add_child(nivel_conta)
	perfil.confirmed.connect(func() -> void:
		EstadoJogo.definir_perfil_treinador(nick.text,EstadoJogo.nivel_treinador)
	)

func _process(_delta: float) -> void:
	var restante: float=float(provedor_cooldown.call()) if provedor_cooldown.is_valid() else 0.0
	for cartao in cartoes.values():cartao.atualizar_cooldown(restante)
