extends RefCounted
## Fase 4, lote 2: diárias e tarefas — Daily Gift (G7), Quests & Tasks por cidade, Daily Kill e Daily Catch (G5).
## Puro e determinístico: sem Node e sem relógio próprio (o "agora" vem no comando, em segundos unix); o sorteio do
## Daily Kill usa o RNG da sim com semente = dia. Mesmo contrato do servico_cidade: tratar(estado, cmd) → mensagens.
## Dados gravados (A) em dados/fase4/ (gerados por ferramentas/gravador/extrair_fase4.py; não editar à mão).
##
## Estado (o mesmo de ponte_cidade.estado_de: gold, itens {"<itemId servidor>": qtd}, bolas {"<ballId>": qtd}), mais:
##   nivel (nível do treinador), vip (bool), boosts [{key, until(ms), pct}],
##   diarias: {gift{ym, feitos, ultimo}, kill{dayKey, opcoes, pickedIdx, have, claimed}, catch{dayKey, claims[]},
##             contagem{kill{"<speciesId>": n}, capture{…}}, tarefas{"<id>": {claimed}}}
##
## Comandos (nomes do original; A = gravado, C = cliente, E = projeto, F = hipótese):
##   daily-get / daily-claim               = GET/POST /api/game/daily            (A: GET; C: POST devolve o estado + claimed)
##   tasks-get / tasks-claim {taskId}      = GET /api/game/tasks, POST /tasks/claim (A: GET; C: claim → {xp, cash, …})
##   daily-kill-get / -pick {idx} / -claim = GET/POST /api/game/daily-kill[/pick|/claim] (A: GET e pick; C: claim)
##   daily-catch-get                       = GET /api/game/daily-catch           (A)
##   dailys-summary                        = GET /api/game/dailys-summary        (A)
##   abate {speciesId} / captura {speciesId}  E: eventos da hunt (contam para tarefas, Daily Kill e Daily Catch)

const Balanceamento := preload("res://sim/balanceamento.gd")
const Rng := preload("res://sim/rng.gd")

const PARAMETROS := {
	"dia_virada_utc_s": 10800,      # A: resetAt = 03:00 UTC (meia-noite de Brasília), igual ao Tipo do Dia
	# Daily Gift (A, G7 + C): calendário de 28 prêmios por mês, um por dia, em sequência ("Come back every day and
	# collect the month's 28 rewards", C); dia VIP bloqueia quem não é VIP (C: "Today's reward is VIP-exclusive");
	# boost ativa por 1 h (C: "activated for 1h!"). E: o mês é o de Brasília; o calendário gravado vale todo mês;
	# offline o prêmio vai direto para a BAG (no original vai para o Gift Center, C).
	"gift_boost_ms": 3600000,
	"gift_pular_vip": false,           # classe 3 (balanceamento.json): sem VIP, pula o dia VIP
	# Daily Kill (A, G5): xp = floor(qtd × xpAbate × 8/3) (3/3 opções); 3 opções; minLevel 25; sem reroll (rerollMax 0);
	# prêmio do tier "hard" = 2 × os itens do tier hard do Daily Catch (A). E: o tier sai do nível do treinador pela
	# tabela do Daily Catch; as espécies saem da lista do tier; as quantidades por faixa abaixo (A só no hard: 798–1497).
	"kill_opcoes": 3,
	"kill_min_nivel": 25,
	"kill_xp_fator": 8.0 / 3.0,
	"kill_qtd": {"superEasy": [100, 300], "easy": [200, 600], "medium": [400, 1200], "hard": [500, 1500]},
	"kill_itens_mult": 2,
	# Daily Catch (A, G5): 2 capturas premiadas por dia; faixas por nível do treinador; capturar espécie da tabela
	# preenche o próximo slot (C: "capture um Pokémon da tabela"). XP = floor(xpAbate × 8/3 × m): A, os 4 casos gravados
	# dão m múltiplo de 0,5 — Larvitar (548) 10 e 14 (G5), Arbok (968) 1,5 e 18 (G9). A regra "m pelo slot" (F de 13/11)
	# caiu (Arbok slot 1 = 1,5, slot 2 = 18). F/E: m sorteado (semente = dia e slot) entre os múltiplos de 0,5 de 1,5 a 18
	# (a faixa observada); limitado a [xpMin, xpMax] da faixa.
	"catch_total": 2,
	"catch_mult_min": 1.5,
	"catch_mult_max": 18.0,
}

