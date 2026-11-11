extends RefCounted
## Fase 4, lote 2: serviços do jogador fora da cidade — sessão, Modo Soneca (farm offline), Streak Points e o Tipo do
## Dia. Puro e determinístico: sem Node, sem relógio próprio (o "agora" vem no comando, em segundos unix), RNG só o
## da simulação da amostra (semente no comando). Mesmo contrato do servico_cidade: tratar(estado, cmd) → mensagens.
##
## Estado (no save; ver ponte_cidade.gd):
##   streak: {totalKills, spent: {exp, loot, shiny}}         gold: int
##   soneca: {} ou {inicio, fim, amostra{slug, kills, fainted, itemsUsed, xpTrainer, xpPokemon, loot, seconds}}
##   sessao: {fechado_em (unix do último fechamento)}
##
## Comandos (nomes do original quando existem; C = cliente, A = gravação, E = projeto):
##   streak-get                       ≈ GET  /api/game/streak               (C: campos da janela)
##   streak-spend {track}             ≈ POST /api/game/streak/spend {track} (C)
##   sleep-mode {agora, amostra}      = WS sleep-mode → sleep-ok            (C; a amostra é calculada por quem tem a
##                                                                           hunt: amostra_soneca(), abaixo)
##   offline-get {agora}              ≈ GET  /api/game/offline → {report?}  (C: campos da janela)
##   offline-claim {agora, boost}     ≈ POST /api/game/offline {boost}      (C)
##   sessao {fechado_em, agora}       E: decide se a sessão expirou (regra do usuário)
##   eventos {agora}                  E: Tipo do Dia offline (formato da mensagem events, A)

const Regras := preload("res://sim/regras.gd")

