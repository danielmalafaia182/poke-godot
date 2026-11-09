extends RefCounted
## Simulação autoritativa de uma instância de hunt, em ticks de 200 ms.
## Entrada: configuração (cenário) + intenções do cliente; saída: mensagens com os mesmos nomes e campos do servidor original.
## Sem Node, Timer, await nem relógio real: o tempo é `inicio_ms + tick * tick_ms`. Mesma semente → mesma saída.
##
## Origem de cada comportamento: ver sim/regras.gd (PARAMETROS) e a seção "Estado" do CLAUDE.md.
## Ordem dentro de um tick (E): respawns → cadáveres → herói (alvo, passo, ataque, abates) → selvagens (passo, ataque)
## → KO/troca → poção → `field` (nos ticks pares, com os hits acumulados desde o último field).

const Regras := preload("res://sim/regras.gd")
const Rng := preload("res://sim/rng.gd")

const DIRECOES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]  # (dcol, drow); retas antes das diagonais

var p: Dictionary = {}
var cfg: Dictionary = {}
var dados: RefCounted
var mapa: RefCounted
var rng: RefCounted

var tick: int = 0
var inicio_ms: int = 0
var hunt_key: String = ""
var slug: String = ""

var heroi := {}
var equipe: Array = []
var ativo: int = 0
var mobs: Array = []
var cadaveres: Array = []
var hits: Array = []
var inventario := {}            # itemId -> quantidade
var balls := {}
var treinador := {"xp": 0, "nivel": 1}
var proxima_pocao_tick: int = 0
var desmaiado: bool = false
var encerrada: bool = false
var _saida: Array = []
var _golpes_cache := {}
var estatisticas := {"abates": 0, "hits_aliado": 0, "hits_selvagem": 0, "curas": 0, "capturas": 0, "kos": 0}


func _init(config: Dictionary, dados_jogo: RefCounted, mapa_hunt: RefCounted) -> void:
	cfg = config
	dados = dados_jogo
	mapa = mapa_hunt
	p = Regras.PARAMETROS.duplicate()
	for k in cfg.get("parametros", {}):
		p[k] = cfg["parametros"][k]
	rng = Rng.new(int(cfg.get("semente", 1)))
	slug = String(cfg["slug"])
	inicio_ms = int(cfg.get("inicio_ms", 0))
	hunt_key = String(cfg.get("hunt_key", "%s:%d" % [slug, inicio_ms]))
	_montar()


# ======================================================================== montagem

func _celula(x: int, y: int) -> Vector2i:
	return Vector2i(x - mapa.min_tx, y - mapa.min_ty)  # (col, row)


func _montar() -> void:
	var ini: Dictionary = cfg["inicio"]
	var c := _celula(int(ini["x"]), int(ini["y"]))
	heroi = {"pos": c, "de": c, "passo_ms": inicio_ms, "facing": "south", "prox_passo": 0, "alvo": -1, "prox_ataque": 0, "passo_dur_ms": int(p.hero_step_ms)}
	equipe = []
	for e in cfg["equipe"]:
		equipe.append(_criar_poke(e))
	ativo = 0
	treinador["xp"] = int(cfg.get("treinador", {}).get("xp", 0))
	treinador["nivel"] = Regras.nivel_por_xp(treinador["xp"])
	inventario = {}
	for it in cfg.get("inventario", []):
		inventario[int(it["itemId"])] = int(it["quantity"])
	balls = (cfg.get("balls", {}) as Dictionary).duplicate(true)
	var nivel_selv := int(cfg.get("nivel_selvagem", 1))
	mobs = []
	var slot := 0
	for s in cfg["spawns"]:
		var sp := _celula(int(s["x"]), int(s["y"]))
		var esp: Dictionary = dados.especie(int(s["pokeId"]))
		# Indivíduo sorteado uma vez por slot e mantido nos respawns (A: maxHp constante por slot na instância).
		var ivs := Regras.sortear_ivs(rng)
		var q := Regras.sortear_qualidade(rng)
		var st := Regras.calcular_stats(esp["base"], ivs, nivel_selv, q)
		var mhp := Regras.hp_combate_selvagem(int(st["hp"]), p)
		mobs.append({"slot": slot, "especie": esp, "species_id": int(s["pokeId"]), "spawn": sp, "pos": sp, "de": sp,
			"passo_ms": inicio_ms, "facing": "south", "prox_passo": 0, "hp": mhp, "max_hp": mhp, "stats": st,
			"ivs": ivs, "qualidade": q, "nivel": nivel_selv, "dead": false, "morte_tick": -1, "prox_ataque": -1,
			"shiny": false})
		slot += 1


