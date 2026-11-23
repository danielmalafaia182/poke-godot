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
const CELULA_PESCA: Vector2i = Vector2i(7, -10)   # A: city-npcs "fishing" em (7, −10)
var placa_pesca: PlacaInteracao
var painel_pesca: Control
var painel_loja: Control
var placa_loja: PlacaInteracao
var painel_config: PanelContainer
var painel_streak: Control
var painel_diarias: Control
var painel_itens: Control
var painel_soneca: Control
var painel_metas: Control
var botao_meta: Button
var janelas_dock: Dictionary = {}
var painel_tutorial: Control
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
	# Ciclo 8: Pescador (C: hud.world.npcAction.fish)
	placa_pesca = PlacaInteracao.new()
	get_node("Interface").add_child(placa_pesca)
	placa_pesca.configurar("Pescador", "🎣 Pescar")
	placa_pesca.botao.pressed.connect(_clicar_pesca)
	painel_pesca = load("res://painel_pesca.gd").new()
	painel_pesca.name = "PainelPesca"
	get_node("Interface").add_child(painel_pesca)
	_criar_ouro_e_config()
	resized.connect(_ajustar_cenario)
	# Novo: personagem animado independente do controlador de caça.
	personagem = TREINADOR_CIDADE.new()
	personagem.name = "Treinador"
	cenario.adicionar_treinador(personagem)
	personagem.iniciar(cenario)
	# Ciclo 4: os NPCs (Nurse Joy, Depot, Mark, Mercado, Pescador) vêm do city-npcs e o cenário os desenha (C).
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
	call_deferred("_pre_aquecer_hunts")

func _pre_aquecer_hunts() -> void:
	## Ciclo 4: o atlas das hunts liberadas é montado em segundo plano enquanto se está na cidade (as mais perto do
	## nível do treinador primeiro; também as que liberam nos próximos 100 níveis), para a entrada na hunt caber em 1 s.
	var hunts: Array = preload("res://ponte_cidade.gd").dados().hunts.values()
	var nivel := int(EstadoJogo.nivel_treinador)
	# as liberadas e as que liberam nos próximos 100 níveis (ficam prontas antes de o treinador chegar lá)
	var lib: Array = preload("res://sim/regras_acesso.gd").hunts_liberadas(hunts, nivel + 100)
	var por_slug := {}
	for h in hunts:
		por_slug[String(h["slug"])] = int(h.get("nivel", 0))
	lib.sort_custom(func(a, b): return absi(int(por_slug[a]) - nivel) < absi(int(por_slug[b]) - nivel))
	EstadoJogo.pre_aquecer_atlas(lib)
	preload("res://render/vista_hunt.gd").pre_carregar()   # espécies e cadáveres da vista da hunt, prontos de antemão

## C: a vista do cliente é 25×13 casas em zoom 1 (25/zoom de largura); o zoom é a opção do jogador (EstadoJogo.zoom_camera,
## padrão 1). A: no vídeo do original o usuário joga em 0.5× (~50×26: o Pokémon Center ocupa ~600 px de 1880).
## zoom_cidade multiplica (ferramentas de print).
const VISTA_CIDADE_TILES := 25.0

func _ajustar_cenario() -> void:
	if cenario == null:
		return
	var zoom := size.x / (VISTA_CIDADE_TILES / EstadoJogo.zoom_camera * 32.0) * zoom_cidade
	cenario.scale = Vector2.ONE * zoom
	if cenario.has_method("definir_vista"):
		cenario.definir_vista((size / (32.0 * zoom)).ceil())
	# Alteração: câmera segue o treinador sem mover os controles.
	var centro: Vector2 = personagem.position if personagem != null else centro_cidade
	cenario.position = (size * 0.5 - centro * zoom).round()

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
	placa_pesca.posicionar(cenario.to_global(Vector2(CELULA_PESCA)*32.0+Vector2(16,16)))
	placa_pesca.visible = pode_mostrar
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
	return mapa_mundi.visible or painel_auto_helper.janela.visible or painel_my_pokes.visible or painel_depot.visible or painel_nurse.visible or painel_time.perfil.visible or painel_pokepedia.visible or painel_loja.visible or _evolucao_aberta() or (painel_streak != null and painel_streak.visible) or (painel_diarias != null and painel_diarias.visible) or (painel_itens != null and painel_itens.visible) or (painel_soneca != null and painel_soneca.visible) or (painel_metas != null and painel_metas.visible) or (painel_pesca != null and painel_pesca.visible)

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