var p: Dictionary = PARAMETROS.duplicate(true)
var dados   # DadosJogo (espécies: nome, looktype, tipos, xpAbate)
var gift: Dictionary
var catch_tab: Dictionary
var tarefas: Dictionary
var kill_gravado: Dictionary


func _init(dados_jogo, parametros: Dictionary = {}) -> void:
	dados = dados_jogo
	Balanceamento.aplicar(p, "diarias")   # classe 3: dados/balanceamento.json
	for k in parametros:
		p[k] = parametros[k]
	gift = _ler("res://dados/fase4/daily_gift.json")
	catch_tab = _ler("res://dados/fase4/daily_catch.json")
	tarefas = _ler("res://dados/fase4/tarefas.json")
	kill_gravado = _ler("res://dados/fase4/daily_kill.json")


static func _ler(caminho: String) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return v if v is Dictionary else {}


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	var agora := int(cmd.get("agora", 0))
	_diarias(estado, agora, cmd.has("agora"))   # sem "agora" (abate vindo da hunt sem relógio) não vira o dia
	match String(cmd.get("type", "")):
		"daily-get":
			return [msg_gift(estado, agora)]
		"daily-claim":
			return _gift_coletar(estado, agora)
		"tasks-get":
			return [msg_tarefas(estado)]
		"tasks-claim":
			return _tarefa_coletar(estado, String(cmd.get("taskId", "")))
		"daily-kill-get":
			return [msg_kill(estado, agora)]
		"daily-kill-pick":
			return _kill_escolher(estado, agora, int(cmd.get("idx", -1)))
		"daily-kill-claim":
			return _kill_coletar(estado, agora)
		"daily-catch-get":
			return [msg_catch(estado, agora)]
		"dailys-summary":
			return [msg_resumo(estado, agora)]
		"abate":
			return _abate(estado, int(cmd.get("speciesId", -1)), int(cmd.get("n", 1)))
		"captura":
			return _captura(estado, agora, int(cmd.get("speciesId", -1)))
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


# ============================================================================== dia e estado

func dia(agora: int) -> int:
	return int(floor(float(agora - int(p.dia_virada_utc_s)) / 86400.0))


func chave_dia(agora: int) -> String:
	return Time.get_date_string_from_unix_time(dia(agora) * 86400)   # A: dayKey "2026-11-13"


func reset_ms(agora: int) -> int:
	return ((dia(agora) + 1) * 86400 + int(p.dia_virada_utc_s)) * 1000   # A: resetAt 1794625200000 em 13/11


func _diarias(estado: Dictionary, agora: int, virar: bool = true) -> Dictionary:
	if not estado.has("diarias"):
		estado["diarias"] = {}
	var d: Dictionary = estado["diarias"]
	for k in ["gift", "kill", "catch", "tarefas"]:
		if not d.has(k):
			d[k] = {}
	if not d.has("contagem"):
		d["contagem"] = {"kill": {}, "capture": {}}
	if not virar:
		if not d["catch"].has("claims"):
			d["catch"]["claims"] = []
		return d
	var chave := chave_dia(agora)
	if String(d["kill"].get("dayKey", "")) != chave:
		d["kill"] = {"dayKey": chave}
	if String(d["catch"].get("dayKey", "")) != chave:
		d["catch"] = {"dayKey": chave, "claims": []}
	return d


func _especie(id: int) -> Dictionary:
	return dados.especie(id) if dados != null else {}


func _poke_info(id: int) -> Dictionary:
	var e := _especie(id)
	var tipos: Array = e.get("tipos", [])
	var r := {"name": String(e.get("nome", "")), "looktype": int(e.get("looktype", 0)), "type1": String(tipos[0]) if tipos.size() > 0 else ""}
	if tipos.size() > 1:
		r["type2"] = String(tipos[1])
	return r


func _msg_inventario(estado: Dictionary) -> Dictionary:
	var itens: Array = []
	for k in estado.get("itens", {}):
		if int(estado["itens"][k]) > 0:
			itens.append({"itemId": int(k), "quantity": int(estado["itens"][k])})
	return {"type": "inventory", "items": itens}


