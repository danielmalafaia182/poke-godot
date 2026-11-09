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
var _campo_mob := PackedInt32Array()
var _campo_mob_caixa := Rect2i()
var _campo_mob_chave := Vector2i(-99999, -99999)
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
	heroi = {"pos": c, "de": c, "passo_ms": inicio_ms, "facing": "south", "ultimo_passo_tick": -1000, "alvo": -1, "prox_ataque": 0, "passo_dur_ms": int(p.hero_step_ms)}
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
			"passo_ms": inicio_ms, "facing": "south", "ultimo_passo_tick": -1000, "hp": mhp, "max_hp": mhp, "stats": st,
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
	_emitir(msg_field_init())
	heroi["alvo"] = _escolher_alvo()  # A: targetSlot nunca é null nos 2009 fields gravados
	_emitir(_montar_field())
	return _saida


func msg_field_init() -> Dictionary:
	## field-init desta instância (também serve para retomar: enter-hunt com resume).
	var grade: Array = []
	for linha in mapa.grade:
		grade.append(linha.duplicate())
	return {"type": "field-init", "huntKey": hunt_key, "slug": slug, "rows": mapa.rows, "cols": mapa.cols,
		"minTx": mapa.min_tx, "minTy": mapa.min_ty, "grid": grade, "heroStepMs": int(p.hero_step_ms), "bike": false,
		"mobStepMs": int(p.mob_step_ms), "trainerStepMs": int(p.trainer_step_ms), "tickMs": int(p.tick_ms)}


func msg_field_atual() -> Dictionary:
	## Retrato do estado atual (resposta a field-get), sem os hits acumulados: eles saem no próximo field
	## regular, para o cliente não desenhar o mesmo dano duas vezes (F: resposta real ao field-get não gravada).
	var guardados := hits
	hits = []
	var f := _montar_field()
	hits = guardados
	return f


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
			m["ultimo_passo_tick"] = tick


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
	if _cheb(m["pos"], heroi["pos"]) > 1 and _espera_minima_ok(heroi, int(p.hero_step_ms)):
		_passo_heroi(m["pos"])
	if _cheb(m["pos"], heroi["pos"]) <= 1 and tick >= int(heroi["prox_ataque"]):
		_ataque_aliado(m)


func _passo_heroi(destino: Vector2i) -> void:
	var prox := _proximo_tile_heroi(destino)   # herói: recalcula a cada tick (sem _plano; ver comentário lá)
	if prox == heroi["pos"]:
		return
	var d: Vector2i = prox - heroi["pos"]
	var diagonal := d.x != 0 and d.y != 0
	if not _espera_ok(heroi, diagonal, int(p.hero_step_ms),
			float(p.passo_extra_prob_heroi_diagonal if diagonal else p.passo_extra_prob_heroi_reto)):
		return
	heroi["de"] = heroi["pos"]
	heroi["pos"] = prox
	heroi["passo_ms"] = agora_ms()
	heroi["facing"] = _facing(d, heroi["facing"])
	heroi["ultimo_passo_tick"] = tick


func _plano(a: Dictionary, centro: Vector2i, calcular: Callable, pode_pisar: Callable) -> Vector2i:
	## O próximo tile é escolhido uma vez por passo (no 1º tick em que um passo reto já seria possível) e mantido
	## enquanto a espera corre, mesmo que o alvo ande, se o tile continuar livre (F: re-sortear quando o alvo anda
	## favorece o passo reto, que fica pronto antes da diagonal; e o original mostra passos que não aproximam).
	var pl = a.get("plano")
	if pl != null and int(pl["ultimo"]) == int(a["ultimo_passo_tick"]) and pode_pisar.call(pl["tile"]):
		return pl["tile"]
	var t: Vector2i = calcular.call()
	if t != a["pos"]:          # "ficar parado" não é guardado: no tick seguinte procura de novo
		a["plano"] = {"ultimo": int(a["ultimo_passo_tick"]), "centro": centro, "tile": t}
	return t


func _espera_minima_ok(a: Dictionary, step_ms: int) -> bool:
	## Atalho: antes da espera de um passo reto nenhum passo é possível (evita o BFS a cada tick).
	return tick - int(a["ultimo_passo_tick"]) >= ceili(float(step_ms) / float(p.tick_ms))


