extends Control
# Alterações visuais da cidade: Área real da janela; HUD no CanvasLayer acima do mundo e abaixo dos modais.

# Alteração: cenário original de Cerulean e menu superior funcional.
# Mantidos os nomes e caminhos já usados pela cidade e pelo mapa.
const TREINADOR_CIDADE: Script = preload("res://treinador_cidade.gd")

const CENARIO_CIDADE: Script = preload("res://cenario_cidade.gd")
const PAINEL_AUTO_HELPER: Script = preload("res://painel_auto_helper.gd")

@export_range(0.5, 2.0, 0.05) var zoom_cidade: float = 1.0
@export var centro_cidade: Vector2 = Vector2(-32.0, -192.0)

@onready var resumo_depot: Label = get_node("VBoxContainer/ResumoDepot")
@onready var mapa_mundi: Control = get_node("Interface/MapaMundi")
# Novo: até seis posições visuais; seguidor permanece como referência ao primeiro.
var seguidores: Array[Node2D] = []
var _sincronizacao_seguidores_pendente: bool = false
var seguidor: Node2D
var painel_time: PanelContainer
var personagem: Node2D
var cenario: Node2D
var painel_auto_helper: Control
var painel_my_pokes: Control
# Novo: posição confirmada no HAR /api/game/city-npcs?slug=cerulean.
const CELULA_NURSE: Vector2i = Vector2i(-3,-10)
var painel_pokepedia: Control
var painel_nurse: Control
var placa_nurse: PlacaInteracao
var placa_depot: PlacaInteracao
var botao_nurse: Button
var resultado_cura: Label
var timer_resultado_cura: Timer
var painel_depot: Control
var botao_depot: Button
const CELULA_DEPOT: Vector2i = Vector2i(-8, -14)
# Fase 4: Mark (loja), posição do city-npcs de Cerulean (npc_shop_22_8, A).
const CELULA_LOJA: Vector2i = Vector2i(22, 8)
var painel_loja: Control
var placa_loja: PlacaInteracao
var painel_config: PanelContainer
var painel_streak: Control
var painel_diarias: Control
var painel_soneca: Control
var rotulo_ouro: Label
# 0 = cidade inteira. Mantém placas e ações disponíveis à distância, como
# solicitado. Um raio positivo pode ser configurado posteriormente no Inspector.
@export_range(0,4096,32) var alcance_interacao_cidade: float = 0.0