func _entregar_itens(estado: Dictionary, itens: Array) -> Array:
	## Itens {itemId, qty} na BAG. itemId −1 (Newbie Gift no Daily Catch, A) não existe no catálogo: fica registrado e
	## não entra (E).
	var entregues: Array = []
	if not estado.has("itens"):
		estado["itens"] = {}
	for it in itens:
		var id := int(it.get("itemId", -1))
		if id < 0:
			continue
		var k := str(id)
		estado["itens"][k] = int(estado["itens"].get(k, 0)) + int(it["qty"])
		entregues.append({"itemId": id, "qty": int(it["qty"]), "label": "%d× %s" % [int(it["qty"]), String(it.get("name", ""))]})
	return entregues


# ============================================================================== Daily Gift

func _ym(agora: int) -> String:
	return chave_dia(agora).substr(0, 7)


func _gift_estado(estado: Dictionary, agora: int) -> Dictionary:
	var g: Dictionary = estado["diarias"]["gift"]
	if String(g.get("ym", "")) != _ym(agora):
		g.clear()
		g["ym"] = _ym(agora)
		g["feitos"] = 0
		g["ultimo"] = ""
	return g


func msg_gift(estado: Dictionary, agora: int) -> Dictionary:
	## A (G7): {ym, vip, total, nextDay, canClaim, claimedToday, blockedByVip, rewards[{day, label, icon, qty, tag, kind,
	## locked, claimed, current}]}.
	var g := _gift_estado(estado, agora)
	var rewards: Array = gift.get("rewards", [])
	var total := rewards.size()
	var prox := int(g["feitos"]) + 1
	var hoje := String(g["ultimo"]) == chave_dia(agora)
	var vip := bool(estado.get("vip", false))
	# Classe 3 (decisão do usuário, ciclo 3; `gift_pular_vip`): sem VIP, o dia VIP é pulado em vez de travar o calendário
	# (no original ele trava, C). O pulado fica marcado como `skipped`.
	if not vip and bool(p.get("gift_pular_vip", false)):
		while prox <= total and str(rewards[prox - 1].get("tag", "")) == "VIP":
			prox += 1
	var bloqueado := false
	if prox <= total and not hoje:
		bloqueado = str(rewards[prox - 1].get("tag", "")) == "VIP" and not vip
	var lista: Array = []
	for r in rewards:
		var d := int(r["day"])
		lista.append({"day": d, "label": String(r["label"]), "icon": String(r["icon"]), "qty": int(r["qty"]), "tag": r.get("tag"),
			"kind": String(r["kind"]), "locked": str(r.get("tag", "")) == "VIP" and not vip, "claimed": d <= int(g["feitos"]) and not (str(r.get("tag", "")) == "VIP" and not vip),
			"skipped": d < prox and str(r.get("tag", "")) == "VIP" and not vip, "current": d == prox})
	return {"type": "daily", "ym": String(g["ym"]), "vip": vip, "total": total, "nextDay": prox,
		"canClaim": prox <= total and not hoje and not bloqueado, "claimedToday": hoje, "blockedByVip": bloqueado, "rewards": lista}


static func _bola_do_icone(icone: String) -> int:
	## Os prêmios de bola só trazem o ícone (A): /assets/markitems/<nome>.png
	for par in [["pokeball", 1], ["greatball", 2], ["superball", 3], ["ultraball", 4], ["idleball", 6]]:
		if icone.get_file().get_basename() == par[0]:
			return int(par[1])
	return -1


static func _pct_e_horas(label: String) -> Array:
	var re := RegEx.new()
	re.compile("\\+(\\d+)%")
	var m := re.search(label)
	return [int(m.get_string(1)) if m != null else 0]


func _id_item_por_nome(nome: String) -> int:
	for id in dados.itens:
		if String(dados.itens[id].get("nome", "")) == nome:
			return int(id)
	return -1