func _clicar_pesca() -> void:
	if personagem == null or personagem.andando or _modal_aberto():
		return
	if alcance_interacao_cidade > 0 and personagem.position.distance_to(Vector2(CELULA_PESCA)*32.0+Vector2(16,16)) > alcance_interacao_cidade:
		return
	painel_pesca.abrir()

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
	painel_config.grow_vertical = Control.GROW_DIRECTION_BEGIN   # cresce para cima conforme entram opções
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
	# Ciclo 4: zoom da câmera (C: as opções do cliente; padrão 25×13)
	var linha_zoom := HBoxContainer.new()
	linha_zoom.name = "Zoom"
	coluna.add_child(linha_zoom)
	var rz := Label.new()
	rz.text = "Zoom:"
	linha_zoom.add_child(rz)
	for par in [[1.0, "25×13"], [0.75, "0.75× (~33×17)"], [0.5, "0.5× (~50×26)"]]:
		var bz := Button.new()
		bz.name = "Zoom_%s" % str(par[0]).replace(".", "_")
		bz.text = String(par[1])
		bz.toggle_mode = true
		bz.button_pressed = is_equal_approx(EstadoJogo.zoom_camera, float(par[0]))
		var zv: float = par[0]
		bz.pressed.connect(func() -> void:
			EstadoJogo.zoom_camera = zv
			for irmao in linha_zoom.get_children():
				if irmao is Button:
					irmao.button_pressed = irmao == bz
			EstadoJogo.solicitar_salvamento()
			_ajustar_cenario())
		linha_zoom.add_child(bz)
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
	# Fase 4, lote 3: itens de uso (Rare Candy e berries).
	var botao_itens := Button.new()
	botao_itens.name = "ItensUso"
	botao_itens.text = "Usar itens (Rare Candy, berries)"
	coluna.add_child(botao_itens)
	painel_itens = load("res://painel_itens_uso.gd").new()
	painel_itens.name = "PainelItensUso"
	get_node("Interface").add_child(painel_itens)
	botao_itens.pressed.connect(func() -> void:
		painel_config.hide()
		painel_itens.abrir())
	painel_soneca = load("res://painel_soneca.gd").new()
	painel_soneca.name = "PainelSoneca"
	get_node("Interface").add_child(painel_soneca)
	call_deferred("verificar_soneca")
	# Jogo novo (C): sem save, o jogo começa pela escolha do inicial. Só no jogo de verdade (nos testes, o SceneTree é o
	# script do teste e o começo continua o do P04).
	if EstadoJogo.salvamento.jogo_novo and get_tree().get_script() == null:
		if EstadoJogo.salvamento.save_do_projeto_disponivel():
			# ciclo 3: jogo exportado na 1ª execução, com save do projeto: oferece importar uma cópia
			var pi: Control = load("res://painel_importar_save.gd").new()
			pi.name = "PainelImportarSave"
			pi.decidido.connect(func(importou: bool) -> void:
				if importou:
					get_tree().reload_current_scene.call_deferred()
				else:
					_abrir_novo_jogo())
			get_node("Interface").add_child(pi)
		else:
			_abrir_novo_jogo()
	var atualizar := func() -> void: rotulo_ouro.text = "💲 %d" % EstadoJogo.ouro
	EstadoJogo.ouro_alterado.connect(atualizar)
	atualizar.call()
	# Ciclo 2: metas visíveis (sim/metas.gd). A próxima meta fica sempre à vista no canto; o clique abre o painel.
	painel_metas = load("res://painel_metas.gd").new()
	painel_metas.name = "PainelMetas"
	get_node("Interface").add_child(painel_metas)
	botao_meta = Button.new()
	botao_meta.name = "MetaAtual"
	botao_meta.flat = true
	botao_meta.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	botao_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	botao_meta.add_theme_color_override("font_color", Color("9fe0a0"))
	botao_meta.add_theme_color_override("font_outline_color", Color.BLACK)
	botao_meta.add_theme_constant_override("outline_size", 4)
	botao_meta.anchor_left = 1.0; botao_meta.anchor_right = 1.0; botao_meta.anchor_top = 1.0; botao_meta.anchor_bottom = 1.0
	botao_meta.offset_left = -560; botao_meta.offset_right = -16; botao_meta.offset_top = -104; botao_meta.offset_bottom = -52
	botao_meta.tooltip_text = "Metas: hunt recomendada, próxima meta, marcos e coleção"
	botao_meta.pressed.connect(func() -> void: painel_metas.abrir())
	get_node("Interface").add_child(botao_meta)
	call_deferred("atualizar_meta")
	# Ciclo 2: ícones do dock que abrem as janelas novas (Perfil, Bolas usadas, Log de Capturas, Streak, Diário, Pokédex)
	janelas_dock = load("res://janelas_dock.gd").instalar(get_node("Interface"), get_node("Interface/MenuSuperior"), null, _abrir_pokepedia)
	# Ciclo 2: tutorial do Professor Carvalho (C) e o botão 🎓 Tutorial no ⚙ para refazer.
	painel_tutorial = load("res://painel_tutorial.gd").new()
	painel_tutorial.name = "PainelTutorial"
	painel_tutorial.raiz = get_node("Interface")
	get_node("Interface").add_child(painel_tutorial)
	# Ciclo 2: tamanho da interface e tela cheia (C: hud.config), em user://config_tela.cfg (fora do save).
	var CT := load("res://config_tela.gd")
	var tela: Dictionary = CT.ler()
	CT.aplicar(get_window(), tela)
	var escala := OptionButton.new()
	escala.name = "EscalaInterface"
	escala.tooltip_text = "Tamanho da interface"
	for e in CT.ESCALAS:
		escala.add_item("Interface %d%%" % int(round(float(e) * 100.0)))
		if absf(float(e) - float(tela["escala"])) < 0.01:
			escala.select(escala.item_count - 1)
	escala.item_selected.connect(func(i: int) -> void:
		tela["escala"] = float(CT.ESCALAS[i])
		CT.gravar(tela)
		CT.aplicar(get_window(), tela))
	coluna.add_child(escala)
	var cheia := CheckButton.new()
	cheia.name = "TelaCheia"
	cheia.text = "Tela cheia"
	cheia.button_pressed = bool(tela["tela_cheia"])
	cheia.toggled.connect(func(lig: bool) -> void:
		tela["tela_cheia"] = lig
		CT.gravar(tela)
		CT.aplicar(get_window(), tela))
	coluna.add_child(cheia)
	var botao_tutorial := Button.new()
	botao_tutorial.name = "Tutorial"
	botao_tutorial.text = "🎓 Tutorial"
	coluna.add_child(botao_tutorial)
	botao_tutorial.pressed.connect(func() -> void:
		painel_config.hide()
		painel_tutorial.reiniciar())
	var botao_metas := Button.new()
	botao_metas.name = "Metas"
	botao_metas.text = "Metas"
	coluna.add_child(botao_metas)
	botao_metas.pressed.connect(func() -> void:
		painel_config.hide()
		painel_metas.abrir())
	# Game Master: painel F12 (sempre em build de desenvolvimento; no jogo exportado, ligado aqui)
	var gm := CheckButton.new()
	gm.name = "PainelGMOpcao"
	gm.text = "Painel do Game Master (F12)"
	gm.button_pressed = preload("res://painel_gm.gd").habilitado()
	gm.toggled.connect(func(v: bool) -> void:
		preload("res://painel_gm.gd").definir_habilitado(v)
		EstadoJogo.ligar_painel_gm(v or OS.is_debug_build()))
	coluna.add_child(gm)
	# Ciclo 7: Poke Slot Machine (Golden Stars). O dock do original não tem o ícone; fica no ⚙.
	var botao_gs := Button.new()
	botao_gs.name = "GoldenStars"
	botao_gs.text = "🎰 Poke Slot Machine"
	coluna.add_child(botao_gs)
	botao_gs.pressed.connect(func() -> void:
		painel_config.hide()
		janelas_dock["estrelas"].abrir())
	# Ciclo 5, item 98: Novo jogo com confirmação e backup automático do save atual.
	var botao_novo := Button.new()
	botao_novo.name = "NovoJogo"
	botao_novo.text = "🆕 Novo jogo"
	coluna.add_child(botao_novo)
	var confirma := ConfirmationDialog.new()
	confirma.name = "ConfirmarNovoJogo"
	confirma.title = "Novo jogo"
	confirma.dialog_text = "Começar um jogo novo do zero?

