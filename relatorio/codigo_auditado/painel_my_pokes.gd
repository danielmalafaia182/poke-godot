extends Control

# TEAM: medidas e composição .team-window, .team-pit e .team-bars do cliente.
# Slots consultam a ficha; apenas Invocar solicita a alteração de líder.
const UI: Script = preload("res://estilo_ui_fiel.gd")
const ESTILO: Script = preload("res://estilo_team.gd")
const TIPOS: Script = preload("res://tipos_pokemon.gd")
const VISUAL: Script = preload("res://visual_pokemon.gd")
const BARRAS: Script = preload("res://barras_pokemon.gd")
const CHAVES: Array[String] = ["hp","atk","def","spAtk","spDef","speed"]
# Primeiras linhas de evolução, com níveis e destinos do catálogo extraído.
const EVOLUCOES: Dictionary = preload("res://regras_evolucao.gd").LINHAS
@export var permitir_troca_lider: bool = true
@export var exigir_lider_saudavel: bool = false
var provedor_cooldown: Callable
var janela: PanelContainer
var corpo: VBoxContainer
var selecionado: DadosPokemon
var slots: Array[Button] = []
var referencias: Dictionary = {}
var retrato_grande: TextureRect
var quadros_ficha: Array[Texture2D] = []
var tempo_animacao: float = 0.0
var barra_hp: ProgressBar
var barra_xp: ProgressBar
var invocar: Button
var evoluir: Button
var nome_pokemon: Label
var nivel_pokemon: Label
var power_pokemon: Label
var selo_qualidade: PanelContainer
var texto_qualidade: Label
var selos_tipos: Array[PanelContainer] = []
var textos_tipos: Array[Label] = []
var barras_atributos: Array[ProgressBar] = []
var valores_atributos: Array[Label] = []
var _retratos_slots: Array[TextureRect] = []
var _fundos_slots: Array[TextureRect] = []
var _marcas_slots: Array[Label] = []
var _iniciais_slots: Array[Label] = []
var _individuos_slots: Array[DadosPokemon] = []
var _ficha: PanelContainer
var _elemento: TextureRect
var _caixa_retrato: PanelContainer
var _retrato_area: Control
var _contador: Label
var _rolagem: ScrollContainer
var _arrastando: bool = false
var _offset_arrasto: Vector2
var _centralizar: bool = true
var _nome_animado: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tema: Theme = Theme.new()
	tema.default_font = UI.TEXTO
	tema.default_font_size = 12
	theme = tema
	referencias = JSON.parse_string(FileAccess.get_file_as_string("res://assets/interface/hud/atributos_base.json"))
	var sombra: ColorRect = ColorRect.new()
	sombra.color = Color(0,0,0,0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed and evento.button_index==MOUSE_BUTTON_LEFT:
			hide()
			get_viewport().set_input_as_handled()
	)
	janela = PanelContainer.new()
	janela.mouse_filter = Control.MOUSE_FILTER_STOP
	janela.add_theme_stylebox_override("panel",ESTILO.janela())
	add_child(janela)
	var estrutura: VBoxContainer = VBoxContainer.new()
	estrutura.add_theme_constant_override("separation",0)
	janela.add_child(estrutura)
	_criar_cabecalho(estrutura)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	estrutura.add_child(_rolagem)
	var margens: MarginContainer = MarginContainer.new()
	margens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lado in ["left","right","bottom"]:
		margens.add_theme_constant_override("margin_"+lado,16)
	margens.add_theme_constant_override("margin_top",14)
	_rolagem.add_child(margens)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation",0)
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margens.add_child(corpo)
	_criar_slots()
	_espaco(14)
	_criar_ficha()
	_espaco(14)
	# Reutiliza a API de atualização sem reconstruir os controles da ficha.
	selecionado = EstadoJogo.obter_lider()
	barra_hp = _criar_barra(false,15)
	corpo.add_child(barra_hp)
	_espaco(6)
	barra_xp = _criar_barra(true,12)
	corpo.add_child(barra_xp)
	_espaco(16)
	_criar_atributos()
	_espaco(20)
	evoluir = Button.new()
	evoluir.disabled = true
	evoluir.custom_minimum_size.y = 34
	evoluir.add_theme_font_override("font",UI.FORTE)
	evoluir.add_theme_font_size_override("font_size",12)
	evoluir.add_theme_color_override("font_disabled_color",Color("9aa6b3"))
	evoluir.add_theme_stylebox_override("disabled",UI.caixa(Color("2d4152"),Color("6a5223"),8,6))
	corpo.add_child(evoluir)
	evoluir.add_theme_stylebox_override("normal",UI.caixa(Color("183b27"),Color("78bc58"),8,6))
	evoluir.pressed.connect(func() -> void:
		var erro: String=EstadoJogo.evoluir_pokemon(selecionado)
		if not erro.is_empty(): evoluir.tooltip_text=erro
	)
	EstadoJogo.depot_alterado.connect(_atualizar_se_aberto)
	EstadoJogo.lider_alterado.connect(_atualizar_se_aberto)
	EstadoJogo.individuo_alterado.connect(_individuo_alterado)
	resized.connect(_ajustar)
	visibility_changed.connect(func() -> void:
		if not visible: _arrastando=false
	)
	hide()