func _criar_poke(e: Dictionary) -> Dictionary:
	var esp: Dictionary = dados.especie(int(e["speciesId"]))
	var xp := int(e.get("xp", Regras.xp_total_para_nivel(int(e.get("nivel", 1)))))
	var nivel := Regras.nivel_por_xp(xp) if e.has("xp") else int(e.get("nivel", 1))
	var poke := e.duplicate(true)
	poke["especie"] = esp
	poke["xp"] = xp
	poke["nivel"] = nivel
	_recalcular_stats(poke)
	poke["hp"] = int(e.get("hp", poke["max_hp"]))
	return poke


func _recalcular_stats(poke: Dictionary) -> void:
	poke["stats"] = Regras.calcular_stats(poke["especie"]["base"], poke["ivs"], int(poke["nivel"]), float(poke["quality"]))
	poke["max_hp"] = Regras.hp_combate_aliado(int(poke["stats"]["hp"]))
	poke["power"] = Regras.power(poke["stats"], float(poke["quality"]))


func agora_ms() -> int:
	return inicio_ms + tick * int(p.tick_ms)


# ======================================================================== API

func iniciar() -> Array:
	## Equivale a enter-hunt: devolve field-init e o primeiro field (tick 0).
	_saida = []
	var grade: Array = []
	for linha in mapa.grade:
		grade.append(linha.duplicate())
	_emitir({"type": "field-init", "huntKey": hunt_key, "slug": slug, "rows": mapa.rows, "cols": mapa.cols,
		"minTx": mapa.min_tx, "minTy": mapa.min_ty, "grid": grade, "heroStepMs": int(p.hero_step_ms), "bike": false,
		"mobStepMs": int(p.mob_step_ms), "trainerStepMs": int(p.trainer_step_ms), "tickMs": int(p.tick_ms)})
	_emitir(_montar_field())
	return _saida


func passo(intencoes: Array = []) -> Array:
	## Avança um tick. Intenções suportadas na fase 1: {"type": "leave-hunt"}.
	_saida = []
	if encerrada:
		return _saida
	for it in intencoes:
		if String(it.get("type", "")) == "leave-hunt":
			encerrada = true
			_emitir({"type": "field-none"})
			return _saida
	tick += 1
	_respawns()
	_expirar_cadaveres()
	if not desmaiado:
		_turno_heroi()
	_turno_selvagens()
	if tick % int(p.ticks_por_field) == 0:
		_emitir(_montar_field())
		hits = []
	return _saida


func _emitir(msg: Dictionary) -> void:
	_saida.append({"t": agora_ms(), "msg": msg})


# ======================================================================== mundo

func _ocupado_por_mob(c: Vector2i, exceto_slot: int = -1) -> bool:
	for m in mobs:
		if not m["dead"] and m["slot"] != exceto_slot and m["pos"] == c:
			return true
	return false


func _livre(c: Vector2i) -> bool:
	return mapa.passavel(c.y, c.x)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _dist2(a: Vector2i, b: Vector2i) -> int:
	return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)


static func _facing(d: Vector2i, atual: String) -> String:
	# A: passo diagonal vira leste/oeste (ex.: herói 40,37 → 39,38 "east").
	if d.x > 0:
		return "east"
	if d.x < 0:
		return "west"
	if d.y > 0:
		return "south"
	if d.y < 0:
		return "north"
	return atual


