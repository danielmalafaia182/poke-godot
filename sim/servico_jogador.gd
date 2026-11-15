extends RefCounted
## Fase 4, lote 2: serviços do jogador fora da cidade — sessão, Modo Soneca (farm offline), Streak Points e o Tipo do
## Dia. Puro e determinístico: sem Node, sem relógio próprio (o "agora" vem no comando, em segundos unix), RNG só o
## da simulação da amostra (semente no comando). Mesmo contrato do servico_cidade: tratar(estado, cmd) → mensagens.
##
## Estado (no save; ver ponte_cidade.gd):
##   streak: {totalKills, spent: {exp, loot, shiny}, bySpecies: {"<speciesId>": abates}}         gold: int
##   soneca: {} ou {inicio, fim, entregue, amostra{slug, startedAt, endedAt, sampleMs, itemsUsed, fainted, killsBySpecies,
##            leaderId, kills, xpSample, pokeXpSample, loot, linha, pocoes}}   (formato da amostra = A, G6; `loot`, `linha`,
##            `pocoes` e `entregue` são E)
##   sessao: {fechado_em (unix do último fechamento)}
##
## Comandos (nomes do original quando existem; C = cliente, A = gravação, E = projeto):
##   streak-get                       = GET  /api/game/streak               (A, G7)
##   streak-spend {track}             = POST /api/game/streak/spend {track} (A, G7: responde o mesmo objeto)
##   sleep-mode {agora, amostra}      = WS sleep-mode → sleep-ok            (C; a amostra é calculada por quem tem a
##                                                                           hunt: amostra_soneca(), abaixo)
##   offline-get {agora, poke}        = GET  /api/game/offline → {report?}  (A, G6) [+ offline-sample, E]
##   offline-claim {agora, boost, poke} = POST /api/game/offline {boost}    (A, G6)
##   sessao {fechado_em, agora}       E: decide se a sessão expirou (regra do usuário)
##   eventos {agora}                  E: Tipo do Dia offline (formato da mensagem events, A)

const Regras := preload("res://sim/regras.gd")

const PARAMETROS := {
	# Sessão (B-relatado / regra do usuário, 11/11): sem soneca, 15 min com o jogo fechado matam a sessão; voltar à
	# mesma hunt pela cidade não penaliza (CenarioJogo.penalizar_entrada). Com soneca coletada, a sessão segue (E).
	"sessao_expira_s": 900,
	# Jogo fechado em hunt, sem soneca (B-relatado pelo usuário, 15/11): o servidor segue caçando até a sessão morrer, 15 min
	# depois de fechar; ao reabrir, offline a sim recupera esse tempo (até 15 min) e descarta o resto.
	"fechado_caca_max_s": 900,
	# Modo Soneca (C, guia "Nap Mode" e janela "While you were away"):
	"soneca_amostra_s": 300,          # C: "the hunt continues on the server for 5 minutes" (combate, XP, loot, Auto-Potion; sem bolas)
	"soneca_teto_s": 86400,           # C: "Time counts from the end of the nap until login, with a cap of 24h"
	"soneca_fracao": 0.5,             # C: "Collect: 50% of the sample's XP rate"
	"soneca_fracao_turbo": 1.0,       # C: "Turbo (2💎): 100%" — sem diamantes offline, o turbo é recusado (E)
	"soneca_turbo_custo": 2,          # C
	"soneca_turbo_disponivel": false, # E: o jogo offline não tem diamantes
	# Streak Points (C, guia): 1 ponto a cada 1000 abates; o n-ésimo ponto custa 25.000 × n de ouro; trilhas exp/loot/shiny.
	"streak_abates_por_ponto": 1000,
	"streak_custo_base": 25000,
	"streak_trilhas": ["exp", "loot", "shiny"],
	# Tipo do Dia (A: evento type-of-day, +20% XP e loot no tipo; termina às 03:00 UTC = meia-noite de Brasília).
	# E: offline, rotação fixa ancorada nos quatro dias observados (A: 09/11/2026 Dragão, 10/11 Inseto, 13/11 Sombrio,
	# 15/11 Veneno); as outras posições são E.
	"dia_virada_utc_s": 10800,
	"dia_ancora": 20766,              # dia (unix/86400, deslocado pela virada) de 09/11/2026 em Brasília
	"rotacao_tipos": ["DRAGON", "BUG", "FIRE", "WATER", "DARK", "GRASS", "POISON", "ELECTRIC", "ICE", "FIGHTING",
		"GROUND", "FLYING", "PSYCHIC", "ROCK", "GHOST", "STEEL", "FAIRY", "NORMAL"],
	"nomes_tipos": {"BUG": ["Inseto", "🐛"], "DARK": ["Sombrio", "🌑"], "DRAGON": ["Dragão", "🐉"], "ELECTRIC": ["Elétrico", "⚡"],
		"FAIRY": ["Fada", "🧚"], "FIGHTING": ["Lutador", "🥊"], "FIRE": ["Fogo", "🔥"], "FLYING": ["Voador", "🕊️"],
		"GHOST": ["Fantasma", "👻"], "GRASS": ["Planta", "🌿"], "GROUND": ["Terra", "⛰️"], "ICE": ["Gelo", "❄️"],
		"NORMAL": ["Normal", "⚪"], "POISON": ["Veneno", "☠️"], "PSYCHIC": ["Psíquico", "🔮"], "ROCK": ["Pedra", "🪨"],
		"STEEL": ["Aço", "⚙️"], "WATER": ["Água", "💧"]},
}

