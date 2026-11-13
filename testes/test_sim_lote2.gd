extends SceneTree
## Fase 4, lote 2: sessão, Modo Soneca, Streak Points, boosts e Tipo do Dia (sim/servico_jogador.gd e as parcelas
## novas da simulacao_hunt). Puro, sem save. Rodar: testes/rodar.sh res://testes/test_sim_lote2.gd

const Regras := preload("res://sim/regras.gd")
const Servico := preload("res://sim/servico_jogador.gd")
const Sim := preload("res://testes/rodar_sim.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const ESTADO := "dados/testes/estado_rhydon_venusaur_1h.json"
const D0 := 1794225600   # 2026-11-09 12:00 UTC (dia de Brasília 09/11)

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


static func _n(x) -> String:
	## Compara com o JSON gravado (números lidos como float): passa o nosso valor pelo mesmo caminho.
	return JSON.stringify(JSON.parse_string(JSON.stringify(x)))


static func tipo(msgs: Array, t: String) -> Dictionary:
	for m in msgs:
		if String(m.get("type", "")) == t:
			return m
	return {}


func nova_sim(dados, mapa, extra: Dictionary, semente: int = 3):
	var cfg := Cenario.de_estado(Sim.caminho_absoluto(ESTADO), dados, semente)
	for k in extra:
		cfg[k] = extra[k]
	var s = Simulacao.new(cfg, dados, mapa)
	s.iniciar()
	return s


func rodar(s, segundos: int) -> Array:
	var kills: Array = []
	for t in segundos * 5:
		for reg in s.passo():
			var m: Dictionary = reg.get("msg", reg)
			if String(m.get("type", "")) == "field-kill":
				kills.append(m)
	return kills


func _init() -> void:
	var sv = Servico.new()
	var dados = DadosJogo.carregar()
	var cfg0 := Cenario.de_estado(Sim.caminho_absoluto(ESTADO), dados, 3)
	var mapa = MapaHunt.carregar(cfg0["slug"], Fontes.ler_mapa(cfg0["slug"]), Fontes.ler_colisao())

	# ---------------------------------------------------------------- Streak Points (C)
	var e := {"gold": 100000, "streak": {"totalKills": 2500, "spent": {}}}
	var st: Dictionary = sv.tratar(e, {"type": "streak-get"})[0]
	checar(int(st["available"]) == 2 and int(st["toNext"]) == 500 and int(st["killsPerPoint"]) == 1000 and int(st["nextCost"]) == 25000,
		"2500 abates = 2 pontos; faltam 500; 1º ponto custa 25.000 (C)", str(st))
	var r: Array = sv.tratar(e, {"type": "streak-spend", "track": "exp"})
	checar(int(e["gold"]) == 75000 and int(tipo(r, "streak")["nextCost"]) == 50000 and int(tipo(r, "streak")["available"]) == 1,
		"gastar: −25.000 e o próximo custa 50.000 (C: 25.000 × nº do ponto)")
	r = sv.tratar(e, {"type": "streak-spend", "track": "loot"})
	checar(int(e["gold"]) == 25000 and int(e["streak"]["spent"]["loot"]) == 1, "2º ponto na trilha Loot por 50.000")
	checar(tipo(sv.tratar(e, {"type": "streak-spend", "track": "exp"}), "error").size() > 0, "sem pontos: recusa")
	checar(tipo(sv.tratar(e, {"type": "streak-spend", "track": "xp"}), "error").size() > 0, "trilha inválida: recusa")
	var e2 := {"gold": 10, "streak": {"totalKills": 1000}}
	checar(tipo(sv.tratar(e2, {"type": "streak-spend", "track": "exp"}), "error").get("message", "").contains("Ouro"), "ouro insuficiente: recusa")
	Servico.somar_abates(e2, 999, 74)
	checar(int(sv.msg_streak(e2)["available"]) == 1 and int(sv.msg_streak(e2)["toNext"]) == 1, "somar abates conta para o próximo ponto")
	checar(sv.msg_streak(e2, dados)["kills"] == [{"speciesId": 74, "name": String(dados.especie(74).get("nome", "")), "looktype": int(dados.especie(74).get("looktype", 0)), "kills": 999}],
		"abates por espécie na janela (A: lista kills)", str(sv.msg_streak(e2, dados)["kills"]))
	# A (G7): a conta gravada (682.962 abates, 19 pontos em Shiny, 80.116.751 de ouro) → GET e POST /streak/spend {exp}
	var grav: Array = JSON.parse_string(FileAccess.get_file_as_string("res://dados/fase4/streak.json"))["respostas"]
	var eg := {"gold": 80116751, "streak": {"totalKills": 682962, "spent": {"exp": 0, "loot": 0, "shiny": 19}}}
	var g0: Dictionary = sv.msg_streak(eg)
	var iguais := true
	for k in grav[0]["corpo"]:
		if _n(g0.get(k)) != JSON.stringify(grav[0]["corpo"][k]):
			iguais = false
			print("  difere ", k, ": ", g0.get(k), " × ", grav[0]["corpo"][k])
	checar(iguais, "GET /streak igual ao gravado, campo a campo (A, G7)")
	eg["streak"]["totalKills"] = 682965
	var g1: Dictionary = tipo(sv.tratar(eg, {"type": "streak-spend", "track": "exp"}), "streak")
	iguais = true
	for k in grav[1]["corpo"]:
		if _n(g1.get(k)) != JSON.stringify(grav[1]["corpo"][k]):
			iguais = false
			print("  difere ", k, ": ", g1.get(k), " × ", grav[1]["corpo"][k])
	checar(iguais, "POST /streak/spend {exp}: 20º ponto por 500.000 e resposta igual à gravada (A, G7)")

	# ---------------------------------------------------------------- Tipo do Dia (A: until às 03:00 UTC; E: rotação)
	var ev: Dictionary = sv.tratar({}, {"type": "eventos", "agora": D0})[0]
	var ev2: Dictionary = sv.tratar({}, {"type": "eventos", "agora": D0 + 86400})[0]
	checar(ev["events"][0]["tipo"] == "DRAGON" and ev2["events"][0]["tipo"] == "BUG" and sv.tipo_do_dia(D0 + 4 * 86400) == "DARK",
		"09/11 Dragão, 10/11 Inseto, 13/11 Sombrio (A: os três dias gravados)")
	checar(int(ev2["events"][0]["until"]) == 1794366000000 and ev2["events"][0]["key"] == "type-of-day", "fim do dia = 1794366000000, como na gravação (A)")
	checar(sv.tipo_do_dia(D0 + 18 * 86400) == "DRAGON" and sv.tipo_do_dia(D0 - 86400) == "NORMAL", "rotação de 18 dias (E)")

	# ---------------------------------------------------------------- sessão (regra do usuário)
	checar(bool(sv.tratar({}, {"type": "sessao", "fechado_em": 1000, "agora": 1000 + 899})[0]["expirada"]) == false, "fechado 14 min 59 s: sessão viva")
	checar(bool(sv.tratar({}, {"type": "sessao", "fechado_em": 1000, "agora": 1000 + 900})[0]["expirada"]), "fechado 15 min: sessão expira (sem soneca)")

	# ---------------------------------------------------------------- Modo Soneca (C; contas e formatos A, G6)
	var s1 = nova_sim(dados, mapa, {})
	rodar(s1, 30)
	var a1: Dictionary = Servico.amostra_soneca(s1, 300, 5000000)
	var s2 = nova_sim(dados, mapa, {})
	rodar(s2, 30)
	var a2: Dictionary = Servico.amostra_soneca(s2, 300, 5000000)
	checar(JSON.stringify(a1) == JSON.stringify(a2), "amostra determinística (mesma semente → mesma amostra)")
	checar(int(a1["kills"]) > 0 and int(a1["xpSample"]) > 0 and int(a1["sampleMs"]) == 300000 and not bool(s1.cfg["auto_catch"]),
		"amostra de 5 min com abates e XP, sem bolas (C)", "%d abates, %d XP" % [int(a1["kills"]), int(a1["xpSample"])])
	var chaves_a: Array = a1.keys()
	chaves_a.erase("loot")
	checar(chaves_a == ["slug", "startedAt", "endedAt", "sampleMs", "itemsUsed", "fainted", "killsBySpecies", "leaderId", "kills", "xpSample", "pokeXpSample"],
		"amostra com os campos gravados (A: sample do GET /offline)", str(chaves_a))
	var soma_k := 0
	for k in a1["killsBySpecies"]:
		soma_k += int(a1["killsBySpecies"][k])
	checar(soma_k == int(a1["kills"]), "killsBySpecies soma os abates")
	var es := {"soneca": {}}
	checar(bool(tipo(sv.tratar(es, {"type": "sleep-mode", "agora": 5000, "amostra": a1}), "sleep-ok")["ghost"]), "sleep-mode → sleep-ok {ghost: true} (C)")
	var rel_m: Array = sv.tratar(es.duplicate(true), {"type": "offline-get", "agora": 5000 + 299})
	checar(rel_m.size() == 1 and rel_m[0]["report"] == null and bool(rel_m[0].get("canceled", false)), "voltar antes de 5 min cancela a soneca, sem entregar a amostra (C/E)")
	var horas := 2 * 3600
	rel_m = sv.tratar(es, {"type": "offline-get", "agora": 5000 + 300 + horas})
	var ent: Dictionary = tipo(rel_m, "offline-sample")
	var rel: Dictionary = tipo(rel_m, "offline")
	checar(int(ent.get("xp", -1)) == int(a1["xpSample"]) and int(ent["pokeXp"]) == int(a1["pokeXpSample"]) and ent["loot"] == a1["loot"],
		"1ª leitura depois dos 5 min: a amostra é entregue (XP, loot, poções; A: já estava no Pokémon antes da coleta)")
	checar(tipo(sv.tratar(es, {"type": "offline-get", "agora": 5000 + 300 + horas}), "offline-sample").is_empty(), "a amostra é entregue uma vez só")
	var taxa := float(a1["xpSample"]) / 300.0
	checar(int(rel["report"]["seconds"]) == horas and int(rel["report"]["xp50"]) == Regras.js_round(taxa * horas * 0.5) and rel["report"]["cappedAt"] is bool,
		"2 h fora: round(taxa × tempo × 50%), sem teto (A)", "xp50 %d" % int(rel["report"]["xp50"]))
	var cap: Dictionary = tipo(sv.tratar(es.duplicate(true), {"type": "offline-get", "agora": 5000 + 300 + 3 * 86400}), "offline")
	checar(int(cap["report"]["seconds"]) == 86400 and int(cap["report"]["cappedAt"]) == 86400, "teto de 24 h (C)")
	checar(tipo(sv.tratar(es.duplicate(true), {"type": "offline-claim", "agora": 5000 + 300 + horas, "boost": true}), "error").size() > 0,
		"turbo recusado (E: sem diamantes)")
	var r2: Array = sv.tratar(es, {"type": "offline-claim", "agora": 5000 + 300 + horas, "boost": false})
	var col: Dictionary = tipo(r2, "offline-claimed")
	checar(int(col["xpGained"]) == int(rel["report"]["xp50"]) and int(col["pokeXpGained"]) == int(rel["report"]["pokeXp50"]) and es["soneca"].is_empty()
		and tipo(r2, "offline-sample").is_empty(), "coleta: só os 50% do tempo fora (A: a amostra não entra de novo); soneca zerada")
	checar(tipo(sv.tratar(es, {"type": "offline-claim", "agora": 99999999}), "error").size() > 0, "coletar de novo: nada a coletar")
	checar(bool(sv.tratar({"soneca": {"inicio": 1000, "fim": 1300, "amostra": a1}}, {"type": "sessao", "fechado_em": 1000, "agora": 1000 + 3600})[0]["expirada"]) == false,
		"com soneca valendo, 1 h fechado não mata a sessão (E)")
	# A (G6): a amostra gravada (32 abates, 384 XP em 300.551 ms) → relatório aos 217 s e coleta aos 227 s
	var gs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://dados/fase4/soneca.json"))["respostas"]
	var am_a: Dictionary = gs[0]["corpo"]["report"]["sample"]
	var ini_a := int(am_a["startedAt"]) / 1000
	var eg2 := {"soneca": {"inicio": ini_a, "fim": ini_a + 300, "amostra": am_a}}
	var rg: Dictionary = tipo(sv.tratar(eg2, {"type": "offline-get", "agora": ini_a + 300 + 217, "poke": gs[0]["corpo"]["report"]["poke"]}), "offline")
	var iguais_s := true
	for k in gs[0]["corpo"]["report"]:
		if _n(rg["report"].get(k)) != JSON.stringify(gs[0]["corpo"]["report"][k]):
			iguais_s = false
			print("  difere ", k, ": ", rg["report"].get(k), " × ", gs[0]["corpo"]["report"][k])
	checar(iguais_s, "GET /offline igual ao gravado, campo a campo (A, G6: xp50 139, xp100 278, estKills 23)")
	var cg: Dictionary = tipo(sv.tratar(eg2, {"type": "offline-claim", "agora": ini_a + 300 + 227, "boost": false, "poke": gs[1]["corpo"]["poke"]}), "offline-claimed")
	var esperado: Dictionary = gs[1]["corpo"]
	checar(int(cg["xpGained"]) == int(esperado["xpGained"]) and int(cg["pokeXpGained"]) == int(esperado["pokeXpGained"]) and int(cg["estKills"]) == int(esperado["estKills"])
		and int(cg["seconds"]) == int(esperado["seconds"]) and String(cg["slug"]) == String(esperado["slug"]) and bool(cg["pokeApplied"]) and int(cg["diamonds"]) == 0,
		"POST /offline aos 227 s: +145 / +145, estKills 24, como gravado (A, G6)", JSON.stringify(cg))

	# ---------------------------------------------------------------- parcelas na hunt (F: % da base) e efeitos
	var base_k := rodar(nova_sim(dados, mapa, {}), 600)
	var agora_ms := int(cfg0["inicio_ms"])
	var fim := agora_ms + 10 * 3600 * 1000
	var tipo_rhydon: String = Regras.tipos_de(dados.especie(112))[0]
	var cfg_b := {"boosts": [{"key": "xp", "until": fim, "pct": 50}, {"key": "pokexp", "until": fim, "pct": 50}, {"key": "loot", "until": fim, "pct": 40}],
		"eventos": [{"key": "type-of-day", "tipo": tipo_rhydon, "until": fim, "name": "x", "desc": "y", "pct": 0, "emoji": "z"}],
		"streak": {"exp": 30, "loot": 1500}}
	var sb = nova_sim(dados, mapa, cfg_b)
	var ks := rodar(sb, 600)
	var k0: Dictionary = ks[ks.size() - 1]
	var b := int(k0["xpParts"]["base"])
	checar(int(k0["xpParts"]["boost"]) == Regras.js_round(b * 0.5) and int(k0["pokeXp"]["parts"]["boost"]) == Regras.js_round(b * 0.5)
		and int(k0["xpParts"]["typeDay"]) == int(floor(b * 0.2 + 1e-9)) and int(k0["xpParts"]["streak"]) == int(floor(b * 0.03 + 1e-9)),
		"parcelas: boost 50% (F), tipo do dia floor(20%) e streak 30 pts = floor(3%) (A, G7/G8)", JSON.stringify(k0["xpParts"]))
	checar(int(k0["xpGained"]) == b + int(k0["xpParts"]["vip"]) + int(k0["xpParts"]["boost"]) + int(k0["xpParts"]["typeDay"]) + int(k0["xpParts"]["streak"])
		and int(k0["pokeXp"]["xpGained"]) == b + int(k0["pokeXp"]["parts"]["vip"]) + int(k0["pokeXp"]["parts"]["boost"]) + int(k0["pokeXp"]["parts"]["typeDay"]),
		"XP total = soma das parcelas; o Pokémon não leva a do streak (A: pokeXp.parts sem chave streak)")
	var n0 := 0
	var n1 := 0
	for k in base_k:
		n0 += (k["loot"] as Array).size()
	for k in ks:
		n1 += (k["loot"] as Array).size()
	var porabate0 := float(n0) / maxi(1, base_k.size())
	var porabate1 := float(n1) / maxi(1, ks.size())
	checar(porabate1 > porabate0 * 1.8, "loot por abate sobe com loot boost, tipo do dia e 1,5 rolagem extra do streak", "%.2f → %.2f" % [porabate0, porabate1])
	var ini: Array = nova_sim(dados, mapa, cfg_b).iniciar()
	var mb := {}
	var me := {}
	for reg in ini:
		var m: Dictionary = reg.get("msg", reg)
		if m.get("type") == "boosts": mb = m
		if m.get("type") == "events": me = m
	var chaves_b: Array = []
	for bo in mb.get("boosts", []):
		if bo["key"] != "shinylock":
			chaves_b.append(bo["key"])
	checar(chaves_b == ["xp", "pokexp", "loot"] and mb["boosts"][0].keys() == ["key", "until", "pct"] and me.get("events", []).size() == 1,
		"no início: boosts {key, until, pct} (com o shinylock da entrada, se houver) e events no formato gravado (A)", JSON.stringify(mb))
	var sp = nova_sim(dados, mapa, {"boosts": [{"key": "capture", "until": fim, "pct": 0}], "auto_catch": true, "bola_auto_catch": 3})
	checar(true, "boost de captura aceito na simulação")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(0 if falhas == 0 else 1)
