extends Control

# Composição .ah-modal do cliente: janela central de 236px, overlay e chips.
# Interface configura os mesmos métodos públicos; nenhum consumo ocorre aqui.
@export var mostrar_botao_abrir: bool = true
const UI: Script = preload("res://estilo_ui_fiel.gd")
const ICONES: Dictionary[int,String] = {1:"pokeball",2:"greatball",3:"superball",4:"ultraball",6:"idleball",7:"idleball_gold"}
var janela: PanelContainer
var ativar_pocao: CheckBox
var ativar_captura: CheckBox
var ativar_shiny: CheckBox
var seletor_pocao: OptionButton
var seletor_limite: OptionButton
var resumo_pocao: Label
var nomes: LineEdit
var resumo: Label
var botoes_bolas: Dictionary[int,Button] = {}
var _sombra: ColorRect
var _rolagem: ScrollContainer
var _conteudo: VBoxContainer
var _pocoes: PanelContainer
var _bolas: PanelContainer
var _filtro: PanelContainer
var _grade: HFlowContainer
var _camada: CanvasLayer
var _centralizar: bool = true
var _arrastando: bool = false
var _offset_arrasto: Vector2
var _checkbox_on: Texture2D
var _checkbox_off: Texture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_checkbox_on = UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14"><rect x=".5" y=".5" width="13" height="13" rx="3" fill="#4ec24a"/><path d="M3.4 7l2.4 2.4 4.8-5" fill="none" stroke="#153516" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>')
	_checkbox_off = UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14"><rect x=".5" y=".5" width="13" height="13" rx="3" fill="#101821" stroke="#687582"/></svg>')
	var abrir: Button = Button.new()
	preload("res://estilo_depot_fiel.gd").aplicar_auto_helper(abrir)
	abrir.visible = mostrar_botao_abrir
	abrir.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	abrir.position = Vector2(-206,66)
	abrir.size = Vector2(190,34)
	add_child(abrir)
	abrir.pressed.connect(_alternar_painel)
	# Camada própria preserva os acessos existentes a janela.hide()/visible.
	_camada = CanvasLayer.new()
	_camada.layer = 70
	_camada.name = "ModalAutoHelper"
	add_child(_camada)
	var tela: Control = Control.new()
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(tela)
	_sombra = ColorRect.new()
	_sombra.color = Color(0,0,0,0.6)
	_sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sombra.mouse_filter = Control.MOUSE_FILTER_STOP
	tela.add_child(_sombra)
	_sombra.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed and evento.button_index==MOUSE_BUTTON_LEFT:
			janela.hide()
			get_viewport().set_input_as_handled()
	)
	janela = PanelContainer.new()
	janela.custom_minimum_size.x = 236
	janela.mouse_filter = Control.MOUSE_FILTER_STOP
	var caixa: StyleBoxFlat = UI.caixa(Color("0c121bfc"),Color("785a28"),10,2)
	caixa.set_border_width_all(2)
	caixa.shadow_color = Color(0,0,0,0.45)
	caixa.shadow_size = 20
	caixa.shadow_offset = Vector2(0,10)
	janela.add_theme_stylebox_override("panel",caixa)
	var tema: Theme = Theme.new()
	tema.default_font = UI.TEXTO
	tema.default_font_size = 11
	janela.theme = tema
	tela.add_child(janela)
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.add_theme_constant_override("separation",0)
	janela.add_child(coluna)
	var cabecalho: PanelContainer = PanelContainer.new()
	var estilo_topo: StyleBoxFlat = UI.caixa(Color("101823"),Color("9975304d"),0,12)
	estilo_topo.set_border_width_all(0)
	estilo_topo.border_width_bottom = 1
	estilo_topo.content_margin_top = 8
	estilo_topo.content_margin_bottom = 8
	cabecalho.add_theme_stylebox_override("panel",estilo_topo)
	cabecalho.mouse_default_cursor_shape = Control.CURSOR_MOVE
	cabecalho.mouse_filter = Control.MOUSE_FILTER_STOP
	cabecalho.gui_input.connect(_entrada_cabecalho)
	coluna.add_child(cabecalho)
	var topo: HBoxContainer = HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_theme_constant_override("separation",6)
	cabecalho.add_child(topo)
	var engrenagem: TextureRect = TextureRect.new()
	engrenagem.texture = UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"><path fill="#d5d8dc" d="M19.4 13a7 7 0 000-2l2-1.5-2-3.5-2.4 1a8 8 0 00-1.7-1L15 3h-4l-.4 2.5a8 8 0 00-1.7 1l-2.4-1-2 3.5 2 1.5a7 7 0 000 2l-2 1.5 2 3.5 2.4-1a8 8 0 001.7 1L11 21h4l.4-2.5a8 8 0 001.7-1l2.4 1 2-3.5z"/><circle cx="13" cy="12" r="3.3" fill="#101823"/></svg>')
	engrenagem.custom_minimum_size = Vector2(16,16)
	engrenagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	engrenagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	engrenagem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	engrenagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_child(engrenagem)
	var titulo: Label = UI.texto("Auto-Helper",15,Color("f0e6d2"),true)
	titulo.add_theme_font_override("font",UI.TITULO)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(titulo)
	var fechar: Button = Button.new()
	fechar.flat = true
	fechar.icon = UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18"><path d="M2 2l14 14M16 2L2 16" fill="none" stroke="#9aa6b3" stroke-width="1.5" stroke-linecap="round"/></svg>')
	fechar.custom_minimum_size = Vector2(20,22)
	fechar.tooltip_text = "Close"
	fechar.pressed.connect(janela.hide)
	topo.add_child(fechar)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(_rolagem)
	var margens: MarginContainer = MarginContainer.new()
	for lado in ["left","right","top","bottom"]:
		margens.add_theme_constant_override("margin_"+lado,12 if lado in ["left","right","bottom"] else 10)
	margens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rolagem.add_child(margens)
	_conteudo = VBoxContainer.new()
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conteudo.add_theme_constant_override("separation",7)
	margens.add_child(_conteudo)
	ativar_pocao = _criar_linha("Auto-Potion","", "res://assets/interface/pocoes/ultimate_potion.png",false)
	ativar_pocao.toggled.connect(_on_auto_potion_toggled)
	_pocoes = _subsecao()
	var linhas: VBoxContainer = VBoxContainer.new()
	linhas.add_theme_constant_override("separation",6)
	_pocoes.add_child(linhas)
	var linha: HBoxContainer = HBoxContainer.new()
	linhas.add_child(linha)
	linha.add_child(UI.texto("Potion:"))
	seletor_pocao = _seletor()
	seletor_pocao.custom_minimum_size.x = 130
	seletor_pocao.size_flags_horizontal = Control.SIZE_SHRINK_END
	linha.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seletor_pocao.add_item("Automatic (best)",0)
	for dados in EstadoJogo.CATALOGO_POCOES:
		seletor_pocao.add_item(str(dados["nome"]),int(dados["id"]))
	linha.add_child(seletor_pocao)
	seletor_pocao.item_selected.connect(_on_pocao_selecionada)
	linha = HBoxContainer.new()
	linhas.add_child(linha)
	linha.add_child(UI.texto("Heal when HP ≤"))
	seletor_limite = _seletor()
	seletor_limite.custom_minimum_size.x = 108
	seletor_limite.size_flags_horizontal = Control.SIZE_SHRINK_END
	linha.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for percentual in EstadoJogo.LIMITES_AUTO_POTION:
		seletor_limite.add_item(str(percentual)+"%",percentual)
	linha.add_child(seletor_limite)
	seletor_limite.item_selected.connect(_on_limite_selecionado)
	# Mensagens de estado preservadas como tooltip para não alongar a janela.
	resumo_pocao = Label.new()
	resumo_pocao.hide()
	add_child(resumo_pocao)
	ativar_captura = _criar_linha("Auto-\nCatch","Normal\nPokémon","res://assets/interface/bolas/pokeball.png",true)
	ativar_captura.toggled.connect(_on_auto_catch_toggled)
	_bolas = _subsecao()
	var bola_coluna: VBoxContainer = VBoxContainer.new()
	bola_coluna.add_theme_constant_override("separation",4)
	_bolas.add_child(bola_coluna)
	bola_coluna.add_child(UI.texto("Pokéball:"))
	_grade = HFlowContainer.new()
	_grade.add_theme_constant_override("h_separation",5)
	_grade.add_theme_constant_override("v_separation",5)
	bola_coluna.add_child(_grade)
	var grupo: ButtonGroup = ButtonGroup.new()
	for dados in EstadoJogo.CATALOGO_BOLAS:
		var id: int = int(dados["id"])
		if not ICONES.has(id):
			continue
		var botao: Button = Button.new()
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.add_theme_font_override("font",UI.FORTE)
		botao.add_theme_font_size_override("font_size",13)
		botao.add_theme_color_override("font_color",Color("cfd8e2"))
		botao.add_theme_stylebox_override("normal",UI.caixa(Color("ffffff0a"),Color("3a4a5c"),16,4))
		botao.add_theme_stylebox_override("hover",UI.caixa(Color("ffffff12"),Color("c8aa6e"),16,4))
		botao.add_theme_stylebox_override("pressed",UI.caixa(Color("c8aa6e2e"),Color("c8aa6e"),16,4))
		botao.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		var caminho: String = "res://assets/interface/bolas/"+ICONES[id]+".png"
		if not ResourceLoader.exists(caminho):
			caminho = "res://assets/interface/depot/"+ICONES[id]+".png"
		if ResourceLoader.exists(caminho):
			botao.icon = load(caminho)
		elif id == 7:
			# O ícone de inventário dourado não foi extraído. Usa um quadro
			# da textura dourada original que já acompanha este projeto.
			var dourada: AtlasTexture = AtlasTexture.new()
			dourada.atlas = preload("res://assets/efeitos/captura/throw/idleball_gold.png")
			dourada.region = Rect2(0,0,16,16)
			botao.icon = dourada
		botao.expand_icon = true
		botao.add_theme_constant_override("icon_max_width",22)
		botao.custom_minimum_size = Vector2(0,30)
		_grade.add_child(botao)
		botoes_bolas[id] = botao
		botao.pressed.connect(_on_bola_pressed.bind(id))
	resumo = UI.texto("",10,Color("f7c54a"))
	resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bola_coluna.add_child(resumo)
	ativar_shiny = _criar_linha("Auto-Catch\nShiny","Shiny\nPokémon","res://assets/interface/bolas/idleball.png",true)
	ativar_shiny.disabled = true
	ativar_shiny.tooltip_text = "Captura de shinies ainda não implementada neste protótipo."
	_filtro = _subsecao()
	var filtro_coluna: VBoxContainer = VBoxContainer.new()
	filtro_coluna.add_theme_constant_override("separation",4)
	_filtro.add_child(filtro_coluna)
	filtro_coluna.add_child(UI.texto("Names (comma-separated):"))
	nomes = LineEdit.new()
	nomes.placeholder_text = "e.g.: charizard, gyarados"
	nomes.add_theme_font_override("font",UI.TEXTO)
	nomes.add_theme_font_size_override("font_size",11)
	nomes.add_theme_color_override("font_color",Color("f0e6d2"))
	nomes.add_theme_color_override("font_placeholder_color",Color("5b6577"))
	nomes.add_theme_stylebox_override("normal",UI.caixa(Color("0a0f16"),Color("6a5223"),6,5))
	nomes.add_theme_stylebox_override("focus",UI.caixa(Color("0a0f16"),Color("c8aa6e"),6,5))
	nomes.custom_minimum_size.y = 25
	filtro_coluna.add_child(nomes)
	nomes.text_changed.connect(_on_nomes_text_changed)
	var dica: Label = UI.texto("Empty field = catch all. The filter applies to\nboth modes.",10,Color("9aa6b3"))
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.tooltip_text = "Nesta versão o filtro é aplicado ao Auto-Catch normal."
	filtro_coluna.add_child(dica)
	EstadoJogo.estoque_bolas_alterado.connect(atualizar)
	EstadoJogo.auto_catch_alterado.connect(atualizar)
	EstadoJogo.estoque_pocoes_alterado.connect(_atualizar_pocoes)
	EstadoJogo.auto_potion_alterado.connect(_atualizar_pocoes)
	_conteudo.minimum_size_changed.connect(func() -> void: call_deferred("_ajustar_tamanho"))
	janela.visibility_changed.connect(_sincronizar_overlay)
	resized.connect(_ajustar_tamanho)
	atualizar()
	_atualizar_pocoes()
	janela.hide()
	_sincronizar_overlay()