var p: Dictionary = PARAMETROS.duplicate(true)


func _init(parametros: Dictionary = {}) -> void:
	for k in parametros:
		p[k] = parametros[k]


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	match String(cmd.get("type", "")):
		"streak-get":
			return [msg_streak(estado)]
		"streak-spend":
			return _gastar_streak(estado, String(cmd.get("track", "")))
		"sleep-mode":
			return _dormir(estado, cmd)
		"offline-get":
			return _relatorio_msgs(estado, int(cmd.get("agora", 0)), cmd.get("poke", {}))
		"offline-claim":
			return _coletar(estado, int(cmd.get("agora", 0)), bool(cmd.get("boost", false)), cmd.get("poke", {}))
		"sessao":
			return [_sessao(estado, int(cmd.get("fechado_em", 0)), int(cmd.get("agora", 0)))]
		"eventos":
			return [msg_eventos(int(cmd.get("agora", 0)))]
	return [{"type": "error", "message": "comando desconhecido: " + String(cmd.get("type", ""))}]


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


# ============================================================================== sessão

func _sessao(estado: Dictionary, fechado_em: int, agora: int) -> Dictionary:
	var soneca: Dictionary = estado.get("soneca", {})
	var expirou := fechado_em <= 0 or (agora - fechado_em >= int(p.sessao_expira_s))
	if not soneca.is_empty() and agora - int(soneca.get("inicio", 0)) >= int(p.soneca_amostra_s):
		expirou = false   # E: com a soneca valendo, a sessão continua
	return {"type": "sessao", "expirada": expirou, "fechadoS": maxi(0, agora - fechado_em)}


# ============================================================================== jogo fechado em hunt (sem soneca)

func segundos_recuperar(estado: Dictionary, fechado_em: int, agora: int) -> int:
	## Quanto da caça recuperar ao reabrir: fechado numa hunt (estado.hunt_ao_fechar) e sem soneca → min(tempo fechado,
	## 15 min); com soneca, 0 (vale a regra da soneca); sem hunt, 0.
	if String(estado.get("hunt_ao_fechar", "")) == "" or fechado_em <= 0:
		return 0
	if not (estado.get("soneca", {}) as Dictionary).is_empty():
		return 0
	return clampi(agora - fechado_em, 0, int(p.fechado_caca_max_s))