func _gift_coletar(estado: Dictionary, agora: int) -> Array:
	var m := msg_gift(estado, agora)
	if not bool(m["canClaim"]):
		if bool(m["blockedByVip"]):
			return [_erro("O prêmio de hoje é exclusivo VIP.")]
		if bool(m["claimedToday"]):
			return [_erro("Já coletado hoje.")]
		return [_erro("Calendário completo.")]
	var r: Dictionary = gift["rewards"][int(m["nextDay"]) - 1]
	var saida: Array = []
	var kind := String(r["kind"])
	var qtd := int(r["qty"])
	match kind:
		"ball", "idleball":
			var b := _bola_do_icone(String(r["icon"]))
			if b < 0:
				return [_erro("Bola desconhecida: " + String(r["icon"]))]
			if not estado.has("bolas"):
				estado["bolas"] = {}
			estado["bolas"][str(b)] = int(estado["bolas"].get(str(b), 0)) + qtd
			saida.append({"type": "balls", "counts": estado["bolas"].duplicate(), "gold": int(estado.get("gold", 0))})
		"item":
			var id := _id_item_por_nome(String(r["label"]))
			if id < 0:
				return [_erro("Item desconhecido: " + String(r["label"]))]
			_entregar_itens(estado, [{"itemId": id, "qty": qtd, "name": r["label"]}])
			saida.append(_msg_inventario(estado))
		"xpboost", "lootboost":
			var chave := "xp" if kind == "xpboost" else "loot"
			var pct: int = _pct_e_horas(String(r["label"]))[0]
			if not estado.has("boosts"):
				estado["boosts"] = []
			var ate := agora * 1000 + int(p.gift_boost_ms)
			var achou := false
			for bst in estado["boosts"]:
				if String(bst.get("key", "")) == chave and int(bst.get("pct", 0)) == pct and int(bst.get("until", 0)) > agora * 1000:
					bst["until"] = int(bst["until"]) + int(p.gift_boost_ms)   # E: o mesmo boost ativo soma 1 h
					achou = true
			if not achou:
				estado["boosts"].append({"key": chave, "until": ate, "pct": pct})
			saida.append({"type": "boosts", "boosts": estado["boosts"].duplicate(true)})
		_:
			return [_erro("Prêmio desconhecido: " + kind)]
	var g := _gift_estado(estado, agora)
	g["feitos"] = int(m["nextDay"])   # o dia coletado (os VIP pulados antes dele contam como passados)
	g["ultimo"] = chave_dia(agora)
	var novo := msg_gift(estado, agora)
	# A (G9): POST /daily → o estado + claimed {day, kind, refId, qty, label, icon, tag} + toGiftCenter (true no original:
	# o prêmio vai para o Gift Center). Offline vai direto para a BAG/boosts (E), então toGiftCenter = false. refId 0 nos
	# boosts (A); nas bolas e itens, o id (E: não gravado).
	var ref := 0
	if kind in ["ball", "idleball"]:
		ref = _bola_do_icone(String(r["icon"]))
	elif kind == "item":
		ref = _id_item_por_nome(String(r["label"]))
	novo["claimed"] = {"day": int(r["day"]), "kind": kind, "refId": ref, "qty": qtd, "label": String(r["label"]),
		"icon": String(r["icon"]), "tag": r.get("tag")}
	novo["toGiftCenter"] = false
	return [novo] + saida


# ============================================================================== Quests & Tasks

func _have(estado: Dictionary, g: Dictionary) -> int:
	## E: kill/capture contam desde que o contador existe (o original mostra o progresso do servidor, A); deliver conta
	## o que está na BAG agora (E: o item sai na coleta).
	var c: Dictionary = estado["diarias"]["contagem"]
	match String(g["kind"]):
		"kill":
			return int(c["kill"].get(str(int(g["pokeId"])), 0))
		"capture":
			return int(c["capture"].get(str(int(g["pokeId"])), 0))
		"deliver":
			return int(estado.get("itens", {}).get(str(int(g["pokeId"])), 0))
	return 0


func _tarefa(estado: Dictionary, t: Dictionary) -> Dictionary:
	## A (G5): {id, npc, city, goals, xp, cash, claimed, goalProgress[{pokeId, name, qty, kind, have, done, looktype,
	## type1, type2?}], complete}; have limitado a qty (A: Rattata 15/15).
	var claimed := bool(estado["diarias"]["tarefas"].get(String(t["id"]), {}).get("claimed", false))
	var prog: Array = []
	var completa := true
	for g in t["goals"]:
		var h := mini(int(g["qty"]), _have(estado, g))
		var linha := {"pokeId": int(g["pokeId"]), "name": String(g["name"]), "qty": int(g["qty"]), "kind": String(g["kind"]), "have": h, "done": h >= int(g["qty"])}
		if String(g["kind"]) != "deliver":
			linha.merge(_poke_info(int(g["pokeId"])))
			linha["name"] = String(g["name"])
		prog.append(linha)
		completa = completa and h >= int(g["qty"])
	return {"id": String(t["id"]), "npc": String(t["npc"]), "city": String(t["city"]), "goals": t["goals"], "xp": int(t["xp"]),
		"cash": int(t["cash"]), "claimed": claimed, "goalProgress": prog, "complete": completa}