func _criar_cabecalho(estrutura: VBoxContainer) -> void:
	var cabecalho: PanelContainer = PanelContainer.new()
	var estilo: StyleBoxFlat = UI.caixa(Color.TRANSPARENT,Color("99753059"),0,16)
	estilo.set_border_width_all(0)
	estilo.border_width_bottom = 1
	estilo.content_margin_top = 11
	estilo.content_margin_bottom = 11
	cabecalho.add_theme_stylebox_override("panel",estilo)
	cabecalho.mouse_filter = Control.MOUSE_FILTER_STOP
	cabecalho.mouse_default_cursor_shape = Control.CURSOR_MOVE
	cabecalho.gui_input.connect(_entrada_cabecalho)
	estrutura.add_child(cabecalho)
	var linha: HBoxContainer = HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override("separation",9)
	cabecalho.add_child(linha)
	var icone: TextureRect = TextureRect.new()
	icone.texture = preload("res://assets/interface/hud/pokemon.png")
	icone.custom_minimum_size = Vector2(20,20)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(icone)
	var titulo: Label = UI.texto("Team",18,Color("f0e6d2"),true)
	titulo.add_theme_font_override("font",UI.TITULO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(titulo)
	_contador = UI.texto("",13,Color("e8c98a"),true)
	linha.add_child(_contador)
	var fechar: Button = Button.new()
	fechar.name = "FecharTeam"
	fechar.flat = true
	fechar.icon = UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><path d="M3 3l12 12M15 3L3 15" fill="none" stroke="#9aa6b3" stroke-width="1.5" stroke-linecap="round"/></svg>')
	fechar.custom_minimum_size = Vector2(23,24)
	fechar.tooltip_text = "Close"
	fechar.pressed.connect(hide)
	linha.add_child(fechar)

func _criar_slots() -> void:
	var linha: HBoxContainer = HBoxContainer.new()
	linha.add_theme_constant_override("separation",8)
	corpo.add_child(linha)
	for indice in range(6):
		var botao: Button = Button.new()
		botao.custom_minimum_size = Vector2(0,76)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.clip_contents = true
		botao.focus_mode = Control.FOCUS_NONE
		linha.add_child(botao)
		slots.append(botao)
		_individuos_slots.append(null)
		var fundo: TextureRect = TextureRect.new()
		fundo.texture = preload("res://assets/interface/hud/pokeball_open_v2.png")
		fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao.add_child(fundo)
		_fundos_slots.append(fundo)
		var retrato: TextureRect = TextureRect.new()
		retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao.add_child(retrato)
		_retratos_slots.append(retrato)
		var marca: Label = UI.texto("⚔",11,Color("ffdf5e"),true)
		marca.add_theme_constant_override("outline_size",1)
		botao.add_child(marca)
		_marcas_slots.append(marca)
		var inicial: Label = UI.texto("🎓",10,Color("e8c98a"))
		inicial.tooltip_text = "Pokémon inicial"
		botao.add_child(inicial)
		_iniciais_slots.append(inicial)
		botao.resized.connect(_posicionar_slot.bind(indice))
		botao.pressed.connect(_selecionar_slot.bind(indice))

func _posicionar_slot(indice: int) -> void:
	var tamanho: Vector2 = slots[indice].size
	_fundos_slots[indice].position = Vector2(tamanho.x*0.06,tamanho.y*0.11)
	_fundos_slots[indice].size = tamanho*0.88
	var retrato: TextureRect = _retratos_slots[indice]
	if retrato.texture!=null:
		# Escala do canvas do cliente: 54px em referência de outfit 64px.
		retrato.size = retrato.texture.get_size()*(minf(54,tamanho.x*0.78)/64.0)
		retrato.position = Vector2((tamanho.x-retrato.size.x)*0.5,tamanho.y*0.82-retrato.size.y)
	_marcas_slots[indice].position = Vector2(maxf(0,tamanho.x-14),1)
	_iniciais_slots[indice].position = Vector2(2,maxf(0,tamanho.y-15))

func _criar_ficha() -> void:
	_ficha = PanelContainer.new()
	_ficha.clip_contents = true
	corpo.add_child(_ficha)
	# Marca d'água original /assets/elements; não substitui a insígnia /types.
	var area_marca: Control = Control.new()
	area_marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ficha.add_child(area_marca)
	_elemento = TextureRect.new()
	_elemento.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_elemento.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_elemento.modulate.a = 0.15
	_elemento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_marca.add_child(_elemento)
	_elemento.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_elemento.offset_left = -114
	_elemento.offset_right = 34
	_elemento.offset_top = -34
	_elemento.offset_bottom = 114
	var detalhes: VBoxContainer = VBoxContainer.new()
	detalhes.add_theme_constant_override("separation",14)
	_ficha.add_child(detalhes)
	var topo: HBoxContainer = HBoxContainer.new()
	topo.add_theme_constant_override("separation",16)
	detalhes.add_child(topo)
	_caixa_retrato = PanelContainer.new()
	_caixa_retrato.custom_minimum_size = Vector2(124,124)
	topo.add_child(_caixa_retrato)
	_retrato_area = Control.new()
	_caixa_retrato.add_child(_retrato_area)
	var fundo_retrato: TextureRect = TextureRect.new()
	fundo_retrato.texture = ESTILO.fundo_retrato()
	fundo_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo_retrato.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato_area.add_child(fundo_retrato)
	retrato_grande = TextureRect.new()
	retrato_grande.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato_grande.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato_grande.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_retrato_area.add_child(retrato_grande)
	_retrato_area.resized.connect(_posicionar_retrato)
	var dados: VBoxContainer = VBoxContainer.new()
	dados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dados.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dados.add_theme_constant_override("separation",5)
	topo.add_child(dados)
	nome_pokemon = UI.texto("",23,Color("e2c88c"),true)
	nome_pokemon.add_theme_font_override("font",ESTILO.NOME)
	nome_pokemon.clip_text = true
	dados.add_child(nome_pokemon)
	var linha: HBoxContainer = HBoxContainer.new()
	linha.add_theme_constant_override("separation",4)
	dados.add_child(linha)
	nivel_pokemon = UI.texto("",12,Color("7fe6dd"),true)
	linha.add_child(nivel_pokemon)
	power_pokemon = UI.texto("",12,Color("f0c040"),true)
	linha.add_child(power_pokemon)
	var tipos: HFlowContainer = HFlowContainer.new()
	tipos.add_theme_constant_override("h_separation",6)
	tipos.add_theme_constant_override("v_separation",5)
	dados.add_child(tipos)
	for indice in range(2):
		var selo: PanelContainer = PanelContainer.new()
		var texto: Label = UI.texto("",10,Color.WHITE,true)
		selo.add_child(texto)
		tipos.add_child(selo)
		selos_tipos.append(selo)
		textos_tipos.append(texto)
	selo_qualidade = PanelContainer.new()
	texto_qualidade = UI.texto("",10,Color("0b1420"),true)
	selo_qualidade.add_child(texto_qualidade)
	tipos.add_child(selo_qualidade)
	invocar = Button.new()
	invocar.custom_minimum_size.y = 40
	invocar.add_theme_font_override("font",UI.FORTE)
	invocar.add_theme_font_size_override("font_size",12)
	invocar.pressed.connect(func() -> void:
		if selecionado!=null and permitir_troca_lider and (not exigir_lider_saudavel or selecionado.obter_vida_atual()>0):
			EstadoJogo.selecionar_lider(selecionado)
	)
	detalhes.add_child(invocar)

func _criar_barra(xp: bool, altura: int) -> ProgressBar:
	var barra: ProgressBar = BARRAS.criar(selecionado,xp,altura)
	barra.add_theme_stylebox_override("background",UI.capsula("fundo",altura))
	barra.add_theme_stylebox_override("fill",UI.capsula("xp" if xp else "hp",altura))
	var texto: Label = barra.get_child(0) as Label
	texto.add_theme_font_override("font",UI.FORTE)
	texto.add_theme_font_size_override("font_size",10)
	texto.add_theme_constant_override("outline_size",1)
	return barra

func _criar_atributos() -> void:
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.add_theme_constant_override("separation",4)
	corpo.add_child(coluna)
	var rotulos: Array[String] = ["HP","Atk","Def","SpA","SpD","Vel"]
	for indice in range(6):
		var linha: HBoxContainer = HBoxContainer.new()
		linha.custom_minimum_size.y = 16
		linha.add_theme_constant_override("separation",10)
		coluna.add_child(linha)
		var rotulo: Label = UI.texto(rotulos[indice],12,Color("b9c3ce"),true)
		rotulo.custom_minimum_size.x = 34
		linha.add_child(rotulo)
		var barra: ProgressBar = ProgressBar.new()
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		barra.custom_minimum_size.y = 10
		barra.show_percentage = false
		barra.add_theme_stylebox_override("background",UI.capsula("fundo",10))
		linha.add_child(barra)
		barras_atributos.append(barra)
		var numero: Label = UI.texto("",12,Color("f0e6d2"),true)
		numero.custom_minimum_size.x = 34
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		linha.add_child(numero)
		valores_atributos.append(numero)

func _espaco(altura: int) -> void:
	var espaco: Control = Control.new()
	espaco.custom_minimum_size.y = altura
	corpo.add_child(espaco)

func abrir() -> void:
	selecionado = EstadoJogo.obter_lider()
	_centralizar = true
	show()
	atualizar()

func _selecionar_slot(indice: int) -> void:
	if indice>=EstadoJogo.time_pokemon.size():
		return
	selecionado = EstadoJogo.time_pokemon[indice]
	atualizar()

func _atualizar_se_aberto() -> void:
	if visible:
		atualizar()

func _individuo_alterado(pokemon: DadosPokemon) -> void:
	if visible and pokemon==selecionado:
		_atualizar_ficha()

func atualizar() -> void:
	if selecionado==null or not EstadoJogo.time_pokemon.has(selecionado):
		selecionado = EstadoJogo.obter_lider()
	_contador.text = "%d/6" % EstadoJogo.time_pokemon.size()
	for indice in range(6):
		var botao: Button = slots[indice]
		var ocupado: bool = indice<EstadoJogo.time_pokemon.size()
		botao.disabled = not ocupado
		_fundos_slots[indice].visible = ocupado
		_retratos_slots[indice].visible = ocupado
		_marcas_slots[indice].visible = false
		_iniciais_slots[indice].visible = false
		botao.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		botao.add_theme_stylebox_override("disabled",UI.caixa(Color("00000044"),Color("ffffff0f"),8,0))
		if not ocupado:
			_individuos_slots[indice] = null
			continue
		var pokemon: DadosPokemon = EstadoJogo.time_pokemon[indice]
		var cor: Color = TIPOS.cor(TIPOS.primario(pokemon))
		var lider: bool = pokemon==EstadoJogo.obter_lider()
		var estilo: StyleBoxFlat = UI.caixa(Color("00000060"),Color("ffdf5e") if lider else (Color("e8c98a") if pokemon==selecionado else Color("99753059")),8,0)
		estilo.border_width_bottom = 2
		if pokemon==selecionado:
			estilo.shadow_color = Color(cor.r,cor.g,cor.b,0.25)
			estilo.shadow_size = 6
		botao.add_theme_stylebox_override("normal",estilo)
		botao.add_theme_stylebox_override("hover",UI.caixa(Color("122a29"),Color("e8c98a"),8,0))
		botao.add_theme_stylebox_override("pressed",estilo)
		botao.tooltip_text = pokemon.especie.nome+(" — Líder" if lider else " — consultar ficha")
		_fundos_slots[indice].modulate.a = 0.95 if pokemon==selecionado else 0.78
		_retratos_slots[indice].texture = VISUAL.retrato_frente(pokemon.especie.nome)
		_individuos_slots[indice] = pokemon
		_marcas_slots[indice].visible = lider
		_iniciais_slots[indice].visible = pokemon==EstadoJogo.pokemon_inicial
		_posicionar_slot(indice)
	_atualizar_ficha()
	call_deferred("_ajustar")

func _atualizar_ficha() -> void:
	var tipo: String = TIPOS.primario(selecionado)
	var cor: Color = TIPOS.cor(tipo)
	_ficha.add_theme_stylebox_override("panel",ESTILO.ficha(cor))
	_elemento.texture = TIPOS.elemento(tipo)
	_elemento.visible = _elemento.texture!=null
	var retrato_estilo: StyleBoxFlat = UI.caixa(Color("101c29"),cor,12,2)
	retrato_estilo.set_border_width_all(2)
	retrato_estilo.shadow_color = Color(cor.r,cor.g,cor.b,0.25)
	retrato_estilo.shadow_size = 9
	_caixa_retrato.add_theme_stylebox_override("panel",retrato_estilo)
	if _nome_animado!=selecionado.especie.nome:
		_nome_animado = selecionado.especie.nome
		quadros_ficha = VISUAL.quadros_frente(_nome_animado)
		tempo_animacao = 0
	if not quadros_ficha.is_empty():
		retrato_grande.texture = quadros_ficha[int(tempo_animacao/0.15)%quadros_ficha.size()]
		_posicionar_retrato()
	nome_pokemon.text = selecionado.especie.nome
	nivel_pokemon.text = "Level %d ·" % selecionado.nivel
	power_pokemon.text = "⚡ %d Power" % selecionado.obter_power()
	var base: Dictionary = referencias.get(selecionado.especie.nome,{})
	for indice in range(2):
		var chave: String = str(base.get("type%d" % (indice+1),""))
		selos_tipos[indice].visible = not chave.is_empty()
		textos_tipos[indice].text = chave
		selos_tipos[indice].add_theme_stylebox_override("panel",ESTILO.selo(TIPOS.cor(chave)))
	var qualidade: Dictionary = ESTILO.qualidade(selecionado.qualidade)
	selo_qualidade.add_theme_stylebox_override("panel",ESTILO.selo(qualidade["cor"],true))
	texto_qualidade.text = "%s ×%.2f" % [str(qualidade["nome"]).to_upper(),selecionado.qualidade]
	selo_qualidade.tooltip_text = "Quality %.3f · IV %d/192\nHP %d · Atk %d · Def %d · SpA %d · SpD %d · Vel %d" % [selecionado.qualidade,selecionado.obter_total_ivs(),selecionado.iv_hp,selecionado.iv_atk,selecionado.iv_def,selecionado.iv_sp_atk,selecionado.iv_sp_def,selecionado.iv_spd]
	_atualizar_acao_invocar()
	var acao: StyleBoxFlat = UI.caixa(Color("0c1d17"),cor,21,8)
	acao.shadow_color = Color(cor.r,cor.g,cor.b,0.18)
	acao.shadow_size = 8
	invocar.add_theme_stylebox_override("normal",acao)
	invocar.add_theme_stylebox_override("disabled",acao)
	invocar.add_theme_stylebox_override("hover",UI.caixa(Color("1b3028"),cor.lightened(0.2),21,8))
	invocar.add_theme_color_override("font_disabled_color",Color.WHITE.lerp(cor,0.22))
	BARRAS.atualizar(barra_hp,selecionado,false)
	BARRAS.atualizar(barra_xp,selecionado,true)
	var proporcao: float = float(selecionado.obter_vida_atual())/maxi(1,selecionado.obter_vida_maxima())
	barra_hp.add_theme_stylebox_override("fill",UI.capsula("critico" if proporcao<=0.2 else ("baixo" if proporcao<=0.5 else "hp"),15))
	var atributos: Dictionary = selecionado.obter_atributos()
	var maximo: float = maxf(1,float(atributos.values().max())) if not atributos.is_empty() else 1.0
	for indice in range(6):
		var valor: int = int(atributos.get(CHAVES[indice],0))
		barras_atributos[indice].max_value = maximo
		barras_atributos[indice].value = valor
		valores_atributos[indice].text = str(valor)
		var fill: StyleBoxFlat = UI.caixa(ESTILO.cor_atributo(float(valor)/maximo),Color.TRANSPARENT,4,0)
		fill.set_border_width_all(0)
		barras_atributos[indice].add_theme_stylebox_override("fill",fill)
	var evolucao: Dictionary = EVOLUCOES.get(selecionado.especie.nome,{})
	evoluir.visible = not evolucao.is_empty()
	evoluir.text = "↑ Evolve to %s · Lv.%d" % [evolucao.get("nome",""),int(evolucao.get("nivel",1))]
	evoluir.tooltip_text=EstadoJogo.validar_evolucao(selecionado)
	evoluir.disabled=not evoluir.tooltip_text.is_empty()

func _posicionar_retrato() -> void:
	if retrato_grande.texture==null:
		return
	# Mantém a escala de outfit do original, em vez de ampliar o corpo até 124px.
	retrato_grande.size = retrato_grande.texture.get_size()*(84.0/64.0)
	retrato_grande.position = ((_retrato_area.size-retrato_grande.size)*0.5).floor()

func _ajustar() -> void:
	if janela==null:
		return
	janela.size = Vector2(minf(533,maxf(280,size.x-32)),minf(620,maxf(160,size.y-32)))
	if _centralizar:
		janela.position = ((size-janela.size)*0.5).floor()
	janela.position = janela.position.clamp(Vector2(8,8),(size-janela.size-Vector2(8,8)).max(Vector2(8,8)))

func _entrada_cabecalho(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index==MOUSE_BUTTON_LEFT:
		_arrastando = evento.pressed
		if _arrastando:
			_centralizar = false
			_offset_arrasto = evento.global_position-janela.position

func _input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
	elif _arrastando and evento is InputEventMouseMotion:
		janela.position = (evento.global_position-_offset_arrasto).clamp(Vector2(8,8),(size-janela.size-Vector2(8,8)).max(Vector2(8,8)))
	elif evento is InputEventMouseButton and not evento.pressed:
		_arrastando = false

func _process(delta: float) -> void:
	if visible: _atualizar_acao_invocar()
	if not visible or quadros_ficha.is_empty():
		return
	var antes: int = int(tempo_animacao/0.15)%quadros_ficha.size()
	tempo_animacao += delta
	var depois: int = int(tempo_animacao/0.15)%quadros_ficha.size()
	if antes!=depois:
		retrato_grande.texture = quadros_ficha[depois]
		_posicionar_retrato()

func _atualizar_acao_invocar() -> void:
	if selecionado==null or invocar==null:return
	var ativo: bool=selecionado==EstadoJogo.obter_lider()
	var sem_hp: bool=exigir_lider_saudavel and selecionado.obter_vida_atual()<=0
	var restante: float=float(provedor_cooldown.call()) if provedor_cooldown.is_valid() else 0.0
	invocar.disabled=ativo or not permitir_troca_lider or sem_hp or restante>0
	if ativo:invocar.text="⚔ Active — the Pokémon that hunts"
	elif sem_hp:invocar.text="No HP — heal this Pokémon first"
	elif not permitir_troca_lider:invocar.text="Return to the city to change leader"
	elif restante>0:invocar.text="Switch available in %d s" % ceili(restante)
	else:invocar.text="⚔ Summon — use in hunt"