O save atual (time, box, itens, ouro, nível) é copiado antes para a pasta de backups e o jogo reinicia na escolha do inicial.
Para voltar ao jogo antigo, copie o backup de volta para progresso_v1.json."
	confirma.ok_button_text = "Começar do zero"
	confirma.cancel_button_text = "Cancelar"
	confirma.dialog_autowrap = true
	confirma.min_size = Vector2i(520, 0)
	add_child(confirma)
	botao_novo.pressed.connect(func() -> void:
		painel_config.hide()
		confirma.popup_centered())
	confirma.confirmed.connect(func() -> void:
		var r: Dictionary = EstadoJogo.salvamento.pedir_jogo_novo(OS.get_environment("POKE_NOVO_JOGO_SEM_REINICIAR") == "")
		if r.has("erro"):
			painel_soneca.abrir_texto("Novo jogo", String(r["erro"]))
		else:
			ultimo_backup = String(r.get("backup", "")))

var ultimo_backup := ""

func _abrir_novo_jogo() -> void:
	var pn: Control = load("res://painel_novo_jogo.gd").new()
	pn.name = "PainelNovoJogo"
	get_node("Interface").add_child(pn)

func atualizar_meta() -> void:
	if botao_meta != null:
		botao_meta.text = load("res://painel_metas.gd").linha_resumo(EstadoJogo.metas())