func _ready() -> void:
	# Alteração: usa a área real da janela, inclusive em 1920x1080.
	preload("res://tela_jogo.gd").aplicar(get_window())
	cenario = CENARIO_CIDADE.new()
	cenario.name = "CenarioCidade"
	cenario.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(cenario)
	move_child(cenario, 0)
	EstadoJogo.iniciar_depot()
	_atualizar_resumo_depot()
	EstadoJogo.depot_alterado.connect(_atualizar_resumo_depot)
	# Novo: contorno mantém os textos legíveis sobre o cenário.
	for nome in ["Titulo", "ResumoDepot"]:
		var legenda: Label = get_node("VBoxContainer/" + nome)
		legenda.add_theme_color_override("font_outline_color", Color.BLACK)
		legenda.add_theme_constant_override("outline_size", 5)
	_criar_menu()
	painel_auto_helper = PAINEL_AUTO_HELPER.new()
	painel_auto_helper.name = "AutoHelper"
	painel_auto_helper.mostrar_botao_abrir = false
	get_node("Interface").add_child(painel_auto_helper)
	painel_depot = load("res://painel_depot.gd").new()
	painel_depot.name = "PainelDepot"
	get_node("Interface").add_child(painel_depot)
	# Novo: janela TEAM é independente do HUD permanente.
	painel_my_pokes = load("res://painel_my_pokes.gd").new()
	painel_my_pokes.name = "MyPokes"
	get_node("Interface").add_child(painel_my_pokes)
	# Novo: Pokepedia local consulta dados sem tocar no Pokémon ativo.
	painel_pokepedia = load("res://painel_pokepedia.gd").new()
	painel_pokepedia.name = "PokepediaLocal"
	get_node("Interface").add_child(painel_pokepedia)
	painel_nurse = load("res://painel_nurse_joy.gd").new()
	painel_nurse.name = "NurseJoy"
	get_node("Interface").add_child(painel_nurse)
	painel_nurse.cura_solicitada.connect(_confirmar_cura_nurse)
	placa_nurse = PlacaInteracao.new()
	get_node("Interface").add_child(placa_nurse)
	placa_nurse.configurar("Nurse Joy","Talk")
	botao_nurse = placa_nurse.botao
	botao_nurse.pressed.connect(_clicar_nurse)
	resultado_cura = Label.new()
	resultado_cura.add_theme_color_override("font_color",Color("8bf07a"))
	resultado_cura.add_theme_color_override("font_outline_color",Color.BLACK)
	resultado_cura.add_theme_constant_override("outline_size",4)
	resultado_cura.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_node("Interface").add_child(resultado_cura)
	timer_resultado_cura = Timer.new()
	timer_resultado_cura.one_shot = true
	timer_resultado_cura.wait_time = 3.0
	timer_resultado_cura.timeout.connect(resultado_cura.hide)
	add_child(timer_resultado_cura)
	placa_depot = PlacaInteracao.new()
	get_node("Interface").add_child(placa_depot)
	placa_depot.configurar("Depot","Open Depot")
	botao_depot = placa_depot.botao
	botao_depot.pressed.connect(_clicar_depot)
	painel_loja = load("res://painel_loja.gd").new()
	painel_loja.name = "PainelLoja"
	get_node("Interface").add_child(painel_loja)
	placa_loja = PlacaInteracao.new()
	get_node("Interface").add_child(placa_loja)
	placa_loja.configurar("Mark","Open Shop")
	placa_loja.botao.pressed.connect(_clicar_loja)
	_criar_ouro_e_config()
	resized.connect(_ajustar_cenario)
	# Novo: personagem animado independente do controlador de caça.
	personagem = TREINADOR_CIDADE.new()
	personagem.name = "Treinador"
	cenario.adicionar_treinador(personagem)
	personagem.iniciar(cenario)
	# Novo: imagem original do NPC, na mesma camada com Y-sort do treinador.
	var nurse: Sprite2D = Sprite2D.new()
	nurse.name = "ImagemNurseJoy"
	nurse.texture = preload("res://assets/interface/hud/nurse.png")
	nurse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	nurse.position = Vector2(CELULA_NURSE)*32.0+Vector2(16,16)
	# styleNpc do cliente: anchor(.5, 1-11.52/altura). O -16 em X
	# deslocava a Nurse para o lado. Conserva a célula original (-3,-10).
	nurse.offset = Vector2(0,11.52-float(nurse.texture.get_height())*0.5)
	cenario.adicionar_treinador(nurse)
	cenario.atualizar_cobertura(personagem.position, true)
	var ajuda: Label = Label.new()
	ajuda.text = "WASD: caminhar  |  Clique para interagir  |  Esc: fechar painel"
	ajuda.add_theme_color_override("font_outline_color", Color.BLACK)
	ajuda.add_theme_constant_override("outline_size", 5)
	get_node("VBoxContainer").add_child(ajuda)
	# Novo: HUD fica abaixo dos painéis modais e acima do cenário.
	painel_time = load("res://painel_time.gd").new()
	painel_time.name = "PainelTime"
	# Alteração: HUD em CanvasLayer, sobre o mundo e abaixo dos modais.
	get_node("Interface").add_child(painel_time)
	get_node("Interface").move_child(painel_time,0)
	# Novo: usa a mesma camada ordenada do treinador para respeitar objetos/telhados.
	_sincronizar_seguidores()
	EstadoJogo.depot_alterado.connect(_agendar_sincronizacao_seguidores)
	EstadoJogo.lider_alterado.connect(_agendar_sincronizacao_seguidores)
	# Alteração: resumo antigo permanece conectado, mas o HUD assume sua apresentação.
	get_node("VBoxContainer").hide()
	# Placas ficam antes dos controles também na ordem de entrada do mouse.
	get_node("Interface").move_child(placa_nurse,0)
	get_node("Interface").move_child(placa_depot,0)
	get_node("Interface").move_child(placa_loja,0)
	_ajustar_cenario()

func _ajustar_cenario() -> void:
	if cenario == null:
		return
	cenario.scale = Vector2.ONE * zoom_cidade
	# Alteração: câmera segue o treinador sem mover os controles.
	var centro: Vector2 = personagem.position if personagem != null else centro_cidade
	cenario.position = size * 0.5 - centro * zoom_cidade