static func rodar_recuperacao(sim, segundos: int) -> Dictionary:
	## Roda a hunt por `segundos` com as configurações do jogador (Auto-Catch e Auto-Potion como estavam) e resume:
	## abates por espécie, XP do treinador e de cada membro, loot, capturas (espécie), bolas e poções gastas, HP no fim.
	var xp_t0 := int(sim.treinador["xp"])
	var xp0 := {}
	for e in sim.equipe:
		xp0[String(e.get("id", ""))] = int(e["xp"])
	var inv0: Dictionary = sim.inventario.duplicate()
	var bolas0: Dictionary = (sim.balls.get("counts", {}) as Dictionary).duplicate()
	var por_especie := {}
	var loot := {}
	var capturas: Array = []
	var ticks := segundos * 1000 / int(sim.p.tick_ms)
	var feitos := 0
	for t in ticks:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			match String(m.get("type", "")):
				"field-kill":
					var k := str(int(m.get("speciesId", 0)))
					por_especie[k] = int(por_especie.get(k, 0)) + 1
					for it in m.get("loot", []):
						loot[str(int(it["itemId"]))] = int(loot.get(str(int(it["itemId"])), 0)) + int(it["qty"])
				"catch-result":
					if bool(m.get("success", false)):
						capturas.append(String(m.get("speciesName", "")))
		feitos = t + 1
		if sim.encerrada:
			break
	var xp_membros := {}
	var hp := {}
	for e in sim.equipe:
		var id := String(e.get("id", ""))
		xp_membros[id] = int(e["xp"]) - int(xp0.get(id, 0))
		hp[id] = int(e["hp"])
	var pocoes := {}
	for k in inv0:
		var g := int(inv0[k]) - int(sim.inventario.get(k, 0))
		if g > 0:
			pocoes[str(int(k))] = g
	var bolas := {}
	for k in bolas0:
		var g2 := int(bolas0[k]) - int(sim.balls.get("counts", {}).get(k, 0))
		if g2 > 0:
			bolas[str(k)] = g2
	var kills := 0
	for k in por_especie:
		kills += int(por_especie[k])
	return {"segundos": feitos * int(sim.p.tick_ms) / 1000, "kills": kills, "killsBySpecies": por_especie,
		"xpTreinador": int(sim.treinador["xp"]) - xp_t0, "xpMembros": xp_membros, "hp": hp, "loot": loot,
		"capturas": capturas, "pocoes": pocoes, "bolas": bolas, "encerrada": bool(sim.encerrada)}


# ============================================================================== Streak Points

func _streak(estado: Dictionary) -> Dictionary:
	if not estado.has("streak"):
		estado["streak"] = {}
	var s: Dictionary = estado["streak"]
	if not s.has("totalKills"):
		s["totalKills"] = 0
	if not s.has("spent"):
		s["spent"] = {}
	if not s.has("bySpecies"):
		s["bySpecies"] = {}
	for t in p.streak_trilhas:
		if not s["spent"].has(t):
			s["spent"][t] = 0
	return s


func _gastos(s: Dictionary) -> int:
	var n := 0
	for t in s["spent"]:
		n += int(s["spent"][t])
	return n


func msg_streak(estado: Dictionary, dados = null) -> Dictionary:
	## A (G7): GET /api/game/streak = {totalKills, killsPerPoint, earned, spent, available, toNext, nextCost, canBuy, gold,
	## tracks{exp, loot, shiny} (pontos), bonusPct{…} (0,1% por ponto), kills[{speciesId, name, looktype, kills}]
	## (abates por espécie, do maior para o menor)}. Custos conferidos: 20º ponto = 500.000, 21º = 525.000 (A).
	var s := _streak(estado)
	var por := int(p.streak_abates_por_ponto)
	var ganhos := int(s["totalKills"]) / por
	var gastos := _gastos(s)
	var trilhas := {}
	var bonus := {}
	for t in p.streak_trilhas:
		trilhas[t] = int(s["spent"][t])
		bonus[t] = int(s["spent"][t]) * 0.1
	var custo := int(p.streak_custo_base) * (gastos + 1)
	var lista: Array = []
	for k in s["bySpecies"]:
		var e: Dictionary = dados.especie(int(k)) if dados != null else {}
		lista.append({"speciesId": int(k), "name": String(e.get("nome", "")), "looktype": int(e.get("looktype", 0)), "kills": int(s["bySpecies"][k])})
	lista.sort_custom(func(a, b): return int(a["kills"]) > int(b["kills"]) or (int(a["kills"]) == int(b["kills"]) and int(a["speciesId"]) < int(b["speciesId"])))
	var disp := maxi(0, ganhos - gastos)
	return {"type": "streak", "totalKills": int(s["totalKills"]), "killsPerPoint": por, "earned": ganhos, "spent": gastos,
		"available": disp, "toNext": por - (int(s["totalKills"]) % por), "nextCost": custo,
		"canBuy": disp > 0 and int(estado.get("gold", 0)) >= custo, "gold": int(estado.get("gold", 0)),
		"tracks": trilhas, "bonusPct": bonus, "kills": lista}


