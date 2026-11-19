extends RefCounted
## Simulação autoritativa de uma instância de hunt, em ticks de 200 ms.
## Entrada: configuração (cenário) + intenções do cliente; saída: mensagens com os mesmos nomes e campos do servidor original.
## Sem Node, Timer, await nem relógio real: o tempo é `inicio_ms + tick * tick_ms`. Mesma semente → mesma saída.
##
## Origem de cada comportamento: ver sim/regras.gd (PARAMETROS) e a seção "Estado" do CLAUDE.md.
## Ordem dentro de um tick (E): respawns → cadáveres → herói (alvo, passo, ataque, abates) → selvagens (passo, ataque)
## → KO/troca → poção → `field` (nos ticks pares, com os hits acumulados desde o último field).

const Balanceamento := preload("res://sim/balanceamento.gd")
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
var penalidade_ate_ms: int = 0   # fim do lock de entrada (boost shinylock), em ms do relógio da sim; 0 = sem lock
var medidor := {}               # speciesId (str) -> {investido, tentativas, total, gasto}: medidor de captura (C)
var _cards := {}               # nome da espécie -> id do Shiny Card (cache)
var garantia_pedras := {}       # itemId (str) -> chance acumulada sem a pedra cair (garantia, classe 3; vai no save)
var troca_manual_liberada_tick: int = 0
var _campo_mob := PackedInt32Array()
var _campo_mob_caixa := Rect2i()
var _campo_mob_chave := Vector2i(-99999, -99999)
var _ilhas := PackedInt32Array()   # componente 8-conexa de cada tile livre (-1 = bloqueado); a grade não muda
var ajuste_inicio := {}            # diagnóstico: como o `start` do hunt-config foi ajustado (vazio = usado como veio)
var _pass := PackedByteArray()     # 1 = tile transitável (cópia plana da grade, para o laço do caminho)
const _DX := [0, 1, 0, -1, 1, 1, -1, -1]   # = DIRECOES (retas antes das diagonais)
const _DY := [-1, 0, 1, 0, -1, 1, 1, -1]
var _campo_alvo := PackedInt32Array()           # campo do alvo vindo de fora da visão (alvo_vem_ao_encontro)
var _campo_alvo_caixa := Rect2i()
var _campo_alvo_chave := Vector3i(-99999, -99999, -1)
var _campo_global := PackedInt32Array()          # campo de tempo do herói no mapa inteiro (sem selvagens), por destino
var _campo_global_chave := Vector2i(-99999, -99999)
var estatisticas := {"abates": 0, "hits_aliado": 0, "hits_selvagem": 0, "curas": 0, "capturas": 0, "kos": 0,
	"trocas_ko": 0, "trocas_manuais": 0}


func _init(config: Dictionary, dados_jogo: RefCounted, mapa_hunt: RefCounted) -> void:
	cfg = config
	dados = dados_jogo
	mapa = mapa_hunt
	p = Regras.PARAMETROS.duplicate()
	Balanceamento.aplicar(p, "combate")   # classe 3: dados/balanceamento.json
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
	atualizar_grade()
	var spawns_cel: Array = []
	for s in cfg["spawns"]:
		spawns_cel.append(_celula(int(s["x"]), int(s["y"])))
	var c := _ajustar_inicio(_celula(int(ini["x"]), int(ini["y"])), spawns_cel)
	heroi ={"pos": c, "de": c, "passo_ms": inicio_ms, "facing": "south", "ultimo_passo_tick": -1000, "alvo": -1, "prox_ataque": 0, "passo_dur_ms": int(p.hero_step_ms)}
	equipe = []
	for e in cfg["equipe"]:
		equipe.append(_criar_poke(e))
	ativo = clampi(int(cfg.get("ativo_inicial", 0)), 0, maxi(0, equipe.size() - 1))   # E: o líder do save começa em campo
	treinador["xp"] = int(cfg.get("treinador", {}).get("xp", 0))
	treinador["nivel"] = Regras.nivel_por_xp(treinador["xp"])
	inventario = {}
	for it in cfg.get("inventario", []):
		inventario[int(it["itemId"])] = int(it["quantity"])
	balls = (cfg.get("balls", {}) as Dictionary).duplicate(true)
	medidor = (cfg.get("medidor_captura", {}) as Dictionary).duplicate(true)
	garantia_pedras = (cfg.get("garantia_pedras", {}) as Dictionary).duplicate(true)
	if cfg.has("penalidade_ate_ms"):
		penalidade_ate_ms = int(cfg["penalidade_ate_ms"])
	elif cfg.get("entrada_nova", false):
		penalidade_ate_ms = inicio_ms - int(cfg.get("ms_desde_saida", 0)) + int(p.penalidade_duracao_ms)
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
		# Validação (ferramentas/validar_resultado.py): com o maxHp gravado de cada slot, sorteia de novo até o indivíduo ter
		# o mesmo HP (tira o ruído de instância: 15 indivíduos reais × 15 sorteados). O jogo não passa isso: sorteio livre.
		var alvos: Array = cfg.get("maxhp_por_slot", [])
		if slot < alvos.size() and int(alvos[slot]) > 0:
			var tent := 0
			while mhp != int(alvos[slot]) and tent < 3000:
				ivs = Regras.sortear_ivs(rng)
				q = Regras.sortear_qualidade(rng)
				st = Regras.calcular_stats(esp["base"], ivs, nivel_selv, q)
				mhp = Regras.hp_combate_selvagem(int(st["hp"]), p)
				tent += 1
		mobs.append({"slot": slot, "especie": esp, "species_id": int(s["pokeId"]), "spawn": sp, "pos": sp, "de": sp, "shiny": _sortear_shiny(int(s["pokeId"])),
			"passo_ms": inicio_ms, "facing": "south", "ultimo_passo_tick": -1000, "hp": mhp, "max_hp": mhp, "stats": st,
			"stats_dano": Regras.calcular_stats_dano(esp["base"], ivs, nivel_selv, q, String(p.stats_dano_selvagem)),
			"ivs": ivs, "qualidade": q, "nivel": nivel_selv, "dead": false, "morte_tick": -1, "prox_ataque": -1})
		slot += 1


