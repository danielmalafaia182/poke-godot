extends Control

# Novo: composição da caça a partir do print original; não copia dados da conta.
const UI: Script=preload("res://estilo_ui_fiel.gd")
const ESTILO: Script = preload("res://estilo_hud_original.gd")
var controlador: Node2D
var mapa_mundi: Control
var painel_time: Control
var menu: Control
var my_pokes: Control
var pokepedia: Control
var recompensas: Control
var painel_golpes: PanelContainer
var captura: PanelContainer
var resumo_captura: Label
var estoque: HFlowContainer
var nome_aliado: TextureRect
var placa_aliado: Node2D
var vida_aliado: ProgressBar
var capturados_hunt: int=0
var contador_wilds: Label
var capturas_contadas: Dictionary={}
var aviso_ofensivo: PanelContainer
var texto_aviso_ofensivo: Label

var janelas_dock: Dictionary = {}
var painel_captura: PanelContainer
var avisos: Control
var tutorial: Control
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_time = load("res://painel_time.gd").new()
	painel_time.provedor_cooldown=controlador.obter_troca_restante
	painel_time.nome_local = EstadoJogo.especie_caca.nome if EstadoJogo.especie_caca != null else "Hunt"
	add_child(painel_time)
	menu = load("res://menu_superior_original.gd").new()
	add_child(menu)
	my_pokes = load("res://painel_my_pokes.gd").new()
	my_pokes.provedor_cooldown=controlador.obter_troca_restante
	# Troca sincronizada pelo controlador, sem reiniciar a instância da hunt.
	my_pokes.permitir_troca_lider = true
	my_pokes.exigir_lider_saudavel = true
	add_child(my_pokes)
	pokepedia = load("res://painel_pokepedia.gd").new()
	add_child(pokepedia)
	menu.time_solicitado.connect(my_pokes.abrir)
	menu.pokepedia_solicitada.connect(pokepedia.abrir)
	menu.auto_helper_solicitado.connect(controlador.painel_auto_helper._alternar_painel)
	menu.cidade_solicitada.connect(controlador._on_botao_voltar_cidade_pressed)
	menu.mapa_solicitado.connect(_abrir_mapa_mundi)
	menu.botoes["map"].tooltip_text = "Mapa-Múndi — escolher outra hunt"
	# Ciclo 2: ícones do dock com janela (Perfil, Bolas usadas, Log de Capturas, Hunt Analyser, Streak, Diário, Pokédex)
	janelas_dock = load("res://janelas_dock.gd").instalar(self, menu, controlador if "registro" in controlador else null, pokepedia.abrir)
	avisos = load("res://avisos_hud.gd").new()
	avisos.name = "AvisosHud"
	add_child(avisos)
	avisos.relogio_ms = func() -> int: return controlador.sim.agora_ms() if "sim" in controlador and controlador.sim != null else 0
	if controlador.has_signal("subiu_nivel"):   # só a cena nova (caca_sim); a antiga (caca.gd) não tem estes sinais
		controlador.subiu_nivel.connect(func(nome: String, nivel: int, treinador: bool) -> void:
			if treinador:
				avisos.nivel_treinador(nivel)
			else:
				avisos.nivel_pokemon(nome, nivel))
		controlador.shiny_apareceu.connect(avisos.shiny_apareceu)
		controlador.capturado.connect(func(nome: String, shiny: bool) -> void:
			if shiny:
				avisos.shiny_capturado(String(EstadoJogo.nome_treinador), nome))
		controlador.boosts_alterados.connect(avisos.definir_boosts)
	tutorial = load("res://painel_tutorial.gd").new()
	tutorial.name = "PainelTutorial"
	tutorial.na_hunt = true
	tutorial.raiz = self
	add_child(tutorial)
	controlador.derrota_recompensada.connect(func(_e) -> void: tutorial.ao_abate())
	if controlador.has_signal("bola_lancada"):
		controlador.bola_lancada.connect(func() -> void: tutorial.ao_evento("ball-thrown"))
	# 2b: o mapa-múndi da hunt é criado na 1ª abertura (instanciá-lo custava ~0,5 s na entrada da hunt)
	recompensas = load("res://cartoes_derrota.gd").new()
	add_child(recompensas)
	controlador.derrota_recompensada.connect(recompensas.apresentar)
	controlador.captura_resolvida.connect(_captura_resolvida)
	# Ciclo 4: o painel de captura do original (painel_captura.gd: pendentes, lançar, fichas das bolas). O de antes fica
	# montado fora da árvore só para os contadores internos (capturados_hunt, estoque).
	painel_captura = load("res://painel_captura.gd").new()
	painel_captura.controlador = controlador
	add_child(painel_captura)
	if controlador.has_signal("pendentes_alterados"):
		controlador.pendentes_alterados.connect(painel_captura.receber_pendentes)
		controlador.resultado_captura.connect(painel_captura.receber_resultado)
	captura=PanelContainer.new()
	var coluna: VBoxContainer=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",8)
	captura.add_child(coluna)
	var cabecalho: HBoxContainer=HBoxContainer.new()
	cabecalho.add_theme_constant_override("separation",6)
	coluna.add_child(cabecalho)
	cabecalho.add_child(UI.texto("🎯",16,Color.WHITE))
	var titulo: Label=UI.texto("Capture",14,Color("f0e6d2"),true)
	titulo.add_theme_font_override("font",UI.TITULO)
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	var selo: PanelContainer=PanelContainer.new()
	selo.add_theme_stylebox_override("panel",UI.caixa(Color("080e17"),Color("997530"),6,6))
	contador_wilds=UI.texto("0 wilds",10,Color("e8c98a"),true)
	selo.add_child(contador_wilds)
	cabecalho.add_child(selo)
	estoque=HFlowContainer.new()
	estoque.add_theme_constant_override("h_separation",5)
	estoque.add_theme_constant_override("v_separation",5)
	coluna.add_child(estoque)
	# Compatibilidade de acesso: não exibe mensagens de resultado.
	resumo_captura=Label.new()
	resumo_captura.hide()
	coluna.add_child(resumo_captura)
	EstadoJogo.estoque_bolas_alterado.connect(_atualizar_estoque)
	_atualizar_estoque()
	# Alteração: resumo de depuração não ocupa o canto do HUD permanente.
	controlador.titulo.visible = not controlador.populacao_iniciada
	if not controlador.populacao_iniciada:
		controlador.titulo.position = Vector2(20,240)
	controlador.botao_voltar_cidade.hide()
	# Novo: nome e HP ancorados no aliado em espaço de mundo, como no print.
	if controlador.pokemon_aliado != null:
		placa_aliado=Node2D.new()
		placa_aliado.top_level=true
		placa_aliado.z_index=preload("res://estilo_combate.gd").CAMADA_INDICADORES
		placa_aliado.z_as_relative=false
		controlador.imagem_aliado.add_child(placa_aliado)
		nome_aliado=preload("res://estilo_combate.gd").nome(controlador.pokemon_aliado.especie.nome)
		placa_aliado.add_child(nome_aliado)
		vida_aliado=preload("res://estilo_combate.gd").barra()
		placa_aliado.add_child(vida_aliado)
		_atualizar_vida_aliado(controlador.pokemon_aliado)
	EstadoJogo.individuo_alterado.connect(_atualizar_vida_aliado)
	controlador.aliado_alterado.connect(_atualizar_aliado)
	painel_golpes = load("res://painel_golpes_caca.gd").new()
	painel_golpes.controlador = controlador
	add_child(painel_golpes)
	painel_golpes.set_process(false)
	painel_golpes.hide()
	# P04: aviso funcional local; não usa textos flutuantes de ataque.
	aviso_ofensivo=PanelContainer.new()
	aviso_ofensivo.name="AvisoOfensivo"
	aviso_ofensivo.add_theme_stylebox_override("panel",UI.caixa(Color("0c1420f5"),Color("997530"),8,10))
	add_child(aviso_ofensivo)
	var conteudo_aviso: VBoxContainer=VBoxContainer.new()
	aviso_ofensivo.add_child(conteudo_aviso)
	texto_aviso_ofensivo=UI.texto("",12,Color("e8c98a"))
	texto_aviso_ofensivo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	conteudo_aviso.add_child(texto_aviso_ofensivo)
	var opcoes_aviso: HBoxContainer=HBoxContainer.new()
	conteudo_aviso.add_child(opcoes_aviso)
	var ver_time: Button=Button.new()
	ver_time.text="Ver time"
	ver_time.tooltip_text="Escolher um Pokémon vivo; mantém o cooldown de troca de cinco segundos."
	ver_time.pressed.connect(my_pokes.abrir)
	opcoes_aviso.add_child(ver_time)
	var ver_mapa: Button=Button.new()
	ver_mapa.text="Mapa-Múndi"
	ver_mapa.pressed.connect(_abrir_mapa_mundi)
	opcoes_aviso.add_child(ver_mapa)
	controlador.ofensiva_aliado_alterada.connect(_atualizar_aviso_ofensivo)
	_atualizar_aviso_ofensivo(controlador.diagnostico_ofensivo_aliado)
	painel_time.resized.connect(_posicionar_aviso_ofensivo)
	resized.connect(_ajustar)
	_ajustar()
	# Modais precisam ficar acima dos elementos permanentes.
	my_pokes.move_to_front()
	pokepedia.move_to_front()
	controlador.painel_auto_helper.move_to_front()