func _gastar_streak(estado: Dictionary, trilha: String) -> Array:
	var s := _streak(estado)
	if not (trilha in p.streak_trilhas):
		return [_erro("Trilha inválida.")]
	var m := msg_streak(estado)
	if int(m["available"]) <= 0:
		return [_erro("Sem pontos disponíveis.")]
	var custo := int(m["nextCost"])
	if int(estado.get("gold", 0)) < custo:
		return [_erro("Ouro insuficiente.")]
	estado["gold"] = int(estado.get("gold", 0)) - custo
	s["spent"][trilha] = int(s["spent"][trilha]) + 1
	return [msg_streak(estado)]   # A (G7): a resposta é o próprio objeto do streak (gold já descontado)


static func somar_abates(estado: Dictionary, n: int, especie: int = -1) -> void:
	## Abates contam para o Streak (C: "1 point every 1000 total kills"; A: a janela lista abates por espécie).
	if not estado.has("streak"):
		estado["streak"] = {"totalKills": 0, "spent": {}}
	estado["streak"]["totalKills"] = int(estado["streak"].get("totalKills", 0)) + n
	if especie >= 0:
		if not estado["streak"].has("bySpecies"):
			estado["streak"]["bySpecies"] = {}
		var k := str(especie)
		estado["streak"]["bySpecies"][k] = int(estado["streak"]["bySpecies"].get(k, 0)) + n


func efeitos_streak(estado: Dictionary) -> Dictionary:
	## Para a simulação (cfg.streak): pontos de cada trilha.
	var s := _streak(estado)
	return {"exp": int(s["spent"]["exp"]), "loot": int(s["spent"]["loot"]), "shiny": int(s["spent"]["shiny"])}


# ============================================================================== Modo Soneca