func _criar_menu() -> void:
	# Alteração: substitui a faixa provisória pelo dock com ícones originais.
	var menu: Control = load("res://menu_superior_original.gd").new()
	menu.name = "MenuSuperior"
	get_node("Interface").add_child(menu)
	get_node("Interface").move_child(menu,0)
	menu.pokepedia_solicitada.connect(_abrir_pokepedia)
	menu.mapa_solicitado.connect(_on_botao_cacar_pressed)
	menu.auto_helper_solicitado.connect(_abrir_auto_helper)
	menu.time_solicitado.connect(_abrir_my_pokes)
	menu.cidade_solicitada.connect(func() -> void:
		mapa_mundi.hide()
		painel_auto_helper.janela.hide()
		painel_my_pokes.hide()
		painel_nurse.hide()
		painel_pokepedia.hide()
		painel_depot.fechar()
	)

func _adicionar_botao(linha: HBoxContainer, texto: String, icone: String, acao: Callable) -> void:
	var botao: Button = Button.new()
	botao.text = texto
	botao.tooltip_text = texto
	botao.icon = load("res://assets/interface/cidade/" + icone + ".png")
	botao.expand_icon = true
	botao.add_theme_constant_override("icon_max_width", 28)
	botao.custom_minimum_size = Vector2(160.0, 40.0)
	linha.add_child(botao)
	botao.pressed.connect(acao)

func _on_botao_cacar_pressed() -> void:
	painel_nurse.hide()
	painel_pokepedia.hide()
	painel_my_pokes.hide()
	# Novo: um painel por vez; mantém a cena da cidade carregada.
	if painel_auto_helper != null:
		painel_auto_helper.janela.hide()
	painel_depot.fechar()
	mapa_mundi.show()

func _abrir_auto_helper() -> void:
	painel_nurse.hide()
	painel_pokepedia.hide()
	painel_my_pokes.hide()
	painel_depot.fechar()
	mapa_mundi.hide()
	painel_auto_helper._alternar_painel()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		mapa_mundi.hide()
		painel_auto_helper.janela.hide()
		painel_my_pokes.hide()
		painel_nurse.hide()
		painel_pokepedia.hide()
		painel_depot.fechar()
		painel_loja.hide()
		var evo: Control = get_node("Interface").get_node_or_null("PainelEvolucao")
		if evo != null: evo.hide()
		get_viewport().set_input_as_handled()

func _atualizar_resumo_depot() -> void:
	resumo_depot.text = "Pokémon no depot: " + str(EstadoJogo.pokemons_capturados.size())

func _perto_depot() -> bool:
	return personagem != null and (alcance_interacao_cidade<=0 or personagem.position.distance_to(Vector2(CELULA_DEPOT) * 32.0 + Vector2(16,16)) <= alcance_interacao_cidade)

func _clicar_depot() -> void:
	painel_nurse.hide()
	painel_pokepedia.hide()
	painel_my_pokes.hide()
	if not _perto_depot() or personagem.andando:
		return
	mapa_mundi.hide()
	painel_auto_helper.janela.hide()
	painel_depot.abrir_convite()

# Novo: movimento suspenso enquanto um painel está aberto.
func _process(delta: float) -> void:
	if personagem == null:
		return
	personagem.atualizar(delta, not _modal_aberto())
	# Alteração: a atualização segue a ordem da cadeia para propagar os trechos.
	for membro in seguidores:
		membro.atualizar(delta, personagem.velocidade_movimento)
	cenario.atualizar_cobertura(personagem.position)
	_ajustar_cenario()
	var pode_mostrar: bool = not _modal_aberto()
	placa_nurse.posicionar(cenario.to_global(Vector2(CELULA_NURSE)*32.0+Vector2(16,16)))
	placa_nurse.visible = pode_mostrar
	placa_depot.posicionar(cenario.to_global(Vector2(CELULA_DEPOT)*32.0+Vector2(16,16)))
	placa_depot.visible = pode_mostrar
	placa_loja.posicionar(cenario.to_global(Vector2(CELULA_LOJA)*32.0+Vector2(16,16)))
	placa_loja.visible = pode_mostrar
	resultado_cura.position = Vector2(size.x*0.5-220,size.y*0.5-100)
	resultado_cura.size = Vector2(440,36)