func _texto(texto: String, tamanho: int) -> Label:
	var label: Label = Label.new()
	label.text = texto
	label.add_theme_font_override("font",preload("res://assets/interface/depot/barlow_semibold.ttf"))
	label.add_theme_font_size_override("font_size",tamanho)
	label.add_theme_color_override("font_color",Color("e9e2d0"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _ajustar() -> void:
	if is_instance_valid(aviso_ofensivo):
		_posicionar_aviso_ofensivo()
		aviso_ofensivo.size=Vector2(maxf(180,minf(360,size.x-40)),0)
	if is_instance_valid(painel_golpes):
		painel_golpes.position = Vector2(282,maxf(160,size.y-146))
		painel_golpes.size = Vector2(maxf(200,minf(360,size.x-590)),130)
	# Adaptação local: reserva espaço para captura em janelas de 648px.
	recompensas.maximo_cartoes = 1
	# Ciclo 4: o cartão mede em px da tela de 1880 do original (kc-card 340 px), como os painéis novos.
	var f_kc: float = maxf(0.5, size.x / 1880.0)
	recompensas.scale = Vector2(f_kc, f_kc)
	recompensas.position = Vector2(maxf(12, size.x - (340 + 12) * f_kc), 170.0)   # abaixo do botão Auto-Helper
	captura.position = Vector2(maxf(12,size.x-274),maxf(150,size.y-250))
	captura.size = Vector2(262,0)
	if painel_captura != null:   # C: right/bottom 8 px, scale .88, origem no canto
		painel_captura.scale = Vector2(0.88, 0.88) * (size.x / 1880.0)   # medidas do CSS em px de 1880 de largura

func _atualizar_aviso_ofensivo(diagnostico: Dictionary) -> void:
	aviso_ofensivo.visible=str(diagnostico.get("estado","")) in ["bloqueado","aguardando_alvo"]
	texto_aviso_ofensivo.text=str(diagnostico.get("mensagem",""))
	if aviso_ofensivo.visible:
		_posicionar_aviso_ofensivo()

func _posicionar_aviso_ofensivo() -> void:
	if is_instance_valid(aviso_ofensivo):
		aviso_ofensivo.position=Vector2(20,maxf(190,painel_time.position.y+painel_time.size.y+12))

var _estoque_assinatura: String = ""
var _estoque_rotulos: Dictionary = {}

func _atualizar_estoque() -> void:
	# 2b.6 (desempenho): cada tentativa de auto-catch muda o estoque; se o conjunto de bolas e a selecionada não
	# mudaram, só os números são trocados (recriar os botões com os ícones custava milissegundos por abate).
	var ids_com_estoque: Array = []
	for id in [1,2,3,4,5,6,7]:
		if EstadoJogo.obter_quantidade_bola(id) > 0:
			ids_com_estoque.append(id)
	var assinatura: String = str(ids_com_estoque)+"|"+str(EstadoJogo.auto_catch_ball_id)
	if assinatura == _estoque_assinatura and _estoque_rotulos.size() == ids_com_estoque.size():
		for id in ids_com_estoque:
			var dados_bola: Dictionary = EstadoJogo.obter_dados_bola(id)
			var texto: String = "∞" if bool(dados_bola.get("infinita",false)) else _numero(EstadoJogo.obter_quantidade_bola(id))
			var rotulo: Label = _estoque_rotulos[id]
			if rotulo.text != texto:
				rotulo.text = texto
				(rotulo.get_meta("botao") as Button).custom_minimum_size.x=UI.FORTE.get_string_size(texto,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+33
		return
	_estoque_assinatura = assinatura
	_estoque_rotulos.clear()
	for filho in estoque.get_children():
		estoque.remove_child(filho)
		filho.queue_free()
	for id in [1,2,3,4,5,6,7]:
		var quantidade: int = EstadoJogo.obter_quantidade_bola(id)
		if quantidade <= 0:
			continue
		var bola: Button = Button.new()
		var dados: Dictionary = EstadoJogo.obter_dados_bola(id)
		bola.text = "∞" if bool(dados.get("infinita",false)) else _numero(quantidade)
		var icones: Dictionary = {1:"pokeball",2:"greatball",3:"superball",4:"ultraball",5:"masterball",6:"idleball",7:"idleball_gold"}
		var caminho: String = "res://assets/interface/bolas/"+str(icones[id])+".png"
		# Usa o catálogo já disponível no projeto.
		if not ResourceLoader.exists(caminho):
			caminho = "res://assets/interface/depot/"+str(icones[id])+".png"
		if ResourceLoader.exists(caminho):
			bola.icon = load(caminho)
		var texto_quantidade: String=bola.text
		var textura: Texture2D=bola.icon
		bola.text=""
		bola.icon=null
		bola.custom_minimum_size.x=UI.FORTE.get_string_size(texto_quantidade,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+33
		var centro: CenterContainer=CenterContainer.new()
		centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		centro.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bola.add_child(centro)
		var linha: HBoxContainer=HBoxContainer.new()
		linha.add_theme_constant_override("separation",5)
		linha.mouse_filter=Control.MOUSE_FILTER_IGNORE
		centro.add_child(linha)
		var imagem: TextureRect=preload("res://estilo_resultado_combate.gd").icone(preload("res://visual_pokemon.gd").centralizar_retrato(textura),11)
		imagem.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		linha.add_child(imagem)
		var rotulo_quantidade: Label = UI.texto(texto_quantidade,12,Color("e5eaf0"),true)
		rotulo_quantidade.set_meta("botao", bola)
		_estoque_rotulos[id] = rotulo_quantidade
		linha.add_child(rotulo_quantidade)
		bola.add_theme_constant_override("icon_max_width",11)
		bola.add_theme_font_override("font",UI.FORTE)
		bola.add_theme_font_size_override("font_size",12)
		bola.add_theme_color_override("font_color",Color("e5eaf0"))
		bola.add_theme_stylebox_override("normal",UI.caixa(Color("202632"),Color("997530") if id==EstadoJogo.auto_catch_ball_id else Color("3a4658"),15,8))
		bola.add_theme_stylebox_override("hover",UI.caixa(Color("293442"),Color("c8aa6e"),15,8))
		bola.custom_minimum_size.y=30
		bola.tooltip_text = str(dados.get("nome","Bola"))+" — configurar Auto-Helper"
		bola.pressed.connect(controlador.painel_auto_helper._alternar_painel)
		estoque.add_child(bola)

func _numero(valor: int) -> String:
	var texto: String=str(valor)
	var grupos: String=""
	while texto.length()>3:
		grupos="."+texto.right(3)+grupos
		texto=texto.left(texto.length()-3)
	return texto+grupos
func _captura_resolvida(evento: Dictionary) -> void:
	if not bool(evento.get("sucesso",false)): return
	var id: String=str(evento.get("id",""))
	if not id.is_empty() and capturas_contadas.has(id): return
	if not id.is_empty(): capturas_contadas[id]=true
	capturados_hunt+=1
	contador_wilds.text="%d wilds" % capturados_hunt

func _atualizar_vida_aliado(pokemon: DadosPokemon) -> void:
	if pokemon == controlador.pokemon_aliado and is_instance_valid(vida_aliado):
		preload("res://estilo_combate.gd").atualizar(vida_aliado,pokemon.obter_vida_atual(),pokemon.obter_vida_maxima())

func _process(_delta: float) -> void:
	if is_instance_valid(placa_aliado):
		placa_aliado.global_position=controlador.imagem_aliado.global_position
		placa_aliado.visible=controlador.imagem_aliado.is_visible_in_tree() and controlador.vida_aliado>0

func _abrir_mapa_mundi() -> void:
	if mapa_mundi == null:
		mapa_mundi=load("res://mapa_mundi.tscn").instantiate()
		mapa_mundi.name="MapaMundiHunt"
		add_child(mapa_mundi)
	my_pokes.hide()
	pokepedia.hide()
	if is_instance_valid(painel_time.perfil): painel_time.perfil.hide()
	if is_instance_valid(controlador.painel_auto_helper): controlador.painel_auto_helper.janela.hide()
	mapa_mundi.move_to_front()
	mapa_mundi.show()

func _atualizar_aliado(pokemon: DadosPokemon) -> void:
	if is_instance_valid(nome_aliado):
		nome_aliado.texture=preload("res://fonte_mundo.gd").texto(pokemon.especie.nome,Color("00ff00"))
		nome_aliado.size=nome_aliado.texture.get_size()
		nome_aliado.position.x=-floorf(nome_aliado.size.x*0.5)
	_atualizar_vida_aliado(pokemon)
