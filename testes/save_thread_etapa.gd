extends SceneTree
## Etapas do teste do save em thread (driver: testes/test_save_thread.py, que isola o APPDATA e coloca/confere arquivos).
##   --modo antigo    : o save antigo (posto pelo driver) carrega; grava em thread; confere o arquivo; exclusividade;
##                      custo na thread principal (thread × síncrono).
##   --modo martelar  : grava sem parar (XP do treinador sobe 1 por gravação) e imprime "SALVO <xp>" a cada conclusão;
##                      o driver mata o processo num instante aleatório.
##   --modo conferir  : carrega e imprime "CARREGADO <xp> <bloqueado> <aviso>".

var args := {"modo": "antigo"}
var falhas := 0
var total := 0
var ej: Node
var co: Node


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size() - 1):
		if a[i].begins_with("--"):
			args[a[i].substr(2)] = a[i + 1]
	call_deferred("executar")


func _encher_box(n: int) -> void:
	# save grande: gravações mais longas (mais chance de o processo morrer no meio)
	while ej.pokemons_capturados.size() < n:
		var p := DadosPokemon.new()
		p.especie = ej.time_pokemon[0].especie
		p.iv_hp = 10; p.iv_atk = 11; p.iv_def = 12; p.iv_sp_atk = 13; p.iv_sp_def = 14; p.iv_spd = 15
		p.qualidade = 1.2
		p.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
		ej.pokemons_capturados.append(p)


func _esperar_thread() -> void:
	while co.gravando():
		await process_frame


func executar() -> void:
	ej = root.get_node("EstadoJogo")
	co = ej.salvamento
	var modo := String(args["modo"])
	if modo == "conferir":
		print("CARREGADO %d %s %s" % [ej.experiencia_treinador_acumulada, str(co._persistencia.bloqueado), co.aviso_salvamento.replace(" ", "_")])
		quit(0)
		return
	if modo == "martelar":
		_encher_box(400)
		var xp: int = ej.experiencia_treinador_acumulada
		while true:
			xp += 1
			ej.experiencia_treinador_acumulada = xp
			print("INICIO %d" % xp)
			co._iniciar_gravacao_em_thread()
			await _esperar_thread()
			print("SALVO %d" % xp)
		return
	# --- antigo
	var Loot = load("res://regras_loot.gd")
	checar(not co._persistencia.bloqueado and co._persistencia.encontrado, "save antigo carregado (sem bloqueio)", co.aviso_salvamento)
	var mats_antes: Dictionary = ej.inventario.estoque_materiais.duplicate()
	var depot_antes: Dictionary = ej.itens_depot.duplicate()
	checar(int(mats_antes.get(39, 0)) == 120 and int(mats_antes.get(1000002, 0)) == 3, "materiais do save antigo no inventário", str(mats_antes))
	ej.inventario.estoque_materiais[39] = 121           # muda algo para o arquivo novo ser diferente
	_encher_box(300)
	# custo na thread principal: síncrono × thread (média de 5)
	var sinc := 0
	for i in 5:
		var t := Time.get_ticks_usec()
		co.salvar_agora()
		sinc += Time.get_ticks_usec() - t
	var princ := 0
	for i in 5:
		var t := Time.get_ticks_usec()
		co._iniciar_gravacao_em_thread()
		princ += Time.get_ticks_usec() - t
		await _esperar_thread()
	checar(princ * 3 < sinc, "gravação em thread tira a maior parte do custo da thread principal",
		"thread principal %d µs × síncrono %d µs (média de 5, box com 300)" % [princ / 5, sinc / 5])
	var lido: Dictionary = co._persistencia.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json"))
	checar(lido.has("dados") and int(lido["dados"]["materiais"].get("39", 0)) == 121 and (lido["dados"]["box"] as Array).size() == 300,
		"arquivo gravado pela thread decodifica e tem o estado novo", str(lido.get("erro", "")))
	checar(not FileAccess.file_exists("user://progresso_v1.json.tmp") and FileAccess.file_exists("user://progresso_v1.json.bak"),
		"sem .tmp sobrando; cópia .bak presente")
	# exclusividade: muitos pedidos seguidos durante gravações
	var Salv = load("res://salvamento_local.gd")
	Salv.max_gravacoes_simultaneas = 0
	for i in 40:
		ej.inventario.estoque_materiais[39] = 200 + i
		co._iniciar_gravacao_em_thread()      # ignorado se já houver uma em andamento
		co.solicitar_salvamento()
		if i % 7 == 0:
			co.salvar_agora()                 # síncrono no meio: espera a da thread
		await process_frame
	await _esperar_thread()
	co.salvar_agora()
	checar(Salv.max_gravacoes_simultaneas == 1, "nunca duas gravações ao mesmo tempo", "máximo simultâneo %d" % Salv.max_gravacoes_simultaneas)
	lido = co._persistencia.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json"))
	checar(lido.has("dados") and int(lido["dados"]["materiais"].get("39", 0)) == 239, "o último estado é o que fica no disco",
		str(lido.get("dados", {}).get("materiais", {}).get("39", "?")))
	checar(int(lido["dados"]["depot"].get("126", 0)) == int(depot_antes.get(126, -1)), "depot do save antigo preservado")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
