extends RefCounted
## Monta a configuração de uma simulação a partir de um estado inicial extraído de gravação real
## (dados/testes/estado_<...>.json, gerado por ferramentas/gravador/extrair_estado_inicial.py) + hunt-config do snapshot.

const Fontes := preload("res://sim/fontes.gd")
const Regras := preload("res://sim/regras.gd")


static func de_estado(caminho_estado: String, dados: RefCounted, semente: int, outra_hunt: String = "") -> Dictionary:
	## `outra_hunt`: reaproveita o time/inventário do estado real numa hunt diferente (testes de desenho e desempenho;
	## os selvagens, spawns e nível vêm do hunt-config e do catálogo dessa hunt).
	var est: Dictionary = Fontes.ler_json(caminho_estado)
	var slug := outra_hunt if outra_hunt != "" else String(est["slug"])
	var hc: Dictionary = Fontes.ler_hunt_config(slug)
	var hunt: Dictionary = dados.hunts.get(slug, {})
	var pd: Dictionary = est["pokeDelta"]
	var esp: Dictionary = dados.especie(int(pd["speciesId"]))
	# IVs do herói (D): os únicos que reproduzem os stats exibidos no nível do poke-delta; a soma tem de bater com ivTotal.
	var cand := Regras.estimar_ivs(esp["base"], pd["stats"], int(pd["level"]), float(pd["quality"]))
	var ivs := {}
	var soma := 0
	for k in Regras.CHAVES_STATS:
		var lista: Array = cand[k]
		if lista.size() != 1:
			push_error("IV de %s ambíguo ou impossível: %s" % [k, str(lista)])
			ivs[k] = lista[0] if lista.size() > 0 else 16
		else:
			ivs[k] = lista[0]
		soma += int(ivs[k])
	if soma != int(pd["ivTotal"]):
		push_error("Soma dos IVs estimados (%d) diferente do ivTotal (%d)" % [soma, int(pd["ivTotal"])])
	# XP do herói antes do primeiro abate gravado na hunt (A: primeiro poke-xp menos o ganho).
	var ppx: Dictionary = est["primeiroPokeXp"]
	var xp_poke := int(ppx["xp"]) - int(ppx["xpGained"])
	var pfk: Dictionary = est["primeiroFieldKill"]
	var xp_treinador := int(pfk["totalXp"]) - int(pfk["xpGained"])
	var heroi := {"id": pd["id"], "speciesId": int(pd["speciesId"]), "xp": xp_poke, "ivs": ivs, "quality": float(pd["quality"]),
		"shiny": pd.get("shiny", false), "finalStage": pd.get("finalStage", false), "leader": pd.get("leader", false),
		"starter": pd.get("starter", false), "sellValue": int(pd.get("sellValue", 0))}
	var equipe: Array = [heroi]
	var time_real: Array = est.get("time", [])
	if time_real.size() > 1:
		# A (gravação livre, 18/11): o time inteiro vem no `pokes.list`; IVs estimados dos stats exibidos (D), XP da mensagem.
		for p in time_real:
			if String(p.get("id", "")) == String(pd["id"]):
				continue
			var e2: Dictionary = dados.especie(int(p["speciesId"]))
			var c2 := Regras.estimar_ivs(e2["base"], p["stats"], int(p["level"]), float(p["quality"]))
			var iv2 := {}
			for k in Regras.CHAVES_STATS:
				iv2[k] = (c2[k] as Array)[0] if (c2[k] as Array).size() > 0 else 16
			equipe.append({"id": String(p["id"]), "speciesId": int(p["speciesId"]), "xp": int(p.get("xp", Regras.xp_total_para_nivel(int(p["level"])))),
				"ivs": iv2, "quality": float(p["quality"]), "leader": false, "starter": bool(p.get("starter", false)), "sellValue": int(p.get("sellValue", 0))})
	else:
		# Reservas: o field só mostra hp/maxHp (24/24, piso do combatHp). Espécie/stats reais não gravados:
		# F — Geodude nível 1, IV 16, Quality 1,0 (dá maxHp 24, igual ao observado). Só importam se o herói cair.
		var bt: Array = est["primeiroField"]["bossTeam"]
		for i in range(1, bt.size()):
			equipe.append({"id": "reserva-%d" % i, "speciesId": 74, "nivel": 1, "ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16},
				"quality": 1.0, "leader": false, "starter": false, "sellValue": 0})
	var base_ms := int(String(est["huntKey"]).split(":")[1])
	# maxHp de cada slot no 1º field (A): a sim sorteia indivíduos com o mesmo HP (validação de resultado por trecho)
	var maxhp_slots: Array = est.get("primeiroField", {}).get("mobsMaxHp", [])
	var balls: Dictionary = est.get("balls", {})
	return {
		"maxhp_por_slot": maxhp_slots,
		# Auto-Helper gravado (A): limite e poção fixa da Auto-Potion
		"parametros": ({"pocao_limiar": float(est["autohelper"].get("autoPotionThreshold", 50)) / 100.0}
			if est.has("autohelper") and est["autohelper"].get("autoPotionThreshold") != null else {}),
		"pocao_fixa": int(est.get("autohelper", {}).get("autoPotionItemId", 0) if est.get("autohelper", {}).get("autoPotionItemId") != null else 0),
		"slug": slug,
		"semente": semente,
		"inicio_ms": base_ms,
		"hunt_key": "%s:%d:sim%d" % [slug, base_ms, semente],
		"nivel_selvagem": int(hunt.get("nivel", 1)),
		"inicio": hc["start"],
		"spawns": hc["spawns"],
		# A: entrada nova (huntKey sem ":rN") recebe a penalidade de XP; retomada não (gravação antiga é ":r1")
		"entrada_nova": not _eh_retomada(String(est["huntKey"])),
		"vip": est.has("vip"),
		# Auto-Helper gravado quando existe (A); senão, pelo 1º catch-result (a bola da auto-captura não é balls.selected)
		"auto_catch": bool(est["autohelper"].get("autoCatch")) if est.has("autohelper") and est["autohelper"].get("autoCatch") != null else est.has("primeiroCatchResult"),
		"bola_auto_catch": int(est["autohelper"].get("autoCatchBallId")) if est.has("autohelper") and est["autohelper"].get("autoCatchBallId") != null 			else int(est.get("primeiroCatchResult", {}).get("ballId", 0)),
		"auto_catch_shiny": bool(est.get("autohelper", {}).get("autoCatchShiny", false) == true),
		"bola_auto_catch_shiny": int(est.get("autohelper", {}).get("autoCatchShinyBallId", 0) if est.get("autohelper", {}).get("autoCatchShinyBallId") != null else 0),
		"auto_catch_nomes": String(est.get("autohelper", {}).get("autoCatchNames", "") if est.get("autohelper", {}).get("autoCatchNames") != null else ""),
		"auto_potion": true,
		"equipe": equipe,
		"treinador": {"xp": xp_treinador},
		"inventario": est.get("inventario", []),
		"balls": balls,
		"cadaveres": _corpos(false, est.get("cadaveres", {})),
		"cadaveres_shiny": _corpos(true, {}),
	}


static func _eh_retomada(hunt_key: String) -> bool:
	## "rhydon:1794193271335:r3" → true; "rhydon:1794241362363" → false.
	var partes := hunt_key.split(":")
	var ult := partes[partes.size() - 1]
	return partes.size() >= 3 and ult.begins_with("r") and ult.substr(1).is_valid_int()


static func _corpos(shiny: bool, do_estado: Dictionary) -> Dictionary:
	## Tabela observada nas gravações (dados/corpos_por_especie.json, A) + o que o estado trouxer.
	var r := do_estado.duplicate()
	var d = Fontes.ler_json(Fontes.pasta_dados() + "/corpos_por_especie.json")
	if d is Dictionary:
		var g: Dictionary = d.get("shiny" if shiny else "normal", {})
		for k in g:
			r[k] = int(g[k]["corpo"])
	return r