# Novo: agrupa sinais do depósito/líder para não reconstruir estados intermediários.
func _agendar_sincronizacao_seguidores() -> void:
	if _sincronizacao_seguidores_pendente:
		return
	_sincronizacao_seguidores_pendente = true
	call_deferred("_sincronizar_seguidores")

func _sincronizar_seguidores() -> void:
	_sincronizacao_seguidores_pendente = false
	var ordem: Array[DadosPokemon] = [EstadoJogo.obter_lider()]
	for pokemon in EstadoJogo.time_pokemon:
		if pokemon != ordem[0]:
			ordem.append(pokemon)
	# Novo: só remove a cauda; posições e trilhas existentes permanecem estáveis.
	while seguidores.size() > ordem.size():
		var removido: Node2D = seguidores.pop_back()
		var anterior: Node2D = seguidores[-1] if not seguidores.is_empty() else personagem
		if anterior.trecho_percorrido.is_connected(removido._registrar_trecho):
			anterior.trecho_percorrido.disconnect(removido._registrar_trecho)
		removido.hide()
		removido.queue_free()
	var ocupadas: Dictionary = {personagem.celula: true}
	for membro in seguidores:
		ocupadas[membro.celula] = true
	for indice in range(ordem.size()):
		if indice < seguidores.size():
			seguidores[indice].definir_pokemon(ordem[indice])
			continue
		var novo: Node2D = load("res://seguidor_cidade.gd").new()
		novo.name = "SeguidorPokemon_" + str(indice + 1)
		cenario.adicionar_treinador(novo)
		var anterior: Node2D = personagem if indice == 0 else seguidores[indice - 1]
		novo.iniciar(anterior, cenario, ordem[indice], ocupadas)
		seguidores.append(novo)
		ocupadas[novo.celula] = true
	seguidor = seguidores[0] if not seguidores.is_empty() else null

func _abrir_my_pokes() -> void:
	painel_nurse.hide()
	painel_pokepedia.hide()
	# Alteração: Pokébola abre a ficha TEAM; nunca oculta o HUD.
	mapa_mundi.hide()
	painel_auto_helper.janela.hide()
	painel_depot.fechar()
	painel_my_pokes.abrir()

# Alcance configurável; zero libera interações em qualquer posição da cidade.
func _perto_nurse() -> bool:
	return personagem != null and (alcance_interacao_cidade<=0 or personagem.position.distance_to(Vector2(CELULA_NURSE)*32.0+Vector2(16,16)) <= alcance_interacao_cidade)

func _modal_aberto() -> bool:
	return mapa_mundi.visible or painel_auto_helper.janela.visible or painel_my_pokes.visible or painel_depot.visible or painel_nurse.visible or painel_time.perfil.visible or painel_pokepedia.visible or painel_loja.visible or _evolucao_aberta() or (painel_streak != null and painel_streak.visible) or (painel_diarias != null and painel_diarias.visible) or (painel_soneca != null and painel_soneca.visible)

func _clicar_nurse() -> void:
	if not _perto_nurse() or personagem.andando or _modal_aberto():
		return
	painel_nurse.abrir()

func _confirmar_cura_nurse() -> void:
	# Revalida o contexto e o alcance configurado antes de confirmar a cura.
	if not painel_nurse.visible or not _perto_nurse() or personagem.andando:
		return
	var resultado: Dictionary = EstadoJogo.curar_time()
	painel_nurse.hide()
	painel_pokepedia.hide()
	resultado_cura.text = "Seu time foi curado! +%d HP" % resultado["hp"] if resultado["quantidade"] > 0 else "Seu time já está saudável."
	resultado_cura.show()
	timer_resultado_cura.start()

func _abrir_pokepedia() -> void:
	mapa_mundi.hide()
	painel_depot.fechar()
	painel_my_pokes.hide()
	painel_nurse.hide()
	painel_auto_helper.janela.hide()
	painel_pokepedia.abrir()

# ---------------------------------------------------------------- fase 4: loja, ouro e configurações
func _evolucao_aberta() -> bool:
	var p: Control = get_node("Interface").get_node_or_null("PainelEvolucao")
	return p != null and p.visible

func _perto_loja() -> bool:
	return personagem != null and (alcance_interacao_cidade<=0 or personagem.position.distance_to(Vector2(CELULA_LOJA)*32.0+Vector2(16,16)) <= alcance_interacao_cidade)

