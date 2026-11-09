extends SceneTree
## Servidor headless da simulação para a ponte com o cliente original (poke-local).
##
## Escuta TCP em 127.0.0.1:<porta>, uma conexão por vez, JSON por linha nos dois sentidos.
## Recebe os comandos da hunt que o cliente manda pelo WebSocket (encaminhados pela ponte Python):
##   enter-hunt {slug, resume}, leave-hunt, field-get, view {hc, hr}
## e devolve, linha a linha, as mensagens que a simulação emite (field-init, field, field-kill, poke-xp,
## catch-result, poke-delta, inventory, balls, auto-heal, field-none), já no formato do servidor original.
##
## A simulação continua pura (sim/): este script só dá o relógio real — um passo() a cada tick_ms — e faz o
## serverNow começar no horário real da entrada (o cliente interpola por stepStartAt − serverNow).
## Cada conexão nova começa sem hunt ativa (como uma conexão WS nova no servidor local).
##
## Uso: godot --headless --path . --script res://ponte/servidor_sim.gd -- --porta 8765 \
##        --estado dados/testes/estado_rhydon_venusaur.json --semente 1

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Json := preload("res://sim/json_canonico.gd")

var args := {"porta": "8765", "estado": "dados/testes/estado_rhydon_venusaur.json", "semente": "1"}
var dados: RefCounted
var servidor := TCPServer.new()
var cliente: StreamPeerTCP = null
var buffer := ""
var sim: RefCounted = null
var proximo_tick_ms := 0
var intencoes: Array = []
var enviadas := 0
var instancias := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			args[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	dados = DadosJogo.carregar()
	var erro := servidor.listen(int(args["porta"]), "127.0.0.1")
	if erro != OK:
		printerr("servidor_sim: não consegui escutar na porta %s (erro %d)" % [args["porta"], erro])
		quit(1)
		return
	print("servidor_sim: escutando em 127.0.0.1:%s (estado %s, semente %s)" % [args["porta"], args["estado"], args["semente"]])


func _process(_delta: float) -> bool:
	if servidor.is_connection_available():
		var novo := servidor.take_connection()
		if cliente != null:
			cliente.disconnect_from_host()
		cliente = novo
		cliente.set_no_delay(true)
		buffer = ""
		sim = null
		print("servidor_sim: ponte conectada")
	if cliente == null:
		OS.delay_msec(5)
		return false
	cliente.poll()
	var st := cliente.get_status()
	if st != StreamPeerTCP.STATUS_CONNECTED:
		if st != StreamPeerTCP.STATUS_CONNECTING:
			print("servidor_sim: ponte desconectou (%d mensagens enviadas)" % enviadas)
			cliente = null
			sim = null
		return false
	var n := cliente.get_available_bytes()
	if n > 0:
		var r := cliente.get_partial_data(n)
		if r[0] == OK:
			buffer += (r[1] as PackedByteArray).get_string_from_utf8()
			while buffer.find("\n") >= 0:
				var k := buffer.find("\n")
				var linha := buffer.substr(0, k).strip_edges()
				buffer = buffer.substr(k + 1)
				if linha != "":
					_comando(linha)
	_ticks()
	OS.delay_msec(2)
	return false


func _agora_real_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _enviar(msgs: Array) -> void:
	if cliente == null:
		return
	for m in msgs:
		# a simulação devolve {t, msg} (t = serverNow da emissão); pelo fio vai só a mensagem
		var corpo: Dictionary = m["msg"] if m.has("msg") and m.has("t") else m
		cliente.put_data((Json.texto(corpo) + "\n").to_utf8_buffer())
		enviadas += 1


func _comando(linha: String) -> void:
	var c = JSON.parse_string(linha)
	if typeof(c) != TYPE_DICTIONARY:
		_enviar([{"type": "error", "message": "servidor_sim: linha não é um objeto JSON"}])
		return
	var tipo := String(c.get("type", ""))
	match tipo:
		"enter-hunt":
			var slug := String(c.get("slug", ""))
			if sim != null and not sim.encerrada and bool(c.get("resume", false)) and sim.slug == slug:
				_enviar([sim.msg_field_init(), sim.msg_field_atual()])
				return
			_nova_hunt(slug)
		"leave-hunt":
			if sim != null and not sim.encerrada:
				intencoes.append({"type": "leave-hunt"})
				_enviar(sim.passo(intencoes))   # field-none imediato (o passo com leave-hunt não avança o tick)
				intencoes = []
			else:
				_enviar([{"type": "field-none"}])
		"field-get":
			if sim != null and not sim.encerrada:
				_enviar([sim.msg_field_atual()])
			else:
				_enviar([{"type": "field-none"}])
		"view":
			pass   # A: o cliente manda {hc: 27, hr: 15}, que é a visão já usada em PARAMETROS (visao_meia_*)
		_:
			_enviar([{"type": "error", "message": "servidor_sim: comando não tratado: " + tipo}])


func _nova_hunt(slug: String) -> void:
	var cfg := Cenario.de_estado(_absoluto(String(args["estado"])), dados, int(args["semente"]) + instancias)
	if String(cfg["slug"]) != slug:
		_enviar([{"type": "error", "message": "servidor_sim: só há estado inicial para a hunt '%s' (pedida: '%s')" % [cfg["slug"], slug]}])
		return
	instancias += 1
	var agora := _agora_real_ms()
	cfg["inicio_ms"] = agora
	cfg["hunt_key"] = "%s:%d:ponte%d" % [slug, agora, instancias]
	cfg["entrada_nova"] = true   # A: entrar pelo mapa é entrada nova (penalidade de XP nos primeiros abates)
	var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
	sim = Simulacao.new(cfg, dados, mapa)
	_enviar(sim.iniciar())
	proximo_tick_ms = Time.get_ticks_msec() + int(sim.p.tick_ms)
	print("servidor_sim: hunt %s iniciada (%s)" % [slug, cfg["hunt_key"]])


func _ticks() -> void:
	if sim == null or sim.encerrada:
		return
	var agora := Time.get_ticks_msec()
	var passo := int(sim.p.tick_ms)
	if agora - proximo_tick_ms > 5000:
		proximo_tick_ms = agora   # processo ficou parado (ex.: suspensão): não despeja minutos de ticks de uma vez
	while agora >= proximo_tick_ms:
		_enviar(sim.passo(intencoes))
		intencoes = []
		proximo_tick_ms += passo


func _absoluto(c: String) -> String:
	return c if c.is_absolute_path() else Fontes.raiz_projeto() + "/" + c