func atualizar_grade() -> void:
	## Cópias derivadas da grade (plana e ilhas). A grade não muda numa hunt; testes que a editam chamam isto depois.
	_pass.resize(int(mapa.rows) * int(mapa.cols))
	for r in int(mapa.rows):
		for c0 in int(mapa.cols):
			_pass[r * int(mapa.cols) + c0] = 1 if mapa.passavel(r, c0) else 0
	_ilhas = _rotular_ilhas()


func _rotular_ilhas() -> PackedInt32Array:
	## Componentes 8-conexas dos tiles livres (o passo diagonal não exige os ortogonais livres, como em DIRECOES).
	var cols := int(mapa.cols)
	var rows := int(mapa.rows)
	var rot := PackedInt32Array()
	rot.resize(rows * cols)
	rot.fill(-1)
	var n := 0
	for r in rows:
		for c in cols:
			if rot[r * cols + c] >= 0 or not mapa.passavel(r, c):
				continue
			rot[r * cols + c] = n
			var pilha := PackedInt32Array([r * cols + c])
			while not pilha.is_empty():
				var k := pilha[pilha.size() - 1]
				pilha.resize(pilha.size() - 1)
				var pr := k / cols
				var pc := k % cols
				for d in DIRECOES:
					var qr: int = pr + d.y
					var qc: int = pc + d.x
					if qr < 0 or qc < 0 or qr >= rows or qc >= cols:
						continue
					var q := qr * cols + qc
					if rot[q] < 0 and mapa.passavel(qr, qc):
						rot[q] = n
						pilha.append(q)
			n += 1
	return rot


