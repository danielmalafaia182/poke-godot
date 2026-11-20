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

var jogo_novo := false   # true quando o jogo abriu sem nenhum save (o novo jogo do original começa pela escolha do inicial)

func iniciar(fachada: Node) -> void:
	estado = fachada
	estado.iniciar_depot()
	_persistencia = SALVAMENTO_LOCAL.new()
	_criar_aviso_save()
	var carregou: bool = _persistencia.carregar(estado)
	jogo_novo = not _persistencia.encontrado
	# Novo: normaliza sem perder nível, indivíduos ou proporção de HP do save antigo.
	for pokemon in estado.time_pokemon + estado.pokemons_capturados:
		pokemon.normalizar_atributos()
	var inicial_corrigido: bool=estado.colecao.corrigir_inicial_prototipo()
	_persistencia_pronta = true
	_persistencia.aquecer()      # o que a validação lê já carregado: a gravação em thread não carrega recursos
	set_process(false)
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

# Ciclo 3: o jogo exportado usa a própria pasta (%APPDATA%/PokeIdle, use_custom_user_dir); a do projeto
# (%APPDATA%/Godot/app_userdata/PokeIdle) fica só para desenvolvimento. Na 1ª execução sem save, a cidade oferece importar
# uma CÓPIA do save do projeto (nunca move).
static func caminho_save_projeto() -> String:
	return OS.get_environment("APPDATA").replace("\\", "/") + "/Godot/app_userdata/PokeIdle/progresso_v1.json"


func save_do_projeto_disponivel() -> bool:
	var antigo := caminho_save_projeto()
	var meu := ProjectSettings.globalize_path(_persistencia.caminho)
	return jogo_novo and not FileAccess.file_exists(MARCA_JOGO_NOVO) and FileAccess.file_exists(antigo) and antigo.to_lower() != meu.replace("\\", "/").to_lower()


func importar_save_do_projeto() -> String:
	## Copia o save do projeto (e o .bak, se houver) para a pasta do jogo e carrega. "" = ok, senão o motivo.
	var antigo := caminho_save_projeto()
	var destino := ProjectSettings.globalize_path(_persistencia.caminho)
	DirAccess.make_dir_recursive_absolute(destino.get_base_dir())
	if DirAccess.copy_absolute(antigo, destino) != OK:
		return "Não foi possível copiar o save."
	if FileAccess.file_exists(antigo + ".bak"):
		DirAccess.copy_absolute(antigo + ".bak", destino + ".bak")
	var carregou: bool = _persistencia.carregar(estado)
	jogo_novo = not _persistencia.encontrado
	for pokemon in estado.time_pokemon + estado.pokemons_capturados:
		pokemon.normalizar_atributos()
	return "" if carregou else String(_persistencia.erro)


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

func _aguardando_inicial() -> bool:
	## Jogo novo de verdade (sem save, fora dos testes): até a escolha do inicial não há o que gravar. Gravar antes deixava
	## o time provisório do P04 no disco, e a próxima abertura pulava a tela de jogo novo.
	return jogo_novo and Engine.get_main_loop() != null and Engine.get_main_loop().get_script() == null


func solicitar_salvamento() -> void:
	if not _persistencia_pronta or _persistencia.bloqueado or _aguardando_inicial():
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
		_iniciar_gravacao_em_thread()

# Item 1 (fase 2b): a gravação roda numa thread de trabalho. Na thread principal fica só construir_dados (uma cópia
# nova do estado); validação, JSON, sha256, escrita do .tmp, releitura, .bak e renames vão para a thread
# (salvamento_local.gd `gravar`). Nunca há duas gravações ao mesmo tempo: um pedido durante a gravação fica pendente e
# sai quando ela termina (com o estado de então); o caminho síncrono (salvar_agora, fechar o jogo) espera a que está
# em andamento antes de gravar.
var _tarefa: int = -1
var _resultado_thread: Dictionary = {}
var perfil_saves := {"n": 0, "us": 0, "max_us": 0, "thread_us": 0, "thread_max_us": 0}   # us = thread principal

func gravando() -> bool:
	return _tarefa != -1

