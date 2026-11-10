class_name CoordenadorSalvamento
extends Node

# Coordena I/O, fila e aviso; o formato continua em salvamento_local.gd.
signal estado_salvamento_alterado
var estado: Node
const SALVAMENTO_LOCAL: Script = preload("res://salvamento_local.gd")
var aviso_salvamento: String = ""
var erro_salvamento: bool = false
var _persistencia: RefCounted
var _persistencia_pronta: bool = false
var _salvamento_pendente: bool = false
var _salvamento_agendado: bool = false
var _painel_aviso_save: PanelContainer
var _rotulo_aviso_save: Label
var _tempo_aviso_save: Timer
var _timer_salvamento: Timer

func iniciar(fachada: Node) -> void:
	estado = fachada
	estado.iniciar_depot()
	_persistencia = SALVAMENTO_LOCAL.new()
	_criar_aviso_save()
	var carregou: bool = _persistencia.carregar(estado)
	# Novo: normaliza sem perder nível, indivíduos ou proporção de HP do save antigo.
	for pokemon in estado.time_pokemon + estado.pokemons_capturados:
		pokemon.normalizar_atributos()
	var inicial_corrigido: bool=estado.colecao.corrigir_inicial_prototipo()
	_persistencia_pronta = true
	if not carregou:
		_informar_salvamento(_persistencia.erro, true)
	elif not _persistencia.aviso.is_empty():
		_informar_salvamento(_persistencia.aviso, false)
	_timer_salvamento = Timer.new()
	_timer_salvamento.name = "TimerSalvamentoLocal"
	_timer_salvamento.wait_time = 0.8
	add_child(_timer_salvamento)
	_timer_salvamento.timeout.connect(_salvar_se_pendente)
	_timer_salvamento.start()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_fechar_jogo)
	if not _persistencia.encontrado or inicial_corrigido:
		solicitar_salvamento()

func _informar_salvamento(texto: String, falhou: bool) -> void:
	if aviso_salvamento == texto and erro_salvamento == falhou:
		return
	aviso_salvamento = texto
	erro_salvamento = falhou
	estado_salvamento_alterado.emit()
	if is_instance_valid(_painel_aviso_save):
		_rotulo_aviso_save.text = texto
		_rotulo_aviso_save.add_theme_color_override("font_color", Color("ffc3ae") if falhou else Color("b7edc8"))
		_painel_aviso_save.visible = not texto.is_empty()
		_tempo_aviso_save.stop()
		if not falhou:
			_tempo_aviso_save.start()
	if falhou:
		push_warning(texto)

# E (2b.6): numa hunt cada abate/poção pede um save (~15 ms na thread principal). Com intervalo_minimo_ms > 0 o pedido
# só marca pendente e o timer de 0,8 s grava quando o intervalo venceu; quem liga (caca_sim) zera ao sair e salva.
var intervalo_minimo_ms: int = 0
var _ultimo_save_ms: int = -1000000

func solicitar_salvamento() -> void:
	if not _persistencia_pronta or _persistencia.bloqueado:
		return
	_salvamento_pendente = true
	if intervalo_minimo_ms > 0:
		return
	if not _salvamento_agendado:
		_salvamento_agendado = true
		call_deferred("_salvar_se_pendente")

func _salvar_se_pendente() -> void:
	_salvamento_agendado = false
	if _salvamento_pendente and (intervalo_minimo_ms <= 0 or Time.get_ticks_msec() - _ultimo_save_ms >= intervalo_minimo_ms):
		salvar_agora()

var perfil_saves := {"n": 0, "us": 0, "max_us": 0}   # diagnóstico: quantos saves e quanto custaram

func salvar_agora() -> bool:
	if not _persistencia_pronta:
		return false
	var _t0 := Time.get_ticks_usec()
	_ultimo_save_ms = Time.get_ticks_msec()
	var ok: bool = _persistencia.salvar(estado)
	var _dt := Time.get_ticks_usec() - _t0
	perfil_saves["n"] += 1
	perfil_saves["us"] += _dt
	perfil_saves["max_us"] = maxi(int(perfil_saves["max_us"]), _dt)
	if not ok:
		_informar_salvamento(_persistencia.erro, true)
		return false
	_salvamento_pendente = false
	if erro_salvamento:
		_informar_salvamento("Progresso salvo.", false)
	return true

func _fechar_jogo() -> void:
	if _persistencia.bloqueado:
		get_tree().quit()
		return
	if salvar_agora():
		get_tree().quit()
	else:
		_informar_salvamento("Não foi possível salvar. O jogo permanece aberto para preservar o progresso desta sessão.", true)

func _criar_aviso_save() -> void:
	var camada: CanvasLayer = CanvasLayer.new()
	camada.layer = 100
	camada.name = "AvisoProgresso"
	add_child(camada)
	var tela: Control = Control.new()
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(tela)
	_painel_aviso_save = PanelContainer.new()
	_painel_aviso_save.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_painel_aviso_save.offset_left = 12
	_painel_aviso_save.offset_right = -12
	_painel_aviso_save.offset_top = -76
	_painel_aviso_save.offset_bottom = -12
	_painel_aviso_save.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color("15212bef")
	estilo.border_color = Color("9c8145")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	_painel_aviso_save.add_theme_stylebox_override("panel", estilo)
	tela.add_child(_painel_aviso_save)
	_rotulo_aviso_save = Label.new()
	_rotulo_aviso_save.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo_aviso_save.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel_aviso_save.add_child(_rotulo_aviso_save)
	_painel_aviso_save.hide()
	_tempo_aviso_save = Timer.new()
	_tempo_aviso_save.wait_time = 8.0
	_tempo_aviso_save.one_shot = true
	add_child(_tempo_aviso_save)
	_tempo_aviso_save.timeout.connect(_painel_aviso_save.hide)

func marcar_posicao_pendente() -> void:
	if _persistencia_pronta and not _persistencia.bloqueado:
		_salvamento_pendente = true
