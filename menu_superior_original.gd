extends Control
# Alterações visuais da cidade: Dock1244x48 em Full HD, ícones menores e distribuídos, sem trilho de rolagem; ícones indisponíveis preservam a cor.

# Novo: ícones e ordem vêm do catálogo mB do cliente extraído.
# Apenas ações locais existentes são habilitadas; as demais são explicitamente indisponíveis.
signal mapa_solicitado
signal time_solicitado
signal auto_helper_solicitado
signal pokepedia_solicitada
signal cidade_solicitada
signal janela_solicitada(chave: String)   # ciclo 2: janelas novas (perfil, bolas usadas, analyzer, streak, diárias…)
const JANELAS := ["profile", "usedballs", "analyzer", "streak", "daily", "quest", "pokedex", "inventory", "gyms", "bosses"]
const ESTILO: Script = preload("res://estilo_hud_original.gd")
var barra: PanelContainer
var rolagem: ScrollContainer
var abrir: Button
var botoes: Dictionary = {}
# Alteração: mantém a linha acessível para adaptação e validação do dock.
var linha: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra = PanelContainer.new()
	barra.name = "DockOriginal"
	var moldura: StyleBoxTexture = ESTILO.moldura()
	moldura.content_margin_left = 10
	moldura.content_margin_right = 10
	moldura.content_margin_top = 5
	moldura.content_margin_bottom = 5
	barra.add_theme_stylebox_override("panel",moldura)
	add_child(barra)
	rolagem = ScrollContainer.new()
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Alteração: todos os ícones cabem em Full HD; telas menores mantêm rolagem sem trilho.
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rolagem.get_h_scroll_bar().custom_minimum_size.y = 5
	barra.add_child(rolagem)
	linha = HBoxContainer.new()
	linha.add_theme_constant_override("separation",2)
	rolagem.add_child(linha)
	var itens: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/interface/hud/menu_original.json"))
	for item in itens:
		var botao: Button = Button.new()
		botao.name = item["chave"]
		botao.custom_minimum_size = Vector2(34,36)
		botao.icon = load("res://assets/interface/hud/" + item["icone"])
		botao.expand_icon = true
		botao.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		botao.add_theme_constant_override("icon_max_width",26 if item["chave"] in ["map","home","gyms","pokecards"] else 24)
		botao.focus_mode = Control.FOCUS_NONE
		botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		botao.add_theme_stylebox_override("normal",ESTILO.plano(Color.TRANSPARENT,Color.TRANSPARENT))
		botao.add_theme_stylebox_override("hover",ESTILO.plano(Color("c8aa6e1f"),Color("c8aa6e66")))
		botao.add_theme_stylebox_override("pressed",ESTILO.plano(Color("2dc5ff29"),Color("2dc5ff8c")))
		botao.add_theme_stylebox_override("disabled",ESTILO.plano(Color.TRANSPARENT,Color.TRANSPARENT))
		botao.add_theme_color_override("icon_disabled_color",Color(1.0,1.0,1.0,1.0))
		var chave: String = item["chave"]
		botao.tooltip_text = item["nome"]
		match chave:
			"map": botao.pressed.connect(func() -> void: mapa_solicitado.emit())
			"pokemon":
				botao.tooltip_text = "Pokémon — abrir TEAM / My Pokes"
				botao.pressed.connect(func() -> void: time_solicitado.emit())
			"pokepedia": botao.pressed.connect(func() -> void: pokepedia_solicitada.emit())
			"home": botao.pressed.connect(func() -> void: cidade_solicitada.emit())
			_ when chave in JANELAS:
				botao.pressed.connect(func() -> void: janela_solicitada.emit(chave))
			_:
				botao.disabled = true
				botao.mouse_default_cursor_shape = Control.CURSOR_HELP
				botao.tooltip_text += " — Ainda não implementado nesta versão"
		linha.add_child(botao)
		botoes[chave] = botao
	# Alteração: o Auto-Helper é separado à direita, como na referência.
	abrir = Button.new()
	preload("res://estilo_depot_fiel.gd").aplicar_auto_helper(abrir)
	abrir.pressed.connect(func() -> void: auto_helper_solicitado.emit())
	add_child(abrir)
	resized.connect(_ajustar)
	_ajustar()

func _ajustar() -> void:
	# Alteração: dock de até 1244px, centrado e com reserva para o TEAM de 208px.
	var largura: float = minf(1244.0,maxf(232.0,size.x-480.0))
	barra.position = Vector2((size.x-largura)*0.5,16)
	barra.size = Vector2(largura,48)
	# Distribui os 33 ícones por toda a largura quando há espaço disponível.
	linha.custom_minimum_size.x = maxf(0.0,largura-20.0)
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	for botao in botoes.values():
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abrir.position = Vector2(maxf(16,size.x-206),72)
	abrir.size = Vector2(190,34)