func _subsecao() -> PanelContainer:
	var painel: PanelContainer = PanelContainer.new()
	painel.add_theme_stylebox_override("panel",UI.caixa(Color("00000047"),Color("99753047"),8,8))
	_conteudo.add_child(painel)
	return painel

func _criar_linha(titulo: String, dica: String, caminho: String, duas_linhas: bool) -> CheckBox:
	var controle: CheckBox = CheckBox.new()
	controle.custom_minimum_size.y = 42 if duas_linhas else 34
	controle.add_theme_icon_override("checked",_checkbox_on)
	controle.add_theme_icon_override("unchecked",_checkbox_off)
	controle.add_theme_icon_override("checked_disabled",_checkbox_on)
	controle.add_theme_icon_override("unchecked_disabled",_checkbox_off)
	controle.add_theme_stylebox_override("normal",UI.caixa(Color("ffffff08"),Color("99753047"),8,8))
	controle.add_theme_stylebox_override("pressed",UI.caixa(Color("4ec24a1f"),Color("4ec24a"),8,8))
	controle.add_theme_stylebox_override("hover",UI.caixa(Color("ffffff12"),Color("c8aa6e80"),8,8))
	controle.add_theme_stylebox_override("hover_pressed",UI.caixa(Color("4ec24a1f"),Color("4ec24a"),8,8))
	controle.add_theme_stylebox_override("disabled",UI.caixa(Color("ffffff08"),Color("99753047"),8,8))
	controle.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	_conteudo.add_child(controle)
	var linha: HBoxContainer = HBoxContainer.new()
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 36
	linha.offset_right = -8
	linha.add_theme_constant_override("separation",6)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controle.add_child(linha)
	var icone: TextureRect = TextureRect.new()
	if ResourceLoader.exists(caminho):
		icone.texture = load(caminho)
	icone.custom_minimum_size = Vector2(20,20)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(icone)
	var nome: Label = UI.texto(titulo,12,Color("eaf0f6"),true)
	nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(nome)
	if not dica.is_empty():
		var hint: Label = UI.texto(dica,10,Color("8a93a0"))
		hint.custom_minimum_size.x = 73
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha.add_child(hint)
	return controle

