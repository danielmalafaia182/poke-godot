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
## Uso: testes/rodar.sh res://testes/campanha.gd [--horas N] [--nivel_alvo N] [--semente N] [--saida caminho.json]
##      (padrão: 300 h simuladas ou treinador 2000)

const Regras := preload("res://sim/regras.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const ServicoCidade := preload("res://sim/servico_cidade.gd")
const NovoJogo := preload("res://sim/servico_novo_jogo.gd")
const Acesso := preload("res://sim/regras_acesso.gd")

const TICKS_MIN := 300
var dados
var cidade
var mapas := {}
var hunts_lista: Array = []
var args := {"horas": 300.0, "nivel_alvo": 2000, "semente": 1, "saida": "saida_testes/campanha.json", "sessao_min": 60, "sonda_min": 2}

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
	est = {"gold": int(r["ouro"]), "cidade": "cerulean", "vip": false, "itens": {}, "bolas": {}, "depot": {"itens": {}},
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
		"medidor_captura": medidor, "vip": false, "penalizar": penalizar}


func _rodar(slug: String, minutos: float, penalizar: bool, aplicar: bool) -> Dictionary:
	semente_seq += 1
	var cfg := CenarioJogo.configurar(_jogo(slug, penalizar), dados, int(args["semente"]) * 100003 + semente_seq, 0)
	var sim = Simulacao.new(cfg, dados, _mapa(slug))
	sim.iniciar()
	var r := {"slug": slug, "ticks": 0, "abates": 0, "morte": false, "xp": 0, "loot": {}, "capturas": 0, "pocoes": 0,
		"travado_max_s": 0.0}
	var xp0 := treinador_xp
	var parado := 0
	var ult_pos := Vector2i(-999, -999)
	var n := int(minutos * TICKS_MIN)
	for t in n:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			match String(m.get("type", "")):
				"field-kill":
					r["abates"] += 1
					for it in m.get("loot", []):
						var k := str(int(it.get("itemId", 0)))
						r["loot"][k] = int(r["loot"].get(k, 0)) + int(it.get("qty", 0))
						if aplicar and String(dados.itens.get(int(k), {}).get("categoria", "")) == "stone":
							pedras_obtidas[k] = int(pedras_obtidas.get(k, 0)) + int(it.get("qty", 0))
				"catch-result":
					if bool(m.get("success", false)):
						r["capturas"] += 1
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
	return r


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


func _campanha() -> void:
	var horas_max := float(args["horas"])
	var sessao := 0
	while minutos_jogados < horas_max * 60.0 and _nivel_treinador() < int(args["nivel_alvo"]):
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
		"por_hunt": lista, "linha_tempo": linha_tempo, "pedras_obtidas": pedras_obtidas, "problemas": problemas, "segundos_reais": (Time.get_ticks_msec() - t0) / 1000.0}
	var f := FileAccess.open(String(args["saida"]), FileAccess.WRITE)
	f.store_string(JSON.stringify(saida, "  "))
	f.close()
	print("FIM %.1f h jogadas, treinador %d, líder %s %d, ouro %d, %d hunts, problemas %s, %.0f s reais" % [minutos_jogados / 60.0,
		_nivel_treinador(), saida["especie_final"], _nivel_lider(), int(est["gold"]), lista.size(), str(problemas), saida["segundos_reais"]])