func msg_tarefas(estado: Dictionary) -> Dictionary:
	var lista: Array = []
	for t in tarefas.get("tarefas", []):
		lista.append(_tarefa(estado, t))
	return {"type": "tasks", "tasks": lista, "cities": tarefas.get("cidades", [])}


func _tarefa_coletar(estado: Dictionary, id: String) -> Array:
	## C: POST /tasks/claim {taskId} → {xp, cash, totalXp, level, leveledUp}. E: cada tarefa paga uma vez.
	for t in tarefas.get("tarefas", []):
		if String(t["id"]) != id:
			continue
		var r := _tarefa(estado, t)
		if bool(r["claimed"]):
			return [_erro("Tarefa já entregue.")]
		if not bool(r["complete"]):
			return [_erro("Tarefa incompleta.")]
		var saida: Array = []
		for g in t["goals"]:
			if String(g["kind"]) == "deliver":
				var k := str(int(g["pokeId"]))
				estado["itens"][k] = int(estado["itens"][k]) - int(g["qty"])
				if int(estado["itens"][k]) <= 0:
					estado["itens"].erase(k)
				saida = [_msg_inventario(estado)]
		estado["diarias"]["tarefas"][id] = {"claimed": true}
		estado["gold"] = int(estado.get("gold", 0)) + int(t["cash"])
		# A (G9): {ok, taskId, xp, cash, totalXp, level, leveledUp} (totalXp/level/leveledUp: o cliente completa)
		return [{"type": "tasks-claimed", "ok": true, "taskId": id, "xp": int(t["xp"]), "cash": int(t["cash"])},
			{"type": "currency", "gold": int(estado["gold"])}] + saida
	return [_erro("Tarefa desconhecida.")]


# ============================================================================== Daily Catch

func _tiers_liberados(estado: Dictionary) -> Array:
	var n := int(estado.get("nivel", 1))
	return (catch_tab.get("tiers", []) as Array).filter(func(t): return n >= int(t["minLevel"]))


func _tier_do_nivel(nivel: int) -> Dictionary:
	## E: a faixa cujo [minLevel, maxLevel] contém o nível; acima da última, a última.
	var tiers: Array = catch_tab.get("tiers", [])
	for t in tiers:
		if nivel >= int(t["minLevel"]) and (t.get("maxLevel") == null or nivel <= int(t["maxLevel"])):
			return t
	if not tiers.is_empty() and nivel > int(tiers[tiers.size() - 1]["minLevel"]):
		return tiers[tiers.size() - 1]
	return {}


func msg_catch(estado: Dictionary, agora: int) -> Dictionary:
	## A (G5): {dayKey, resetAt, used, total, claims[{slot, speciesId, tierKey, xp, …}], tiers[…]} (só as faixas
	## liberadas no nível, C: "Faixas liberadas").
	var c: Dictionary = estado["diarias"]["catch"]
	var tiers: Array = []
	for t in _tiers_liberados(estado):
		var esp: Array = []
		for s in t["species"]:
			var e := {"id": int(s["id"]), "huntLevel": int(s["huntLevel"])}
			e.merge(_poke_info(int(s["id"])))
			e["name"] = String(s["name"])
			esp.append(e)
		tiers.append({"key": t["key"], "label": t["label"], "minLevel": t["minLevel"], "maxLevel": t.get("maxLevel"),
			"reward": t["reward"], "rewardText": t["rewardText"], "species": esp})
	return {"type": "daily-catch", "dayKey": String(c["dayKey"]), "resetAt": reset_ms(agora), "used": (c["claims"] as Array).size(),
		"total": int(p.catch_total), "claims": (c["claims"] as Array).duplicate(true), "tiers": tiers}