static func amostra_soneca(sim, segundos: int, agora_ms: int = 0) -> Dictionary:
	## Roda a hunt atual por `segundos` (C: 5 min no servidor; combate, XP, loot e Auto-Potion; sem bolas) a partir do
	## estado em que está e resume a amostra no formato gravado (A, G6: sample{slug, startedAt, endedAt, sampleMs,
	## itemsUsed, fainted, killsBySpecies, leaderId, kills, xpSample, pokeXpSample}). `loot` vai junto para o cliente
	## entregar (a amostra aconteceu de verdade, A: o XP dela já estava no Pokémon antes da coleta).
	sim.cfg["auto_catch"] = false
	var inv_antes: Dictionary = sim.inventario.duplicate()
	var xp_t0 := int(sim.treinador["xp"])
	var ativo0: Dictionary = sim.equipe[sim.ativo]
	var xp_p0 := int(ativo0["xp"])
	var abates0 := int(sim.estatisticas["abates"])
	var desmaio_s := -1
	var loot := {}
	var por_especie := {}
	var ticks := segundos * 1000 / int(sim.p.tick_ms)
	var t_fim := ticks
	# Linha do tempo (E, para o cancelamento entregar só o que já rodou, A G6b): [ms, xp, pokeXp, speciesId, {loot}] por
	# abate e [ms, itemId, qtd] por poção gasta.
	var linha: Array = []
	var pocoes: Array = []
	var xp_t_ant := xp_t0
	var xp_p_ant := xp_p0
	var inv_ant: Dictionary = inv_antes.duplicate()
	for t in ticks:
		var ms_t := (t + 1) * int(sim.p.tick_ms)
		var curou := false
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			if String(m.get("type", "")) == "field-kill":
				var k := str(int(m.get("speciesId", 0)))
				por_especie[k] = int(por_especie.get(k, 0)) + 1
				var lk := {}
				for it in m.get("loot", []):
					loot[str(int(it["itemId"]))] = int(loot.get(str(int(it["itemId"])), 0)) + int(it["qty"])
					lk[str(int(it["itemId"]))] = int(lk.get(str(int(it["itemId"])), 0)) + int(it["qty"])
				linha.append([ms_t, int(sim.treinador["xp"]) - xp_t_ant, int(ativo0["xp"]) - xp_p_ant, int(m.get("speciesId", 0)), lk])
				xp_t_ant = int(sim.treinador["xp"])
				xp_p_ant = int(ativo0["xp"])
			if String(m.get("type", "")) == "auto-heal":
				curou = true
			if String(m.get("type", "")) == "field-none":
				desmaio_s = t * int(sim.p.tick_ms) / 1000
		if curou:
			for k in inv_ant:
				var g := int(inv_ant[k]) - int(sim.inventario.get(k, 0))
				if g > 0:
					pocoes.append([ms_t, int(k), g])
			inv_ant = sim.inventario.duplicate()
		if sim.encerrada:
			if desmaio_s < 0:
				desmaio_s = t * int(sim.p.tick_ms) / 1000
			t_fim = t + 1
			break
	var usados := {}
	for k in inv_antes:
		var gasto := int(inv_antes[k]) - int(sim.inventario.get(k, 0))
		if gasto > 0:
			usados[str(int(k))] = gasto
	var ms := t_fim * int(sim.p.tick_ms)
	return {"slug": String(sim.slug), "startedAt": agora_ms, "endedAt": agora_ms + ms, "sampleMs": ms,
		"itemsUsed": usados, "fainted": desmaio_s >= 0, "killsBySpecies": por_especie, "leaderId": String(ativo0.get("id", "")),
		"kills": int(sim.estatisticas["abates"]) - abates0, "xpSample": int(sim.treinador["xp"]) - xp_t0,
		"pokeXpSample": int(ativo0["xp"]) - xp_p0, "loot": loot, "linha": linha, "pocoes": pocoes}


func _dormir(estado: Dictionary, cmd: Dictionary) -> Array:
	## C: o cliente manda sleep-mode e espera sleep-ok {ghost: true} (sai do jogo); sem hunt → sleep-ok sem ghost.
	var amostra: Dictionary = cmd.get("amostra", {})
	if amostra.is_empty():
		return [{"type": "sleep-ok"}]
	var agora := int(cmd.get("agora", 0))
	estado["soneca"] = {"inicio": agora, "fim": agora + int(p.soneca_amostra_s), "amostra": amostra}
	return [{"type": "sleep-ok", "ghost": true}]


func _contas(estado: Dictionary, agora: int) -> Dictionary:
	## A (G6): a taxa é a da amostra sobre os 300 s NOMINAIS (não o sampleMs de 300.551) e o arredondamento é round:
	## 384 XP, 217 s fora → xp100 = round(384/300 × 217) = 278, xp50 = round(… × 0,5) = 139, estKills = round(32/300 × 217)
	## = 23; na coleta, 227 s → 145 (os três batem exatamente).
	var s: Dictionary = estado.get("soneca", {})
	var a: Dictionary = s["amostra"]
	var bruto := maxi(0, agora - int(s["fim"]))
	var seg := mini(bruto, int(p.soneca_teto_s))
	var base_s := float(p.soneca_amostra_s)
	var taxa_t := float(a.get("xpSample", 0)) / base_s
	var taxa_p := float(a.get("pokeXpSample", 0)) / base_s
	return {"seconds": seg, "capped": bruto > seg, "estKills": Regras.js_round(float(a.get("kills", 0)) / base_s * seg),
		"xp50": Regras.js_round(taxa_t * seg * float(p.soneca_fracao)), "xp100": Regras.js_round(taxa_t * seg * float(p.soneca_fracao_turbo)),
		"pokeXp50": Regras.js_round(taxa_p * seg * float(p.soneca_fracao)), "pokeXp100": Regras.js_round(taxa_p * seg * float(p.soneca_fracao_turbo))}