func _seletor() -> OptionButton:
	var seletor: OptionButton = OptionButton.new()
	seletor.fit_to_longest_item = false
	seletor.clip_text = true
	seletor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seletor.add_theme_font_override("font",UI.TEXTO)
	seletor.add_theme_font_size_override("font_size",11)
	seletor.add_theme_color_override("font_color",Color("f0e6d2"))
	seletor.add_theme_stylebox_override("normal",UI.caixa(Color("0a0f16"),Color("6a5223"),6,5))
	seletor.add_theme_stylebox_override("hover",UI.caixa(Color("0a0f16"),Color("c8aa6e"),6,5))
	seletor.add_theme_stylebox_override("focus",UI.caixa(Color("0a0f16"),Color("c8aa6e"),6,5))
	seletor.add_theme_icon_override("arrow",UI.icone_svg('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><path d="M1 2.5l3 3 3-3" fill="none" stroke="#b9c3ce" stroke-width="1"/></svg>'))
	seletor.custom_minimum_size.y = 23
	var popup: PopupMenu = seletor.get_popup()
	popup.add_theme_font_override("font",UI.TEXTO)
	popup.add_theme_font_size_override("font_size",12)
	popup.add_theme_stylebox_override("panel",UI.caixa(Color("0c141f"),Color("6a5223"),6,5))
	return seletor