func _captura(estado: Dictionary, agora: int, especie: int) -> Array:
	var cont: Dictionary = estado["diarias"]["contagem"]["capture"]
	cont[str(especie)] = int(cont.get(str(especie), 0)) + 1
	var c: Dictionary = estado["diarias"]["catch"]
	var slot := (c["claims"] as Array).size() + 1
	if slot > int(p.catch_total):
		return []
	var tier: Dictionary = {}
	for t in _tiers_liberados(estado):   # E: a faixa mais alta liberada que tem a espécie
		for s in t["species"]:
			if int(s["id"]) == especie:
				tier = t
	if tier.is_empty():
		return []
	var rng = Rng.new(dia(agora) * 104729 + slot * 7 + 3)
	var passos := int(round((float(p.catch_mult_max) - float(p.catch_mult_min)) / 0.5))
	var m := float(p.catch_mult_min) + 0.5 * float(int(rng.randf() * (passos + 1)))
	var xp_abate := float(_especie(especie).get("xpAbate", 0))
	var xp := int(floor(xp_abate * float(p.kill_xp_fator) * m + 1e-6))
	var rw: Dictionary = tier["reward"]
	xp = clampi(xp, int(rw.get("xpMin", 0)), int(rw.get("xpMax", xp))) if rw.has("xpMax") else xp
	var claim := {"slot": slot, "speciesId": especie, "tierKey": String(tier["key"]), "tierLabel": String(tier["label"]), "xp": xp}
	claim.merge(_poke_info(especie))
	c["claims"].append(claim)
	var entregues := _entregar_itens(estado, rw.get("items", []))
	return [{"type": "daily-catch-claimed", "claim": claim, "xp": xp, "items": entregues}, _msg_inventario(estado)]


# ============================================================================== Daily Kill

func _kill_gerar(estado: Dictionary, agora: int) -> void:
	var k: Dictionary = estado["diarias"]["kill"]
	if k.has("opcoes"):
		return
	var tier := _tier_do_nivel(int(estado.get("nivel", 1)))
	k["tierKey"] = String(tier.get("key", ""))
	k["tierLabel"] = String(tier.get("label", ""))
	k["pickedIdx"] = -1
	k["have"] = 0
	k["claimed"] = false
	k["opcoes"] = []
	if tier.is_empty():
		return
	var rng = Rng.new(dia(agora) * 7919 + 17)   # E: o mesmo dia sorteia as mesmas opções
	var pool: Array = (tier["species"] as Array).duplicate()
	var faixa: Array = p.kill_qtd.get(String(tier["key"]), [500, 1500])
	for i in mini(int(p.kill_opcoes), pool.size()):
		var j := int(rng.randf() * pool.size())
		var s: Dictionary = pool[j]
		pool.remove_at(j)
		var qtd := int(faixa[0]) + int(rng.randf() * (int(faixa[1]) - int(faixa[0]) + 1))
		k["opcoes"].append({"speciesId": int(s["id"]), "qty": qtd})


func _kill_xp(o: Dictionary) -> int:
	return int(floor(float(o["qty"]) * float(_especie(int(o["speciesId"])).get("xpAbate", 0)) * float(p.kill_xp_fator) + 1e-6))


func msg_kill(estado: Dictionary, agora: int) -> Dictionary:
	## A (G5): {dayKey, resetAt, tierKey, tierLabel, options[{xp, qty, name, speciesId, looktype, type1, have, done}],
	## pickedIdx, claimed, reward{xp, items}, rewardText, locked, minLevel, cards, rerollCost, rerolls, rerollMax}.
	_kill_gerar(estado, agora)
	var k: Dictionary = estado["diarias"]["kill"]
	var pick := int(k["pickedIdx"])
	var ops: Array = []
	for i in (k["opcoes"] as Array).size():
		var o: Dictionary = k["opcoes"][i]
		var h := int(k["have"]) if i == pick else 0
		var e := {"xp": _kill_xp(o), "qty": int(o["qty"]), "speciesId": int(o["speciesId"]), "have": mini(h, int(o["qty"])), "done": h >= int(o["qty"])}
		e.merge(_poke_info(int(o["speciesId"])))
		ops.append(e)
	var tier := _tier_do_nivel(int(estado.get("nivel", 1)))
	var itens: Array = []
	var texto: Array = []
	for it in tier.get("reward", {}).get("items", []):
		if int(it["itemId"]) < 0:
			continue
		var q := int(it["qty"]) * int(p.kill_itens_mult)
		itens.append({"icon": it.get("icon", ""), "itemId": int(it["itemId"]), "name": String(it["name"]), "qty": q})
		texto.append("%d× %s" % [q, String(it["name"])])
	return {"type": "daily-kill", "dayKey": String(k["dayKey"]), "resetAt": reset_ms(agora), "tierKey": String(k["tierKey"]),
		"tierLabel": String(k["tierLabel"]), "options": ops, "pickedIdx": pick, "claimed": bool(k["claimed"]),
		"reward": {"xp": int(ops[pick]["xp"]) if pick >= 0 else 0, "items": itens}, "rewardText": texto,
		"locked": int(estado.get("nivel", 1)) < int(p.kill_min_nivel), "minLevel": int(p.kill_min_nivel), "cards": 0,
		"rerollCost": 1, "rerolls": 0, "rerollMax": 0}


