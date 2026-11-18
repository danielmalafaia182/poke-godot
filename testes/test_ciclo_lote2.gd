extends SceneTree
## Fase 4, lote 2 — ciclo na cena, com save ISOLADO (rodar com testes/rodar.sh):
##   cidade → hunt do Rhydon (Tipo do Dia e Streak na simulação) → abates contam para o Streak → Zzz (amostra de 5 min)
##   → save com a soneca → "volta" 2 h depois: relatório e coleta (50%) → regra da sessão ao carregar → investir ponto.

const ESPECIES: Script = preload("res://especies_importadas.gd")
const XP: Script = preload("res://sim/regras.gd")

var falhas := 0
var total := 0
var etapa := 0
var quadros := 0
var caca: Node
var venusaur: DadosPokemon


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var ej = get_root().get_node("EstadoJogo")
	ej.iniciar_depot()
	venusaur = DadosPokemon.new()
	venusaur.especie = ESPECIES.obter_especies()["Venusaur"]
	venusaur.experiencia_total = XP.xp_total_para_nivel(120)
	for c in ["iv_hp", "iv_atk", "iv_def", "iv_sp_atk", "iv_sp_def", "iv_spd"]:
		venusaur.set(c, 20)
	venusaur.qualidade = 0.9
	venusaur.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
	venusaur.normalizar_atributos()
	venusaur.vida_atual = venusaur.obter_vida_maxima()
	var time: Array[DadosPokemon] = [venusaur, ej.pokemon_inicial]
	ej.colecao.time_pokemon = time
	ej.selecionar_lider(venusaur)
	ej.definir_auto_potion(true)
	ej.inventario.estoque_pocoes[203] = 300
	ej.selecionar_pocao_auto_potion(0)
	ej.streak = {"totalKills": 990, "spent": {"exp": 0, "loot": 0, "shiny": 0}}
	ej.ouro = 30000
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 5:
				var mapa: Node = load("res://mapa_mundi.tscn").instantiate()
				current_scene.add_child(mapa)
				etapa = 1
				quadros = 0
		1:
			if quadros == 3:
				var mapa: Node = current_scene.get_child(current_scene.get_child_count() - 1)
				# Desde 18/11 o mapa cobra o nível do treinador (C): a hunt do Rhydon é nível 80.
				var estado = get_root().get_node("EstadoJogo")
				estado.definir_perfil_treinador(estado.nome_treinador, maxi(80, estado.nivel_treinador))
				for r in mapa.catalogo:
					if String(r["name"]) == "Rhydon":
						mapa._selecionar_registro(r)
				etapa = 2
				quadros = 0
		2:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn":
				caca = current_scene
				caca.velocidade = 30.0
				var ev: Array = caca.sim.cfg.get("eventos", [])
				checar(ev.size() == 1 and String(ev[0]["key"]) == "type-of-day" and caca.sim.cfg.has("streak"),
					"a hunt recebe o Tipo do Dia e o Streak (cfg)", str(ev))
				checar(caca.get_node_or_null("Interface/BotaoSoneca") != null, "botão Zzz na HUD da hunt")
				etapa = 3
				quadros = 0
			elif quadros > 300:
				checar(false, "cena da hunt abriu")
				return _fim()
		3:
			if caca.sim.tick >= int(60 * 1000 / 200) or caca._encerrada:
				var abates := int(caca.registro["abates"])
				checar(abates > 0 and int(ej.streak["totalKills"]) == 990 + abates, "abates da hunt contam para o Streak", "%d abates → %d" % [abates, int(ej.streak["totalKills"])])
				var soma_esp := 0
				for k in ej.streak.get("bySpecies", {}):
					soma_esp += int(ej.streak["bySpecies"][k])
				var soma_diar := 0
				for k in ej.diarias.get("contagem", {}).get("kill", {}):
					soma_diar += int(ej.diarias["contagem"]["kill"][k])
				checar(soma_esp == abates and soma_diar == abates, "abates da hunt contam por espécie no Streak e nas diárias/tarefas (A: lista kills)", "%d / %d / %d" % [abates, soma_esp, soma_diar])
				var xp_t: int = ej.experiencia_treinador_acumulada
				var erro: String = caca.soneca()
				var am: Dictionary = ej.soneca.get("amostra", {})
				checar(erro.is_empty() and not ej.soneca.is_empty() and int(am.get("kills", 0)) > 0 and int(am.get("sampleMs", 0)) == 300000,
					"Zzz: amostra de 5 min gravada na soneca (C)", "%d abates na amostra" % int(am.get("kills", 0)))
				checar(ej.experiencia_treinador_acumulada == xp_t, "a amostra não entrega XP na hora (entra quando os 5 min se completam)")
				checar(ej.salvar_agora(), "save com a soneca gravado")
				var lido: Dictionary = preload("res://salvamento_local.gd").new().decodificar(FileAccess.get_file_as_string("user://progresso_v1.json"))
				checar(lido.has("dados") and not (lido["dados"].get("soneca", {}) as Dictionary).is_empty() and int(lido["dados"]["streak"]["totalKills"]) == int(ej.streak["totalKills"]),
					"save relido: soneca e Streak", str(lido.get("erro", "")))
				# volta 2 h depois do fim da amostra
				var agora: int = int(ej.soneca["fim"]) + 2 * 3600
				var xp_t0: int = ej.experiencia_treinador_acumulada
				var xp_v0: int = venusaur.experiencia_total
				var rel: Dictionary = ej.relatorio_offline(agora)
				checar(ej.experiencia_treinador_acumulada == xp_t0 + int(am["xpSample"]) and venusaur.experiencia_total == xp_v0 + int(am["pokeXpSample"])
					and int(ej.streak["totalKills"]) == 990 + abates + int(am["kills"]),
					"ao abrir depois dos 5 min: a amostra entra (XP do treinador e do Venusaur, abates no Streak; A: antes da coleta)")
				checar(rel.get("report") != null and int(rel["report"]["seconds"]) == 7200 and int(rel["report"]["xp50"]) > 0, "relatório da soneca: 2 h fora", str(rel.get("report", {}).get("xp50", -1)))
				var xp_v: int = venusaur.experiencia_total
				var xp_t1: int = ej.experiencia_treinador_acumulada
				var c: Dictionary = ej.coletar_offline(agora)
				checar(not c.has("erro") and ej.experiencia_treinador_acumulada == xp_t1 + int(c["xpGained"]) and venusaur.experiencia_total == xp_v + int(c["pokeXpGained"])
					and int(c["xpGained"]) == int(rel["report"]["xp50"]) and int(c["totalXp"]) == ej.experiencia_treinador_acumulada and ej.soneca.is_empty(),
					"coleta: só os 50% do tempo fora, no treinador e no Venusaur; soneca zerada (A, G6)")
				checar(int(ej.streak["totalKills"]) == 990 + abates + int(am["kills"]), "abates da amostra contam para o Streak; os estimados não (F)", str(ej.streak["totalKills"]))
				# regra da sessão ao carregar o save
				var sl = preload("res://salvamento_local.gd").new()
				var d: Dictionary = sl.construir_dados(ej)
				d["salvo_em_unix"] = int(Time.get_unix_time_from_system()) - 3600
				d["soneca"] = {}
				sl._restaurar(ej, d)
				checar(ej.sessao_expirada, "fechado 1 h sem soneca: sessão expirada (regra do usuário)")
				d["salvo_em_unix"] = int(Time.get_unix_time_from_system()) - 600
				sl._restaurar(ej, d)
				checar(not ej.sessao_expirada, "fechado 10 min: sessão viva")
				d["salvo_em_unix"] = int(Time.get_unix_time_from_system()) - 3600
				d["soneca"] = {"inicio": int(Time.get_unix_time_from_system()) - 3600, "fim": int(Time.get_unix_time_from_system()) - 3300, "amostra": am}
				sl._restaurar(ej, d)
				checar(not ej.sessao_expirada, "fechado 1 h com soneca valendo: sessão viva (E)")
				# investir um ponto de Streak
				ej.soneca = {}
				ej.ouro = 30000
				var info: Dictionary = ej.streak_info()
				var erro_s: String = ej.gastar_streak("exp")
				checar(int(info["available"]) >= 1 and erro_s.is_empty() and ej.ouro == 5000 and int(ej.efeitos_streak()["exp"]) == 1,
					"investe 1 ponto na trilha EXP por 25.000 (C)", erro_s)
				return _fim()
	return false


func _fim() -> bool:
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
