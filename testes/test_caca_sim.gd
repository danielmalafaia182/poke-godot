extends SceneTree
## Fluxo jogável da fase 2, de ponta a ponta, com o save ISOLADO (rodar com testes/rodar.sh ou rodar_janela.sh, que
## trocam o APPDATA: o save real nunca é tocado):
##   cidade → mapa-múndi (_selecionar_registro "Rhydon", o mesmo caminho do clique) → cena caca_sim.tscn com o mapa real
##   → simulação em processo (acelerada) → "Voltar para a cidade" → cidade.tscn.
## Confere no EstadoJogo: XP do treinador e do Pokémon, loot no inventário, poções e bolas gastas, HP do time gravado.

const ESPECIES: Script = preload("res://especies_importadas.gd")
const XP: Script = preload("res://sim/regras.gd")

var falhas := 0
var total := 0
var etapa := 0
var quadros := 0
var caca: Node
var antes := {}
var venusaur: DadosPokemon
var registro_ref: Dictionary = {}
var motivo_fim := ""
var args := {"segundos_sim": "180", "velocidade": "30", "captura": "", "medir": "0"}
var tempos := PackedFloat64Array()
var _us := 0
var _t_medida := 0.0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			args[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	var ej = get_root().get_node_or_null("EstadoJogo")
	checar(ej != null, "autoload EstadoJogo carregado (save isolado)", ProjectSettings.globalize_path("user://"))
	if ej == null:
		quit(1)
		return
	# time de teste: o Venusaur das gravações (IVs 26/5/4/18/17/28, Q 0,835) no nível 120, como líder
	venusaur = DadosPokemon.new()
	venusaur.especie = ESPECIES.obter_especies()["Venusaur"]
	venusaur.experiencia_total = XP.xp_total_para_nivel(120)
	venusaur.iv_hp = 26; venusaur.iv_atk = 5; venusaur.iv_def = 4; venusaur.iv_sp_atk = 18; venusaur.iv_sp_def = 17; venusaur.iv_spd = 28
	venusaur.qualidade = 0.835
	venusaur.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()   # formato que o save valida
	venusaur.normalizar_atributos()
	venusaur.vida_atual = venusaur.obter_vida_maxima()
	var time: Array[DadosPokemon] = [venusaur]
	for pk in ej.time_pokemon:
		if pk != null and time.size() < 3:
			time.append(pk)
	ej.colecao.time_pokemon = time
	ej.definir_perfil_treinador("Teste", 120)
	ej.definir_auto_potion(true)
	ej.inventario.estoque_pocoes[203] = 500          # Hyper Potions no save isolado
	ej.selecionar_pocao_auto_potion(0)                # "Automatic (best)": a regra medida (A)
	antes = {"xp_t": ej.experiencia_treinador_acumulada, "xp_v": venusaur.experiencia_total,
		"pocoes": ej.estoque_pocoes.duplicate(), "materiais": ej.inventario.estoque_materiais.duplicate()}
	if float(args["medir"]) > 0.0:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_position(Vector2i(0, 0))
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 5:
				checar(true, "cidade carregada")
				var mapa: Node = load("res://mapa_mundi.tscn").instantiate()
				current_scene.add_child(mapa)
				etapa = 1
				quadros = 0
		1:
			if quadros == 3:
				var mapa: Node = current_scene.get_node_or_null("MapaMundi") if current_scene.get_node_or_null("MapaMundi") else current_scene.get_child(current_scene.get_child_count() - 1)
				var reg := {}
				for r in mapa.catalogo:
					if String(r["name"]) == "Rhydon":
						reg = r
				checar(bool(reg.get("simulada", false)), "mapa-múndi marca Rhydon como hunt simulada (mapa real no snapshot)")
				mapa._selecionar_registro(reg)
				etapa = 2
				quadros = 0
		2:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn":
				caca = current_scene
				caca.velocidade = float(args["velocidade"])
				registro_ref = caca.registro
				caca.hunt_encerrada.connect(func(m): motivo_fim = m)
				checar(caca.sim != null and String(caca.sim.slug) == "rhydon", "mapa-múndi abriu a hunt do Rhydon na cena nova")
				etapa = 3
				quadros = 0
			elif quadros > 300:
				checar(false, "cena da hunt abriu", str(current_scene.scene_file_path if current_scene else "nenhuma"))
				return _fim()
		3:
			if float(args["medir"]) > 0.0 and _t_medida < float(args["medir"]):
				# medição em tempo real (velocidade 1) na cena do jogo, com HUD, 1920×1080; 3 s de aquecimento
				caca.velocidade = 1.0
				var us := Time.get_ticks_usec()
				if _us > 0:
					var dt := (us - _us) / 1000.0
					_t_medida += dt / 1000.0
					if _t_medida > 3.0:
						tempos.append(dt)
				_us = us
				if _t_medida >= float(args["medir"]):
					_relatorio_medida()
					caca.velocidade = float(args["velocidade"])
				return false
			var tick_alvo := int(float(args["segundos_sim"]) * 1000.0 / 200.0)
			if args["captura"] != "" and quadros == 60:
				get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://") + String(args["captura"]))
			if not is_instance_valid(caca):
				checar(false, "hunt seguiu até o tempo pedido", "encerrou antes: motivo %s, registro %s" % [motivo_fim, str(registro_ref)])
				return _fim()
			if caca.sim.tick >= tick_alvo or caca._encerrada:
				var r: Dictionary = caca.registro
				print("registro: ", r, " | sim: ", caca.sim.estatisticas)
				checar(int(r["abates"]) > 0, "a simulação matou selvagens na cena", str(r["abates"]))
				checar(ej.experiencia_treinador_acumulada == int(antes["xp_t"]) + int(r["xp_treinador"]) and int(r["xp_treinador"]) > 0,
					"XP do treinador aplicada no save", "%d → %d" % [int(antes["xp_t"]), ej.experiencia_treinador_acumulada])
				checar(venusaur.experiencia_total == int(antes["xp_v"]) + int(r["xp_pokemon"]) and int(r["xp_pokemon"]) > 0,
					"XP do Venusaur aplicada no save", "%d → %d" % [int(antes["xp_v"]), venusaur.experiencia_total])
				var ok_loot := not (r["loot"] as Dictionary).is_empty()
				for id in r["loot"]:
					ok_loot = ok_loot and ej.inventario.quantidade_item_bag(int(id)) == int(antes["materiais"].get(int(id), 0)) + int(r["loot"][id])
				checar(ok_loot, "loot entrou no inventário", str(r["loot"]))
				var ok_poc := true
				for id in r["pocoes"]:
					ok_poc = ok_poc and int(ej.estoque_pocoes[id]) == int(antes["pocoes"].get(id, 0)) - int(r["pocoes"][id])
				checar(ok_poc, "poções gastas pela Auto-Potion saíram do inventário", str(r["pocoes"]))
				checar(int(r["cartoes"]) >= 1 and int(r["cartoes"]) <= 30, "cartões de derrota limitados (≤ 30)", str(r["cartoes"]))
				var hp_sim := int(caca.sim.equipe[0]["hp"])
				caca.voltar_cidade()
				checar(venusaur.vida_atual == hp_sim, "HP do time gravado ao sair (sem curar)", "%d" % hp_sim)
				etapa = 4
				quadros = 0
		4:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn":
				checar(true, "voltou para a cidade")
				var salvou: bool = ej.salvar_agora()
				checar(salvou and not ej.erro_salvamento, "save (isolado) gravado depois da hunt", String(ej.aviso_salvamento))
				return _fim()
			elif quadros > 300:
				checar(false, "voltou para a cidade")
				return _fim()
	return false


func _fim() -> bool:
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true


func _relatorio_medida() -> void:
	var v := Array(tempos)
	v.sort()
	var n := v.size()
	var soma := 0.0
	for x in v:
		soma += x
	var r := {"cena": "caca_sim.tscn (rhydon)", "janela": [get_root().size.x, get_root().size.y], "quadros": n,
		"media_ms": soma / n, "p50_ms": v[int(0.5 * n)], "p95_ms": v[int(0.95 * n)], "p99_ms": v[mini(n - 1, int(0.99 * n))],
		"max_ms": v[n - 1], "acima_16_7ms": v.filter(func(x): return x > 16.7).size(),
		"gpu": RenderingServer.get_video_adapter_name(), "vsync": DisplayServer.window_get_vsync_mode()}
	print("frametime: ", JSON.stringify(r))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://") + "saida_testes/caca_sim_frametime.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
	checar(float(r["p99_ms"]) <= 16.7, "60 fps estáveis na cena do jogo em 1920×1080 (p99 ≤ 16,7 ms)", "p99 %.2f ms" % float(r["p99_ms"]))