func _respawns() -> void:
	var t_resp := int(p.respawn_ms) / int(p.tick_ms)
	for m in mobs:
		if m["dead"] and tick >= int(m["morte_tick"]) + t_resp:
			m["dead"] = false
			m["hp"] = m["max_hp"]
			m["pos"] = m["spawn"]
			m["de"] = m["spawn"]
			m["passo_ms"] = agora_ms() - int(p.mob_step_ms)
			m["facing"] = "south"
			m["prox_ataque"] = -1
			m["prox_passo"] = tick


func _expirar_cadaveres() -> void:
	var resto: Array = []
	for c in cadaveres:
		if tick < int(c["expira"]):
			resto.append(c)
	cadaveres = resto


# ======================================================================== herói

func _poke_ativo() -> Dictionary:
	return equipe[ativo]


func _escolher_alvo() -> int:
	# A (19 de 23 trocas): o selvagem vivo mais próximo em Chebyshev; desempate por distância euclidiana e slot (F).
	var melhor := -1
	var chave := Vector2i(1 << 30, 1 << 30)
	for m in mobs:
		if m["dead"]:
			continue
		var k := Vector2i(_cheb(m["pos"], heroi["pos"]), _dist2(m["pos"], heroi["pos"]))
		if k.x < chave.x or (k.x == chave.x and k.y < chave.y):
			chave = k
			melhor = m["slot"]
	return melhor


func _turno_heroi() -> void:
	var alvo := int(heroi["alvo"])
	if alvo < 0 or mobs[alvo]["dead"]:
		alvo = _escolher_alvo()
		heroi["alvo"] = alvo
	if alvo < 0:
		return
	var m: Dictionary = mobs[alvo]
	if _cheb(m["pos"], heroi["pos"]) > 1 and tick >= int(heroi["prox_passo"]):
		_passo_heroi(m["pos"])
	if _cheb(m["pos"], heroi["pos"]) <= 1 and tick >= int(heroi["prox_ataque"]):
		_ataque_aliado(m)


func _passo_heroi(destino: Vector2i) -> void:
	var prox := _primeiro_passo_bfs(heroi["pos"], destino)
	if prox == heroi["pos"]:
		return
	var d: Vector2i = prox - heroi["pos"]
	heroi["de"] = heroi["pos"]
	heroi["pos"] = prox
	heroi["passo_ms"] = agora_ms()
	heroi["facing"] = _facing(d, heroi["facing"])
	var custo := int(p.passo_heroi_ticks)
	if d.x != 0 and d.y != 0:
		custo *= int(p.fator_diagonal_heroi)
	heroi["prox_passo"] = tick + custo


func _primeiro_passo_bfs(origem: Vector2i, alvo_pos: Vector2i) -> Vector2i:
	## BFS 8 direções até qualquer tile vizinho (Chebyshev 1) do alvo, sem atravessar selvagens vivos (F).
	var cols: int = mapa.cols
	var rows: int = mapa.rows
	var bloqueado := PackedByteArray()
	bloqueado.resize(cols * rows)
	for m in mobs:
		if not m["dead"]:
			var q: Vector2i = m["pos"]
			if q.x >= 0 and q.y >= 0 and q.x < cols and q.y < rows:
				bloqueado[q.y * cols + q.x] = 1
	var pai := PackedInt32Array()
	pai.resize(cols * rows)
	pai.fill(-1)
	var ini := origem.y * cols + origem.x
	pai[ini] = ini
	var fila := PackedInt32Array([ini])
	var i := 0
	while i < fila.size():
		var atual := fila[i]
		i += 1
		var c := Vector2i(atual % cols, atual / cols)
		if _cheb(c, alvo_pos) <= 1 and c != alvo_pos:
			# reconstrói até o primeiro passo
			var k := atual
			while pai[k] != ini and k != ini:
				k = pai[k]
			return Vector2i(k % cols, k / cols) if k != ini else origem
		for d in DIRECOES:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			var idx := n.y * cols + n.x
			if pai[idx] != -1 or bloqueado[idx] == 1 or not mapa.grade[n.y][n.x]:
				continue
			pai[idx] = atual
			fila.append(idx)
	return origem


