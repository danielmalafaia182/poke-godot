extends SceneTree
## Fase 4, item 3: Daily Gift (G7), Quests & Tasks, Daily Kill e Daily Catch (G5) — sim/servico_diarias.gd, puro e
## sem save. Confere com os valores gravados (A) em dados/fase4/. Rodar: testes/rodar.sh res://testes/test_sim_diarias.gd

const Servico := preload("res://sim/servico_diarias.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const D13 := 1794585960   # 13/11/2026 ~15:26 UTC (a hora do G5)

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


func _init() -> void:
	var dados = DadosJogo.carregar()
	var sv = Servico.new(dados)

	# ---------------------------------------------------------------- Daily Gift (A: G7; C: regras da janela)
	var e := {"gold": 0, "itens": {}, "bolas": {}, "vip": true, "nivel": 100}
	var g: Dictionary = sv.tratar(e, {"type": "daily-get", "agora": D13})[0]
	checar(String(g["ym"]) == "2026-11" and int(g["total"]) == 28 and int(g["nextDay"]) == 1 and bool(g["canClaim"]) and g["rewards"].size() == 28,
		"calendário de 28 prêmios do mês (A)", str([g["ym"], g["total"], g["nextDay"]]))
	checar(String(g["rewards"][0]["label"]) == "Poké Ball" and int(g["rewards"][0]["qty"]) == 100 and String(g["rewards"][4]["kind"]) == "xpboost",
		"dia 1 = Poké Ball ×100, dia 5 = XP Boost (A)")
	var r: Array = sv.tratar(e, {"type": "daily-claim", "agora": D13})
	checar(int(e["bolas"].get("1", 0)) == 100 and tipo(r, "daily")["claimedToday"] and not tipo(r, "daily")["canClaim"] and int(tipo(r, "daily")["nextDay"]) == 2,
		"coletar o dia 1: +100 Poké Balls; já coletado hoje (A: claimedToday)")
	checar(tipo(sv.tratar(e, {"type": "daily-claim", "agora": D13 + 3600}), "error").size() > 0, "um prêmio por dia (C)")
	sv.tratar(e, {"type": "daily-claim", "agora": D13 + 86400})
	checar(int(e["itens"].get("200", 0)) == 100, "dia seguinte: dia 2 = Small Potion ×100 (A)")
	sv.tratar(e, {"type": "daily-claim", "agora": D13 + 2 * 86400})
	checar(int(e["bolas"].get("6", 0)) == 15, "dia 3 (VIP): Idle Ball ×15 para quem é VIP (A)")
	sv.tratar(e, {"type": "daily-claim", "agora": D13 + 3 * 86400})
	r = sv.tratar(e, {"type": "daily-claim", "agora": D13 + 4 * 86400})
	var bst: Array = tipo(r, "boosts").get("boosts", [])
	checar(bst.size() == 1 and String(bst[0]["key"]) == "xp" and int(bst[0]["pct"]) == 50 and int(bst[0]["until"]) == (D13 + 4 * 86400) * 1000 + 3600000,
		"dia 5: XP Boost +50% por 1 h (C: 'activated for 1h!')", str(bst))
	var nv := {"gold": 0, "itens": {}, "bolas": {}, "vip": false, "nivel": 100}
	sv.tratar(nv, {"type": "daily-claim", "agora": D13})
	sv.tratar(nv, {"type": "daily-claim", "agora": D13 + 86400})
	var g3: Dictionary = sv.tratar(nv, {"type": "daily-get", "agora": D13 + 2 * 86400})[0]
	checar(bool(g3["blockedByVip"]) and not bool(g3["canClaim"]) and tipo(sv.tratar(nv, {"type": "daily-claim", "agora": D13 + 2 * 86400}), "error").size() > 0
		and bool(g3["rewards"][2]["locked"]), "sem VIP, o dia 3 (VIP) bloqueia (C: 'subscribe to VIP')")
	var dez: Dictionary = sv.tratar(e, {"type": "daily-get", "agora": D13 + 20 * 86400})[0]
	checar(String(dez["ym"]) == "2026-12" and int(dez["nextDay"]) == 1, "mês novo: o calendário recomeça (E)")
	# A: a conta gravada (13 coletados, VIP, 13/11) → nextDay 14, claimedToday
	var grav: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/fase4/daily_gift.json"))
	checar(grav["rewards"].size() == 28, "dados do Daily Gift: 28 prêmios gravados")

	# ---------------------------------------------------------------- Quests & Tasks (A: G5)
	var t := {"gold": 0, "itens": {}, "bolas": {}, "nivel": 50}
	var tk: Dictionary = sv.tratar(t, {"type": "tasks-get"})[0]
	checar(tk["tasks"].size() == 124 and tk["cities"].size() == 43, "124 tarefas em 43 cidades (A)")
	var paul: Dictionary = tk["tasks"][0]
	checar(String(paul["id"]) == "paul" and paul["goalProgress"].size() == 2 and int(paul["goalProgress"][0]["have"]) == 0 and not bool(paul["complete"])
		and int(paul["goalProgress"][0]["looktype"]) == 36 and String(paul["goalProgress"][0]["type1"]) == "NORMAL",
		"Paul (Viridian): 15 Rattata e 5 Zubat; formato do goalProgress (A)")
	for i in 20:
		sv.tratar(t, {"type": "abate", "speciesId": 19})
	for i in 5:
		sv.tratar(t, {"type": "abate", "speciesId": 41})
	paul = sv.tratar(t, {"type": "tasks-get"})[0]["tasks"][0]
	checar(int(paul["goalProgress"][0]["have"]) == 15 and bool(paul["complete"]), "abates contam; have limitado a qty (A: 15/15)")
	r = sv.tratar(t, {"type": "tasks-claim", "taskId": "paul"})
	checar(int(tipo(r, "tasks-claimed")["xp"]) == 920 and int(t["gold"]) == 0 and tipo(sv.tratar(t, {"type": "tasks-claim", "taskId": "paul"}), "error").size() > 0,
		"entregar: +920 XP (A); só uma vez (E)")
	t["itens"]["4"] = 25
	t["itens"]["90"] = 2
	r = sv.tratar(t, {"type": "tasks-claim", "taskId": "douglas298b"})
	checar(int(t["gold"]) == 2700 and int(t["itens"].get("4", 0)) == 5 and not t["itens"].has("90"), "tarefa de entrega: consome 20 Bag of Pollen e 2 Mushroom, +2700 (A: prêmio; E: consumo)")
	checar(tipo(sv.tratar(t, {"type": "tasks-claim", "taskId": "billeevee"}), "error").size() > 0, "captura que falta: incompleta")
	sv.tratar(t, {"type": "captura", "speciesId": 133, "agora": D13})
	checar(tipo(sv.tratar(t, {"type": "tasks-claim", "taskId": "billeevee"}), "tasks-claimed").size() > 0, "capturar um Eevee completa a tarefa do Bill")

	# ---------------------------------------------------------------- Daily Kill (A: G5)
	var k := {"gold": 0, "itens": {}, "bolas": {}, "nivel": 169}
	var dk: Dictionary = sv.tratar(k, {"type": "daily-kill-get", "agora": D13})[0]
	var ok_xp := true
	for o in dk["options"]:
		ok_xp = ok_xp and int(o["xp"]) == int(floor(float(o["qty"]) * float(dados.especie(int(o["speciesId"]))["xpAbate"]) * 8.0 / 3.0 + 1e-6))
	checar(dk["options"].size() == 3 and String(dk["tierKey"]) == "hard" and String(dk["dayKey"]) == "2026-11-13" and int(dk["resetAt"]) == 1794625200000 and ok_xp,
		"3 opções do tier hard; dayKey e resetAt como gravados; xp = floor(qtd × xpAbate × 8/3) (A)", JSON.stringify(dk["options"]).left(200))
	# a fórmula do xp contra as 3 opções gravadas
	var gk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/fase4/daily_kill.json"))["dia"]
	var ok_g := true
	for o in gk["options"]:
		ok_g = ok_g and int(sv._kill_xp({"qty": int(o["qty"]), "speciesId": int(o["speciesId"])})) == int(o["xp"])
	checar(ok_g, "xp das 3 opções gravadas (Furious Pidgeot 798, Ancient Marowak 1497, Politoed 1199) bate (A)")
	checar(JSON.stringify(dk["reward"]["items"].map(func(x): return [int(x["itemId"]), int(x["qty"])])) == "[[13115,6],[21287,2]]",
		"prêmio do hard: 6 Devoted Token + 2 Bronze Dimensional Key (A)")
	var dk2: Dictionary = sv.tratar(k.duplicate(true), {"type": "daily-kill-get", "agora": D13 + 3600})[0]
	checar(JSON.stringify(dk2["options"]) == JSON.stringify(dk["options"]), "mesmo dia → mesmas opções (E: semente = dia)")
	checar(tipo(sv.tratar(k, {"type": "daily-kill-claim", "agora": D13}), "error").size() > 0, "coletar sem escolher: recusa")
	var dp: Dictionary = tipo(sv.tratar(k, {"type": "daily-kill-pick", "idx": 2, "agora": D13}), "daily-kill")
	checar(int(dp["pickedIdx"]) == 2 and int(dp["reward"]["xp"]) == int(dk["options"][2]["xp"]) and int(dp["options"][2]["have"]) == 0,
		"pick {idx: 2}: pickedIdx e reward.xp da opção (A)")
	checar(tipo(sv.tratar(k, {"type": "daily-kill-pick", "idx": 0, "agora": D13}), "error").size() > 0, "uma escolha por dia (A: rerollMax 0)")
	var alvo := int(dk["options"][2]["speciesId"])
	var q := int(dk["options"][2]["qty"])
	sv.tratar(k, {"type": "abate", "speciesId": alvo, "n": q - 1})
	checar(tipo(sv.tratar(k, {"type": "daily-kill-claim", "agora": D13}), "error").size() > 0, "faltando 1 abate: incompleta")
	sv.tratar(k, {"type": "abate", "speciesId": alvo})
	var sm: Dictionary = sv.tratar(k, {"type": "dailys-summary", "agora": D13})[0]
	checar(bool(sm["kill"]["picked"]) and bool(sm["kill"]["done"]) and int(sm["kill"]["qty"]) == q and int(sm["kill"]["have"]) == q and int(sm["resetAt"]) == 1794625200000,
		"dailys-summary no formato gravado (A)", JSON.stringify(sm))
	r = sv.tratar(k, {"type": "daily-kill-claim", "agora": D13})
	checar(int(tipo(r, "daily-kill-claimed")["payout"]["xp"]) == int(dk["options"][2]["xp"]) and int(k["itens"].get("13115", 0)) == 6 and int(k["itens"].get("21287", 0)) == 2,
		"coletar: XP da missão + itens (C: payout)")
	checar(bool(sv.tratar({"nivel": 10}, {"type": "daily-kill-get", "agora": D13})[0]["locked"]), "abaixo do nível 25: travado (A: minLevel 25)")
	var novo_dia: Dictionary = sv.tratar(k, {"type": "daily-kill-get", "agora": D13 + 86400})[0]
	checar(int(novo_dia["pickedIdx"]) == -1 and not bool(novo_dia["claimed"]) and String(novo_dia["dayKey"]) == "2026-11-14", "virada às 03:00 UTC: missão nova (A: resetAt)")

	# ---------------------------------------------------------------- Daily Catch (A: G5; xp F)
	var c := {"gold": 0, "itens": {}, "bolas": {}, "nivel": 169}
	var dc: Dictionary = sv.tratar(c, {"type": "daily-catch-get", "agora": D13})[0]
	checar(dc["tiers"].size() == 4 and int(dc["total"]) == 2 and int(dc["used"]) == 0, "nível 169: 4 faixas liberadas, 2 capturas por dia (A)")
	checar(sv.tratar({"nivel": 70}, {"type": "daily-catch-get", "agora": D13})[0]["tiers"].size() == 2, "nível 70: superEasy e easy (A: minLevel 25 e 60)")
	r = sv.tratar(c, {"type": "captura", "speciesId": 246, "agora": D13})
	var cl: Dictionary = tipo(r, "daily-catch-claimed")
	checar(int(cl["claim"]["slot"]) == 1 and int(cl["xp"]) == 14613 and String(cl["claim"]["tierKey"]) == "hard", "Larvitar, slot 1: 14613 XP (A, F na regra)", JSON.stringify(cl.get("claim", {})))
	r = sv.tratar(c, {"type": "captura", "speciesId": 246, "agora": D13})
	checar(int(tipo(r, "daily-catch-claimed")["xp"]) == 20458 and int(c["itens"].get("13115", 0)) == 6, "Larvitar, slot 2: 20458 XP (A); itens do tier por captura (F)")
	checar(sv.tratar(c, {"type": "captura", "speciesId": 246, "agora": D13}).is_empty(), "terceira captura: sem prêmio (A: total 2)")
	checar(sv.tratar(c, {"type": "captura", "speciesId": 246, "agora": D13 + 86400}).size() > 0, "dia seguinte: slots livres de novo")
	checar(sv.tratar({"nivel": 169}, {"type": "captura", "speciesId": 10546, "agora": D13}).is_empty(), "espécie fora da tabela: não conta")

	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
