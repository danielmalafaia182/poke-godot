extends SceneTree
## Campanha do zero na sim pura (escopo de 18/11, item 3). Sem cena, sem autoload, sem save: só sim/.
##
## Jogador (política E, documentada no relatório):
##   - Começo = jogo novo do projeto (sim/servico_novo_jogo.gd): Geodude Lv.1, treinador 1, 100 Small Potions,
##     100 Poké Balls, ouro 0, Cerulean.
##   - Cidade a cada sessão (sim/servico_cidade.gd, os mesmos comandos do jogo): Nurse Joy (joy-heal), vende todo o loot
##     vendável (shop-sell; poções e pedras o Mark não compra, C), evolui com pedras quando dá (evolve-info/evolve
##     useStone; nunca sem pedra, que volta ao Lv.1), compra poções e Poké Balls (shop-buy).
##   - Poção: a menor que cura ≥ 35% do HP máximo (ou a maior), estoque-alvo 150. Bolas: Poké Ball, estoque-alvo 60,
##     Auto-Catch ligado com ela, capturas vão para a BOX (o time é só o líder).
##   - Escolha da hunt: entre as liberadas pelo nível do treinador (sim/regras_acesso.gd, C), as das 3 faixas de nível
##     mais altas que não passam de nível do líder + 20, mais a atual; até 5, cada uma sondada por 2 min (sem a
##     penalidade de entrada, para comparar). Fica a de maior XP/min sem desmaio. A sondagem não conta no tempo jogado.
##   - Hunt onde o líder morreu fica de fora até ele subir 10 níveis (um jogador não insiste na hunt que o derruba).
##   - Pedras: com o nível para evoluir e sem as pedras, entram nas candidatas as hunts liberadas cujas espécies dropam a
##     pedra que falta (tabela de loot do creatures.json, A); a nota soma XP/min e pedras/min, cada um dividido pelo
##     melhor das candidatas.
##   - Sessão: 60 min de sim na hunt escolhida (para antes se o time cai: field-none sem-reserva = morte). A penalidade
##     de entrada vale como no original (hunt diferente da anterior: lock de 60 s, A).
## Por hunt: minutos jogados, abates/min, mortes, XP/h do treinador, ouro/h (venda do loot daquela hunt), poções/h, e o
## maior trecho travado (herói parado, sem lutar, com selvagem vivo e alvo definido).
##
## Ciclo 2 (`--completo 1`): tudo que o offline tem ligado, com relógio de calendário (início 19/11/2026 03:00 UTC):
##   - Dia = `--horas_dia` (16) h de jogo ativo + o resto em Modo Soneca (sim/servico_jogador.gd: amostra de 5 min na
##     última hunt, sem bolas; coleta de 50% da taxa pelo tempo fora, A/C).
##   - Streak Points (C/A): abates contam; na cidade compra ponto na trilha EXP quando o ouro passa de 1,5× o custo (E).
##   - Daily Gift todo dia (boosts de 1 h vão para a sim; itens e bolas para a BAG), Daily Kill (escolhe a opção de mais XP
##     cuja espécie está numa hunt liberada que o líder aguenta; a nota da hunt soma o XP marginal da missão), Daily Catch
##     (capturas dão XP), Quests & Tasks (entrega tudo que completar, antes de vender o loot).
##   - Tipo do Dia pela rotação (sim/servico_jogador.gd), boosts ativos, VIP por `--vip 0|1`.
##   - Ginásios (ciclo 3): na cidade desafia os liberados sem insígnia ativa, só com o líder; as ativas valem na hunt.
##   - Orre ×10 de XP (balanceamento.json xp_regiao, decisão do ciclo 3). Berries e Rare Candy: lote 3 congelado, fora.
##   - Auto-Catch Shiny ligado com a melhor bola que tiver (decisão do ciclo 2).
##   - Metas visíveis (sim/metas.gd): a cada sessão registra a hunt recomendada, a próxima meta e os marcos.
##
## Uso: testes/rodar.sh res://testes/campanha.gd [--horas N] [--nivel_alvo N] [--semente N] [--saida caminho.json]
##      [--completo 1] [--vip 1] [--horas_dia 16]   (padrão: 300 h simuladas ou treinador 2000)