func _espera_ok(a: Dictionary, diagonal: bool, step_ms: int, prob_extra: float) -> bool:
	## A (medir_passos.py): a espera desde o passo anterior depende do passo que VAI ser dado: reto = stepMs,
	## diagonal = 2 × stepMs (o mesmo custo que o cliente usa na animação, dS), arredondada para cima ao tick.
	## Herói: reto 600 ms (500 → 3 ticks), diagonal 1000/1200; selvagem: reto 1000/1200, diagonal 2000.
	## Quando a espera cai exatamente num tick, o passo às vezes sai 1 tick depois (taxa medida, A; mecanismo F:
	## provavelmente o servidor compara relógio real, que varia ±1 ms por tick). Sorteio feito uma vez, no tick exato.
	var custo_ms := step_ms * (int(p.fator_diagonal_passo) if diagonal else 1)
	var base := ceili(float(custo_ms) / float(p.tick_ms))
	var desde := tick - int(a["ultimo_passo_tick"])
	if desde < base:
		return false
	if desde == base and custo_ms % int(p.tick_ms) == 0 and prob_extra > 0.0 and rng.randf() < prob_extra:
		return false
	return true


# ---------------------------------------------------------------- caminho de tempo mínimo
# A (medir_passos.py + escolha de direção nas gravações): a espera antes de um passo é stepMs (reto) ou 2 × stepMs
# (diagonal). Herói fora do eixo do alvo: reto no eixo maior 475, diagonal 146, reto no eixo menor 26; com o alvo na
# diagonal exata: diagonal 77 de 88. É o que um caminho de tempo mínimo produz (para o herói, diagonal 5 ticks <
# 2 retos 6 ticks; reto no eixo menor nunca é ótimo). Selvagens fora do eixo: eixo maior 385, diagonal 232, eixo
# menor 143 — para eles diagonal (10 ticks) = 2 retos, então os três empatam. F: caminho = Dijkstra com esses custos
# em ticks; empates sorteados com pesos iguais às frequências medidas (PARAMETROS desempate_*).

const INF := 1 << 30


func _custos(step_ms: int) -> Vector2i:
	var t := int(p.tick_ms)
	return Vector2i(ceili(float(step_ms) / t), ceili(float(step_ms * int(p.fator_diagonal_passo)) / t))


func _campo_tempo(centro: Vector2i, caixa: Rect2i, custos: Vector2i, bloqueados: Dictionary) -> PackedInt32Array:
	## Tempo mínimo (ticks) de cada tile da caixa até um tile vizinho (Chebyshev 1) de `centro`, sem pisar em
	## `bloqueados` nem em `centro`. Dial (fila por baldes): os custos são inteiros pequenos.
	var w := caixa.size.x
	var h := caixa.size.y
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(INF)
	var baldes: Array = [PackedInt32Array()]
	for d in DIRECOES:
		var g: Vector2i = centro + d
		if caixa.has_point(g) and _livre(g) and not bloqueados.has(g):
			var gi := (g.y - caixa.position.y) * w + (g.x - caixa.position.x)
			dist[gi] = 0
			baldes[0].append(gi)
	var k := 0
	while k < baldes.size():
		var balde: PackedInt32Array = baldes[k]
		for idx in balde:
			if dist[idx] != k:
				continue
			var c := Vector2i(idx % w + caixa.position.x, idx / w + caixa.position.y)
			for d in DIRECOES:
				var n: Vector2i = c + d
				if not caixa.has_point(n) or n == centro or not _livre(n) or bloqueados.has(n):
					continue
				var nd := k + (custos.y if d.x != 0 and d.y != 0 else custos.x)
				var ni := (n.y - caixa.position.y) * w + (n.x - caixa.position.x)
				if nd < dist[ni]:
					dist[ni] = nd
					while baldes.size() <= nd:
						baldes.append(PackedInt32Array())
					baldes[nd].append(ni)
		k += 1
	return dist


