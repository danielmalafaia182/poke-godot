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
	Servico.somar_abates(e2, 999)
	checar(int(sv.msg_streak(e2)["available"]) == 1 and int(sv.msg_streak(e2)["toNext"]) == 1, "somar abates conta para o próximo ponto")

	# ---------------------------------------------------------------- Tipo do Dia (A: until às 03:00 UTC; E: rotação)
	var ev: Dictionary = sv.tratar({}, {"type": "eventos", "agora": D0})[0]
	var ev2: Dictionary = sv.tratar({}, {"type": "eventos", "agora": D0 + 86400})[0]
	checar(ev["events"][0]["tipo"] == "DRAGON" and ev2["events"][0]["tipo"] == "BUG", "09/11 = Dragão e 10/11 = Inseto (A: os dois dias gravados)")
	checar(int(ev2["events"][0]["until"]) == 1794366000000 and ev2["events"][0]["key"] == "type-of-day", "fim do dia = 1794366000000, como na gravação (A)")
	checar(sv.tipo_do_dia(D0 + 18 * 86400) == "DRAGON" and sv.tipo_do_dia(D0 - 86400) == "NORMAL", "rotação de 18 dias (E)")

	# ---------------------------------------------------------------- sessão (regra do usuário)
	checar(bool(sv.tratar({}, {"type": "sessao", "fechado_em": 1000, "agora": 1000 + 899})[0]["expirada"]) == false, "fechado 14 min 59 s: sessão viva")
	checar(bool(sv.tratar({}, {"type": "sessao", "fechado_em": 1000, "agora": 1000 + 900})[0]["expirada"]), "fechado 15 min: sessão expira (sem soneca)")

	# ---------------------------------------------------------------- Modo Soneca (C)
	var s1 = nova_sim(dados, mapa, {})
	rodar(s1, 30)
	var a1: Dictionary = Servico.amostra_soneca(s1, 300)
	var s2 = nova_sim(dados, mapa, {})
	rodar(s2, 30)
	var a2: Dictionary = Servico.amostra_soneca(s2, 300)
	checar(JSON.stringify(a1) == JSON.stringify(a2), "amostra determinística (mesma semente → mesma amostra)")
	checar(int(a1["kills"]) > 0 and int(a1["xpTrainer"]) > 0 and int(a1["seconds"]) == 300 and not bool(s1.cfg["auto_catch"]),
		"amostra de 5 min com abates e XP, sem bolas (C)", "%d abates, %d XP" % [int(a1["kills"]), int(a1["xpTrainer"])])
	var es := {"soneca": {}}
	checar(bool(tipo(sv.tratar(es, {"type": "sleep-mode", "agora": 5000, "amostra": a1}), "sleep-ok")["ghost"]), "sleep-mode → sleep-ok {ghost: true} (C)")
	var rel: Dictionary = sv.tratar(es.duplicate(true), {"type": "offline-get", "agora": 5000 + 299})[0]
	checar(rel["report"] == null and bool(rel.get("canceled", false)), "voltar antes de 5 min cancela a soneca (C)")
	var horas := 2 * 3600
	rel = sv.tratar(es, {"type": "offline-get", "agora": 5000 + 300 + horas})[0]
	var taxa := float(a1["xpTrainer"]) / 300.0
	checar(int(rel["report"]["seconds"]) == horas and int(rel["report"]["xp50"]) == int(floor(taxa * horas * 0.5)) and rel["report"]["cappedAt"] == null,
		"2 h fora: 50% da taxa de XP da amostra (C)", "xp50 %d" % int(rel["report"]["xp50"]))
	checar(int(rel["report"]["estKills"]) == int(round(float(a1["kills"]) / 300.0 * horas)), "abates estimados pela taxa da amostra")
	var cap: Dictionary = sv.tratar(es.duplicate(true), {"type": "offline-get", "agora": 5000 + 300 + 3 * 86400})[0]
	checar(int(cap["report"]["seconds"]) == 86400 and int(cap["report"]["cappedAt"]) == 86400, "teto de 24 h (C)")
	checar(tipo(sv.tratar(es.duplicate(true), {"type": "offline-claim", "agora": 5000 + 300 + horas, "boost": true}), "error").size() > 0,
		"turbo recusado (E: sem diamantes)")
	r = sv.tratar(es, {"type": "offline-claim", "agora": 5000 + 300 + horas, "boost": false})
	var col: Dictionary = tipo(r, "offline-claimed")
	checar(int(col["xpTrainer"]) == int(a1["xpTrainer"]) + int(rel["report"]["xp50"]) and int(col["xpPokemon"]) > int(a1["xpPokemon"]) and es["soneca"].is_empty(),
		"coleta: XP da amostra + 50% do tempo fora, no treinador e no Pokémon (C); soneca zerada")
	checar(tipo(sv.tratar(es, {"type": "offline-claim", "agora": 99999999}), "error").size() > 0, "coletar de novo: nada a coletar")
	checar(bool(sv.tratar({"soneca": {"inicio": 1000, "fim": 1300, "amostra": a1}}, {"type": "sessao", "fechado_em": 1000, "agora": 1000 + 3600})[0]["expirada"]) == false,
		"com soneca valendo, 1 h fechado não mata a sessão (E)")

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
		and int(k0["xpParts"]["typeDay"]) == Regras.js_round(b * 0.2) and int(k0["xpParts"]["streak"]) == Regras.js_round(b * 0.03),
		"parcelas: boost 50%, tipo do dia 20%, streak 30 pts = 3% (F: sobre a base)", JSON.stringify(k0["xpParts"]))
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
