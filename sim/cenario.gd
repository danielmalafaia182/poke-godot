extends RefCounted
## Monta a configuração de uma simulação a partir de um estado inicial extraído de gravação real
## (dados/testes/estado_<...>.json, gerado por ferramentas/gravador/extrair_estado_inicial.py) + hunt-config do snapshot.

const Fontes := preload("res://sim/fontes.gd")
const Regras := preload("res://sim/regras.gd")


static func de_estado(caminho_estado: String, dados: RefCounted, semente: int) -> Dictionary:
	var est: Dictionary = Fontes.ler_json(caminho_estado)
	var slug := String(est["slug"])
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
	# Reservas: o field só mostra hp/maxHp (24/24, piso do combatHp). Espécie/stats reais não gravados:
	# F — Geodude nível 1, IV 16, Quality 1,0 (dá maxHp 24, igual ao observado). Só importam se o herói cair.
	var bt: Array = est["primeiroField"]["bossTeam"]
	for i in range(1, bt.size()):
		equipe.append({"id": "reserva-%d" % i, "speciesId": 74, "nivel": 1, "ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16},
			"quality": 1.0, "leader": false, "starter": false, "sellValue": 0})
	var base_ms := int(String(est["huntKey"]).split(":")[1])
	var balls: Dictionary = est.get("balls", {})
	return {
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
		"auto_catch": est.has("primeiroCatchResult"),
		"bola_auto_catch": int(est.get("primeiroCatchResult", {}).get("ballId", 0)),  # A: não é balls.selected
		"auto_potion": true,
		"equipe": equipe,
		"treinador": {"xp": xp_treinador},
		"inventario": est.get("inventario", []),
		"balls": balls,
		"cadaveres": est.get("cadaveres", {}),
	}


static func _eh_retomada(hunt_key: String) -> bool:
	## "rhydon:1794193271335:r3" → true; "rhydon:1794241362363" → false.
	var partes := hunt_key.split(":")
	var ult := partes[partes.size() - 1]
	return partes.size() >= 3 and ult.begins_with("r") and ult.substr(1).is_valid_int()