func _escolher_passo(origem: Vector2i, centro: Vector2i, campo: PackedInt32Array, caixa: Rect2i, custos: Vector2i,
		pode_pisar: Callable, pesos: Array) -> Vector2i:
	## Entre os vizinhos que realizam o tempo mínimo (custo do passo + campo), sorteia pela classe do passo
	## (0 = reto no eixo maior, 1 = diagonal, 2 = reto no eixo menor) com `pesos`. Só anda se houver progresso.
	var w := caixa.size.x
	var atual := INF
	if caixa.has_point(origem):
		atual = campo[(origem.y - caixa.position.y) * w + (origem.x - caixa.position.x)]
	var melhor := INF
	var opcoes: Array = []
	for d in DIRECOES:
		var n: Vector2i = origem + d
		if not caixa.has_point(n) or not pode_pisar.call(n):
			continue
		var dn := campo[(n.y - caixa.position.y) * w + (n.x - caixa.position.x)]
		if dn >= INF or dn >= atual:
			continue
		var total := dn + (custos.y if d.x != 0 and d.y != 0 else custos.x)
		if total < melhor:
			melhor = total
			opcoes = [d]
		elif total == melhor:
			opcoes.append(d)
	if opcoes.is_empty():
		return origem
	if opcoes.size() == 1:
		return origem + opcoes[0]
	var delta := centro - origem
	var soma := 0.0
	var ps: Array = []
	for d in opcoes:
		var classe := 1
		if d.x == 0 or d.y == 0:
			var eixo_maior_x := absi(delta.x) > absi(delta.y)
			var eixo_maior_y := absi(delta.y) > absi(delta.x)
			classe = 0 if (d.x != 0 and eixo_maior_x) or (d.y != 0 and eixo_maior_y) else 2
		var pw := float(pesos[classe])
		ps.append(pw)
		soma += pw
	var r: float = rng.randf() * soma
	for i in opcoes.size():
		r -= float(ps[i])
		if r < 0.0:
			return origem + opcoes[i]
	return origem + opcoes[opcoes.size() - 1]