func _ilha(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= int(mapa.cols) or c.y >= int(mapa.rows):
		return -1
	return _ilhas[c.y * int(mapa.cols) + c.x]


func _alcanca(ilha: int, c: Vector2i) -> bool:
	## Da ilha `ilha` dá para encostar (Chebyshev ≤ 1) em `c`: algum tile livre em volta de `c` (ou o próprio) é dela.
	if ilha < 0:
		return true   # herói fora da grade: sem filtro (comportamento antigo)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if _ilha(c + Vector2i(dx, dy)) == ilha:
				return true
	return false


func _livre_mais_proximo(c: Vector2i, ilha: int) -> Vector2i:
	## Tile livre mais próximo de `c` (anel de Chebyshev; no anel, ordem linha → coluna), opcionalmente numa ilha.
	var lim := maxi(int(mapa.cols), int(mapa.rows))
	for r in range(1, lim + 1):
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != r:
					continue
				var t := Vector2i(x, y)
				var il := _ilha(t)
				if il >= 0 and (ilha < 0 or il == ilha):
					return t
	return c


func _ajustar_inicio(c: Vector2i, spawns_cel: Array) -> Vector2i:
	var orig := c
	if bool(p.inicio_bloqueado_anel) and _ilha(c) < 0:
		c = _livre_mais_proximo(c, -1)
		ajuste_inicio["start_bloqueado"] = [orig.x, orig.y]
	if bool(p.inicio_ilha_com_spawns) and _ilha(c) >= 0 and not spawns_cel.is_empty():
		var por_ilha := {}
		for s in spawns_cel:
			var vistas := {}
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var il := _ilha(s + Vector2i(dx, dy))
					if il >= 0:
						vistas[il] = true
			for il in vistas:
				por_ilha[il] = int(por_ilha.get(il, 0)) + 1
		if not por_ilha.has(_ilha(c)) and not por_ilha.is_empty():
			var melhor := -1
			for il in por_ilha:
				if melhor < 0 or int(por_ilha[il]) > int(por_ilha[melhor]) or (int(por_ilha[il]) == int(por_ilha[melhor]) and int(il) < melhor):
					melhor = int(il)
			var antes := c
			c = _livre_mais_proximo(c, melhor)
			ajuste_inicio["ilha_sem_spawn"] = [antes.x, antes.y]
	if c != orig:
		ajuste_inicio["inicio_usado"] = [c.x, c.y]
	return c


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
	poke["stats_dano"] = Regras.calcular_stats_dano(poke["especie"]["base"], poke["ivs"], int(poke["nivel"]), float(poke["quality"]), String(p.stats_dano_aliado))
	poke["max_hp"] = Regras.hp_combate_aliado(int(poke["stats"]["hp"]))
	poke["power"] = Regras.power(poke["stats"], float(poke["quality"]))


func agora_ms() -> int:
	return inicio_ms + tick * int(p.tick_ms)


# ======================================================================== API

func iniciar() -> Array:
	## Equivale a enter-hunt: devolve field-init e o primeiro field (tick 0).
	_saida = []
	_emitir(msg_field_init())
	if penalidade_ativa() or not _boosts_ativos().is_empty():
		_emitir(msg_boosts())   # A: logo depois do field-init, {key: shinylock, until, pct: 0}
	if not (cfg.get("eventos", []) as Array).is_empty():
		_emitir(msg_events())   # A: formato {type: events, events: [{key, name, desc, pct, emoji, until}]}
	heroi["alvo"] = _escolher_alvo()  # A: targetSlot nunca é null nos 2009 fields gravados
	_emitir(_montar_field())
	return _saida


func penalidade_ativa() -> bool:
	return agora_ms() < penalidade_ate_ms


func msg_boosts() -> Dictionary:
	var b: Array = []
	if penalidade_ativa():
		b.append({"key": "shinylock", "until": penalidade_ate_ms, "pct": 0})
	b.append_array(_boosts_ativos())
	return {"type": "boosts", "boosts": b}


func _boosts_ativos() -> Array:
	var r: Array = []
	for bo in cfg.get("boosts", []):
		if agora_ms() < int(bo.get("until", 0)):
			r.append({"key": String(bo["key"]), "until": int(bo["until"]), "pct": int(bo.get("pct", 0))})
	return r


func _boost_ativo(chave: String) -> bool:
	for bo in _boosts_ativos():
		if String(bo["key"]) == chave:
			return true
	return false


func msg_events() -> Dictionary:
	var l: Array = []
	for ev in cfg.get("eventos", []):
		var x: Dictionary = {}
		for k in ["key", "name", "desc", "pct", "emoji", "until"]:
			if ev.has(k):
				x[k] = ev[k]
		l.append(x)
	return {"type": "events", "events": l}


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
		if String(it.get("type", "")) == "switch":
			_troca_manual(int(it.get("teamIndex", -1)))
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
			m["shiny"] = _sortear_shiny(int(m["species_id"]))   # cada aparição sorteia de novo (o indivíduo é o mesmo)


func _sortear_shiny(especie_id: int) -> bool:
	## A: só espécie com forma shiny; nunca durante o lock de entrada (C: "nenhum Pokémon Shiny aparece"). Streak Shiny (C):
	## +0,1% por ponto, relativo à chance (F). Sem forma shiny, não gasta número do RNG (a saída de quem não tem fica igual).
	if not dados.shiny.has(especie_id) or float(p.shiny_chance) <= 0.0:
		return false
	var r: float = rng.randf()
	if penalidade_ativa():
		return false
	var mult := 1.0 + float(p.streak_pct_por_ponto) * float(cfg.get("streak", {}).get("shiny", 0))
	return r < float(p.shiny_chance) * mult


func _expirar_cadaveres() -> void:
	var resto: Array = []
	for c in cadaveres:
		if tick < int(c["expira"]):
			resto.append(c)
	cadaveres = resto


# ======================================================================== herói

func _poke_ativo() -> Dictionary:
	return equipe[ativo]


func _escolher_alvo(so_encostados: bool = false) -> int:
	# A (18/11, ferramentas/gravador/medir_alvo.py, 2400 trocas em 16 hunts): o selvagem vivo com o menor TEMPO DE CAMINHO
	# até encostar acerta 2295 (Chebyshev 2067); nos 457 casos em que os dois discordam, caminho 408 × Chebyshev 180.
	# `alvo_criterio` "caminho" (padrão) ou "chebyshev" (o de antes). Desempate: Chebyshev, distância euclidiana, slot (F).
	# O campo de tempo ignora os outros selvagens (F, como na medição).
	var por_caminho := String(p.get("alvo_criterio", "caminho")) == "caminho" and not so_encostados
	var campo := PackedInt32Array()
	if por_caminho:
		campo = _campo_tempo(heroi["pos"], Rect2i(0, 0, int(mapa.cols), int(mapa.rows)), _custos(int(p.hero_step_ms)), {})
	var melhor := -1
	var chave := Vector3i(INF, INF, INF)
	for m in mobs:
		if m["dead"] or not _alvo_valido(m) or (so_encostados and _cheb(m["pos"], heroi["pos"]) > 1):
			continue
		var c := _cheb(m["pos"], heroi["pos"])
		var tempo := 0
		if por_caminho and c > 1:
			tempo = _tempo_ate_encostar(campo, m["pos"])
		var k := Vector3i(tempo, c, _dist2(m["pos"], heroi["pos"]))
		if k < chave:
			chave = k
			melhor = m["slot"]
	return melhor


func _tempo_ate_encostar(campo: PackedInt32Array, alvo: Vector2i) -> int:
	## Menor tempo (ticks, campo do herói no mapa inteiro) até um tile livre a Chebyshev 1 do alvo; INF se não há.
	var cols := int(mapa.cols)
	var melhor := INF
	for d in DIRECOES:
		var g: Vector2i = alvo + d
		if g.x >= 0 and g.y >= 0 and g.x < cols and g.y < int(mapa.rows):
			melhor = mini(melhor, campo[g.y * cols + g.x])
	return melhor


func _alvo_valido(m: Dictionary) -> bool:
	## F (alvo_so_alcancavel): só selvagens em que o herói consegue encostar; o que já está encostado sempre vale.
	if not bool(p.alvo_so_alcancavel) or _cheb(m["pos"], heroi["pos"]) <= 1:
		return true
	return _alcanca(_ilha(heroi["pos"]), m["pos"])


func _turno_heroi() -> void:
	var alvo := int(heroi["alvo"])
	if alvo < 0 or mobs[alvo]["dead"] or not _alvo_valido(mobs[alvo]):
		alvo = _escolher_alvo()
		heroi["alvo"] = alvo
	if alvo < 0:
		return
	var m: Dictionary = mobs[alvo]
	if _cheb(m["pos"], heroi["pos"]) > 1 and _espera_minima_ok(heroi, int(p.hero_step_ms)):
		if not _passo_heroi(m["pos"]) and bool(p.alvo_troca_se_bloqueado):
			# F: sem caminho até o alvo (ex.: corredor fechado por outros selvagens) → ataca o encostado mais próximo
			var viz := _escolher_alvo(true)
			if viz >= 0:
				alvo = viz
				heroi["alvo"] = viz
				m = mobs[viz]
	if _cheb(m["pos"], heroi["pos"]) <= 1 and tick >= int(heroi["prox_ataque"]):
		_ataque_aliado(m)


func _passo_heroi(destino: Vector2i) -> bool:
	## false = não há caminho até o destino agora (true também quando só está esperando o passo).
	var prox := _proximo_tile_heroi(destino)   # herói: recalcula a cada tick (sem _plano; ver comentário lá)
	if prox == heroi["pos"]:
		return false
	var d: Vector2i = prox - heroi["pos"]
	var diagonal := d.x != 0 and d.y != 0
	if not _espera_ok(heroi, diagonal, int(p.hero_step_ms),
			float(p.passo_extra_prob_heroi_diagonal if diagonal else p.passo_extra_prob_heroi_reto)):
		return true
	heroi["de"] = heroi["pos"]
	heroi["pos"] = prox
	heroi["passo_ms"] = agora_ms()
	heroi["facing"] = _facing(d, heroi["facing"])
	heroi["ultimo_passo_tick"] = tick
	return true


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
	var ox := caixa.position.x
	var oy := caixa.position.y
	var cols := int(mapa.cols)
	var com_bloq := not bloqueados.is_empty()
	var k := 0
	while k < baldes.size():
		var balde: PackedInt32Array = baldes[k]
		for idx in balde:
			if dist[idx] != k:
				continue
			var lx := idx % w
			var ly := idx / w
			# mesma ordem de DIRECOES e mesmas regras de antes, com índices planos (2b.6: ~2× mais rápido)
			for j in 8:
				var nx: int = lx + _DX[j]
				var ny: int = ly + _DY[j]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var gx := nx + ox
				var gy := ny + oy
				if gx == centro.x and gy == centro.y:
					continue
				if _pass[gy * cols + gx] == 0:
					continue
				if com_bloq and bloqueados.has(Vector2i(gx, gy)):
					continue
				var nd := k + (custos.y if j >= 4 else custos.x)
				var ni := ny * w + nx
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
		# sem caminho dentro da caixa (parede no meio): campo de tempo no mapa inteiro. F (2b.6, desempenho): esse campo
		# ignora os selvagens (eles só bloqueiam na escolha do passo) e fica guardado enquanto o destino não muda — fora
		# da visão o alvo não anda, então é calculado ~1 vez por alvo (antes: a cada passo, até 40 ms em labirinto).
		caixa = Rect2i(0, 0, int(mapa.cols), int(mapa.rows))
		if _campo_global_chave != destino:
			_campo_global_chave = destino
			_campo_global = _campo_tempo(destino, caixa, custos, {})
		t = _escolher_passo(heroi["pos"], destino, _campo_global, caixa, custos, pode, p.desempate_heroi)
	return t


func _golpe(poke_ou_mob: Dictionary, especie_def: Dictionary, stats_def: Dictionary, chave_def: String) -> Dictionary:
	var chave := "%s|%d|%s" % [str(poke_ou_mob.get("id", poke_ou_mob.get("slot", ""))), int(poke_ou_mob["nivel"]), chave_def]
	if not _golpes_cache.has(chave):
		_golpes_cache[chave] = Regras.escolher_golpe(poke_ou_mob["especie"], int(poke_ou_mob["nivel"]), poke_ou_mob["stats_dano"], especie_def, stats_def, p)
	return _golpes_cache[chave]


func _aleatorio() -> float:
	return float(p.aleatorio_min) + rng.randf() * (float(p.aleatorio_max) - float(p.aleatorio_min))


func _ataque_aliado(m: Dictionary) -> void:
	var poke := _poke_ativo()
	heroi["prox_ataque"] = tick + int(p.ataque_aliado_ticks)
	var g := _golpe(poke, m["especie"], m["stats_dano"], "mob%d" % m["slot"])
	if g.is_empty():
		return
	var especial: bool = g["categoria"] == "SPECIAL"
	var a := float(poke["stats_dano"]["spAtk"] if especial else poke["stats_dano"]["atk"])
	var d := float(m["stats_dano"]["spDef"] if especial else m["stats_dano"]["def"])
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
	# A: o cadáver depende da espécie e de ser shiny (Rhydon 2858, shiny 31489; Rattata shiny = normal 2848).
	# F: shiny sem dado próprio usa o normal. E: espécie nunca vista morrendo → corpse 0 (genérico; a vista desenha o
	# próprio sprite da espécie escurecido no tile). Sem `cadaver_generico`, fica sem corpo como antes.
	var sid := str(m["species_id"])
	var corpo := -1
	if bool(m["shiny"]):
		corpo = int(cfg.get("cadaveres_shiny", {}).get(sid, -1))
	if corpo < 0:
		corpo = int(cfg.get("cadaveres", {}).get(sid, -1))
	if corpo < 0 and bool(p.cadaver_generico):
		corpo = 0
	if corpo >= 0:
		cadaveres.append({"row": m["pos"].y, "col": m["pos"].x, "corpse": corpo, "expira": tick + int(p.cadaver_ms) / int(p.tick_ms)})
	# XP (A): base = experience da espécie; vip = 50% da base em parcela separada.
	var base := int(esp.get("xpAbate", 0))
	var vip := Regras.js_round(float(base) * float(p.vip_fracao)) if cfg.get("vip", false) else 0
	# Fase 4, lote 2 (F: cada parcela é um % da base): streak (só treinador), boost xp / pokexp, tipo do dia.
	# A (G7): streak = floor(base × 0,1% × pontos) — Blastoise base 3848 com 1 ponto → 3 (round daria 4)
	var streak_xp := int(floor(float(base) * float(p.streak_pct_por_ponto) * float(cfg.get("streak", {}).get("exp", 0)) + 1e-9))
	var boost_t := Regras.js_round(float(base) * _pct_boost("xp") / 100.0)
	var boost_p := Regras.js_round(float(base) * _pct_boost("pokexp") / 100.0)
	var tipo_dia := _tipo_do_dia_ativo(esp)
	# A (G8): typeDay = floor(20% da base) — Tyranitar base 6008 → 1201 em 61/61 abates (round daria 1202)
	var parcela_dia := int(floor(float(base) * float(p.tipo_do_dia_pct) / 100.0 + 1e-9)) if tipo_dia else 0
	# Insígnias de ginásio (C, janela Gym Rewards: "Each ACTIVE badge grants +1% XP and +1% chance of an extra drop roll";
	# cfg.insignias = nº de insígnias ativas, sim/servico_ginasios.gd). Parcela `gym` (A: a chave existe no xpParts e no
	# pokeXp.parts, sempre 0 nas gravações); F: floor sobre a base, como streak e typeDay, e no Pokémon também.
	var n_ins := int(cfg.get("insignias", 0))
	var gym_xp := int(floor(float(base) * float(p.insignia_pct_xp) / 100.0 * n_ins + 1e-9)) if n_ins > 0 else 0
	# Multiplicador de XP por região (classe 3, proposta do ciclo 2, balanceamento.json `xp_regiao`; padrão 1 = desligado):
	# não muda o XP da espécie (a base fica igual, classe 1); entra na parcela `event` (A: a chave existe e é 0 nas gravações).
	var mult_reg := float((p.get("xp_regiao", {}) as Dictionary).get(String(cfg.get("area", "")), 1.0))
	var evento := int(floor(float(base) * (mult_reg - 1.0) + 1e-9)) if mult_reg > 1.0 else 0
	var total := base + vip + streak_xp + boost_t + parcela_dia + gym_xp + evento
	var total_p := base + vip + boost_p + parcela_dia + gym_xp + evento
	# Penalidade de entrada (boost shinylock; A/C/F, ver PARAMETROS): XP = floor(total × 0,3) enquanto o lock durar.
	var debuff := 0
	var debuff_p := 0
	var lock := penalidade_ativa()
	if lock:
		debuff = int(floor(float(total) * float(p.penalidade_fator))) - total
		total += debuff
		debuff_p = int(floor(float(total_p) * float(p.penalidade_fator))) - total_p
		total_p += debuff_p
	var nivel_t_antes := int(treinador["nivel"])
	treinador["xp"] = int(treinador["xp"]) + total
	treinador["nivel"] = Regras.nivel_por_xp(treinador["xp"])
	var poke := _poke_ativo()
	var nivel_p_antes := int(poke["nivel"])
	poke["xp"] = int(poke["xp"]) + total_p
	poke["nivel"] = Regras.nivel_por_xp(poke["xp"])
	var subiu_poke: bool = int(poke["nivel"]) != nivel_p_antes
	if subiu_poke:
		_recalcular_stats(poke)  # A: subir de nível não cura (HP absoluto mantido, máximo novo)
	# Loot (A): cada entrada sorteada com chance/100000; quantidade uniforme min..max.
	var loot: Array = []
	# Rolagens de drop: 1 + as extras da trilha Loot do Streak (C). Sem pontos, uma rolagem e nenhum sorteio a mais.
	var rolagens := 1
	var extra := float(p.streak_pct_por_ponto) * float(cfg.get("streak", {}).get("loot", 0)) + float(p.insignia_pct_drop) / 100.0 * n_ins
	if extra > 0.0:
		rolagens += int(floor(extra))
		if rng.randf() < extra - floor(extra):
			rolagens += 1
	var mult_loot := (1.0 + _pct_boost("loot") / 100.0) * (float(p.tipo_do_dia_loot) if tipo_dia else 1.0)
	for _r in rolagens:
		_rolar_loot(esp, lock, mult_loot, loot)
	_garantir_pedras(esp, lock, mult_loot, rolagens, loot)
	if bool(m["shiny"]):
		_card_shiny(esp, loot)
	_emitir({"type": "field-kill", "xpGained": total, "totalXp": treinador["xp"], "level": treinador["nivel"],
		"leveledUp": int(treinador["nivel"]) != nivel_t_antes, "loot": loot, "speciesId": m["species_id"],
		"looktype": int(esp.get("looktype", 0)), "speciesName": esp.get("nome", ""), "shiny": m["shiny"],
		"xpParts": _com_debuff({"base": base, "streak": streak_xp, "boost": boost_t, "vip": vip, "event": evento, "gym": gym_xp, "typeDay": parcela_dia}, debuff),
		"pokeXp": {"xpGained": total_p, "parts": _com_debuff({"base": base, "boost": boost_p, "vip": vip, "event": evento, "mentor": 0, "gym": gym_xp, "typeDay": parcela_dia}, debuff_p),
			"speciesId": int(poke["speciesId"]), "level": poke["nivel"]},
		"row": m["pos"].y, "col": m["pos"].x, "slot": m["slot"]})
	_emitir({"type": "poke-xp", "id": poke.get("id", ""), "speciesId": int(poke["speciesId"]), "xpGained": total_p,
		"xp": poke["xp"], "level": poke["nivel"], "leveledUp": subiu_poke})
	var bola := _tentar_captura(m)
	if subiu_poke:
		_emitir({"type": "poke-delta", "poke": _poke_delta(poke)})
	_emitir(_msg_inventario())
	_fim_abate(m, bola)


func _berry_pct(poke: Dictionary, efeito: String) -> float:
	## Berries ativas (cfg.berries: {"<id do Pokémon>": [{efeito, pct, until}]}, sim/servico_itens.gd): efeito = tipo do golpe
	## (redução do dano recebido) ou "heal" (cura das poções). Soma as diferentes (E); a mesma não acumula (C).
	var lista: Array = cfg.get("berries", {}).get(str(poke.get("id", "")), [])
	var t := 0.0
	for b in lista:
		if String(b.get("efeito", "")) == efeito and agora_ms() < int(b.get("until", 0)):
			t += float(b.get("pct", 0))
	return minf(t, 100.0)


func _pct_boost(chave: String) -> float:
	## Boost ativo (cfg.boosts: [{key, until, pct}], A: formato da mensagem boosts) → pct; 0 sem boost.
	for b in cfg.get("boosts", []):
		if String(b.get("key", "")) == chave and agora_ms() < int(b.get("until", 0)):
			return float(b.get("pct", 0))
	return 0.0


func _tipo_do_dia_ativo(esp: Dictionary) -> bool:
	## Evento type-of-day (cfg.eventos, A: formato da mensagem events): vale para selvagem de um dos tipos do dia.
	for ev in cfg.get("eventos", []):
		if String(ev.get("key", "")) == "type-of-day" and agora_ms() < int(ev.get("until", 0)):
			return String(ev.get("tipo", "")) in Regras.tipos_de(esp)
	return false


func _rolar_loot(esp: Dictionary, lock: bool, mult: float, loot: Array) -> void:
	for e in esp.get("loot", []):
		var chance := float(e.get("chanceBruta", 0.0)) * mult
		if chance <= 0.0:
			continue
		if lock and String(p.penalidade_loot) == "chance":
			chance *= float(p.penalidade_fator)
		if rng.randf() * 100000.0 < chance:
			var qtd: int = rng.randi_intervalo(int(e.get("min", 1)), int(e.get("max", 1)))
			if lock and String(p.penalidade_loot) == "quantidade":
				qtd = int(floor(float(qtd) * float(p.penalidade_fator)))
				if qtd <= 0:
					continue
			if e.get("itemId") == null:
				continue  # item sem id no catálogo (relatorio_importacao.loot_sem_item): sorteado, mas não entregue
			loot.append({"itemId": int(e["itemId"]), "name": e["item"], "qty": qtd})
			inventario[int(e["itemId"])] = int(inventario.get(int(e["itemId"]), 0)) + qtd


func _card_shiny(esp: Dictionary, loot: Array) -> void:
	## C: "Derrote shinies selvagens — eles podem dropar o Card da espécie"; chance classe 3 (balanceamento.json
	## bosses.card_chance_shiny). Só espécies que têm o "Shiny <Espécie> Card" no catálogo (A: 52 cards).
	if _cards.is_empty():
		_cards = {"_": -1}
		for id in dados.itens:
			var n := String(dados.itens[id].get("nome", ""))
			if String(dados.itens[id].get("categoria", "")) == "card" and n.begins_with("Shiny ") and n.ends_with(" Card"):
				_cards[n.trim_prefix("Shiny ").trim_suffix(" Card").to_lower()] = int(id)
	var iid := int(_cards.get(String(esp.get("nome", "")).to_lower(), -1))
	if iid < 0:
		return
	if rng.randf() < float(p.get("card_chance_shiny", 0.0)):
		loot.append({"itemId": iid, "name": String(dados.itens[iid]["nome"]), "qty": 1})
		inventario[iid] = int(inventario.get(iid, 0)) + 1


func _garantir_pedras(esp: Dictionary, lock: bool, mult: float, rolagens: int, loot: Array) -> void:
	## Classe 3 (decisão do usuário, ciclo 2; balanceamento.json `pedra_garantia_fator`): para cada pedra de evolução da
	## tabela da espécie, soma a chance efetiva de cair neste abate; se a soma chega a `fator` (= fator × os abates
	## esperados para uma pedra) sem a pedra cair, ela cai agora. Cair zera a conta. Fator 0 desliga. O contador vai no save.
	var fator := float(p.get("pedra_garantia_fator", 0.0))
	if fator <= 0.0:
		return
	var caiu := {}
	for it in loot:
		caiu[int(it["itemId"])] = true
	for e in esp.get("loot", []):
		if e.get("itemId") == null:
			continue
		var iid := int(e["itemId"])
		if String(dados.itens.get(iid, {}).get("categoria", "")) != "stone":
			continue
		var chance := float(e.get("chanceBruta", 0.0)) * mult / 100000.0 * rolagens
		if lock and String(p.penalidade_loot) == "chance":
			chance *= float(p.penalidade_fator)
		var k := str(iid)
		if caiu.has(iid):
			garantia_pedras[k] = 0.0
			continue
		garantia_pedras[k] = float(garantia_pedras.get(k, 0.0)) + chance
		if float(garantia_pedras[k]) >= fator:
			garantia_pedras[k] = 0.0
			loot.append({"itemId": iid, "name": e["item"], "qty": int(e.get("min", 1)), "garantida": true})
			inventario[iid] = int(inventario.get(iid, 0)) + int(e.get("min", 1))


func _fim_abate(m: Dictionary, bola: bool) -> void:
	if bola:
		_emitir(_msg_balls())
	# re-alvo imediato (A: o alvo novo aparece no mesmo field da morte)
	heroi["alvo"] = _escolher_alvo()


func _troca_manual(i: int) -> void:
	## Troca pedida pelo jogador (C: comando {type: "switch", teamIndex}). E: bloqueada nos 5 s depois de uma troca
	## automática por KO; o membro precisa estar vivo e não ser o ativo. Recusa → {type: "error"} (E: o texto do
	## servidor real para isso não foi gravado).
	var motivo := ""
	if i < 0 or i >= equipe.size():
		motivo = "membro inexistente"
	elif i == ativo:
		motivo = "já está em campo"
	elif int(equipe[i]["hp"]) <= 0:
		motivo = "membro desmaiado"
	elif tick < troca_manual_liberada_tick:
		motivo = "aguarde %.1f s" % (float(troca_manual_liberada_tick - tick) * float(p.tick_ms) / 1000.0)
	if motivo != "":
		_emitir({"type": "error", "message": "Troca recusada: " + motivo})
		return
	ativo = i
	estatisticas["trocas_manuais"] += 1
	_golpes_cache.clear()


static func _com_debuff(partes: Dictionary, debuff: int) -> Dictionary:
	## A: a chave "debuff" só aparece nos abates penalizados (nos outros 601 da rhydon-1h ela não existe).
	if debuff != 0:
		partes["debuff"] = debuff
	return partes


static func nomes_filtro(texto: String) -> Array:
	## C (Auto-Helper): "Nomes (separe por vírgula)"; "Campo em branco = capturar todos. O filtro vale pros dois modos."
	var r: Array = []
	for n in texto.split(",", false):
		var t := n.strip_edges().to_lower()
		if t != "":
			r.append(t)
	return r


func _tentar_captura(m: Dictionary) -> bool:
	# C (Auto-Helper): Auto-Catch (bola própria) e Auto-Catch Shiny (outra bola, só em shiny); o filtro de nomes vale para
	# os dois. A (M3): com o Auto-Catch desligado e o Shiny ligado, só os shinies recebem bola (Idle Ball).
	var shiny := bool(m["shiny"])
	var usa_shiny := shiny and bool(cfg.get("auto_catch_shiny", false)) and int(balls.get("counts", {}).get(str(int(cfg.get("bola_auto_catch_shiny", 0))), 0)) > 0
	if not usa_shiny and not cfg.get("auto_catch", false):
		return false
	var nomes: Array = nomes_filtro(String(cfg.get("auto_catch_nomes", "")))
	if not nomes.is_empty() and not String(m["especie"].get("nome", "")).to_lower() in nomes:
		return false
	# A bola da auto-captura é configuração própria (A: balls.selected = 1, mas as tentativas gastam a bola 3).
	var sel := str(int(cfg.get("bola_auto_catch_shiny", 0) if usa_shiny else cfg.get("bola_auto_catch", 0)))
	var counts: Dictionary = balls.get("counts", {})
	if sel == "" or int(counts.get(sel, 0)) <= 0:
		return false
	counts[sel] = int(counts[sel]) - 1
	# Medidor de investimento por espécie (C; forma F, ver PARAMETROS): soma esta bola, sorteia, zera ao capturar.
	var sid := str(m["species_id"]) + ("s" if bool(m["shiny"]) else "")   # C: a tela separa a variante shiny
	var med: Dictionary = medidor.get(sid, {"investido": 0.0, "tentativas": 0, "total": 0, "gasto": 0})
	var chance := Regras.chance_captura(int(sel), float(med.get("investido", 0.0)),
		float(m["especie"].get("precoNpc", 0)), float(cfg.get("bonus_captura", 0.0)) + (float(p.boost_captura_bonus) if _pct_boost("capture") > 0.0 or _boost_ativo("capture") else 0.0), p)
	med["investido"] = float(med.get("investido", 0.0)) + Regras.valor_bola(int(sel), p)
	med["tentativas"] = int(med.get("tentativas", 0)) + 1
	med["total"] = int(med.get("total", 0)) + 1
	med["gasto"] = int(med.get("gasto", 0)) + int(p.captura_preco_bola.get(sel, 0))
	if bool(m["shiny"]):   # C: shiny não usa o medidor (chance fixa por tier × força da bola)
		chance = Regras.chance_captura_shiny(int(sel), String(dados.shiny.get(int(m["species_id"]), {}).get("tier", "")), p)
	var sucesso: bool = rng.randf() < chance
	if sucesso:
		estatisticas["capturas"] += 1
		med["investido"] = 0.0
		med["tentativas"] = 0
	medidor[sid] = med
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
			var vem := _na_visao(m["pos"])
			if not vem and int(m["slot"]) == int(heroi["alvo"]):
				# A (19/11, medir_alvo_fora.py): o alvo persegue dentro da borda real 13×13 (7,8% dos intervalos com
				# |dy| 8–13, contra 1,5% dos outros); fora dela nunca (0 de 9.120). `alvo_vem_ao_encontro` (de qualquer
				# distância) foi ajuste de curva do ciclo 1 e fica desligado.
				var hh: Vector2i = heroi["pos"]
				vem = bool(p.alvo_vem_ao_encontro) or (absi(m["pos"].x - hh.x) <= int(p.visao_meia_largura) and absi(m["pos"].y - hh.y) <= int(p.visao_meia_altura_alvo))
			if vem and _espera_minima_ok(m, int(p.mob_step_ms)) 					and tick - int(heroi["ultimo_passo_tick"]) >= int(p.mob_espera_apos_heroi_ticks):
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
	var campo := _campo_mob
	var caixa := _campo_mob_caixa
	if not caixa.has_point(atual):
		# alvo fora da caixa de visão vindo ao encontro (alvo_vem_ao_encontro): campo numa caixa que cobre os dois
		if _campo_alvo_chave != Vector3i(h.x, h.y, slot):
			_campo_alvo_chave = Vector3i(h.x, h.y, slot)
			_campo_alvo_caixa = _caixa(h, atual, int(p.caminho_margem), int(p.caminho_margem))
			_campo_alvo = _campo_tempo(h, _campo_alvo_caixa, _custos(int(p.mob_step_ms)), {})
		campo = _campo_alvo
		caixa = _campo_alvo_caixa
	var melhor := _plano(m, h, func(): return _escolher_passo(atual, h, campo, caixa,
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
	var g := _golpe(m, poke["especie"], poke["stats_dano"], "poke%s|%d" % [str(poke.get("id", ativo)), int(poke["nivel"])])
	if g.is_empty():
		return
	var especial: bool = g["categoria"] == "SPECIAL"
	var a := float(m["stats_dano"]["spAtk"] if especial else m["stats_dano"]["atk"])
	var d := float(poke["stats_dano"]["spDef"] if especial else poke["stats_dano"]["def"])
	var v := Regras.dano(int(m["nivel"]), int(g["poder"]), a, d, g["stab"], float(g["eff"]), true, _aleatorio(), p)
	var red := _berry_pct(poke, String(g["tipo"]))
	if red > 0.0:
		# Lote 3 (A: texto do items.json "Reduz … o dano sofrido de golpes do tipo X (N% de redução)"); F: round e piso 1
		v = maxi(int(p.piso_selvagem), Regras.js_round(float(v) * (1.0 - red / 100.0)))
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
			# E: sem reserva viva no time, a hunt acaba e o jogador volta à cidade (a cena trata o field-none).
			desmaiado = true
			encerrada = true
			_emitir({"type": "field-none", "slug": slug, "motivo": "sem-reserva"})
			return
		ativo = vivos[rng.randi_intervalo(0, vivos.size() - 1)]
		troca_manual_liberada_tick = tick + int(p.troca_cooldown_ms) / int(p.tick_ms)   # E: 5 s
		estatisticas["trocas_ko"] += 1
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
	var bonus := _berry_pct(poke, "heal")
	# Lote 3 (A: texto do items.json "Aumenta … a cura recebida de todas as poções usadas neste Pokémon (+N% de cura)");
	# F: a poção cura × (1 + N%) e continua limitada ao que falta (A)
	var cura := mini(Regras.js_round(float(item.get("cura", 0)) * (1.0 + bonus / 100.0)) if bonus > 0.0 else int(item.get("cura", 0)), falta)
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
	# E: poção escolhida à mão no Auto-Helper (≠ "Automatic (best)") é usada sempre que houver no inventário
	var fixa := int(cfg.get("pocao_fixa", 0))
	if fixa > 0:
		return fixa if int(inventario.get(fixa, 0)) > 0 else -1
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