func _kill_escolher(estado: Dictionary, agora: int, idx: int) -> Array:
	var m := msg_kill(estado, agora)
	var k: Dictionary = estado["diarias"]["kill"]
	if bool(m["locked"]):
		return [_erro("Daily Kill libera no nível %d." % int(p.kill_min_nivel))]
	if int(k["pickedIdx"]) >= 0:
		return [_erro("Missão de hoje já escolhida.")]
	if idx < 0 or idx >= (k["opcoes"] as Array).size():
		return [_erro("Opção inválida.")]
	k["pickedIdx"] = idx
	k["have"] = 0   # A: have 0 logo depois do pick
	return [msg_kill(estado, agora)]


func _kill_coletar(estado: Dictionary, agora: int) -> Array:
	## C: POST /daily-kill/claim → {state, payout{xp, items[{label}], totalXp, level, leveledUp}}.
	var m := msg_kill(estado, agora)
	var k: Dictionary = estado["diarias"]["kill"]
	var pick := int(k["pickedIdx"])
	if pick < 0:
		return [_erro("Escolha uma missão primeiro.")]
	if bool(k["claimed"]):
		return [_erro("Prêmio de hoje já coletado.")]
	if not bool(m["options"][pick]["done"]):
		return [_erro("Missão incompleta.")]
	k["claimed"] = true
	var entregues := _entregar_itens(estado, m["reward"]["items"])
	return [{"type": "daily-kill-claimed", "state": msg_kill(estado, agora), "payout": {"xp": int(m["reward"]["xp"]), "items": entregues}},
		_msg_inventario(estado)]


func _abate(estado: Dictionary, especie: int, n: int) -> Array:
	var cont: Dictionary = estado["diarias"]["contagem"]["kill"]
	cont[str(especie)] = int(cont.get(str(especie), 0)) + n
	var k: Dictionary = estado["diarias"]["kill"]
	if k.has("opcoes") and int(k.get("pickedIdx", -1)) >= 0 and not bool(k.get("claimed", false)):
		if int(k["opcoes"][int(k["pickedIdx"])]["speciesId"]) == especie:
			k["have"] = int(k["have"]) + n
	return []


# ============================================================================== resumo

func msg_resumo(estado: Dictionary, agora: int) -> Dictionary:
	## A (G5): {resetAt, kill{locked, picked, done, claimed, target, have, qty}, catch{used, total}, tasks{ready}}.
	var km := msg_kill(estado, agora)
	var pick := int(km["pickedIdx"])
	var alvo: Variant = null
	var qtd := 0
	var have := 0
	var feito := false
	if pick >= 0:
		alvo = String(km["options"][pick]["name"])
		qtd = int(km["options"][pick]["qty"])
		have = int(km["options"][pick]["have"])
		feito = bool(km["options"][pick]["done"])
	var prontas := 0
	for t in msg_tarefas(estado)["tasks"]:
		if bool(t["complete"]) and not bool(t["claimed"]):
			prontas += 1
	var cm := msg_catch(estado, agora)
	return {"type": "dailys-summary", "resetAt": reset_ms(agora), "kill": {"locked": bool(km["locked"]), "picked": pick >= 0,
		"done": feito, "claimed": bool(km["claimed"]), "target": alvo, "have": have, "qty": qtd},
		"catch": {"used": int(cm["used"]), "total": int(cm["total"])}, "tasks": {"ready": prontas}}