const Regras := preload("res://sim/regras.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const ServicoCidade := preload("res://sim/servico_cidade.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")
const Acesso := preload("res://sim/regras_acesso.gd")
const ServicoJogador := preload("res://sim/servico_jogador.gd")
const ServicoDiarias := preload("res://sim/servico_diarias.gd")
const Metas := preload("res://sim/metas.gd")
const Ginasios := preload("res://sim/servico_ginasios.gd")

const TICKS_MIN := 300
var dados
var cidade
var mapas := {}
var hunts_lista: Array = []
var args := {"horas": 300.0, "nivel_alvo": 2000, "semente": 1, "saida": "saida_testes/campanha.json", "sessao_min": 60, "sonda_min": 2,
	"completo": 0, "vip": 0, "horas_dia": 16.0}

# estado do jogador (formato do sim/servico_cidade.gd)
var est := {}
var treinador_xp := 0
var medidor := {}
var ultima_hunt := ""
var semente_seq := 0

var por_hunt := {}
var bloqueadas := {}   # slug -> nível do líder quando morreu ali
var pedras_obtidas := {}   # itemId -> qtd (loot de pedra na campanha)
var linha_tempo: Array = []
var minutos_jogados := 0.0
var t0 := 0
# ciclo 2
var jogador
var diarias
var gin
var agora_s := 0          # relógio de calendário (unix s)
var ativo_no_dia := 0.0   # minutos de jogo ativo no dia atual
var dia_atual := -1
var colecao := {}         # speciesId -> true (espécies capturadas)
var nome_para_id := {}
var extras := {"soneca_xp": 0, "soneca_pxp": 0, "sonecas": 0, "tarefas_xp": 0, "tarefas_ouro": 0, "tarefas": 0, "kill_xp": 0,
	"kills_diarios": 0, "catch_xp": 0, "ginasios_vitorias": 0, "ginasios_derrotas": 0, "insignias_max": 0, "gift": 0, "streak_pontos": 0, "streak_ouro": 0, "shiny_vistos": 0, "shiny_capturados": 0}
var marcos_vistos := {}
var metas_linha: Array = []


func _init() -> void:
	t0 = Time.get_ticks_msec()
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		var k := String(a[i]).trim_prefix("--")
		if args.has(k) and i + 1 < a.size():
			args[k] = type_convert(a[i + 1], typeof(args[k]))
	dados = DadosJogo.carregar()
	cidade = ServicoCidade.new(dados)
	hunts_lista = dados.hunts.values()
	jogador = ServicoJogador.new()
	diarias = ServicoDiarias.new(dados)
	gin = Ginasios.new(dados)
	agora_s = int(Time.get_unix_time_from_datetime_string("2026-11-19T03:00:00"))
	for id in dados.especies:
		nome_para_id[String(dados.especies[id]["nome"])] = int(id)
	_novo_jogo()
	_campanha()
	_relatorio()
	quit(0)


func _mapa(slug: String):
	if not mapas.has(slug):
		if mapas.size() > 40:
			mapas.clear()
		mapas[slug] = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
	return mapas[slug]


func _novo_jogo() -> void:
	var r: Dictionary = NovoJogo.criar(NovoJogo.INICIAL_PROJETO, int(args["semente"]), "Campanha")
	var ini: Dictionary = r["inicial"]
	est = {"gold": int(r["ouro"]), "cidade": "cerulean", "vip": int(args["vip"]) == 1, "streak": {}, "boosts": [], "itens": {}, "bolas": {}, "depot": {"itens": {}},
		"pokes": [{"id": "lider", "speciesId": int(ini["speciesId"]), "xp": int(ini["xp"]), "ivs": ini["ivs"],
			"quality": float(ini["quality"]), "hp": -1, "shiny": false, "team": true, "slot": 0, "leader": true, "starter": true}]}
	for k in r["pocoes"]:
		est["itens"][str(k)] = int(r["pocoes"][k])
	for k in r["bolas"]:
		est["bolas"][str(k)] = int(r["bolas"][k])
	print("INICIO Geodude Lv.1, IV %s (total %d), Q %.3f" % [str(ini["ivs"]), _soma_iv(ini["ivs"]), float(ini["quality"])])


static func _soma_iv(ivs: Dictionary) -> int:
	var s := 0
	for k in ivs:
		s += int(ivs[k])
	return s


func _lider() -> Dictionary:
	return est["pokes"][0]


func _nivel_lider() -> int:
	return Regras.nivel_por_xp(int(_lider()["xp"]))


func _nivel_treinador() -> int:
	return Regras.nivel_por_xp(treinador_xp)


func _jogo(slug: String, penalizar: bool) -> Dictionary:
	var l: Dictionary = _lider()
	var inv: Array = []
	for k in est["itens"]:
		if int(k) >= 200 and int(k) <= 204:
			inv.append({"itemId": int(k), "quantity": int(est["itens"][k])})
	var bolas := {}
	for k in est["bolas"]:
		bolas[int(k)] = int(est["bolas"][k])
	return {"slug": slug, "hunt": String(dados.hunts[slug]["nome"]), "equipe": [{"id": "lider",
		"nome": String(dados.especie(int(l["speciesId"]))["nome"]), "xp": int(l["xp"]), "ivs": l["ivs"], "quality": float(l["quality"]),
		"hp": int(l["hp"])}], "lider": 0, "treinador_xp": treinador_xp, "inventario": inv, "bolas": bolas,
		"auto_catch": int(est["bolas"].get("1", 0)) > 0, "bola_auto_catch": 1, "auto_potion": true, "pocao_id": 0,
		"medidor_captura": medidor, "vip": int(args["vip"]) == 1, "penalizar": penalizar,
		"auto_catch_shiny": completo(), "bola_auto_catch_shiny": _bola_shiny()}


func completo() -> bool:
	return int(args["completo"]) == 1


func _bola_shiny() -> int:
	for id in [7, 6, 4, 3, 2, 1]:
		if int(est["bolas"].get(str(id), 0)) > 0:
			return id
	return 0


func _rodar(slug: String, minutos: float, penalizar: bool, aplicar: bool, sem_bolas: bool = false) -> Dictionary:
	semente_seq += 1
	var cfg := CenarioJogo.configurar(_jogo(slug, penalizar), dados, int(args["semente"]) * 100003 + semente_seq, agora_s * 1000 if completo() else 0)
	if completo():
		cfg["streak"] = jogador.efeitos_streak(est)
		cfg["eventos"] = jogador.msg_eventos(agora_s)["events"]
		cfg["boosts"] = (est["boosts"] as Array).filter(func(b): return int(b.get("until", 0)) > agora_s * 1000)
		cfg["insignias"] = gin.ativas(est, agora_s)   # ciclo 3: insígnias de ginásio (+1% XP e drop cada)
		if sem_bolas:
			cfg["auto_catch"] = false
			cfg["auto_catch_shiny"] = false
	var sim = Simulacao.new(cfg, dados, _mapa(slug))
	sim.iniciar()
	var r := {"slug": slug, "ticks": 0, "abates": 0, "morte": false, "xp": 0, "loot": {}, "capturas": 0, "pocoes": 0,
		"travado_max_s": 0.0, "por_especie": {}, "capturas_especie": [], "pxp": 0, "shiny": 0, "shiny_cap": 0}
	var xp0 := treinador_xp
	var pxp0 := int(_lider()["xp"])
	var parado := 0
	var ult_pos := Vector2i(-999, -999)
	var n := int(minutos * TICKS_MIN)
	for t in n:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			match String(m.get("type", "")):
				"field-kill":
					r["abates"] += 1
					var ke := str(int(m.get("speciesId", -1)))
					r["por_especie"][ke] = int(r["por_especie"].get(ke, 0)) + 1
					if bool(m.get("shiny", false)):
						r["shiny"] += 1
					for it in m.get("loot", []):
						var k := str(int(it.get("itemId", 0)))
						r["loot"][k] = int(r["loot"].get(k, 0)) + int(it.get("qty", 0))
						if aplicar and String(dados.itens.get(int(k), {}).get("categoria", "")) == "stone":
							pedras_obtidas[k] = int(pedras_obtidas.get(k, 0)) + int(it.get("qty", 0))
				"catch-result":
					if bool(m.get("success", false)):
						r["capturas"] += 1
						r["capturas_especie"].append(int(nome_para_id.get(String(m.get("speciesName", "")), -1)))
						if int(m.get("ballId", 0)) == int(cfg.get("bola_auto_catch_shiny", -1)) and int(cfg.get("bola_auto_catch_shiny", -1)) != int(cfg.get("bola_auto_catch", -2)):
							r["shiny_cap"] += 1
				"auto-heal":
					r["pocoes"] += 1
				"field-none":
					r["morte"] = String(m.get("motivo", "")) == "sem-reserva"
				"field":
					var h: Dictionary = m["hero"]
					var pos := Vector2i(int(h["col"]), int(h["row"]))
					var vivo := false
					for mb in m["mobs"]:
						if not bool(mb["dead"]):
							vivo = true
							break
					if pos == ult_pos and not bool(m.get("fighting", false)) and vivo and m.get("targetSlot") != null and not bool(m.get("fainted", false)):
						parado += 2
					else:
						parado = 0
					ult_pos = pos
					r["travado_max_s"] = maxf(float(r["travado_max_s"]), parado * 0.2)
		r["ticks"] = t + 1
		if sim.encerrada:
			break
	r["xp"] = int(sim.treinador["xp"]) - xp0
	r["pxp"] = int(sim.equipe[0]["xp"]) - pxp0
	if aplicar:
		treinador_xp = int(sim.treinador["xp"])
		var e: Dictionary = sim.equipe[0]
		_lider()["xp"] = int(e["xp"])
		_lider()["hp"] = int(e["hp"])
		for k in est["itens"].keys():
			if int(k) >= 200 and int(k) <= 204:
				est["itens"].erase(k)
		for k in sim.inventario:
			if int(sim.inventario[k]) > 0:
				est["itens"][str(int(k))] = int(sim.inventario[k])
		for k in sim.balls["counts"]:
			est["bolas"][str(k)] = int(sim.balls["counts"][k])
		medidor = sim.medidor.duplicate(true)
		if completo():
			_pos_hunt(r)
	return r


func _pos_hunt(r: Dictionary) -> void:
	## Streak, diárias e coleção com o resultado de um trecho aplicado.
	for k in r["por_especie"]:
		ServicoJogador.somar_abates(est, int(r["por_especie"][k]), int(k))
		diarias.tratar(est, {"type": "abate", "speciesId": int(k), "n": int(r["por_especie"][k])})
	for sid in r["capturas_especie"]:
		if sid < 0:
			continue
		colecao[sid] = true
		est["nivel"] = _nivel_treinador()
		for m in diarias.tratar(est, {"type": "captura", "speciesId": sid, "agora": agora_s}):
			if String(m.get("type", "")) == "daily-catch-claimed":
				treinador_xp += int(m["xp"])
				extras["catch_xp"] += int(m["xp"])
	extras["shiny_vistos"] += int(r["shiny"])
	extras["shiny_capturados"] += int(r["shiny_cap"])


func _cidade() -> Dictionary:
	## Nurse, venda, evolução, compras. Devolve {ouro_venda, evoluiu}.
	var out := {"ouro_venda": 0, "evoluiu": ""}
	cidade.tratar(est, {"type": "joy-heal"})
	var venda: Array = []
	for k in est["itens"]:
		if cidade.preco_venda(int(k)) > 0:
			venda.append({"itemId": int(k), "qty": int(est["itens"][k])})
	if not venda.is_empty():
		for m in cidade.tratar(est, {"type": "shop-sell", "items": venda}):
			if String(m.get("type", "")) == "shop-sold":
				out["ouro_venda"] = int(m["goldGained"])
	var info: Dictionary = cidade.tratar(est, {"type": "evolve-info", "capturedId": "lider"})[0]
	if bool(info.get("canEvolve", false)) and bool(info.get("hasStones", false)) and info.get("destId") != null:
		for m in cidade.tratar(est, {"type": "evolve", "capturedId": "lider", "useStone": true, "destId": info["destId"]}):
			if String(m.get("type", "")) == "evolved":
				out["evoluiu"] = String(m["name"])
	# poção: a menor que cura ≥ 35% do HP máximo, senão a maior
	var max_hp: int = cidade.max_hp(_lider())
	var escolha := 204
	for id in [200, 201, 202, 203, 204]:
		if float(dados.itens[id].get("cura", 0)) >= 0.35 * max_hp:
			escolha = id
			break
	var preco := int(dados.itens[escolha]["precoGold"])
	var falta := 150 - int(est["itens"].get(str(escolha), 0))
	var qtd := mini(falta, int(est["gold"]) / maxi(1, preco))
	if qtd > 0:
		cidade.tratar(est, {"type": "shop-buy", "itemId": escolha, "qty": qtd})
	var falta_b := 60 - int(est["bolas"].get("1", 0))
	var qb := mini(falta_b, (int(est["gold"]) - 0) / 5)
	if qb > 0:
		cidade.tratar(est, {"type": "shop-buy", "ballId": 1, "qty": qb})
	return out


func _pedras_faltando() -> Array:
	## itemIds das pedras que faltam quando o líder já tem o nível para evoluir (evolve-info, como a tela do jogo).
	var info: Dictionary = cidade.tratar(est, {"type": "evolve-info", "capturedId": "lider"})[0]
	var falta: Array = []
	if bool(info.get("canEvolve", false)) and not bool(info.get("hasStones", false)):
		for st in info.get("stones", []):
			if int(st["have"]) < int(st["need"]):
				falta.append(int(st["itemId"]))
	return falta


func _chance_pedra(slug: String, pedras: Array) -> float:
	## Chance média por abate de cair uma das pedras, pela tabela de loot das espécies dos spawns (A: creatures.json).
	var sp: Array = dados.hunts[slug].get("spawns", [])
	if sp.is_empty():
		return 0.0
	var soma := 0.0
	for x in sp:
		for l in dados.especie(int(x.get("pokeId", 0))).get("loot", []):
			if int(l.get("itemId", -1)) in pedras:
				soma += float(l.get("chance", 0))
	return soma / sp.size()


func _liberadas() -> Array:
	var r: Array = []
	for s in Acesso.hunts_liberadas(hunts_lista, _nivel_treinador()):
		if bloqueadas.has(s) and _nivel_lider() < int(bloqueadas[s]) + 10:
			continue
		r.append(s)
	return r


func _candidatas_pedra(pedras: Array) -> Array:
	var c: Array = []
	for s in _liberadas():
		var ch := _chance_pedra(s, pedras)
		if ch > 0.0 and int(dados.hunts[s]["nivel"]) <= _nivel_lider() + 20:
			c.append([ch, s])
	c.sort_custom(func(a, b): return a[0] > b[0])
	var r: Array = []
	for x in c.slice(0, 5):
		r.append(x[1])
	return r


func _candidatas() -> Array:
	var lib := _liberadas()
	var teto := _nivel_lider() + 20
	var niveis := {}
	for s in lib:
		var nv := int(dados.hunts[s]["nivel"])
		if nv <= teto:
			niveis[nv] = true
	var lv: Array = niveis.keys()
	lv.sort()
	lv.reverse()
	lv = lv.slice(0, 3)
	var c: Array = []
	for s in lib:
		if int(dados.hunts[s]["nivel"]) in lv:
			c.append(s)
	c.sort()
	# até 5, espalhadas de forma determinística
	var escolhidas: Array = []
	if c.size() <= 5:
		escolhidas = c
	else:
		var passo := float(c.size()) / 5.0
		for i in 5:
			escolhidas.append(c[int(i * passo + semente_seq) % c.size()])
	if ultima_hunt != "" and ultima_hunt in lib and not ultima_hunt in escolhidas:
		escolhidas.append(ultima_hunt)
	return escolhidas


func _escolher() -> String:
	var melhor := ""
	var melhor_v := -1.0
	var pedras := _pedras_faltando()
	var cands := _candidatas()
	for s in _candidatas_pedra(pedras) if not pedras.is_empty() else []:
		if not s in cands:
			cands.append(s)
	# pontuação = XP/min ÷ melhor XP/min + (faltando pedra) pedras/min ÷ melhor pedras/min; desmaio na sonda derruba
	var notas := []
	var melhor_xp := 0.0001
	var melhor_pedra := 0.0000001
	for s in cands:
		var r := _rodar(s, float(args["sonda_min"]), false, false)
		var mins := maxf(0.1, r["ticks"] / float(TICKS_MIN))
		var xp := float(r["xp"]) / mins
		var pd := float(r["abates"]) / mins * _chance_pedra(s, pedras) if not pedras.is_empty() else 0.0
		xp += _bonus_kill(r, mins)
		notas.append([s, xp, pd, r["morte"]])
		melhor_xp = maxf(melhor_xp, xp)
		melhor_pedra = maxf(melhor_pedra, pd)
	for n in notas:
		var v: float = n[1] / melhor_xp + (n[2] / melhor_pedra if not pedras.is_empty() else 0.0)
		if n[3]:
			v *= 0.01
		if v > melhor_v:
			melhor_v = v
			melhor = n[0]
	return melhor


func _bonus_kill(r: Dictionary, mins: float) -> float:
	## XP/min marginal da Daily Kill escolhida: prêmio × (abates da espécie por min ÷ quantidade que falta).
	if not completo():
		return 0.0
	var k: Dictionary = est.get("diarias", {}).get("kill", {})
	if int(k.get("pickedIdx", -1)) < 0 or bool(k.get("claimed", false)):
		return 0.0
	var o: Dictionary = k["opcoes"][int(k["pickedIdx"])]
	var falta := maxi(1, int(o["qty"]) - int(k.get("have", 0)))
	var taxa := float(r["por_especie"].get(str(int(o["speciesId"])), 0)) / mins
	return float(diarias._kill_xp(o)) * minf(1.0, taxa / falta)


func _dia_novo() -> void:
	## Daily Gift e escolha da Daily Kill (a opção de mais XP cuja espécie está numa hunt liberada que o líder aguenta).
	est["nivel"] = _nivel_treinador()
	for m in diarias.tratar(est, {"type": "daily-claim", "agora": agora_s}):
		if String(m.get("type", "")) == "daily-gift" or m.has("claimed"):
			extras["gift"] += 1
		if String(m.get("type", "")) == "boosts":
			est["boosts"] = (m["boosts"] as Array).duplicate(true)
	var mk: Dictionary = diarias.tratar(est, {"type": "daily-kill-get", "agora": agora_s})[0]
	if bool(mk.get("locked", true)) or int(mk.get("pickedIdx", -1)) >= 0:
		return
	var aguenta := {}
	var pl := Metas.poder_lider(dados, _lider())
	for slug in _liberadas():
		if Metas.poder_hunt(dados, slug) <= pl:
			for x in dados.hunts[slug].get("spawns", []):
				aguenta[int(x.get("pokeId", 0))] = true
	var melhor := -1
	var melhor_xp := -1
	for i in (mk["options"] as Array).size():
		var o: Dictionary = mk["options"][i]
		if aguenta.has(int(o["speciesId"])) and int(o["xp"]) > melhor_xp:
			melhor = i
			melhor_xp = int(o["xp"])
	if melhor >= 0:
		diarias.tratar(est, {"type": "daily-kill-pick", "idx": melhor, "agora": agora_s})


func _diarias_cidade() -> void:
	## Antes da venda: tarefas completas, Daily Kill completa, Streak.
	est["nivel"] = _nivel_treinador()
	var mt: Dictionary = diarias.tratar(est, {"type": "tasks-get", "agora": agora_s})[0]
	for t in mt["tasks"]:
		if bool(t["complete"]) and not bool(t["claimed"]):
			for m in diarias.tratar(est, {"type": "tasks-claim", "taskId": String(t["id"]), "agora": agora_s}):
				if String(m.get("type", "")) == "tasks-claimed":
					treinador_xp += int(m["xp"])
					extras["tarefas_xp"] += int(m["xp"])
					extras["tarefas_ouro"] += int(m["cash"])
					extras["tarefas"] += 1
	for m in diarias.tratar(est, {"type": "daily-kill-claim", "agora": agora_s}):
		if String(m.get("type", "")) == "daily-kill-claimed":
			treinador_xp += int(m["payout"]["xp"])
			extras["kill_xp"] += int(m["payout"]["xp"])
			extras["kills_diarios"] += 1
	while true:
		var ms: Dictionary = jogador.msg_streak(est)
		if int(ms["available"]) <= 0 or int(est["gold"]) < int(ms["nextCost"]) * 3 / 2:
			break
		extras["streak_ouro"] += int(ms["nextCost"])
		jogador.tratar(est, {"type": "streak-spend", "track": "exp"})
		extras["streak_pontos"] += 1


func _ginasios() -> void:
	## Ciclo 3: na cidade, desafia cada ginásio liberado sem insígnia ativa (o time é só o líder, a política da campanha).
	est["nivel"] = _nivel_treinador()
	var l: Dictionary = _lider()
	var time := [{"speciesId": int(l["speciesId"]), "xp": int(l["xp"]), "ivs": l["ivs"], "quality": float(l["quality"])}]
	for g in gin.p.lista:
		var gid := String(g["id"])
		if _nivel_treinador() < int(g["nivel_treinador"]):
			continue
		if int(est.get("ginasios", {}).get("insignias", {}).get(gid, 0)) > agora_s * 1000:
			continue
		var m: Array = gin.tratar(est, {"type": "ginasio-desafiar", "gymId": gid, "agora": agora_s, "nivel": _nivel_treinador(), "time": time, "semente": agora_s + semente_seq})
		if String(m[0].get("type", "")) != "gym-result":
			continue
		if bool(m[0]["venceu"]):
			extras["ginasios_vitorias"] += 1
		else:
			extras["ginasios_derrotas"] += 1
	extras["insignias_max"] = maxi(int(extras["insignias_max"]), gin.ativas(est, agora_s))
	var chave := "insignias_%d" % gin.ativas(est, agora_s)
	if not marcos_vistos.has(chave):
		marcos_vistos[chave] = snappedf(minutos_jogados / 60.0, 0.01)


func _soneca() -> void:
	## Fim do dia ativo: Zzz na última hunt (amostra de 5 min, sem bolas) e coleta ao acordar (50%, A/C).
	var fora := int((24.0 - float(args["horas_dia"])) * 3600.0)
	if ultima_hunt != "" and fora > 300:
		var r := _rodar(ultima_hunt, 5.0, false, true, true)
		var e := {"soneca": {"inicio": agora_s, "fim": agora_s + 300, "amostra": {"xpSample": int(r["xp"]), "pokeXpSample": int(r["pxp"]),
			"kills": int(r["abates"]), "slug": ultima_hunt, "leaderId": "lider"}}}
		for m in jogador.tratar(e, {"type": "offline-claim", "agora": agora_s + fora, "boost": false}):
			if String(m.get("type", "")) == "offline-claimed":
				treinador_xp += int(m["xpGained"])
				_lider()["xp"] = int(_lider()["xp"]) + int(m["pokeXpGained"])
				extras["soneca_xp"] += int(m["xpGained"])
				extras["soneca_pxp"] += int(m["pokeXpGained"])
				extras["sonecas"] += 1
	agora_s += fora
	ativo_no_dia = 0.0


func _registrar_metas() -> Dictionary:
	var esp := colecao.keys()
	var mt := Metas.resumo(dados, hunts_lista, treinador_xp, _lider(), esp)
	var rec: Dictionary = mt["hunt"]
	var marco := int(mt["marco"]["anterior"])
	if not marcos_vistos.has("nivel_%d" % marco):
		marcos_vistos["nivel_%d" % marco] = snappedf(minutos_jogados / 60.0, 0.01)
	var cm := int(mt["colecao"]["especies"])
	for m in Metas.parametros().metas_marcos_colecao:
		if cm >= int(m) and not marcos_vistos.has("colecao_%d" % int(m)):
			marcos_vistos["colecao_%d" % int(m)] = snappedf(minutos_jogados / 60.0, 0.01)
	return {"rec": String(rec["atual"].get("slug", "")), "rec_xp_min": rec["atual"].get("xp_min", 0),
		"prox": String(rec["proxima"].get("slug", "")), "prox_lv": int(rec["proxima"].get("nivel_lider", -1)),
		"prox_salto": bool(rec["proxima"].get("salto", false)), "prox_ganho": int(rec["proxima"].get("ganho_pct", 0)),
		"marco": int(mt["marco"]["proximo"]), "colecao": cm, "regiao_cap": "%d/%d" % [int(mt["colecao"]["liberadas_capturadas"]), int(mt["colecao"]["liberadas_total"])]}


func _campanha() -> void:
	var horas_max := float(args["horas"])
	var sessao := 0
	while minutos_jogados < horas_max * 60.0 and _nivel_treinador() < int(args["nivel_alvo"]):
		if completo():
			var d: int = diarias.dia(agora_s)
			if d != dia_atual:
				dia_atual = d
				_dia_novo()
			_diarias_cidade()
			_ginasios()
		var c := _cidade()
		var slug := _escolher()
		if slug == "":
			print("SEM HUNT liberada?!")
			break
		var nt0 := _nivel_treinador()
		var nl0 := _nivel_lider()
		var r := _rodar(slug, float(args["sessao_min"]), slug != ultima_hunt, true)
		ultima_hunt = slug
		if r["morte"]:
			bloqueadas[slug] = nl0
		var mins: float = r["ticks"] / float(TICKS_MIN)
		minutos_jogados += mins
		var mt := {}
		if completo():
			agora_s += int(mins * 60.0)
			ativo_no_dia += mins
			mt = _registrar_metas()
			if ativo_no_dia >= float(args["horas_dia"]) * 60.0:
				_soneca()
		var ouro_loot := 0
		for k in r["loot"]:
			ouro_loot += cidade.preco_venda(int(k)) * int(r["loot"][k])
		var h: Dictionary = por_hunt.get(slug, {"slug": slug, "nivel": int(dados.hunts[slug]["nivel"]), "area": String(dados.hunts[slug]["area"]),
			"min": 0.0, "abates": 0, "mortes": 0, "xp": 0, "ouro": 0, "pocoes": 0, "capturas": 0, "sessoes": 0, "travado_max_s": 0.0,
			"lider_de": nl0, "lider_ate": nl0})
		h["min"] += mins
		h["abates"] += int(r["abates"])
		h["mortes"] += 1 if r["morte"] else 0
		h["xp"] += int(r["xp"])
		h["ouro"] += ouro_loot
		h["pocoes"] += int(r["pocoes"])
		h["capturas"] += int(r["capturas"])
		h["sessoes"] += 1
		h["travado_max_s"] = maxf(float(h["travado_max_s"]), float(r["travado_max_s"]))
		h["lider_ate"] = _nivel_lider()
		por_hunt[slug] = h
		sessao += 1
		var esp := String(dados.especie(int(_lider()["speciesId"]))["nome"])
		var linha := {"sessao": sessao, "h": snappedf(minutos_jogados / 60.0, 0.01), "slug": slug, "nivel_hunt": int(dados.hunts[slug]["nivel"]),
			"treinador": "%d→%d" % [nt0, _nivel_treinador()], "lider": "%s %d→%d" % [esp, nl0, _nivel_lider()], "abates": int(r["abates"]),
			"morte": r["morte"], "ouro": int(est["gold"]), "evoluiu": c["evoluiu"], "pedras_bag": _pedras_bag(), "venda": c["ouro_venda"], "travado_s": r["travado_max_s"]}
		if completo():
			linha["dias"] = snappedf(float(agora_s - int(Time.get_unix_time_from_datetime_string("2026-11-19T03:00:00"))) / 86400.0, 0.01)
			linha["metas"] = mt
			linha["streak"] = jogador.efeitos_streak(est)["exp"]
			linha["insignias"] = gin.ativas(est, agora_s)
		linha_tempo.append(linha)
		print("SESSAO ", JSON.stringify(linha))


func _pedras_bag() -> Dictionary:
	var r := {}
	for k in est["itens"]:
		if String(dados.itens.get(int(k), {}).get("categoria", "")) == "stone":
			r[String(dados.itens[int(k)]["nome"])] = int(est["itens"][k])
	return r


func _relatorio() -> void:
	var lista: Array = por_hunt.values()
	lista.sort_custom(func(a, b): return int(a["nivel"]) < int(b["nivel"]) or (int(a["nivel"]) == int(b["nivel"]) and String(a["slug"]) < String(b["slug"])))
	var problemas: Array = []
	for h in lista:
		var m := maxf(0.01, float(h["min"]))
		h["abates_min"] = snappedf(h["abates"] / m, 0.01)
		h["xp_h"] = int(h["xp"] / m * 60.0)
		h["ouro_h"] = int(h["ouro"] / m * 60.0)
		h["pocoes_h"] = snappedf(h["pocoes"] / m * 60.0, 0.1)
		if int(h["abates"]) == 0 or int(h["mortes"]) >= 3 or float(h["travado_max_s"]) >= 60.0:
			problemas.append(h["slug"])
	var saida := {"args": args, "minutos_jogados": minutos_jogados, "treinador_final": _nivel_treinador(), "lider_final": _nivel_lider(),
		"especie_final": String(dados.especie(int(_lider()["speciesId"]))["nome"]), "ouro_final": int(est["gold"]),
		"por_hunt": lista, "linha_tempo": linha_tempo, "pedras_obtidas": pedras_obtidas, "problemas": problemas, "segundos_reais": (Time.get_ticks_msec() - t0) / 1000.0,
		"extras": extras, "marcos": marcos_vistos, "colecao": colecao.size()}
	var f := FileAccess.open(String(args["saida"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(saida, "  "))
	f.close()
	print("FIM %.1f h jogadas, treinador %d, líder %s %d, ouro %d, %d hunts, problemas %s, %.0f s reais" % [minutos_jogados / 60.0,
		_nivel_treinador(), saida["especie_final"], _nivel_lider(), int(est["gold"]), lista.size(), str(problemas), saida["segundos_reais"]])