func _golpe(poke_ou_mob: Dictionary, especie_def: Dictionary, stats_def: Dictionary, chave_def: String) -> Dictionary:
	var chave := "%s|%d|%s" % [str(poke_ou_mob.get("id", poke_ou_mob.get("slot", ""))), int(poke_ou_mob["nivel"]), chave_def]
	if not _golpes_cache.has(chave):
		_golpes_cache[chave] = Regras.escolher_golpe(poke_ou_mob["especie"], int(poke_ou_mob["nivel"]), poke_ou_mob["stats"], especie_def, stats_def, p)
	return _golpes_cache[chave]


func _aleatorio() -> float:
	return float(p.aleatorio_min) + rng.randf() * (float(p.aleatorio_max) - float(p.aleatorio_min))


func _ataque_aliado(m: Dictionary) -> void:
	var poke := _poke_ativo()
	heroi["prox_ataque"] = tick + int(p.ataque_aliado_ticks)
	var g := _golpe(poke, m["especie"], m["stats"], "mob%d" % m["slot"])
	if g.is_empty():
		return
	var especial: bool = g["categoria"] == "SPECIAL"
	var a := float(poke["stats"]["spAtk"] if especial else poke["stats"]["atk"])
	var d := float(m["stats"]["spDef"] if especial else m["stats"]["def"])
	var v := Regras.dano(int(poke["nivel"]), int(g["poder"]), a, d, g["stab"], float(g["eff"]), false, _aleatorio(), p)
	hits.append({"slot": m["slot"], "amount": v, "eff": g["eff"], "move": g["nome"], "type": g["tipo"]})
	estatisticas["hits_aliado"] += 1
	m["hp"] = maxi(0, int(m["hp"]) - v)
	if int(m["hp"]) <= 0:
		_abate(m)


# ======================================================================== abate, XP, loot, captura

func _abate(m: Dictionary) -> void:
	m["dead"] = true
	m["hp"] = 0
	m["morte_tick"] = tick
	m["prox_ataque"] = -1
	estatisticas["abates"] += 1
	var esp: Dictionary = m["especie"]
	var corpo := int(cfg.get("cadaveres", {}).get(str(m["species_id"]), 0))
	if corpo > 0:
		cadaveres.append({"row": m["pos"].y, "col": m["pos"].x, "corpse": corpo, "expira": tick + int(p.cadaver_ms) / int(p.tick_ms)})
	# XP (A): base = experience da espécie; vip = 50% da base em parcela separada.
	var base := int(esp.get("xpAbate", 0))
	var vip := Regras.js_round(float(base) * float(p.vip_fracao)) if cfg.get("vip", false) else 0
	var total := base + vip
	var nivel_t_antes := int(treinador["nivel"])
	treinador["xp"] = int(treinador["xp"]) + total
	treinador["nivel"] = Regras.nivel_por_xp(treinador["xp"])
	var poke := _poke_ativo()
	var nivel_p_antes := int(poke["nivel"])
	poke["xp"] = int(poke["xp"]) + total
	poke["nivel"] = Regras.nivel_por_xp(poke["xp"])
	var subiu_poke: bool = int(poke["nivel"]) != nivel_p_antes
	if subiu_poke:
		_recalcular_stats(poke)  # A: subir de nível não cura (HP absoluto mantido, máximo novo)
	# Loot (A): cada entrada sorteada com chance/100000; quantidade uniforme min..max.
	var loot: Array = []
	for e in esp.get("loot", []):
		var chance := float(e.get("chanceBruta", 0.0))
		if chance <= 0.0:
			continue
		if rng.randf() * 100000.0 < chance:
			var qtd: int = rng.randi_intervalo(int(e.get("min", 1)), int(e.get("max", 1)))
			loot.append({"itemId": int(e["itemId"]), "name": e["item"], "qty": qtd})
			inventario[int(e["itemId"])] = int(inventario.get(int(e["itemId"]), 0)) + qtd
	_emitir({"type": "field-kill", "xpGained": total, "totalXp": treinador["xp"], "level": treinador["nivel"],
		"leveledUp": int(treinador["nivel"]) != nivel_t_antes, "loot": loot, "speciesId": m["species_id"],
		"looktype": int(esp.get("looktype", 0)), "speciesName": esp.get("nome", ""), "shiny": m["shiny"],
		"xpParts": {"base": base, "streak": 0, "boost": 0, "vip": vip, "event": 0, "gym": 0, "typeDay": 0},
		"pokeXp": {"xpGained": total, "parts": {"base": base, "boost": 0, "vip": vip, "event": 0, "mentor": 0, "gym": 0, "typeDay": 0},
			"speciesId": int(poke["speciesId"]), "level": poke["nivel"]},
		"row": m["pos"].y, "col": m["pos"].x, "slot": m["slot"]})
	_emitir({"type": "poke-xp", "id": poke.get("id", ""), "speciesId": int(poke["speciesId"]), "xpGained": total,
		"xp": poke["xp"], "level": poke["nivel"], "leveledUp": subiu_poke})
	var bola := _tentar_captura(m)
	if subiu_poke:
		_emitir({"type": "poke-delta", "poke": _poke_delta(poke)})
	_emitir(_msg_inventario())
	if bola:
		_emitir(_msg_balls())
	# re-alvo imediato (A: o alvo novo aparece no mesmo field da morte)
	heroi["alvo"] = _escolher_alvo()


