extends SceneTree
## Fase 4, lote 1: serviços da cidade (sim/servico_cidade.gd), puros, sem save.
## Rodar: testes/rodar.sh res://testes/test_sim_cidade.gd

const Regras := preload("res://sim/regras.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Servico := preload("res://sim/servico_cidade.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


static func ivs(v: int) -> Dictionary:
	return {"hp": v, "atk": v, "def": v, "spAtk": v, "spDef": v, "speed": v}


static func estado_base() -> Dictionary:
	return {"gold": 1000, "cidade": "cerulean", "vip": false, "bola_selecionada": 1,
		"pokes": [
			{"id": "ini", "speciesId": 246, "xp": Regras.xp_total_para_nivel(60), "ivs": ivs(20), "quality": 1.2, "hp": -1, "team": true, "slot": 0, "leader": true, "starter": true},
			{"id": "geo", "speciesId": 74, "xp": Regras.xp_total_para_nivel(45), "ivs": ivs(10), "quality": 1.0, "hp": 30, "team": true, "slot": 1, "leader": false, "starter": false},
			{"id": "char", "speciesId": 5, "xp": Regras.xp_total_para_nivel(80), "ivs": ivs(31), "quality": 1.5, "hp": -1, "team": false, "slot": -1, "leader": false, "starter": false},
			{"id": "eev", "speciesId": 133, "xp": Regras.xp_total_para_nivel(80), "ivs": ivs(5), "quality": 0.9, "hp": -1, "team": false, "slot": -1, "leader": false, "starter": false}],
		"itens": {"200": 3, "4": 10, "109": 1, "53": 2, "49": 2},
		"bolas": {"1": 10, "3": 0, "7": 1},
		"depot": {"itens": {}, "bolas": {}}}


static func tipo(msgs: Array, t: String) -> Dictionary:
	for m in msgs:
		if String(m.get("type", "")) == t:
			return m
	return {}


func _init() -> void:
	var dados = DadosJogo.carregar()
	var sv = Servico.new(dados)

	# ---------------------------------------------------------------- evolução
	var e := estado_base()
	var info: Dictionary = sv.tratar(e, {"type": "evolve-info", "capturedId": "geo"})[0]
	checar(info["destName"] == "Graveler" and int(info["needLevel"]) == 40 and info["canEvolve"],
		"Geodude 45 → Graveler, nível exigido 40 (creatures.json evolveLevel = nível da hunt do destino, A/C)", str(info["needLevel"]))
	checar(info["stones"].size() == 1 and info["stones"][0]["name"] == "Rock Stone" and int(info["stones"][0]["need"]) == 1 and info["hasStones"],
		"receita do Geodude (hunt 1 < 40): 1 Rock Stone (C: 1 de cada pedra; receita F)", str(info["stones"]))
	var geo_antes: Dictionary = sv.poke_delta(sv._poke(e, "geo"))
	var r: Array = sv.tratar(e, {"type": "evolve", "capturedId": "geo", "useStone": true})
	var pd: Dictionary = tipo(r, "poke-delta").get("poke", {})
	checar(pd.get("name") == "Graveler" and int(pd["level"]) == 45 and not e["itens"].has("109"),
		"com pedra: mantém o nível (45) e consome a Rock Stone (C)", "%s %s" % [pd.get("name"), pd.get("level")])
	checar(int(pd["ivTotal"]) == 60 and float(pd["quality"]) == 1.0 and int(pd["stats"]["hp"]) > int(geo_antes["stats"]["hp"]),
		"IV e Quality mantidos, stats recalculados da base nova (C)", "%d → %d HP" % [int(geo_antes["stats"]["hp"]), int(pd["stats"]["hp"])])
	checar(absf(float(pd["hp"]) / float(pd["maxHp"]) - 30.0 / float(geo_antes["maxHp"])) < 0.02, "HP mantém a fração (E)")
	checar(tipo(r, "inventory").size() > 0, "inventory enviado depois de gastar pedra")
	# A (G3): Geodude Lv.40 com 209 Rock Stones → GET /evolve e POST /evolve gravados, campo a campo
	var g3 := {"gold": 0, "cidade": "cerulean", "itens": {"109": 209}, "pokes": [{"id": "g3", "speciesId": 74, "xp": Regras.xp_total_para_nivel(40),
		"ivs": ivs(16), "quality": 1.0, "hp": -1, "team": true}]}
	var i3: Dictionary = sv.tratar(g3, {"type": "evolve-info", "capturedId": "g3"})[0]
	var esperado_i := {"name": "Geodude", "destId": 75, "destName": "Graveler", "level": 40, "needLevel": 40, "canEvolve": true,
		"stones": [{"itemId": 109, "name": "Rock Stone", "icon": "/assets/items/rock_stone.gif", "need": 1, "have": 209}],
		"hasStones": true, "keepLevel": 40, "resetLevel": 1, "itemOnly": false}
	var ok_i := true
	for k in esperado_i:
		if JSON.stringify(i3.get(k)) != JSON.stringify(esperado_i[k]):
			ok_i = false
			print("  difere ", k, ": ", i3.get(k), " × ", esperado_i[k])
	checar(ok_i, "GET /evolve do Geodude 40 igual ao gravado (A, G3: 1 Rock Stone, só o tipo principal)")
	var e3: Dictionary = tipo(sv.tratar(g3, {"type": "evolve", "capturedId": "g3", "useStone": true}), "evolved")
	checar(bool(e3.get("ok")) and e3["name"] == "Graveler" and int(e3["destId"]) == 75 and int(e3["level"]) == 40 and bool(e3["usedStone"])
		and JSON.stringify(e3["stonesSpent"]) == JSON.stringify([{"itemId": 109, "qty": 1}]) and int(g3["itens"]["109"]) == 208,
		"POST /evolve igual ao gravado: {ok, name, destId, level 40, usedStone, stonesSpent [{109, 1}]} (A, G3)", JSON.stringify(e3))
	# sem pedra: volta ao nível 1
	var ini: Dictionary = sv.tratar(e, {"type": "evolve-info", "capturedId": "ini"})[0]
	checar(ini["destName"] == "Pupitar" and not ini["hasStones"], "Larvitar 60 → Pupitar, sem Rock Stone na BAG", str(ini["stones"]))
	checar(tipo(sv.tratar(e, {"type": "evolve", "capturedId": "ini", "useStone": true}), "error").size() > 0, "com pedra e sem pedras: recusa")
	r = sv.tratar(e, {"type": "evolve", "capturedId": "ini", "useStone": false})
	pd = tipo(r, "poke-delta").get("poke", {})
	checar(pd.get("name") == "Pupitar" and int(pd["level"]) == 1 and int(pd["xp"]) == 0 and bool(pd["starter"]),
		"sem pedra: grátis e volta ao Lv.1 (C), inicial continua inicial", "%s Lv %s" % [pd.get("name"), pd.get("level")])
	checar(tipo(sv.tratar(e, {"type": "evolve", "capturedId": "ini", "useStone": false}), "error").get("message", "").begins_with("Requer"),
		"Pupitar Lv.1 não evolui de novo (precisa do nível 100)")
	# receita de 2 tipos e espécie de hunt alta: Charmeleon (hunt 40) → Charizard = 2× Fire + 2× Feather (exemplo do guia, C)
	var ch: Dictionary = sv.tratar(e, {"type": "evolve-info", "capturedId": "char"})[0]
	var rec := {}
	for s in ch["stones"]:
		rec[s["name"]] = int(s["need"])
	checar(rec == {"Fire Stone": 2, "Feather Stone": 2} and ch["hasStones"], "Charmeleon → Charizard: 2× Fire + 2× Feather (guia do original, C)", str(rec))
	var iv: Dictionary = sv.tratar({"gold": 0, "cidade": "cerulean", "pokes": [{"id": "x", "speciesId": 2, "xp": Regras.xp_total_para_nivel(80), "ivs": ivs(1), "quality": 1.0, "hp": -1, "team": true}], "itens": {}}, {"type": "evolve-info", "capturedId": "x"})[0]
	checar(iv["stones"].size() == 1 and iv["stones"][0]["name"] == "Leaf Stone" and int(iv["stones"][0]["need"]) == 4, "Ivysaur → Venusaur: 4× Leaf Stone (guia, C)", str(iv["stones"]))
	# Eevee: ramos
	var ev: Dictionary = sv.tratar(e, {"type": "evolve-info", "capturedId": "eev"})[0]
	checar(ev.has("branches") and ev["branches"].size() >= 5 and ev["destId"] == null, "Eevee: escolha de ramo antes de evoluir", str(ev.get("branches", []).size()))
	checar(tipo(sv.tratar(e, {"type": "evolve", "capturedId": "eev", "useStone": false}), "error").size() > 0, "Eevee sem destino escolhido: recusa")
	e["itens"]["53"] = 2
	r = sv.tratar(e, {"type": "evolve", "capturedId": "eev", "useStone": true, "destId": 136})
	checar(tipo(r, "poke-delta").get("poke", {}).get("name") == "Flareon" and int(tipo(r, "poke-delta")["poke"]["level"]) == 80, "Eevee + Fire Stone → Flareon, mantém o nível")
	# cidade
	var fora := estado_base()
	fora["cidade"] = "viridian"
	checar(tipo(sv.tratar(fora, {"type": "evolve", "capturedId": "geo", "useStone": true}), "error").size() > 0 and fora["pokes"][1]["speciesId"] == 74,
		"fora de Cerulean: recusa sem mudar nada (C)")

	# ---------------------------------------------------------------- loja
	var l := estado_base()
	var loja: Dictionary = sv.tratar(l, {"type": "shop"})[0]
	var precos := {}
	for b in loja["balls"]:
		precos[int(b["id"])] = int(b["priceGold"])
	checar(precos == {1: 5, 2: 20, 3: 50, 4: 130}, "bolas à venda e preços = balls.catalog (A)", str(precos))
	checar(loja["items"].size() == 5 and int(loja["items"][0]["priceGold"]) == 5 and loja["items"][0].has("category") and loja["balls"][0].has("catchRate"),
		"itens à venda: as 5 poções; campos de GET /api/game/shop (A, G1)")
	r = sv.tratar(l, {"type": "shop-buy", "ballId": 3, "qty": 10})
	checar(int(l["gold"]) == 500 and int(l["bolas"]["3"]) == 10 and int(tipo(r, "shop-bought")["bought"]) == 10 and int(tipo(r, "balls")["gold"]) == 500,
		"comprar 10 Super Ball: −500 de ouro, +10 bolas, resposta {gold, bought} (C)")
	var compra: Dictionary = tipo(r, "shop-bought")
	checar(bool(compra["ok"]) and compra["item"] == "Super Ball" and int(compra["goldSpent"]) == 500, "resposta da compra = {ok, bought, item, goldSpent, gold} (A, G1)")
	r = sv.tratar(l, {"type": "shop-buy", "itemId": 203, "qty": 2})
	checar(int(l["gold"]) == 390 and int(l["itens"]["203"]) == 2, "comprar 2 Hyper Potion (55 cada)")
	checar(tipo(sv.tratar(l, {"type": "shop-buy", "ballId": 4, "qty": 100}), "error").size() > 0 and int(l["gold"]) == 390, "ouro insuficiente: recusa sem mudar nada")
	checar(tipo(sv.tratar(l, {"type": "shop-buy", "ballId": 6, "qty": 1}), "error").size() > 0, "Idle Ball não é comprável (A: buyable false)")
	checar(sv.preco_venda(4) == 40 and sv.preco_venda(200) == 0 and sv.preco_venda(109) == 0 and sv.preco_venda(205) == 40 and sv.preco_venda(206) == 350,
		"venda: npcPrice (C); poções e pedras o Mark não compra, Revive/Max Revive sim (C: iV/iK do cliente)",
		"%d %d %d %d %d" % [sv.preco_venda(4), sv.preco_venda(200), sv.preco_venda(109), sv.preco_venda(205), sv.preco_venda(206)])
	checar(tipo(sv.tratar(l, {"type": "shop-sell", "items": [{"itemId": 200, "qty": 1}]}), "error").size() > 0 and int(l["itens"]["200"]) == 3,
		"vender poção: recusa (não está na lista do Mark)")
	r = sv.tratar(l, {"type": "shop-sell", "items": [{"itemId": 4, "qty": 10}]})
	checar(int(tipo(r, "shop-sold")["goldGained"]) == 400 and int(l["gold"]) == 790 and not l["itens"].has("4"),
		"vender 10 Bag of Pollen (40): +400 (A, G1: Bag of Pollen vendido a 40)")
	checar(bool(tipo(r, "shop-sold")["ok"]) and int(tipo(r, "shop-sold")["soldKinds"]) == 1, "resposta da venda = {ok, soldKinds, soldCount, goldGained, gold} (A, G1)")
	checar(tipo(sv.tratar(l, {"type": "shop-sell", "items": [{"itemId": 4, "qty": 99}]}), "error").size() > 0, "vender mais do que tem: recusa")
	r = sv.tratar(l, {"type": "pokemon-sell", "pokeIds": ["char"]})
	checar(int(tipo(r, "pokemon-sold")["goldGained"]) == int(dados.especie(5)["valorVenda"]) and sv._poke(l, "char").is_empty() and tipo(r, "pokes-removed")["ids"] == ["char"],
		"vender Pokémon da BOX pelo valorVenda (F)")
	checar(tipo(sv.tratar(l, {"type": "pokemon-sell", "pokeIds": ["ini"]}), "error").size() > 0, "não vende do time nem o inicial (C)")
	l["pokes"].append({"id": "shy", "speciesId": 19, "xp": 0, "ivs": ivs(1), "quality": 1.0, "hp": -1, "team": false, "slot": -1, "shiny": true})
	var ouro_antes := int(l["gold"])
	checar(tipo(sv.tratar(l, {"type": "pokemon-sell", "pokeIds": ["shy"]}), "error").get("message", "").contains("shiny") and int(l["gold"]) == ouro_antes and not sv._poke(l, "shy").is_empty(),
		"o Mark não compra Pokémon shiny (C: lista de venda do cliente)")
	l["pokes"].append({"id": "b1", "speciesId": 9, "xp": 0, "ivs": ivs(31), "quality": 1.014, "hp": -1, "team": false, "slot": -1})
	l["pokes"].append({"id": "b2", "speciesId": 9, "xp": Regras.xp_total_para_nivel(80), "ivs": ivs(3), "quality": 1.8, "hp": -1, "team": false, "slot": -1})
	r = sv.tratar(l, {"type": "pokemon-sell", "pokeIds": ["b1", "b2"]})
	checar(int(tipo(r, "pokemon-sold")["goldGained"]) == 36000, "Blastoise vale 18000 qualquer que seja nível, Quality e IV (A, G2)", str(tipo(r, "pokemon-sold")))

	# ---------------------------------------------------------------- Nurse Joy
	var n := estado_base()
	r = sv.tratar(n, {"type": "joy-heal"})
	checar(tipo(r, "joy-healed").keys() == ["type"] and int(sv._poke(n, "geo")["hp"]) == -1 and int(n["gold"]) == 1000,
		"Nurse Joy cura o time inteiro de graça (C)")
	var sem := estado_base()
	sem["cidade"] = "pewter"
	checar(tipo(sv.tratar(sem, {"type": "joy-heal"}), "error").size() > 0, "cidade sem Nurse Joy (city-npcs, A): recusa")

	# ---------------------------------------------------------------- depot
	var d := estado_base()
	r = sv.tratar(d, {"type": "poke-store", "id": "geo"})
	checar(not bool(sv._poke(d, "geo")["team"]) and tipo(r, "poke-delta").size() > 0, "guardar Pokémon do time na BOX")
	checar(tipo(sv.tratar(d, {"type": "poke-store", "id": "ini"}), "error").size() > 0, "o inicial não vai para a BOX (E)")
	for i in 5:
		d["pokes"].append({"id": "x%d" % i, "speciesId": 19, "xp": 0, "ivs": ivs(1), "quality": 1.0, "hp": -1, "team": false, "slot": -1})
	for id in ["geo", "char", "x0", "x1", "x2"]:
		sv.tratar(d, {"type": "poke-withdraw", "id": id})
	checar(sv._time(d).size() == 6, "time completo com 6", str(sv._time(d).size()))
	checar(tipo(sv.tratar(d, {"type": "poke-withdraw", "id": "x3"}), "error").get("message", "").begins_with("Time cheio"), "7º no time: recusa (C: 6)")
	var slots: Array = []
	for t in sv._time(d):
		slots.append(int(t["slot"]))
	checar(slots == [0, 1, 2, 3, 4, 5], "slots do time renumerados 0..5", str(slots))
	r = sv.tratar(d, {"type": "depot-move", "itemId": 4, "dir": "store"})
	checar(int(d["depot"]["itens"]["4"]) == 10 and not d["itens"].has("4"), "guardar item no depot: a pilha inteira (A, G4)")
	var md: Dictionary = tipo(r, "depot")
	checar(md.has("inventory") and md.has("depot") and md["depot"][0].keys() == ["id", "name", "icon", "category", "npcPrice", "quantity"],
		"mensagem do depot = {inventory, depot}, itens {id, name, icon, category, npcPrice, quantity} (A, G4)", str(md["depot"][0].keys()))
	r = sv.tratar(d, {"type": "depot-move", "itemId": 4, "dir": "withdraw"})
	checar(int(d["itens"]["4"]) == 10 and not d["depot"]["itens"].has("4"), "retirar item do depot")
	checar(tipo(sv.tratar(d, {"type": "depot-move", "ballId": 1, "dir": "store"}), "error").size() > 0 and int(d["bolas"]["1"]) == 10,
		"bolas não vão para o depot (A, G4)")
	r = sv.tratar(d, {"type": "depot-move", "all": true})
	checar(d["itens"].is_empty() and int(d["bolas"]["1"]) == 10 and int(d["bolas"]["7"]) == 1 and (d["depot"].get("bolas", {}) as Dictionary).is_empty() and int(d["depot"]["itens"]["200"]) == 3,
		"guardar tudo leva os itens (inclusive poções) e deixa as bolas na BAG (A, G4)")
	var cheia := estado_base()
	for i in 200:
		cheia["depot"]["itens"][str(1000 + i)] = 1
	checar(tipo(sv.tratar(cheia, {"type": "depot-move", "itemId": 4, "dir": "store"}), "error").size() > 0, "depot de itens com 200 pilhas: recusa (E)")

	# ---------------------------------------------------------------- determinismo
	var a := estado_base()
	var b := estado_base()
	var ma: Array = []
	var mb: Array = []
	for cmd in [{"type": "shop-buy", "ballId": 1, "qty": 3}, {"type": "evolve", "capturedId": "geo", "useStone": true}, {"type": "joy-heal"}, {"type": "depot-move", "all": true}]:
		ma.append_array(sv.tratar(a, cmd))
		mb.append_array(Servico.new(dados).tratar(b, cmd))
	checar(JSON.stringify(ma) == JSON.stringify(mb) and JSON.stringify(a) == JSON.stringify(b), "mesma entrada → mesmas mensagens e mesmo estado")

	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(0 if falhas == 0 else 1)