func _quantidade(valor: int) -> String:
	var bruto: String = str(valor)
	var resultado: String = ""
	for i in range(bruto.length()):
		if i>0 and (bruto.length()-i)%3==0:
			resultado += "."
		resultado += bruto[i]
	return resultado

func atualizar() -> void:
	# 2b.6 (desempenho): cada tentativa de auto-catch chama isto; só o que mudou é reaplicado e o reajuste de tamanho
	# só é agendado quando algo visível mudou (antes: texto, tamanho e layout de todos os botões a cada abate).
	var mudou: bool = false
	ativar_captura.set_pressed_no_signal(EstadoJogo.auto_catch)
	if nomes.text != EstadoJogo.auto_catch_names:
		nomes.text = EstadoJogo.auto_catch_names
	for id in botoes_bolas:
		var botao: Button = botoes_bolas[id]
		var dados: Dictionary = EstadoJogo.obter_dados_bola(id)
		var quantidade: int = EstadoJogo.obter_quantidade_bola(id)
		var estoque: String = "∞" if bool(dados["infinita"]) and quantidade>0 else _quantidade(quantidade)
		if botao.text != estoque:
			botao.text = estoque
			botao.custom_minimum_size.x = ceilf(UI.FORTE.get_string_size(estoque,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)+42
			botao.tooltip_text = str(dados["nome"])+" — "+estoque
			mudou = true
		# O cliente mostra somente o estoque disponível, sem perder a seleção salva.
		if botao.visible != (quantidade>0):
			botao.visible = quantidade>0
			mudou = true
		botao.disabled = quantidade<=0
		botao.set_pressed_no_signal(id==EstadoJogo.auto_catch_ball_id)
	if _bolas.visible != EstadoJogo.auto_catch:
		mudou = true
	_bolas.visible = EstadoJogo.auto_catch
	_filtro.visible = EstadoJogo.auto_catch
	var sem_bola: bool = EstadoJogo.obter_quantidade_bola(EstadoJogo.auto_catch_ball_id)<=0
	if resumo.visible != (EstadoJogo.auto_catch and sem_bola):
		mudou = true
	resumo.visible = EstadoJogo.auto_catch and sem_bola
	resumo.text = "⚠ You no longer have the configured Poké\nBall — pick another one below."
	if mudou:
		call_deferred("_ajustar_tamanho")

func _atualizar_pocoes() -> void:
	ativar_pocao.set_pressed_no_signal(EstadoJogo.auto_potion)
	_pocoes.visible = EstadoJogo.auto_potion
	for indice in range(seletor_pocao.item_count):
		var id: int = seletor_pocao.get_item_id(indice)
		if id!=0:
			seletor_pocao.set_item_text(indice,str(EstadoJogo.obter_dados_pocao(id)["nome"])+" ×"+_quantidade(EstadoJogo.obter_quantidade_pocao(id)))
		if id==EstadoJogo.auto_potion_item_id:
			seletor_pocao.select(indice)
	for indice in range(seletor_limite.item_count):
		if seletor_limite.get_item_id(indice)==EstadoJogo.auto_potion_threshold:
			seletor_limite.select(indice)
	var id: int = EstadoJogo.escolher_pocao_auto_potion()
	resumo_pocao.text = "Cura automática desligada." if not EstadoJogo.auto_potion else ("Sem estoque da poção configurada." if id<0 else str(EstadoJogo.obter_dados_pocao(id)["nome"])+": até "+str(EstadoJogo.obter_dados_pocao(id)["cura"])+" HP por uso.")
	seletor_pocao.tooltip_text = resumo_pocao.text+" Automático prioriza a maior cura disponível."
	call_deferred("_ajustar_tamanho")

func _alternar_painel() -> void:
	janela.visible = not janela.visible
	if janela.visible:
		_centralizar = true
		atualizar()
		_atualizar_pocoes()
		call_deferred("_ajustar_tamanho")

func _sincronizar_overlay() -> void:
	_sombra.visible = janela.visible
	if not janela.visible:
		_arrastando = false
	else:
		_ajustar_tamanho()

func _ajustar_tamanho() -> void:
	if not is_instance_valid(janela):
		return
	# Espera o mínimo dos controles, incluindo as quebras dos chips e subtítulos.
	var altura_corpo: float = _conteudo.get_combined_minimum_size().y+22
	var altura_visivel: float = minf(altura_corpo,maxf(50,size.y-96))
	_rolagem.custom_minimum_size.y = altura_visivel
	janela.size = Vector2(236,altura_visivel+46)
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
	if not is_instance_valid(janela) or not janela.visible:
		return
	if evento.is_action_pressed("ui_cancel"):
		janela.hide()
		get_viewport().set_input_as_handled()
	elif _arrastando and evento is InputEventMouseMotion:
		janela.position = (evento.global_position-_offset_arrasto).clamp(Vector2(8,8),(size-janela.size-Vector2(8,8)).max(Vector2(8,8)))
	elif evento is InputEventMouseButton and not evento.pressed:
		_arrastando = false

func _on_auto_catch_toggled(ativo: bool) -> void:
	EstadoJogo.definir_auto_catch(ativo)
func _on_bola_pressed(id: int) -> void:
	EstadoJogo.selecionar_bola_auto_catch(id)
func _on_nomes_text_changed(texto: String) -> void:
	EstadoJogo.definir_nomes_auto_catch(texto)
func _on_auto_potion_toggled(ativo: bool) -> void:
	EstadoJogo.definir_auto_potion(ativo)
func _on_pocao_selecionada(indice: int) -> void:
	EstadoJogo.selecionar_pocao_auto_potion(seletor_pocao.get_item_id(indice))
func _on_limite_selecionado(indice: int) -> void:
	EstadoJogo.definir_limite_auto_potion(seletor_limite.get_item_id(indice))