static var _aviso_fora_mostrado := false   # só na 1ª abertura da cidade na sessão (fechado_em_unix vem do save lido)


static func _duracao_txt(seg: int) -> String:
	var h := seg / 3600
	var m := (seg % 3600) / 60
	if h >= 24:
		return "%d d %d h" % [h / 24, h % 24]
	return "%d h %02d min" % [h, m] if h > 0 else "%d min" % maxi(1, m)


static func texto_recuperacao(rec: Dictionary, fora: int, slug: String) -> String:
	## Ciclo 5 (item 99): quanto tempo contou, quanto se perdeu e por quê. B-relatado: fechado numa hunt sem soneca, o
	## servidor segue caçando por 15 min e encerra a sessão.
	var nome: String = String(preload("res://ponte_cidade.gd").dados().hunts.get(slug, {}).get("nome", slug))
	var contou := int(rec.get("segundos", 0))
	var perdido := maxi(0, fora - contou)
	var t := "Fechado há %s. Contaram %s de caça em %s (com o jogo fechado, a hunt segue por até 15 min e a sessão acaba)." % [
		_duracao_txt(fora), _duracao_txt(contou), nome]
	if perdido > 0:
		t += " Os outros %s não renderam: para render mais, use o 💤 Modo Soneca antes de fechar (50%% da taxa de XP, até 24 h)." % _duracao_txt(perdido)
	t += "\n\nResultado: %d abates, +%d XP do treinador, %d captura(s)." % [int(rec.get("kills", 0)), int(rec.get("xpTreinador", 0)), (rec.get("capturas", []) as Array).size()]
	if int(rec.get("kills", 0)) == 0:
		var hp: Dictionary = rec.get("hp", {})
		var vivos := 0
		for k in hp:
			vivos += 1 if int(hp[k]) > 0 else 0
		t += " Nenhum abate: " + ("o time estava desmaiado ao fechar (cure com a Nurse Joy)." if vivos == 0 and not hp.is_empty() else "o líder não derrotou nenhum selvagem nesse tempo (a hunt está acima do nível do time).")
	return t


func verificar_soneca() -> void:
	## Ao abrir a cidade: fechado numa hunt sem soneca → recupera até 15 min de caça (B-relatado); soneca pendente →
	## janela de coleta; voltou antes de 5 min → cancelada com a parte rodada (A, G6b).
	var agora := int(Time.get_unix_time_from_system())
	var fora := maxi(0, agora - int(EstadoJogo.fechado_em_unix)) if int(EstadoJogo.fechado_em_unix) > 0 else 0
	if EstadoJogo.hunt_ao_fechar != "" and EstadoJogo.soneca.is_empty():
		var slug: String = EstadoJogo.hunt_ao_fechar
		var rec: Dictionary = EstadoJogo.recuperar_hunt_fechada(agora)
		if not rec.is_empty():
			painel_soneca.abrir_texto("🌙 Enquanto o jogo esteve fechado", texto_recuperacao(rec, fora, slug))
		return
	if EstadoJogo.soneca.is_empty():
		# Ciclo 5: fechado fora de uma hunt (ou dentro da cidade) por mais de 15 min: diz por que não acumulou nada.
		var primeira := not _aviso_fora_mostrado
		_aviso_fora_mostrado = true
		if fora >= 15 * 60 and primeira and not bool(EstadoJogo.salvamento.jogo_novo):
			painel_soneca.abrir_texto("🌙 Bem-vindo de volta", "O jogo ficou fechado por %s, mas fora de uma hunt: nada foi acumulado. Para render com o jogo fechado, feche dentro de uma hunt (rende os primeiros 15 min) ou use o 💤 Modo Soneca na barra de menu (rende 50%% da taxa de XP por até 24 h)." % _duracao_txt(fora))
		return
	var r: Dictionary = EstadoJogo.relatorio_offline(int(Time.get_unix_time_from_system()))
	if r.get("report") != null:
		painel_soneca.abrir(r)
	elif r.has("notice"):
		painel_soneca.abrir_aviso(r["notice"])
