class_name CartaoPokemonHud
extends PanelContainer

# Medidas finais medidas nos recortes fornecidos: retrato 34px, cartão 44px.
# O cartão continua vivo durante atualizações de HP/XP; só seus valores mudam.
const UI: Script = preload("res://estilo_ui_fiel.gd")
const TIPOS: Script = preload("res://tipos_pokemon.gd")
const BARRAS: Script = preload("res://barras_pokemon.gd")
signal lider_solicitado(pokemon: DadosPokemon)
var pokemon: DadosPokemon
var retrato: TextureRect
var icone_tipo: TextureRect
var nome: Label
var nivel: Label
var barra_hp: ProgressBar
var barra_xp: ProgressBar
var evoluir: Button
var _lider: bool = false
var _hover: bool = false
var mascara_cooldown: Control
var bloqueado_cooldown: bool=false

func configurar(individuo: DadosPokemon, textura: Texture2D) -> void:
	pokemon = individuo
	custom_minimum_size = Vector2(0,44)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_entrada)
	mouse_entered.connect(func() -> void: _hover=true; _estilo())
	mouse_exited.connect(func() -> void: _hover=false; _estilo())
	_estilo()
	var linha: HBoxContainer = HBoxContainer.new()
	linha.add_theme_constant_override("separation",8)
	add_child(linha)
	var circulo: Control = Control.new()
	circulo.custom_minimum_size = Vector2(36,36)
	circulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(circulo)
	var base: Dictionary = preload("res://regras_pokemon.gd").obter_base(pokemon.especie.nome)
	var tipo: String = str(base.get("type1","")).to_lower()
	var fundo: TextureRect = TextureRect.new()
	fundo.texture = UI.circulo(TIPOS.cor(tipo))
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	circulo.add_child(fundo)
	retrato = TextureRect.new()
	retrato.texture = textura
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.position = Vector2(6,5)
	retrato.size = Vector2(24,26)
	circulo.add_child(retrato)
	# O emblema é uma insígnia à frente, não uma marca d'água atrás do Pokémon.
	icone_tipo = TextureRect.new()
	icone_tipo.texture = TIPOS.icone(tipo)
	icone_tipo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone_tipo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone_tipo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone_tipo.position = Vector2(2,23)
	icone_tipo.size = Vector2(12,12)
	circulo.add_child(icone_tipo)
	mascara_cooldown=preload("res://mascara_cooldown.gd").new()
	circulo.add_child(mascara_cooldown)
	mascara_cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dados: VBoxContainer = VBoxContainer.new()
	dados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dados.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dados.add_theme_constant_override("separation",2)
	linha.add_child(dados)
	var nomes: HBoxContainer = HBoxContainer.new()
	nomes.add_theme_constant_override("separation",4)
	dados.add_child(nomes)
	nome = UI.texto(pokemon.especie.nome,9,Color("f0e6d2"),true)
	nome.add_theme_font_override("font",UI.TITULO)
	nome.clip_text = true
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nomes.add_child(nome)
	nivel = UI.texto("",8,Color("7fe6dd"),true)
	nomes.add_child(nivel)
	# Evolução manual: disponibilidade validada pela regra de cidade e nível.
	evoluir = Button.new()
	evoluir.text = "Evolve"
	evoluir.disabled = true
	evoluir.custom_minimum_size = Vector2(29,13)
	evoluir.add_theme_font_override("font",UI.FORTE)
	evoluir.add_theme_font_size_override("font_size",7)
	evoluir.add_theme_color_override("font_disabled_color",Color("9aa6b3"))
	var bloqueado: StyleBoxFlat = UI.caixa(Color("2b3e50"),Color("3a4a5c"),3,2)
	bloqueado.content_margin_top = 0
	bloqueado.content_margin_bottom = 0
	evoluir.add_theme_stylebox_override("disabled",bloqueado)
	evoluir.tooltip_text = "Evolução disponível em Cerulean ao atingir o nível exigido."
	nomes.add_child(evoluir)
	evoluir.add_theme_stylebox_override("normal",bloqueado)
	evoluir.pressed.connect(func() -> void: load("res://painel_evolucao.gd").abrir_para(get_tree(), pokemon))
	call_deferred("atualizar_valores")
	barra_hp = BARRAS.criar(pokemon,false,7)
	dados.add_child(barra_hp)
	barra_xp = BARRAS.criar(pokemon,true,5)
	dados.add_child(barra_xp)
	for barra in [barra_hp,barra_xp]:
		barra.add_theme_stylebox_override("background",UI.capsula("fundo",int(barra.custom_minimum_size.y)))
		var texto: Label = barra.get_child(0) as Label
		texto.add_theme_font_override("font",UI.FORTE)
		texto.add_theme_font_size_override("font_size",6)
		texto.add_theme_constant_override("outline_size",1)
	_ignorar_filhos(self)
	# O botão indisponível conserva seu tooltip, sem propagar clique de liderança.
	evoluir.mouse_filter = Control.MOUSE_FILTER_STOP
	atualizar_valores()