func _relatorio_msgs(estado: Dictionary, agora: int, poke: Dictionary = {}) -> Array:
	## A amostra (5 min de hunt de verdade) é entregue uma vez, quando termina: o XP dela já estava no Pokémon antes da
	## coleta (A, G6). Offline não há servidor rodando a hunt enquanto o jogo está fechado, então ela é calculada no Zzz
	## e entregue na primeira leitura do relatório depois dos 5 min (E). Voltar antes cancela sem entregar nada (E: o
	## original cancela, C; o que ele faz com a amostra parcial não foi gravado).
	var s0: Dictionary = estado.get("soneca", {})
	if not s0.is_empty() and agora - int(s0["inicio"]) < int(p.soneca_amostra_s) and not bool(s0.get("entregue", false)):
		return _cancelar(estado, agora, poke)
	var rel := _relatorio(estado, agora, poke)
	var s: Dictionary = estado.get("soneca", {})
	if rel.get("report") == null or bool(s.get("entregue", false)):
		return [rel]
	s["entregue"] = true
	var a: Dictionary = s["amostra"]
	return [{"type": "offline-sample", "xp": int(a.get("xpSample", 0)), "pokeXp": int(a.get("pokeXpSample", 0)),
		"pokemonId": String(a.get("leaderId", "")), "loot": a.get("loot", {}), "itemsUsed": a.get("itemsUsed", {}),
		"killsBySpecies": a.get("killsBySpecies", {}), "kills": int(a.get("kills", 0))}, rel]


func _cancelar(estado: Dictionary, agora: int, poke: Dictionary) -> Array:
	## A (G6b): voltar antes dos 5 min cancela, mas o que a amostra já rodou fica: offline-notice {notices: [{kind:
	## "cancelled", reason: "reconnect", slug, ms, kills, xp, pokeXp, poke, id, at}]} (voltou aos 91.981 ms com 16 abates e
	## 14.016 XP no treinador e no Pokémon) e o relatório fica null. Loot e poções da parte rodada: entregues também (E: a
	## gravação não mostra a BAG). Aqui a parte rodada sai da linha do tempo da amostra (abates com ms <= o tempo fora).
	var s: Dictionary = estado["soneca"]
	var a: Dictionary = s["amostra"]
	var ms := maxi(0, (agora - int(s["inicio"])) * 1000)
	var xp := 0
	var pxp := 0
	var abates := 0
	var por_especie := {}
	var loot := {}
	for e in a.get("linha", []):
		if int(e[0]) > ms:
			break
		abates += 1
		xp += int(e[1])
		pxp += int(e[2])
		por_especie[str(int(e[3]))] = int(por_especie.get(str(int(e[3])), 0)) + 1
		for k in e[4]:
			loot[k] = int(loot.get(k, 0)) + int(e[4][k])
	var usados := {}
	for e in a.get("pocoes", []):
		if int(e[0]) <= ms:
			usados[str(int(e[1]))] = int(usados.get(str(int(e[1])), 0)) + int(e[2])
	estado["soneca"] = {}
	var aviso := {"kind": "cancelled", "reason": "reconnect", "slug": String(a.get("slug", "")), "ms": ms, "kills": abates,
		"xp": xp, "pokeXp": pxp, "poke": poke, "id": "soneca-%d" % int(s["inicio"]), "at": agora * 1000}
	return [{"type": "offline-notice", "notices": [aviso]},
		{"type": "offline-sample", "xp": xp, "pokeXp": pxp, "pokemonId": String(a.get("leaderId", "")), "loot": loot,
			"itemsUsed": usados, "killsBySpecies": por_especie, "kills": abates},
		{"type": "offline", "report": null, "canceled": true}]