func _tentar_captura(m: Dictionary) -> bool:
	if not cfg.get("auto_catch", false):
		return false
	var sel := str(balls.get("selected", ""))
	var counts: Dictionary = balls.get("counts", {})
	if sel == "" or int(counts.get(sel, 0)) <= 0:
		return false
	counts[sel] = int(counts[sel]) - 1
	var chance := float(cfg.get("catch_chance", 0.0))  # F: fórmula de captura em aberto; hunt-config.catchChance
	var sucesso: bool = rng.randf() < chance
	if sucesso:
		estatisticas["capturas"] += 1
	var nome_bola := ""
	for b in balls.get("catalog", []):
		if str(b.get("id", "")) == sel:
			nome_bola = b.get("name", "")
	_emitir({"type": "catch-result", "auto": true, "success": sucesso, "speciesName": m["especie"].get("nome", ""),
		"ballName": nome_bola, "ballId": int(sel), "row": m["pos"].y, "col": m["pos"].x})
	return true


func _msg_inventario() -> Dictionary:
	var ids := inventario.keys()
	ids.sort()
	var items: Array = []
	for id in ids:
		if int(inventario[id]) > 0:
			items.append({"itemId": int(id), "quantity": int(inventario[id])})
	return {"type": "inventory", "items": items}


func _msg_balls() -> Dictionary:
	var r := {"type": "balls"}
	for k in ["catalog", "counts", "gold", "selected"]:
		if balls.has(k):
			r[k] = balls[k]
	for k in balls:
		if not r.has(k):
			r[k] = balls[k]
	return r


func _poke_delta(poke: Dictionary) -> Dictionary:
	var esp: Dictionary = poke["especie"]
	var tipos := Regras.tipos_de(esp)
	var ivt := 0
	for k in Regras.CHAVES_STATS:
		ivt += int(poke["ivs"][k])
	return {"id": poke.get("id", ""), "speciesId": int(poke["speciesId"]), "name": esp.get("nome", ""), "level": poke["nivel"],
		"shiny": poke.get("shiny", false), "finalStage": poke.get("finalStage", false), "team": true, "slot": equipe.find(poke),
		"leader": poke.get("leader", false), "starter": poke.get("starter", false), "sellValue": int(poke.get("sellValue", 0)),
		"looktype": int(esp.get("looktype", 0)), "barLooktype": int(esp.get("looktype", 0)), "xp": poke["xp"],
		"hp": poke["hp"], "maxHp": poke["max_hp"], "type1": tipos[0], "type2": tipos[1] if tipos[1] != "" else null,
		"stats": poke["stats"], "quality": poke["quality"], "ivTotal": ivt, "power": poke["power"]}