const PARAMETROS := {
	# Sessão (B-relatado / regra do usuário, 11/11): sem soneca, 15 min com o jogo fechado matam a sessão; voltar à
	# mesma hunt pela cidade não penaliza (CenarioJogo.penalizar_entrada). Com soneca coletada, a sessão segue (E).
	"sessao_expira_s": 900,
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
	# E: offline, rotação fixa ancorada nos dois dias observados (09/11/2026 Dragão, 10/11/2026 Inseto).
	"dia_virada_utc_s": 10800,
	"dia_ancora": 20766,              # dia (unix/86400, deslocado pela virada) de 09/11/2026 em Brasília
	"rotacao_tipos": ["DRAGON", "BUG", "FIRE", "WATER", "GRASS", "ELECTRIC", "ICE", "FIGHTING", "POISON", "GROUND",
		"FLYING", "PSYCHIC", "ROCK", "GHOST", "DARK", "STEEL", "FAIRY", "NORMAL"],
	"nomes_tipos": {"BUG": ["Inseto", "🐛"], "DARK": ["Sombrio", "🌑"], "DRAGON": ["Dragão", "🐉"], "ELECTRIC": ["Elétrico", "⚡"],
		"FAIRY": ["Fada", "🧚"], "FIGHTING": ["Lutador", "🥊"], "FIRE": ["Fogo", "🔥"], "FLYING": ["Voador", "🕊️"],
		"GHOST": ["Fantasma", "👻"], "GRASS": ["Planta", "🌿"], "GROUND": ["Terra", "⛰️"], "ICE": ["Gelo", "❄️"],
		"NORMAL": ["Normal", "⚪"], "POISON": ["Venenoso", "☠️"], "PSYCHIC": ["Psíquico", "🔮"], "ROCK": ["Pedra", "🪨"],
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
			return [_relatorio(estado, int(cmd.get("agora", 0)))]
		"offline-claim":
			return _coletar(estado, int(cmd.get("agora", 0)), bool(cmd.get("boost", false)))
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


# ============================================================================== Streak Points

func _streak(estado: Dictionary) -> Dictionary:
	if not estado.has("streak"):
		estado["streak"] = {}
	var s: Dictionary = estado["streak"]
	if not s.has("totalKills"):
		s["totalKills"] = 0
	if not s.has("spent"):
		s["spent"] = {}
	for t in p.streak_trilhas:
		if not s["spent"].has(t):
			s["spent"][t] = 0
	return s


func _gastos(s: Dictionary) -> int:
	var n := 0
	for t in s["spent"]:
		n += int(s["spent"][t])
	return n


func msg_streak(estado: Dictionary) -> Dictionary:
	## Campos que a janela do original lê (C): totalKills, available, spent, toNext, killsPerPoint; e por trilha
	## (pontos e bônus) e o custo do próximo ponto.
	var s := _streak(estado)
	var por := int(p.streak_abates_por_ponto)
	var ganhos := int(s["totalKills"]) / por
	var gastos := _gastos(s)
	var trilhas := {}
	for t in p.streak_trilhas:
		trilhas[t] = {"points": int(s["spent"][t]), "pct": snappedf(int(s["spent"][t]) * 0.1, 0.1)}
	return {"type": "streak", "totalKills": int(s["totalKills"]), "available": maxi(0, ganhos - gastos), "spent": gastos,
		"toNext": por - (int(s["totalKills"]) % por), "killsPerPoint": por, "nextCost": int(p.streak_custo_base) * (gastos + 1),
		"tracks": trilhas}


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
	return [msg_streak(estado), {"type": "currency", "gold": int(estado["gold"])}]


static func somar_abates(estado: Dictionary, n: int) -> void:
	## Abates contam para o Streak (C: "1 point every 1000 total kills"). Chamado pelo cliente a cada field-kill.
	if not estado.has("streak"):
		estado["streak"] = {"totalKills": 0, "spent": {}}
	estado["streak"]["totalKills"] = int(estado["streak"].get("totalKills", 0)) + n


func efeitos_streak(estado: Dictionary) -> Dictionary:
	## Para a simulação (cfg.streak): pontos de cada trilha.
	var s := _streak(estado)
	return {"exp": int(s["spent"]["exp"]), "loot": int(s["spent"]["loot"]), "shiny": int(s["spent"]["shiny"])}


# ============================================================================== Modo Soneca

static func amostra_soneca(sim, segundos: int) -> Dictionary:
	## Roda a hunt atual por `segundos` (C: 5 min no servidor; combate, XP, loot e Auto-Potion; sem bolas) a partir do
	## estado em que está e resume a amostra. `sim` é uma simulacao_hunt já iniciada; a captura é desligada.
	sim.cfg["auto_catch"] = false
	var inv_antes: Dictionary = sim.inventario.duplicate()
	var xp_t0 := int(sim.treinador["xp"])
	var ativo0: Dictionary = sim.equipe[sim.ativo]
	var xp_p0 := int(ativo0["xp"])
	var abates0 := int(sim.estatisticas["abates"])
	var desmaio_s := -1
	var loot := {}
	var ticks := segundos * 1000 / int(sim.p.tick_ms)
	for t in ticks:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			if String(m.get("type", "")) == "field-kill":
				for it in m.get("loot", []):
					loot[str(int(it["itemId"]))] = int(loot.get(str(int(it["itemId"])), 0)) + int(it["qty"])
			if String(m.get("type", "")) == "field-none":
				desmaio_s = t * int(sim.p.tick_ms) / 1000
		if sim.encerrada:
			if desmaio_s < 0:
				desmaio_s = t * int(sim.p.tick_ms) / 1000
			break
	var usados := {}
	for k in inv_antes:
		var gasto := int(inv_antes[k]) - int(sim.inventario.get(k, 0))
		if gasto > 0:
			usados[str(int(k))] = gasto
	return {"slug": String(sim.slug), "kills": int(sim.estatisticas["abates"]) - abates0, "fainted": desmaio_s >= 0,
		"faintedAtS": desmaio_s, "itemsUsed": usados, "loot": loot, "seconds": segundos,
		"xpTrainer": int(sim.treinador["xp"]) - xp_t0, "xpPokemon": int(ativo0["xp"]) - xp_p0,
		"pokemonId": String(ativo0.get("id", ""))}


func _dormir(estado: Dictionary, cmd: Dictionary) -> Array:
	## C: o cliente manda sleep-mode e espera sleep-ok {ghost: true} (sai do jogo); sem hunt → sleep-ok sem ghost.
	var amostra: Dictionary = cmd.get("amostra", {})
	if amostra.is_empty():
		return [{"type": "sleep-ok"}]
	var agora := int(cmd.get("agora", 0))
	estado["soneca"] = {"inicio": agora, "fim": agora + int(p.soneca_amostra_s), "amostra": amostra}
	return [{"type": "sleep-ok", "ghost": true}]


func _contas(estado: Dictionary, agora: int) -> Dictionary:
	var s: Dictionary = estado.get("soneca", {})
	var a: Dictionary = s["amostra"]
	var bruto := maxi(0, agora - int(s["fim"]))
	var seg := mini(bruto, int(p.soneca_teto_s))
	var base_s := maxi(1, int(a.get("seconds", p.soneca_amostra_s)))
	var taxa_t := float(a.get("xpTrainer", 0)) / base_s
	var taxa_p := float(a.get("xpPokemon", 0)) / base_s
	return {"seconds": seg, "capped": bruto > seg, "estKills": int(round(float(a.get("kills", 0)) / base_s * seg)),
		"xp50": int(floor(taxa_t * seg * float(p.soneca_fracao))), "xp100": int(floor(taxa_t * seg * float(p.soneca_fracao_turbo))),
		"xpPoke50": int(floor(taxa_p * seg * float(p.soneca_fracao))), "xpPoke100": int(floor(taxa_p * seg * float(p.soneca_fracao_turbo)))}


func _relatorio(estado: Dictionary, agora: int) -> Dictionary:
	## C: GET /api/game/offline → {report?}; report = {sample{slug, kills, fainted, itemsUsed}, seconds, cappedAt,
	## estKills, xp50, xp100, boostCost}. Voltar antes de 5 min cancela a soneca (C): sem relatório, sessão nova.
	var s: Dictionary = estado.get("soneca", {})
	if s.is_empty():
		return {"type": "offline", "report": null}
	if agora - int(s["inicio"]) < int(p.soneca_amostra_s):
		estado["soneca"] = {}
		return {"type": "offline", "report": null, "canceled": true}
	var c := _contas(estado, agora)
	var a: Dictionary = s["amostra"]
	return {"type": "offline", "report": {"sample": {"slug": a["slug"], "kills": int(a["kills"]), "fainted": bool(a["fainted"]),
		"itemsUsed": a.get("itemsUsed", {})}, "seconds": int(c["seconds"]), "cappedAt": int(p.soneca_teto_s) if bool(c["capped"]) else null,
		"estKills": int(c["estKills"]), "xp50": int(c["xp50"]), "xp100": int(c["xp100"]), "boostCost": int(p.soneca_turbo_custo),
		"xpPokemon50": int(c["xpPoke50"])}}


func _coletar(estado: Dictionary, agora: int, turbo: bool) -> Array:
	var rel := _relatorio(estado, agora)
	if rel.get("report") == null:
		return [_erro("Nenhuma soneca para coletar."), rel] if not rel.has("canceled") else [rel]
	if turbo and not bool(p.soneca_turbo_disponivel):
		return [_erro("Turbo indisponível (sem diamantes no jogo offline).")]
	var s: Dictionary = estado["soneca"]
	var a: Dictionary = s["amostra"]
	var c := _contas(estado, agora)
	# A amostra de 5 min aconteceu de verdade (XP, loot e poções dela valem, C) e o tempo fora rende 50% da taxa
	# de XP no treinador E no Pokémon que lutava (C: "The XP goes to the trainer AND the Pokémon that was fighting").
	var xp_t := int(a.get("xpTrainer", 0)) + int(c["xp100"] if turbo else c["xp50"])
	var xp_p := int(a.get("xpPokemon", 0)) + int(c["xpPoke100"] if turbo else c["xpPoke50"])
	estado["soneca"] = {}
	return [{"type": "offline-claimed", "xpTrainer": xp_t, "xpPokemon": xp_p, "pokemonId": String(a.get("pokemonId", "")),
		"loot": a.get("loot", {}), "itemsUsed": a.get("itemsUsed", {}), "kills": int(a["kills"]) + int(c["estKills"]),
		"sampleKills": int(a["kills"]),   # F: só os abates da amostra (que aconteceram) contam para o Streak; os estimados não
		"seconds": int(c["seconds"])}]


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