func _caixa(a: Vector2i, b: Vector2i, margem_x: int, margem_y: int) -> Rect2i:
	var x0 := maxi(0, mini(a.x, b.x) - margem_x)
	var y0 := maxi(0, mini(a.y, b.y) - margem_y)
	var x1 := mini(int(mapa.cols) - 1, maxi(a.x, b.x) + margem_x)
	var y1 := mini(int(mapa.rows) - 1, maxi(a.y, b.y) + margem_y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _proximo_tile_heroi(destino: Vector2i) -> Vector2i:
	var bloq := {}
	for m in mobs:
		if not m["dead"]:
			bloq[m["pos"]] = true
	var custos := _custos(int(p.hero_step_ms))
	var pode := func(n): return _livre(n) and not bloq.has(n)
	var caixa := _caixa(heroi["pos"], destino, int(p.caminho_margem), int(p.caminho_margem))
	var campo := _campo_tempo(destino, caixa, custos, bloq)
	var t := _escolher_passo(heroi["pos"], destino, campo, caixa, custos, pode, p.desempate_heroi)
	if t == heroi["pos"]:
		# sem caminho dentro da caixa (parede no meio): procura no mapa inteiro
		caixa = Rect2i(0, 0, int(mapa.cols), int(mapa.rows))
		campo = _campo_tempo(destino, caixa, custos, bloq)
		t = _escolher_passo(heroi["pos"], destino, campo, caixa, custos, pode, p.desempate_heroi)
	return t


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
	# A bola da auto-captura é configuração própria (A: balls.selected = 1, mas as tentativas gastam a bola 3).
	var sel := str(int(cfg.get("bola_auto_catch", 0)))
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
			if _na_visao(m["pos"]) and _espera_minima_ok(m, int(p.mob_step_ms)):
				_passo_mob(m)
	_pos_dano()


func _passo_mob(m: Dictionary) -> void:
	# Caminho de tempo mínimo até um vizinho do herói (ver _campo_tempo). O campo depende só da posição do herói
	# (cache); os outros selvagens bloqueiam só na escolha do passo (F).
	var h: Vector2i = heroi["pos"]
	var atual: Vector2i = m["pos"]
	if _campo_mob_chave != h:
		_campo_mob_chave = h
		_campo_mob_caixa = _caixa(h, h, int(p.visao_meia_largura) + int(p.caminho_margem), int(p.visao_meia_altura) + int(p.caminho_margem))
		_campo_mob = _campo_tempo(h, _campo_mob_caixa, _custos(int(p.mob_step_ms)), {})
	var slot: int = m["slot"]
	var pode := func(n): return _livre(n) and n != h and not _ocupado_por_mob(n, slot)
	var melhor := _plano(m, h, func(): return _escolher_passo(atual, h, _campo_mob, _campo_mob_caixa,
		_custos(int(p.mob_step_ms)), pode, p.desempate_mob), pode)
	if melhor == atual:
		return
	var dd: Vector2i = melhor - atual
	var diagonal := dd.x != 0 and dd.y != 0
	if not _espera_ok(m, diagonal, int(p.mob_step_ms),
			float(p.passo_extra_prob_mob_diagonal if diagonal else p.passo_extra_prob_mob_reto)):
		return
	m["de"] = atual
	m["pos"] = melhor
	m["passo_ms"] = agora_ms()
	m["facing"] = _facing(dd, m["facing"])
	m["ultimo_passo_tick"] = tick


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
	# Auto-Potion (A, medir_pocao.py em 209 curas reais): dispara no MESMO tick em que o HP fica ≤ 50% do máximo
	# (91/91 cruzamentos com cobertura contínua, antigas + rhydon-1h; HP exato na cura nunca passa de 0,50). Nenhuma cura
	# adiada observada, então a recarga padrão é 0 (menor intervalo real entre curas: 1988 ms).
	if not cfg.get("auto_potion", false) or tick < proxima_pocao_tick:
		return
	if float(poke["hp"]) > float(poke["max_hp"]) * float(p.pocao_limiar):
		return
	var falta := int(poke["max_hp"]) - int(poke["hp"])
	var pid := _escolher_pocao(falta)
	if pid < 0:
		return
	var item: Dictionary = dados.itens.get(pid, {})
	var cura := mini(int(item.get("cura", 0)), falta)  # A: limitado ao que falta
	if cura <= 0:
		return
	poke["hp"] = int(poke["hp"]) + cura
	inventario[pid] = int(inventario[pid]) - 1
	proxima_pocao_tick = tick + int(p.pocao_recarga_ms) / int(p.tick_ms)
	estatisticas["curas"] += 1
	_emitir({"type": "auto-heal", "kind": "potion", "name": item.get("nome", ""), "heal": cura})
	_emitir(_msg_inventario())


func _escolher_pocao(falta: int) -> int:
	## A (408/408 curas com inventário conhecido; Auto-Helper "Automatic (best)"): a menor poção do inventário cuja cura cobre o que falta;
	## se nenhuma cobre, a maior disponível. Empate de cura → menor id (F; não houve empate nas gravações).
	var menor_que_cobre := -1
	var maior := -1
	for id in inventario:
		if int(inventario[id]) <= 0:
			continue
		var it: Dictionary = dados.itens.get(int(id), {})
		if String(it.get("categoria", "")) != "heal" or int(it.get("cura", 0)) <= 0:
			continue
		var c := int(it["cura"])
		if c >= falta and (menor_que_cobre < 0 or c < _cura(menor_que_cobre) or (c == _cura(menor_que_cobre) and int(id) < menor_que_cobre)):
			menor_que_cobre = int(id)
		if maior < 0 or c > _cura(maior) or (c == _cura(maior) and int(id) < maior):
			maior = int(id)
	return menor_que_cobre if menor_que_cobre >= 0 else maior


func _cura(id: int) -> int:
	return int(dados.itens.get(id, {}).get("cura", 0))


# ======================================================================== field

func _ator(pos: Vector2i, de: Vector2i, passo_ms: int, facing: String, anda: bool = true) -> Dictionary:
	## A (4046 fields reais): stepStartAt == serverNow sempre; walkFrom ≠ posição só no field do tick em que o passo
	## começou (no field seguinte já volta a ser a posição). O treinador nunca mostra walkFrom ≠ posição (anda=false).
	var agora := agora_ms()
	var andando := anda and de != pos and passo_ms == agora
	return {"row": pos.y, "col": pos.x, "facing": facing,
		"walkFrom": {"row": de.y if andando else pos.y, "col": de.x if andando else pos.x},
		"stepStartAt": agora}


func _montar_field() -> Dictionary:
	var poke := _poke_ativo()
	var time: Array = []
	for e in equipe:
		time.append({"hp": e["hp"], "maxHp": e["max_hp"]})
	var hero := _ator(heroi["pos"], heroi["de"], int(heroi["passo_ms"]), heroi["facing"])
	var trainer := _ator(heroi["pos"], heroi["de"], int(heroi["passo_ms"]), heroi["facing"], false)  # A: treinador = herói
	var lista: Array = []
	var todos_mortos := true
	for m in mobs:
		var a := _ator(m["pos"], m["de"], int(m["passo_ms"]), m["facing"])
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
