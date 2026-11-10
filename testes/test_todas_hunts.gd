extends SceneTree
## Varredura de escala (2b.6): entra em cada hunt pela cena nova (caca_sim.tscn, entrada por slug), em modo acelerado,
## por N segundos simulados, e imprime uma linha por hunt:
##   HUNT_INICIO <slug>
##   HUNT_RESULTADO {slug, carga_ms, origem_cache, abates, xp, motivo_fim, ticks, quadros, pior_ms, p99_ms, …}
## O wrapper testes/test_todas_hunts.py atribui as linhas de erro do log à hunt que estava rodando e gera o relatório.
## Save ISOLADO (rodar_janela.sh). Time de teste (E): Venusaur IV 32, Quality 1,8, nível 3 × nível da hunt + 50, poções à vontade.
## Uso: testes/rodar_janela.sh res://testes/test_todas_hunts.gd --segundos 60 --velocidade 30 [--slugs a,b,c]

const ESPECIES: Script = preload("res://especies_importadas.gd")
const XP: Script = preload("res://sim/regras.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
# caca_sim.gd usa o autoload EstadoJogo: não pode ser pré-carregado no topo de um script de SceneTree (o autoload
# ainda não existe quando o script compila). Carregado em _initialize.

var args := {"segundos": "60", "velocidade": "30", "slugs": "", "inicio": "0", "quantos": "100000"}
var fila: Array = []
var atual := ""
var etapa := 0
var t_pedido := 0
var carga_ms := -1
var tempos := PackedFloat64Array()
var _us := 0
var quadros_desde := 0
var render_soma := {"draw_calls": 0.0, "objetos": 0.0, "primitivas": 0.0, "processo_ms": 0.0, "n": 0}
var render_tempos := {"cpu": [], "gpu": [], "script": []}
var _us_script := 0
var _somas_ant := {}
var lentos: Array = []          # composição dos quadros acima de 12 ms (até 40 por hunt)
var caca: Node
var venusaur: DadosPokemon
var dados: RefCounted


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			args[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	dados = DadosJogo.carregar()
	if String(args["slugs"]) != "":
		fila = Array(String(args["slugs"]).split(",", false))
	else:
		fila = dados.hunts.keys()
		fila.sort()
	fila = fila.slice(int(args["inicio"]), int(args["inicio"]) + int(args["quantos"]))
	load("res://caca_sim.gd").sem_trocar_cena_global = true
	if OS.get_environment("PAGINAS_ARRAY") != "":       # 1 = Texture2DArray, 0 = uma textura por página
		load("res://render/mapa_renderizador.gd").usar_array = OS.get_environment("PAGINAS_ARRAY") == "1"
	var ej = get_root().get_node("EstadoJogo")
	venusaur = DadosPokemon.new()
	venusaur.especie = ESPECIES.obter_especies()["Venusaur"]
	# time de teste (E): forte o bastante para a hunt rodar os 60 s em qualquer área (Orre 500, Nightmare 2000)
	venusaur.iv_hp = 32; venusaur.iv_atk = 32; venusaur.iv_def = 32; venusaur.iv_sp_atk = 32; venusaur.iv_sp_def = 32; venusaur.iv_spd = 32
	venusaur.qualidade = 1.8
	venusaur.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	var time: Array[DadosPokemon] = [venusaur]
	for pk in ej.time_pokemon:
		if pk != null and time.size() < 3:
			time.append(pk)
	ej.colecao.time_pokemon = time
	ej.selecionar_lider(venusaur)
	ej.definir_auto_potion(true)
	ej.selecionar_pocao_auto_potion(0)
	RenderingServer.viewport_set_measure_render_time(get_root().get_viewport_rid(), true)
	RenderingServer.frame_pre_draw.connect(func(): _us_script = Time.get_ticks_usec() - _us)
	print("HUNTS_TOTAL %d" % fila.size())
	_proxima()


func _proxima() -> void:
	if fila.is_empty():
		print("HUNTS_FIM")
		quit(0)
		return
	atual = String(fila.pop_front())
	var ej = get_root().get_node("EstadoJogo")
	var nivel_hunt := int(dados.hunts[atual].get("nivel", 1))
	venusaur.experiencia_total = XP.xp_total_para_nivel(mini(100000, nivel_hunt * 3 + 50))
	venusaur.vida_atual = -1
	venusaur.normalizar_atributos()
	venusaur.vida_atual = venusaur.obter_vida_maxima()
	ej.inventario.estoque_pocoes[203] = 999
	ej.inventario.estoque_pocoes[204] = 999
	ej.especie_caca = null
	ej.slug_caca = atual
	print("HUNT_INICIO " + atual)
	tempos = PackedFloat64Array()
	render_soma = {"draw_calls": 0.0, "objetos": 0.0, "primitivas": 0.0, "processo_ms": 0.0, "n": 0}
	render_tempos = {"cpu": [], "gpu": [], "script": []}
	lentos = []
	_somas_ant = {}
	carga_ms = -1
	quadros_desde = 0
	caca = null
	t_pedido = Time.get_ticks_msec()
	change_scene_to_file("res://caca_sim.tscn")
	etapa = 1


func _process(_d: float) -> bool:
	var us := Time.get_ticks_usec()
	var dt := (us - _us) / 1000.0
	_us = us
	if etapa >= 1 and Time.get_ticks_msec() - t_pedido > 120000:
		_relatorio("tempo esgotado (120 s)")
		return false
	if etapa == 1:
		if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn" and current_scene != caca:
			caca = current_scene
			if not "sim" in caca or caca.sim == null:
				_relatorio("cena sem simulação")
				return false
			caca.velocidade = float(args["velocidade"])
			etapa = 2
	elif etapa == 2:
		quadros_desde += 1
		if quadros_desde == 2:
			carga_ms = Time.get_ticks_msec() - t_pedido      # do pedido de troca de cena até o 1º quadro desenhado
		elif quadros_desde > 10:
			tempos.append(dt)                                 # os 10 primeiros quadros pagam a carga
			render_soma["draw_calls"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			render_soma["objetos"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			render_soma["primitivas"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			render_soma["processo_ms"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			render_soma["n"] += 1
			var vp := get_root().get_viewport_rid()
			render_tempos["cpu"].append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
			render_tempos["gpu"].append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			render_tempos["script"].append(_us_script / 1000.0)
			var somas := _somas()
			if dt > 12.0 and lentos.size() < 200:
				var q := {"dt": snappedf(dt, 0.01), "script": snappedf(_us_script / 1000.0, 0.01),
					"t_ms": Time.get_ticks_msec() - t_pedido, "tick": caca.sim.tick if is_instance_valid(caca) else -1}
				for k in somas:
					q[k] = snappedf((float(somas[k]) - float(_somas_ant.get(k, 0))) / 1000.0, 0.01)
				q["msgs"] = ",".join(caca.tipos_no_quadro)
				lentos.append(q)
			_somas_ant = somas
		var fim_ticks := int(float(args["segundos"]) * 1000.0 / 200.0)
		if not is_instance_valid(caca):
			_relatorio("cena liberada")
		elif caca.sim.tick >= fim_ticks or caca._encerrada:
			_relatorio("" if not caca._encerrada else "encerrou")
	return false


func _somas() -> Dictionary:
	if not is_instance_valid(caca) or caca.vista == null:
		return {}
	var pv: Dictionary = caca.vista.perfil
	var r := {"sim_msgs": caca.perfil_sim_us, "vista_laco": pv["quadro_us"], "vista_ent": pv["entidades_us"],
		"vista_placas": pv["placas_us"]}
	if caca.vista.mapa != null:
		r["mapa_drenar"] = caca.vista.mapa.perfil["drenar_us"]
		r["mapa_animar"] = caca.vista.mapa.perfil["animar_us"]
	return r


func _relatorio(obs: String) -> void:
	var v := Array(tempos)
	v.sort()
	var n := v.size()
	var r := {"slug": atual, "carga_ms": carga_ms, "quadros": n,
		"pior_ms": v[n - 1] if n > 0 else -1.0, "p99_ms": v[mini(n - 1, int(0.99 * n))] if n > 0 else -1.0, "obs": obs}
	if is_instance_valid(caca) and "sim" in caca and caca.sim != null:
		r["ticks"] = caca.sim.tick
		r["abates"] = int(caca.registro["abates"])
		r["xp"] = int(caca.registro["xp_treinador"])
		r["motivo_fim"] = "sem-reserva" if caca.sim.desmaiado else ("" if not caca._encerrada else "saida")
		r["origem_cache"] = caca.vista.mapa.origem_cache if caca.vista.mapa != null else "?"
		r["outfits_substituidos"] = caca.vista.outfits.trocas.keys()
		r["especies"] = caca.sim.mobs.map(func(m): return int(m["species_id"])).reduce(func(acc, x): return acc if acc.has(x) else acc + [x], [])
		r["cadaveres_desenhados"] = caca.vista._cadaveres.size()
		r["ajuste_inicio"] = caca.sim.ajuste_inicio
		r["tempos_carga"] = caca.tempos_carga
		var pv: Dictionary = caca.vista.perfil
		var nq := maxi(1, int(pv["n"]))
		r["perfil_us_por_quadro"] = {"sim_e_mensagens": caca.perfil_sim_us / nq, "sim_max": caca.perfil_sim_max_us,
			"vista_laco": int(pv["quadro_us"]) / nq, "vista_entidades": int(pv["entidades_us"]) / nq,
			"vista_placas_danos": int(pv["placas_us"]) / nq, "vista_max": pv["max_total_us"]}
		r["carga_mapa"] = caca.vista.mapa.tempos_carga if caca.vista.mapa != null else {}
		if caca.vista.mapa != null:
			var pm: Dictionary = caca.vista.mapa.perfil
			var nm := maxi(1, int(pm["n"]))
			r["perfil_us_por_quadro"]["mapa_drenar"] = int(pm["drenar_us"]) / nm
			r["perfil_us_por_quadro"]["mapa_drenar_max"] = pm["drenar_max_us"]
			r["perfil_us_por_quadro"]["mapa_animar"] = int(pm["animar_us"]) / nm
			r["perfil_us_por_quadro"]["mapa_animar_max"] = pm["animar_max_us"]
			r["perfil_us_por_quadro"]["mapa_animados"] = pm["animados"]
	var nr := maxi(1, int(render_soma["n"]))
	r["render_medio"] = {"draw_calls": render_soma["draw_calls"] / nr, "objetos": render_soma["objetos"] / nr,
		"primitivas": render_soma["primitivas"] / nr, "processo_ms": render_soma["processo_ms"] / nr}
	for k in render_tempos:   # média e p99 (ms) de: render na CPU (setup + viewport), na GPU, e quadro até o pré-desenho
		var v2: Array = render_tempos[k].duplicate()
		v2.sort()
		if not v2.is_empty():
			r["render_medio"][k + "_media"] = v2.reduce(func(a, x): return a + x, 0.0) / v2.size()
			r["render_medio"][k + "_p99"] = v2[mini(v2.size() - 1, int(0.99 * v2.size()))]
	r["quadros_lentos"] = lentos
	var ps: Dictionary = get_root().get_node("EstadoJogo").salvamento.perfil_saves
	r["saves"] = {"n": ps["n"], "media_us": int(ps["us"]) / maxi(1, int(ps["n"])), "max_us": ps["max_us"]}
	ps["n"] = 0; ps["us"] = 0; ps["max_us"] = 0
	print("HUNT_RESULTADO " + JSON.stringify(r))
	etapa = 0
	_proxima()