func _iniciar_gravacao_em_thread() -> void:
	if _aguardando_inicial():
		_salvamento_pendente = false
		return
	if not _persistencia_pronta or _persistencia.bloqueado or _tarefa != -1:
		return
	var _t0 := Time.get_ticks_usec()
	_ultimo_save_ms = Time.get_ticks_msec()
	var dados: Dictionary = _persistencia.construir_dados(estado)
	var copia: String = _persistencia.ultimo_valido
	var persistencia: RefCounted = _persistencia
	_salvamento_pendente = false
	_resultado_thread = {}
	_tarefa = WorkerThreadPool.add_task(func():
		var t := Time.get_ticks_usec()
		var r: Dictionary = persistencia.gravar(dados, copia)
		r["thread_us"] = Time.get_ticks_usec() - t
		_resultado_thread = r)
	_contar(Time.get_ticks_usec() - _t0)
	set_process(true)

func _process(_delta: float) -> void:
	if _tarefa == -1:
		set_process(false)
		return
	if WorkerThreadPool.is_task_completed(_tarefa):
		_concluir_thread()

func _concluir_thread() -> bool:
	WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	var r: Dictionary = _resultado_thread
	perfil_saves["thread_us"] += int(r.get("thread_us", 0))
	perfil_saves["thread_max_us"] = maxi(int(perfil_saves["thread_max_us"]), int(r.get("thread_us", 0)))
	return _aplicar(r)

func _aplicar(r: Dictionary) -> bool:
	if not _persistencia.aplicar_resultado(r):
		_salvamento_pendente = true          # tenta de novo no próximo ciclo do timer
		_informar_salvamento(_persistencia.erro, true)
		return false
	if erro_salvamento:
		_informar_salvamento("Progresso salvo.", false)
	return true

func _contar(us: int) -> void:
	perfil_saves["n"] += 1
	perfil_saves["us"] += us
	perfil_saves["max_us"] = maxi(int(perfil_saves["max_us"]), us)

func salvar_agora() -> bool:
	## Síncrono: espera a gravação em andamento (se houver) e grava o estado atual na thread principal.
	if not _persistencia_pronta:
		return false
	if _aguardando_inicial():
		return true
	if _tarefa != -1:
		_concluir_thread()
	if _persistencia.bloqueado:
		return false
	var _t0 := Time.get_ticks_usec()
	_ultimo_save_ms = Time.get_ticks_msec()
	_salvamento_pendente = false
	var ok: bool = _aplicar(_persistencia.gravar(_persistencia.construir_dados(estado), _persistencia.ultimo_valido))
	_contar(Time.get_ticks_usec() - _t0)
	return ok

const PASTA_BACKUPS := "user://backups"
const MARCA_JOGO_NOVO := "user://jogo_novo_pedido"   # depois de "Novo jogo": não oferecer importar o save do projeto


func pedir_jogo_novo(reiniciar: bool = true) -> Dictionary:
	## Ciclo 5, item 98 ("Novo jogo" nas Configurações). Grava o estado atual, copia o save (e o .bak) para
	## user://backups/progresso_<data>_<hora>.json, confere a cópia byte a byte e só então apaga o save. O jogo reinicia
	## como numa instalação nova (escolha do inicial), sem nada do jogo anterior. {backup, bak} ou {erro} (nada apagado).
	salvar_agora()
	if _tarefa != -1:
		_concluir_thread()
	var origem: String = _persistencia.caminho
	var r := {}
	if FileAccess.file_exists(origem):
		DirAccess.make_dir_recursive_absolute(PASTA_BACKUPS)
		var carimbo := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		var destino := "%s/progresso_%s.json" % [PASTA_BACKUPS, carimbo]
		var n := 1
		while FileAccess.file_exists(destino):
			n += 1
			destino = "%s/progresso_%s_%d.json" % [PASTA_BACKUPS, carimbo, n]
		if DirAccess.copy_absolute(origem, destino) != OK or FileAccess.get_file_as_bytes(origem) != FileAccess.get_file_as_bytes(destino):
			return {"erro": "Não foi possível fazer o backup do save. Nada foi apagado."}
		r["backup"] = destino
		if FileAccess.file_exists(origem + ".bak"):
			if DirAccess.copy_absolute(origem + ".bak", destino + ".bak") == OK:
				r["bak"] = destino + ".bak"
	_persistencia.bloqueado = true    # daqui até reiniciar, nada grava por cima
	for f in [origem, origem + ".bak", origem + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var m := FileAccess.open(MARCA_JOGO_NOVO, FileAccess.WRITE)
	if m != null:
		m.store_string(String(r.get("backup", "")))
		m.close()
	if reiniciar:
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
		get_tree().quit()
	return r


func _exit_tree() -> void:
	if _tarefa != -1:
		_concluir_thread()

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