# ======================================================================== selvagens

func _na_visao(c: Vector2i) -> bool:
	var h: Vector2i = heroi["pos"]
	return absi(c.x - h.x) <= int(p.visao_meia_largura) and absi(c.y - h.y) <= int(p.visao_meia_altura)


func _turno_selvagens() -> void:
	for m in mobs:
		if m["dead"]:
			continue
		var h: Vector2i = heroi["pos"]
		if _cheb(m["pos"], h) <= 1:
			if desmaiado:
				continue
			if int(m["prox_ataque"]) < 0:
				m["prox_ataque"] = tick + int(p.primeiro_ataque_selvagem_ticks)
			if tick >= int(m["prox_ataque"]):
				_ataque_selvagem(m)
				var extra := 1 if rng.randf() < float(p.ataque_selvagem_extra_prob) else 0
				m["prox_ataque"] = tick + int(p.ataque_selvagem_ticks) + extra
		else:
			m["prox_ataque"] = -1
			if _na_visao(m["pos"]) and tick >= int(m["prox_passo"]):
				_passo_mob(m)
	_pos_dano()


func _passo_mob(m: Dictionary) -> void:
	# F: anda para o vizinho que mais reduz (Chebyshev, depois euclidiana) a distância ao herói; só se melhorar.
	var h: Vector2i = heroi["pos"]
	var atual: Vector2i = m["pos"]
	var melhor := atual
	var chave := Vector2i(_cheb(atual, h), _dist2(atual, h))
	for d in DIRECOES:
		var n: Vector2i = atual + d
		if not _livre(n) or n == h or _ocupado_por_mob(n, m["slot"]):
			continue
		var k := Vector2i(_cheb(n, h), _dist2(n, h))
		if k.x < chave.x or (k.x == chave.x and k.y < chave.y):
			chave = k
			melhor = n
	if melhor == atual:
		return
	var dd: Vector2i = melhor - atual
	m["de"] = atual
	m["pos"] = melhor
	m["passo_ms"] = agora_ms()
	m["facing"] = _facing(dd, m["facing"])
	var custo := int(p.passo_mob_ticks)
	if dd.x != 0 and dd.y != 0:
		custo *= int(p.fator_diagonal_mob)
	m["prox_passo"] = tick + custo


func _ataque_selvagem(m: Dictionary) -> void:
	var poke := _poke_ativo()
	var g := _golpe(m, poke["especie"], poke["stats"], "poke%s|%d" % [str(poke.get("id", ativo)), int(poke["nivel"])])
	if g.is_empty():
		return
	var especial: bool = g["categoria"] == "SPECIAL"
	var a := float(m["stats"]["spAtk"] if especial else m["stats"]["atk"])
	var d := float(poke["stats"]["spDef"] if especial else poke["stats"]["def"])
	var v := Regras.dano(int(m["nivel"]), int(g["poder"]), a, d, g["stab"], float(g["eff"]), true, _aleatorio(), p)
	hits.append({"slot": -1, "amount": v, "eff": g["eff"], "move": g["nome"], "type": g["tipo"]})
	estatisticas["hits_selvagem"] += 1
	poke["hp"] = maxi(0, int(poke["hp"]) - v)