func _entrada(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index==MOUSE_BUTTON_LEFT:
		accept_event()
		if not bloqueado_cooldown: lider_solicitado.emit(pokemon)

func atualizar_lider(inicial: bool) -> void:
	_lider = inicial
	_estilo()

func _estilo() -> void:
	var fundo: Color = Color("c8aa6e1a") if _lider else (Color("ffffff12") if _hover else Color("ffffff08"))
	var estilo: StyleBoxFlat = UI.caixa(fundo,Color("c8aa6eb3") if _lider else Color.TRANSPARENT,5,4)
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 4
	add_theme_stylebox_override("panel",estilo)

func atualizar_valores() -> void:
	if not is_inside_tree(): return
	if evoluir!=null:
		evoluir.visible=not preload("res://regras_evolucao.gd").obter(pokemon.especie.nome).is_empty()
		evoluir.tooltip_text=get_node("/root/EstadoJogo").validar_evolucao(pokemon)
		evoluir.disabled=not evoluir.tooltip_text.is_empty()
	nome.text = pokemon.especie.nome
	nivel.text = "Lv.%d" % pokemon.nivel
	BARRAS.atualizar(barra_hp,pokemon,false)
	BARRAS.atualizar(barra_xp,pokemon,true)
	var proporcao: float = float(pokemon.obter_vida_atual())/maxi(1,pokemon.obter_vida_maxima())
	barra_hp.add_theme_stylebox_override("fill",UI.capsula("critico" if proporcao<=0.2 else ("baixo" if proporcao<=0.5 else "hp"),7))
	barra_xp.add_theme_stylebox_override("fill",UI.capsula("xp",5))
	tooltip_text = "%s\nNível %d · Quality %.3f · %s\nIVs %d/192\nHP %d/%d\nClique para selecionar como líder." % [pokemon.especie.nome,pokemon.nivel,pokemon.qualidade,pokemon.obter_classificacao(),pokemon.obter_total_ivs(),pokemon.obter_vida_atual(),pokemon.obter_vida_maxima()]

func _ignorar_filhos(no: Node) -> void:
	for filho in no.get_children():
		if filho is Control:
			filho.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignorar_filhos(filho)

func atualizar_cooldown(restante: float) -> void:
	bloqueado_cooldown=restante>0.0 and not _lider
	mascara_cooldown.atualizar(restante if bloqueado_cooldown else 0.0)
	var cor: Color=Color("ffffff66") if bloqueado_cooldown else Color.WHITE
	for controle in [nome,nivel,barra_hp,barra_xp,evoluir]:controle.modulate=cor
	mouse_default_cursor_shape=Control.CURSOR_FORBIDDEN if bloqueado_cooldown else Control.CURSOR_POINTING_HAND
	tooltip_text="Troca disponível em %d s" % ceili(restante) if bloqueado_cooldown else "Clique para usar este Pokémon"