func _relatorio(estado: Dictionary, agora: int, poke: Dictionary = {}) -> Dictionary:
	## A (G6): GET /api/game/offline → {report: {sample{…}, seconds, cappedAt, estKills, xp50, xp100, pokeXp50,
	## pokeXp100, boostCost, poke{id, speciesId, nickname, level}, pokeStatus}}. Voltar antes de 5 min cancela (C).
	var s: Dictionary = estado.get("soneca", {})
	if s.is_empty():
		return {"type": "offline", "report": null}
	if agora - int(s["inicio"]) < int(p.soneca_amostra_s):
		estado["soneca"] = {}
		return {"type": "offline", "report": null, "canceled": true}
	var c := _contas(estado, agora)
	var amostra: Dictionary = (s["amostra"] as Dictionary).duplicate(true)
	amostra.erase("loot")
	amostra.erase("linha")
	amostra.erase("pocoes")
	return {"type": "offline", "report": {"sample": amostra, "seconds": int(c["seconds"]),
		"cappedAt": int(p.soneca_teto_s) if bool(c["capped"]) else false, "estKills": int(c["estKills"]),
		"xp50": int(c["xp50"]), "xp100": int(c["xp100"]), "pokeXp50": int(c["pokeXp50"]), "pokeXp100": int(c["pokeXp100"]),
		"boostCost": int(p.soneca_turbo_custo), "poke": poke, "pokeStatus": "ok"}}


func _coletar(estado: Dictionary, agora: int, turbo: bool, poke: Dictionary = {}) -> Array:
	## A (G6): POST /api/game/offline {boost} → {xpGained, pokeXpGained, boosted, totalXp, level, seconds, estKills, poke,
	## pokeApplied, pokeStatus, slug, diamonds}. Só o tempo fora entra (o XP da amostra já foi entregue na hora: o Venusaur
	## tinha 81.113.299 antes da coleta e 81.113.444 depois = +145 = xpGained).
	if turbo and not bool(p.soneca_turbo_disponivel) and not (estado.get("soneca", {}) as Dictionary).is_empty():
		return [_erro("Turbo indisponível (sem diamantes no jogo offline).")]
	var msgs := _relatorio_msgs(estado, agora, poke)
	var rel: Dictionary = msgs[msgs.size() - 1]
	if rel.get("report") == null:
		return [_erro("Nenhuma soneca para coletar."), rel] if not rel.has("canceled") else msgs
	msgs.pop_back()
	var a: Dictionary = estado["soneca"]["amostra"]
	var c := _contas(estado, agora)
	estado["soneca"] = {}
	return msgs + [{"type": "offline-claimed", "xpGained": int(c["xp100"] if turbo else c["xp50"]),
		"pokeXpGained": int(c["pokeXp100"] if turbo else c["pokeXp50"]), "boosted": turbo, "seconds": int(c["seconds"]),
		"estKills": int(c["estKills"]), "poke": poke, "pokeApplied": not poke.is_empty(), "pokeStatus": "ok",
		"slug": String(a.get("slug", "")), "diamonds": 0, "pokemonId": String(a.get("leaderId", ""))}]


# ============================================================================== Tipo do Dia (evento)

func dia(agora: int) -> int:
	return int(floor(float(agora - int(p.dia_virada_utc_s)) / 86400.0))


func tipo_do_dia(agora: int) -> String:
	var r: Array = p.rotacao_tipos
	return String(r[posmod(dia(agora) - int(p.dia_ancora), r.size())])


func msg_eventos(agora: int) -> Dictionary:
	## Formato da mensagem events (A). E: offline só o Tipo do Dia (o "Shiny ×2" depende de shiny, ausente no time).
	var t := tipo_do_dia(agora)
	var nome: Array = p.nomes_tipos.get(t, [t, "⭐"])
	var fim_s := (dia(agora) + 1) * 86400 + int(p.dia_virada_utc_s)
	return {"type": "events", "events": [{"key": "type-of-day", "name": "%s Tipo do Dia: %s" % [nome[1], nome[0]],
		"desc": "+20%% de XP e +20%% de loot em Pokémon do tipo %s" % nome[0], "pct": 0, "emoji": nome[1],
		"until": fim_s * 1000, "tipo": t}]}