func _pos_dano() -> void:
	var poke := _poke_ativo()
	if desmaiado:
		return
	if int(poke["hp"]) <= 0:
		estatisticas["kos"] += 1
		# E: troca automática aleatória entre membros vivos do TIME, sem curar; sem reserva → fim do combate.
		var vivos: Array = []
		for i in equipe.size():
			if int(equipe[i]["hp"]) > 0:
				vivos.append(i)
		if vivos.is_empty():
			desmaiado = true
			return
		ativo = vivos[rng.randi_intervalo(0, vivos.size() - 1)]
		_golpes_cache.clear()
		return
	# Auto-Potion (F: limiar e recarga parametrizados).
	if not cfg.get("auto_potion", false) or tick < proxima_pocao_tick:
		return
	if float(poke["hp"]) > float(poke["max_hp"]) * float(p.pocao_limiar):
		return
	var pid := int(cfg.get("pocao_id", 0))
	if int(inventario.get(pid, 0)) <= 0:
		return
	var item: Dictionary = dados.itens.get(pid, {})
	var cura := mini(int(item.get("cura", 0)), int(poke["max_hp"]) - int(poke["hp"]))  # A: limitado ao que falta
	if cura <= 0:
		return
	poke["hp"] = int(poke["hp"]) + cura
	inventario[pid] = int(inventario[pid]) - 1
	proxima_pocao_tick = tick + int(p.pocao_recarga_ms) / int(p.tick_ms)
	estatisticas["curas"] += 1
	_emitir({"type": "auto-heal", "kind": "potion", "name": item.get("nome", ""), "heal": cura})
	_emitir(_msg_inventario())


# ======================================================================== field

func _ator(pos: Vector2i, de: Vector2i, passo_ms: int, dur_ms: int, facing: String) -> Dictionary:
	var agora := agora_ms()
	var andando := de != pos and agora < passo_ms + dur_ms
	return {"row": pos.y, "col": pos.x, "facing": facing,
		"walkFrom": {"row": de.y if andando else pos.y, "col": de.x if andando else pos.x},
		"stepStartAt": passo_ms if andando else agora}


func _montar_field() -> Dictionary:
	var poke := _poke_ativo()
	var time: Array = []
	for e in equipe:
		time.append({"hp": e["hp"], "maxHp": e["max_hp"]})
	var hero := _ator(heroi["pos"], heroi["de"], int(heroi["passo_ms"]), int(p.hero_step_ms), heroi["facing"])
	var trainer := _ator(heroi["pos"], heroi["de"], int(heroi["passo_ms"]), int(p.trainer_step_ms), heroi["facing"])
	var lista: Array = []
	var todos_mortos := true
	for m in mobs:
		var a := _ator(m["pos"], m["de"], int(m["passo_ms"]), int(p.mob_step_ms), m["facing"])
		a["slot"] = m["slot"]
		a["speciesId"] = m["species_id"]
		a["hp"] = m["hp"]
		a["maxHp"] = m["max_hp"]
		a["dead"] = m["dead"]
		a["respawning"] = m["dead"]
		a["shiny"] = m["shiny"]
		lista.append(a)
		if not m["dead"]:
			todos_mortos = false
	var corpos: Array = []
	for c in cadaveres:
		corpos.append({"row": c["row"], "col": c["col"], "corpse": c["corpse"]})
	var alvo := int(heroi["alvo"])
	var lutando: bool = alvo >= 0 and not mobs[alvo]["dead"] and _cheb(mobs[alvo]["pos"], heroi["pos"]) <= 1 and not desmaiado
	return {"type": "field", "seq": tick, "serverNow": agora_ms(), "heroLooktype": int(poke["especie"].get("looktype", 0)),
		"heroName": poke["especie"].get("nome", ""), "bossTeam": time, "bossActiveIdx": ativo, "hero": hero, "trainer": trainer,
		"mobs": lista, "corpses": corpos, "targetSlot": alvo if alvo >= 0 else null, "fighting": lutando,
		"heroHp": poke["hp"], "heroMaxHp": poke["max_hp"], "fainted": desmaiado, "reviveInMs": 0,
		"allMobsDead": todos_mortos, "waveRespawnAt": null, "hits": hits.duplicate()}