func _clicar_loja() -> void:
	if not _perto_loja() or personagem.andando or _modal_aberto():
		return
	painel_loja.abrir()

func _criar_ouro_e_config() -> void:
	var caixa := HBoxContainer.new()
	caixa.name = "OuroConfig"
	# canto inferior direito: fora do menu e do HUD do time
	caixa.anchor_left = 1.0; caixa.anchor_right = 1.0; caixa.anchor_top = 1.0; caixa.anchor_bottom = 1.0
	caixa.offset_left = -340; caixa.offset_right = -16; caixa.offset_top = -48; caixa.offset_bottom = -16
	caixa.alignment = BoxContainer.ALIGNMENT_END
	get_node("Interface").add_child(caixa)
	rotulo_ouro = Label.new()
	rotulo_ouro.add_theme_color_override("font_color", Color("f0c040"))
	rotulo_ouro.add_theme_color_override("font_outline_color", Color.BLACK)
	rotulo_ouro.add_theme_constant_override("outline_size", 5)
	caixa.add_child(rotulo_ouro)
	var engrenagem := Button.new()
	engrenagem.name = "Configuracoes"
	engrenagem.text = "⚙"
	engrenagem.tooltip_text = "Configurações"
	caixa.add_child(engrenagem)
	painel_config = PanelContainer.new()
	painel_config.name = "PainelConfig"
	painel_config.add_theme_stylebox_override("panel", preload("res://estilo_hud_original.gd").moldura())
	painel_config.anchor_left = 1.0; painel_config.anchor_right = 1.0; painel_config.anchor_top = 1.0; painel_config.anchor_bottom = 1.0
	painel_config.offset_left = -420; painel_config.offset_right = -16; painel_config.offset_top = -100; painel_config.offset_bottom = -56
	painel_config.hide()
	get_node("Interface").add_child(painel_config)
	var vip := CheckButton.new()
	vip.name = "VIP"
	vip.text = "VIP (+50% de XP base, como no original)"
	vip.button_pressed = EstadoJogo.vip
	vip.toggled.connect(func(ligado: bool) -> void: EstadoJogo.vip = ligado)
	painel_config.add_child(vip)
	engrenagem.pressed.connect(func() -> void: painel_config.visible = not painel_config.visible)
	# Fase 4, lote 2: Streak Points e a coleta da soneca.
	painel_config.remove_child(vip)
	var coluna := VBoxContainer.new()
	painel_config.add_child(coluna)
	coluna.add_child(vip)
	var botao_streak := Button.new()
	botao_streak.name = "StreakPoints"
	botao_streak.text = "Streak Points"
	coluna.add_child(botao_streak)
	painel_streak = load("res://painel_streak.gd").new()
	painel_streak.name = "PainelStreak"
	get_node("Interface").add_child(painel_streak)
	botao_streak.pressed.connect(func() -> void:
		painel_config.hide()
		painel_streak.abrir())
	# Fase 4, item 3: Quests, Tasks & Dailys (Daily Gift, Daily Kill, Daily Catch, tarefas por cidade).
	var botao_diarias := Button.new()
	botao_diarias.name = "Diarias"
	botao_diarias.text = "Quests, Tasks & Dailys"
	coluna.add_child(botao_diarias)
	painel_diarias = load("res://painel_diarias.gd").new()
	painel_diarias.name = "PainelDiarias"
	get_node("Interface").add_child(painel_diarias)
	botao_diarias.pressed.connect(func() -> void:
		painel_config.hide()
		painel_diarias.abrir())
	painel_soneca = load("res://painel_soneca.gd").new()
	painel_soneca.name = "PainelSoneca"
	get_node("Interface").add_child(painel_soneca)
	call_deferred("verificar_soneca")
	var atualizar := func() -> void: rotulo_ouro.text = "💲 %d" % EstadoJogo.ouro
	EstadoJogo.ouro_alterado.connect(atualizar)
	atualizar.call()

func verificar_soneca() -> void:
	## Ao abrir a cidade: soneca pendente → janela de coleta; voltou antes de 5 min → cancelada (C), sem janela.
	if EstadoJogo.soneca.is_empty():
		return
	var r: Dictionary = EstadoJogo.relatorio_offline(int(Time.get_unix_time_from_system()))
	if r.get("report") != null:
		painel_soneca.abrir(r)
	elif r.has("notice"):
		painel_soneca.abrir_aviso(r["notice"])
