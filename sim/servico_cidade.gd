extends RefCounted
## Fase 4, lote 1: serviços da cidade (evolução, loja do Mark, Nurse Joy, depot) como o servidor original os decide.
## Puro e determinístico: sem Node, sem relógio, sem RNG. Recebe o estado do jogador (Dictionary no formato abaixo) e um
## comando no formato do protocolo; muda o estado e devolve a lista de mensagens que o servidor mandaria.
## O cliente (EstadoJogo) monta o estado a partir do save, manda o comando e aplica as mensagens (ver ponte_cidade.gd).
##
## Estado do jogador (ids ORIGINAIS do servidor; bolas separadas dos itens, como no original: "ball" × "item"):
##   gold: int · cidade: slug · vip: bool
##   pokes: [{id, speciesId, xp, ivs{hp,atk,def,spAtk,spDef,speed}, quality, hp (−1 = cheio), shiny, team, slot,
##            leader, starter}]
##   itens: {"<itemId>": qtd} (BAG: poções, pedras, loot) · bolas: {"<ballId>": qtd}
##   depot: {"itens": {"<itemId>": qtd}, "bolas": {"<ballId>": qtd}}
##
## Comandos (nomes do original quando existem; C = chunk 0gx72gz9qjk5j.js, E = decisão do projeto):
##   evolve-info {capturedId, destId?}        ≈ GET  /api/game/evolve?capturedId=&destId=   (C; resposta: campos que a tela lê)
##   evolve {capturedId, useStone, destId?}   ≈ POST /api/game/evolve                       (C)
##   shop                                     ≈ GET  /api/game/shop                         (C: a tela lê gold; o resto, E)
##   shop-buy {ballId|itemId, qty}            ≈ POST /api/game/shop/buy → {gold, bought}    (C)
##   shop-sell {items:[{itemId, qty}]}        ≈ POST /api/game/shop/sell → {gold, goldGained, soldCount} (C)
##   pokemon-sell {pokeIds:[...]}             ≈ POST /api/game/pokemon/sell → {gold, goldGained, sold}   (C)
##   joy-heal                                 = WS joy-heal (C; o original não manda resposta própria: E)
##   depot                                    ≈ GET  /api/game/depot                        (C)
##   depot-move {itemId|ballId, dir} | {all}  ≈ POST /api/game/depot/move {itemId, dir} | {all: true} (C; ballId, E)
##   poke-store {id} / poke-withdraw {id}     = WS poke-store / poke-withdraw (C: nomes; campos, E)
## Mensagens de estado depois de cada comando: currency {gold} (C: tipo existe), balls {catalog, counts, gold,
## selected} (A: formato gravado), inventory {items[{itemId, quantity}]} (A), poke-delta {poke} (A: formato gravado),
## depot {items, balls} (E), pokes-removed {ids} (E).

const Regras := preload("res://sim/regras.gd")
const Fontes := preload("res://sim/fontes.gd")

## Cada regra com a origem. C = cliente original; A = gravação; B = Pokepedia; E = decisão do projeto; F = hipótese.
const PARAMETROS := {
	# Evolução
	"evolucao_cidade": "cerulean",          # C: "Only works in Cerulean — the button is locked during a hunt"
	"evolucao_nivel_alto": 40,              # C: "Species from Lv.40+ hunts require 4 stones total"; até 39: 1 de cada
	"evolucao_pedras_total_alto": 4,        # C: "4 stones total — split equally across combos"
	"evolucao_nivel_reset": 1,              # C: sem pedra "goes back to Lv.1"
	# F: receita = pedra do tipo principal da espécie de origem + pedra de cada tipo que a evolução GANHA. Bate com os
	# dois exemplos do guia (C): Ivysaur → Venusaur = 4× Leaf (nenhum tipo novo); Charmeleon → Charizard = 2× Fire +
	# 2× Feather (ganha Flying). A receita real vem do servidor (o cliente só mostra), por isso é hipótese.
	# Tipo → pedra (F, nomes das pedras do items.json; Ghost → Darkness e Normal/Fairy → Heart por falta de pedra própria).
	"pedra_por_tipo": {"BUG": "Cocoon Stone", "DARK": "Darkness Stone", "DRAGON": "Crystal Stone",
		"ELECTRIC": "Thunder Stone", "FAIRY": "Heart Stone", "FIGHTING": "Punch Stone", "FIRE": "Fire Stone",
		"FLYING": "Feather Stone", "GHOST": "Darkness Stone", "GRASS": "Leaf Stone", "GROUND": "Earth Stone",
		"ICE": "Ice Stone", "NORMAL": "Heart Stone", "POISON": "Venom Stone", "PSYCHIC": "Enigma Stone",
		"ROCK": "Rock Stone", "STEEL": "Metal Stone", "WATER": "Water Stone"},
	# C: "Eevee is a special case (its own stone system)"; os ramos (cada pedra leva a um Pokémon) seguem o canon (B/F).
	# O caminho sem pedra vai para o destino do creatures.json (Vaporeon, A/C).
	"ramos_eevee": {"134": "Water Stone", "135": "Thunder Stone", "136": "Fire Stone", "196": "Enigma Stone",
		"197": "Darkness Stone", "470": "Leaf Stone", "471": "Ice Stone", "700": "Heart Stone"},
	# HP depois de evoluir: mantém a fração da vida (E; o original não foi gravado).
	# Loja
	"bolas_catalogo": [   # A: mensagem balls.catalog (gravações): priceGold, buyable, catchRate
		{"id": 1, "name": "Poké Ball", "catchRate": 1, "priceGold": 5, "buyable": true, "infinite": false, "bound": false},
		{"id": 2, "name": "Great Ball", "catchRate": 2, "priceGold": 20, "buyable": true, "infinite": false, "bound": false},
		{"id": 3, "name": "Super Ball", "catchRate": 3, "priceGold": 50, "buyable": true, "infinite": false, "bound": false},
		{"id": 4, "name": "Ultra Ball", "catchRate": 4, "priceGold": 130, "buyable": true, "infinite": false, "bound": false},
		{"id": 6, "name": "Idle Ball", "catchRate": 5, "priceGold": 400, "buyable": false, "infinite": false, "bound": false},
		{"id": 7, "name": "Golden Idle Ball", "catchRate": 5, "priceGold": 400, "buyable": false, "infinite": true, "bound": true},
		{"id": 5, "name": "Master Ball", "catchRate": 255, "priceGold": 0, "buyable": false, "infinite": false, "bound": false}],
	# Compra de item: priceGold > 0 do items.json (C: a tela mostra "Preço: priceGold"; hoje só as 5 poções).
	# Venda: npcPrice (C: "Mark paga: npcPrice"). E: nunca acima do preço de compra quando o item é comprável
	# (Small Potion custa 5 e o npcPrice é 50: sem o teto, comprar e vender daria ouro infinito). Pede gravação.
	"venda_teto_preco_compra": true,
	"venda_pokemon": "valorVenda",          # F: Pokémon vendido pelo valorVenda (sellValue) da espécie; o original não foi gravado
	"qtd_max_por_compra": 100000,           # E: limite de sanidade por operação
	# Depot
	"limite_time": 6,                       # C: "Your team only carries 6 — the rest rest here"
	"capacidade_box": 3000,                 # A: auto-helper.pokeCapacity 3000 (conta VIP; sem VIP não medido)
	"capacidade_depot_pilhas": 200,         # E: limite do P04 (o original não mostra limite no depot de itens)
	"starter_no_time": true,                # E: o inicial não vai para a BOX (regra do P04)
}

var dados   # sim/dados_jogo.gd
var p: Dictionary = PARAMETROS.duplicate(true)
var _cidades: Dictionary = {}
var _pedra_id: Dictionary = {}


func _init(dados_jogo, parametros: Dictionary = {}) -> void:
	dados = dados_jogo
	for k in parametros:
		p[k] = parametros[k]
	var c = Fontes.ler_json(Fontes.pasta_dados() + "/gerados/cidades.json")
	if c is Array:
		for cid in c:
			_cidades[String(cid["slug"])] = cid
	for it in dados.itens.values():
		if String(it.get("categoria", "")) == "stone":
			_pedra_id[String(it["nome"])] = int(it["id"])


# ============================================================================== entrada

func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	match String(cmd.get("type", "")):
		"evolve-info":
			return [_info_evolucao(estado, cmd)]
		"evolve":
			return _evoluir(estado, cmd)
		"shop":
			return [_loja(estado)]
		"shop-buy":
			return _comprar(estado, cmd)
		"shop-sell":
			return _vender(estado, cmd)
		"pokemon-sell":
			return _vender_pokemon(estado, cmd)
		"joy-heal":
			return _curar(estado)
		"depot":
			return [_msg_depot(estado)]
		"depot-move":
			return _mover_depot(estado, cmd)
		"poke-store":
			return _mover_poke(estado, String(cmd.get("id", "")), true)
		"poke-withdraw":
			return _mover_poke(estado, String(cmd.get("id", "")), false)
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


static func _erro(texto: String) -> Dictionary:
	return {"type": "error", "message": texto}


func _npc_na_cidade(estado: Dictionary, tipo: String) -> bool:
	var c: Dictionary = _cidades.get(String(estado.get("cidade", "")), {})
	for n in c.get("npcs", []):
		if String(n.get("kind", "")) == tipo:
			return true
	return false


# ============================================================================== Pokémon

func _poke(estado: Dictionary, id: String) -> Dictionary:
	for pk in estado.get("pokes", []):
		if String(pk.get("id", "")) == id:
			return pk
	return {}


func _time(estado: Dictionary) -> Array:
	var t: Array = []
	for pk in estado.get("pokes", []):
		if bool(pk.get("team", false)):
			t.append(pk)
	t.sort_custom(func(a, b): return int(a.get("slot", 99)) < int(b.get("slot", 99)))
	return t


func _box(estado: Dictionary) -> Array:
	var b: Array = []
	for pk in estado.get("pokes", []):
		if not bool(pk.get("team", false)):
			b.append(pk)
	return b


func _numerar_time(estado: Dictionary) -> void:
	var i := 0
	for pk in _time(estado):
		pk["slot"] = i
		i += 1
	for pk in _box(estado):
		pk["slot"] = -1


func _stats(pk: Dictionary) -> Dictionary:
	var esp: Dictionary = dados.especie(int(pk["speciesId"]))
	return Regras.calcular_stats(esp["base"], pk["ivs"], Regras.nivel_por_xp(int(pk["xp"])), float(pk["quality"]))


func max_hp(pk: Dictionary) -> int:
	return Regras.hp_combate_aliado(int(_stats(pk)["hp"]))


func hp_atual(pk: Dictionary) -> int:
	var m := max_hp(pk)
	return m if int(pk.get("hp", -1)) < 0 else clampi(int(pk["hp"]), 0, m)


func poke_delta(pk: Dictionary) -> Dictionary:
	## Mesmo formato do poke-delta gravado (A), com os stats recalculados.
	var esp: Dictionary = dados.especie(int(pk["speciesId"]))
	var st := _stats(pk)
	var ivt := 0
	for k in Regras.CHAVES_STATS:
		ivt += int(pk["ivs"][k])
	var tipos := Regras.tipos_de(esp)
	var ev: Variant = esp.get("evolui")
	var r := {"id": String(pk["id"]), "speciesId": int(pk["speciesId"]), "name": String(esp.get("nome", "")),
		"level": Regras.nivel_por_xp(int(pk["xp"])), "shiny": bool(pk.get("shiny", false)), "finalStage": ev == null,
		"team": bool(pk.get("team", false)), "slot": int(pk.get("slot", -1)), "leader": bool(pk.get("leader", false)),
		"starter": bool(pk.get("starter", false)), "sellValue": int(esp.get("valorVenda", 0)),
		"looktype": int(esp.get("looktype", 0)), "barLooktype": int(esp.get("looktype", 0)), "xp": int(pk["xp"]),
		"hp": hp_atual(pk), "maxHp": Regras.hp_combate_aliado(int(st["hp"])), "type1": tipos[0],
		"type2": tipos[1] if tipos[1] != "" else null, "stats": st, "quality": float(pk["quality"]), "ivTotal": ivt,
		"power": Regras.power(st, float(pk["quality"]))}
	if ev is Dictionary:
		r["hasEvolution"] = true
		r["evolveNeedLevel"] = int(ev["nivel"])
		r["evolvesToName"] = String(dados.especie(int(ev["para"])).get("nome", ""))
	return r


# ============================================================================== evolução

func _receita(origem: Dictionary, destino: Dictionary) -> Array:
	## [{itemId, name, need}] (F, ver PARAMETROS.pedra_por_tipo).
	var tabela: Dictionary = p.pedra_por_tipo
	var nomes: Array = []
	var t_or := Regras.tipos_de(origem)
	var t_de := Regras.tipos_de(destino)
	if tabela.has(t_or[0]):
		nomes.append(String(tabela[t_or[0]]))
	for t in t_de:
		if t != "" and not (t in t_or) and tabela.has(t) and not (String(tabela[t]) in nomes):
			nomes.append(String(tabela[t]))
	if nomes.is_empty():
		return []
	var alto := int(origem.get("nivelHunt", 0)) >= int(p.evolucao_nivel_alto)
	var cada := maxi(1, ceili(float(p.evolucao_pedras_total_alto) / nomes.size())) if alto else 1
	var r: Array = []
	for n in nomes:
		r.append({"itemId": int(_pedra_id.get(n, 0)), "name": n, "need": cada})
	return r


func _ramos(origem: Dictionary) -> Array:
	## Destinos possíveis: [{destId, needLevel, stones}] (Eevee: um por pedra; os outros: o do creatures.json).
	var ev: Variant = origem.get("evolui")
	if not ev is Dictionary:
		return []
	if String(origem.get("nome", "")) == "Eevee":
		var r: Array = []
		for k in p.ramos_eevee:
			var d: Dictionary = dados.especie(int(k))
			if d.is_empty():
				continue
			var n := String(p.ramos_eevee[k])
			r.append({"destId": int(k), "needLevel": int(ev["nivel"]), "stones": [{"itemId": int(_pedra_id.get(n, 0)), "name": n, "need": 1}]})
		return r
	var dest: Dictionary = dados.especie(int(ev["para"]))
	return [] if dest.is_empty() else [{"destId": int(ev["para"]), "needLevel": int(ev["nivel"]), "stones": _receita(origem, dest)}]


func _com_posse(estado: Dictionary, pedras: Array) -> Array:
	var r: Array = []
	for s in pedras:
		var x: Dictionary = s.duplicate()
		x["have"] = int(estado.get("itens", {}).get(str(int(s["itemId"])), 0))
		r.append(x)
	return r


static func _tem_pedras(pedras: Array) -> bool:
	if pedras.is_empty():
		return false
	for s in pedras:
		if int(s["have"]) < int(s["need"]) or int(s["itemId"]) <= 0:
			return false
	return true


func _info_evolucao(estado: Dictionary, cmd: Dictionary) -> Dictionary:
	## Campos que a tela de evolução do original lê (C): name, level, needLevel, canEvolve, destId, destName, keepLevel,
	## resetLevel, itemOnly, hasStones, stones[{itemId, name, need, have}], branches[{destId, destName, needLevel,
	## canEvolve, hasStones, stones}] (só quando há mais de um destino).
	var pk := _poke(estado, String(cmd.get("capturedId", "")))
	if pk.is_empty():
		return _erro("Pokémon não encontrado.")
	var origem: Dictionary = dados.especie(int(pk["speciesId"]))
	var nivel := Regras.nivel_por_xp(int(pk["xp"]))
	var ramos := _ramos(origem)
	var r := {"type": "evolve-info", "capturedId": String(pk["id"]), "name": String(origem.get("nome", "")), "level": nivel,
		"keepLevel": nivel, "resetLevel": int(p.evolucao_nivel_reset), "itemOnly": false, "canEvolve": false,
		"hasStones": false, "stones": [], "needLevel": 0, "destId": null, "destName": null,
		"inCity": String(estado.get("cidade", "")) == String(p.evolucao_cidade)}
	if ramos.is_empty():
		r["reason"] = "Esta espécie não evolui."
		return r
	var escolhido: Dictionary = {}
	if ramos.size() > 1:
		var lista: Array = []
		for rm in ramos:
			var st := _com_posse(estado, rm["stones"])
			lista.append({"destId": int(rm["destId"]), "destName": String(dados.especie(int(rm["destId"])).get("nome", "")),
				"needLevel": int(rm["needLevel"]), "canEvolve": nivel >= int(rm["needLevel"]), "hasStones": _tem_pedras(st), "stones": st})
			if cmd.get("destId") != null and int(cmd["destId"]) == int(rm["destId"]):
				escolhido = rm
		r["branches"] = lista
		if escolhido.is_empty():
			# sem destino escolhido: o nível exigido é o mesmo em todos os ramos
			r["needLevel"] = int(ramos[0]["needLevel"])
			r["canEvolve"] = nivel >= int(ramos[0]["needLevel"])
			return r
	else:
		escolhido = ramos[0]
	var pedras := _com_posse(estado, escolhido["stones"])
	r["destId"] = int(escolhido["destId"])
	r["destName"] = String(dados.especie(int(escolhido["destId"])).get("nome", ""))
	r["needLevel"] = int(escolhido["needLevel"])
	r["canEvolve"] = nivel >= int(escolhido["needLevel"])
	r["stones"] = pedras
	r["hasStones"] = _tem_pedras(pedras)
	return r


func _evoluir(estado: Dictionary, cmd: Dictionary) -> Array:
	if String(estado.get("cidade", "")) != String(p.evolucao_cidade):
		return [_erro("A evolução só funciona em Cerulean.")]
	var info := _info_evolucao(estado, cmd)
	if info.get("type") == "error":
		return [info]
	if info.get("destId") == null:
		return [_erro(String(info.get("reason", "Escolha a evolução primeiro.")))]
	if not bool(info["canEvolve"]):
		return [_erro("Requer nível %d." % int(info["needLevel"]))]
	var com_pedra := bool(cmd.get("useStone", false))
	if com_pedra and not bool(info["hasStones"]):
		return [_erro("Faltam pedras.")]
	if not com_pedra and bool(info["itemOnly"]):
		return [_erro("Esta evolução exige pedras.")]
	var pk := _poke(estado, String(cmd["capturedId"]))
	var fracao := float(hp_atual(pk)) / float(maxi(1, max_hp(pk)))
	if com_pedra:
		for s in info["stones"]:
			var k := str(int(s["itemId"]))
			estado["itens"][k] = int(estado["itens"][k]) - int(s["need"])
			if int(estado["itens"][k]) <= 0:
				estado["itens"].erase(k)
	else:
		pk["xp"] = Regras.xp_total_para_nivel(int(p.evolucao_nivel_reset))   # C: volta ao Lv.1 (XP do nível 1 = 0)
	pk["speciesId"] = int(info["destId"])
	# IVs e Quality mantidos; stats recalculados da base nova (C: "Growth/Quality are kept — stats are recalculated").
	pk["hp"] = clampi(roundi(fracao * max_hp(pk)), 0, max_hp(pk))   # E: mantém a fração da vida
	var r: Array = [{"type": "evolved", "capturedId": String(pk["id"]), "name": String(info["destName"]),
		"destId": int(info["destId"]), "useStone": com_pedra, "level": Regras.nivel_por_xp(int(pk["xp"]))}, {"type": "poke-delta", "poke": poke_delta(pk)}]
	if com_pedra:
		r.append(msg_inventario(estado))
	return r


# ============================================================================== loja (Mark)

func _bola(id: int) -> Dictionary:
	for b in p.bolas_catalogo:
		if int(b["id"]) == id:
			return b
	return {}


func preco_venda(item_id: int) -> int:
	var it: Dictionary = dados.itens.get(item_id, {})
	var v := int(it.get("precoNpc", 0))
	if bool(p.venda_teto_preco_compra) and int(it.get("precoGold", 0)) > 0:
		v = mini(v, int(it["precoGold"]))
	return maxi(0, v)


func _loja(estado: Dictionary) -> Dictionary:
	var bolas: Array = []
	for b in p.bolas_catalogo:
		if bool(b["buyable"]):
			bolas.append({"id": int(b["id"]), "name": String(b["name"]), "price": int(b["priceGold"])})
	var itens: Array = []
	var ids: Array = dados.itens.keys()
	ids.sort()
	for id in ids:
		var it: Dictionary = dados.itens[id]
		if int(it.get("precoGold", 0)) > 0:
			itens.append({"id": int(id), "name": String(it["nome"]), "price": int(it["precoGold"]), "category": String(it.get("categoria", ""))})
	var venda: Array = []
	var bag: Dictionary = estado.get("itens", {})
	var chaves := bag.keys()
	chaves.sort_custom(func(a, b): return int(a) < int(b))
	for k in chaves:
		var preco := preco_venda(int(k))
		if preco > 0 and int(bag[k]) > 0:
			venda.append({"itemId": int(k), "name": String(dados.itens.get(int(k), {}).get("nome", "")), "price": preco, "quantity": int(bag[k])})
	return {"type": "shop", "gold": int(estado.get("gold", 0)), "balls": bolas, "items": itens, "sell": venda}


func _comprar(estado: Dictionary, cmd: Dictionary) -> Array:
	var qtd := int(cmd.get("qty", 0))
	if qtd <= 0 or qtd > int(p.qtd_max_por_compra):
		return [_erro("Quantidade inválida.")]
	if not _npc_na_cidade(estado, "shop"):
		return [_erro("Não há loja nesta cidade.")]
	var preco := 0
	var nome := ""
	if cmd.has("ballId"):
		var b := _bola(int(cmd["ballId"]))
		if b.is_empty() or not bool(b["buyable"]):
			return [_erro("Esta bola não está à venda.")]
		preco = int(b["priceGold"])
		nome = String(b["name"])
	else:
		var it: Dictionary = dados.itens.get(int(cmd.get("itemId", -1)), {})
		if it.is_empty() or int(it.get("precoGold", 0)) <= 0:
			return [_erro("Este item não está à venda.")]
		preco = int(it["precoGold"])
		nome = String(it["nome"])
	var custo := preco * qtd
	if custo > int(estado.get("gold", 0)):
		return [_erro("Ouro insuficiente.")]
	estado["gold"] = int(estado.get("gold", 0)) - custo
	var r: Array = [{"type": "shop-bought", "gold": int(estado["gold"]), "bought": qtd, "name": nome}, msg_currency(estado)]
	if cmd.has("ballId"):
		var k := str(int(cmd["ballId"]))
		estado["bolas"][k] = int(estado["bolas"].get(k, 0)) + qtd
		r.append(msg_balls(estado))
	else:
		var k := str(int(cmd["itemId"]))
		estado["itens"][k] = int(estado["itens"].get(k, 0)) + qtd
		r.append(msg_inventario(estado))
	return r


func _vender(estado: Dictionary, cmd: Dictionary) -> Array:
	if not _npc_na_cidade(estado, "shop"):
		return [_erro("Não há loja nesta cidade.")]
	var pedidos: Array = cmd.get("items", [])
	var plano: Array = []
	var ganho := 0
	var bag: Dictionary = estado.get("itens", {})
	var somas := {}
	for x in pedidos:
		var k := str(int(x.get("itemId", -1)))
		var q := int(x.get("qty", 0))
		var preco := preco_venda(int(k))
		somas[k] = int(somas.get(k, 0)) + q
		if q <= 0 or preco <= 0 or int(somas[k]) > int(bag.get(k, 0)):
			return [_erro("Venda inválida: %s." % k)]
		plano.append([k, q])
		ganho += preco * q
	if plano.is_empty():
		return [_erro("Nada para vender.")]
	var vendidos := 0
	for pl in plano:
		bag[pl[0]] = int(bag[pl[0]]) - int(pl[1])
		if int(bag[pl[0]]) <= 0:
			bag.erase(pl[0])
		vendidos += int(pl[1])
	estado["gold"] = int(estado.get("gold", 0)) + ganho
	return [{"type": "shop-sold", "gold": int(estado["gold"]), "goldGained": ganho, "soldCount": vendidos},
		msg_currency(estado), msg_inventario(estado)]


func _vender_pokemon(estado: Dictionary, cmd: Dictionary) -> Array:
	if not _npc_na_cidade(estado, "shop"):
		return [_erro("Não há loja nesta cidade.")]
	var ids: Array = cmd.get("pokeIds", [])
	var alvos: Array = []
	var ganho := 0
	for id in ids:
		var pk := _poke(estado, String(id))
		if pk.is_empty() or alvos.has(pk):
			return [_erro("Pokémon inválido.")]
		if bool(pk.get("team", false)) or bool(pk.get("starter", false)):
			return [_erro("Só Pokémon da BOX podem ser vendidos.")]   # E
		alvos.append(pk)
		ganho += int(dados.especie(int(pk["speciesId"])).get("valorVenda", 0))   # F: PARAMETROS.venda_pokemon
	if alvos.is_empty():
		return [_erro("Nada para vender.")]
	var removidos: Array = []
	for pk in alvos:
		estado["pokes"].erase(pk)
		removidos.append(String(pk["id"]))
	estado["gold"] = int(estado.get("gold", 0)) + ganho
	return [{"type": "pokemon-sold", "gold": int(estado["gold"]), "goldGained": ganho, "sold": alvos.size()},
		msg_currency(estado), {"type": "pokes-removed", "ids": removidos}]


# ============================================================================== Nurse Joy

func _curar(estado: Dictionary) -> Array:
	## C: "She heals your whole team for free"; no cliente a cura é a mensagem WS joy-heal, sem custo nem recarga.
	if not _npc_na_cidade(estado, "nurse"):
		return [_erro("Não há Nurse Joy nesta cidade.")]
	var r: Array = []
	var curados := 0
	var total := 0
	for pk in _time(estado):
		var falta := max_hp(pk) - hp_atual(pk)
		if falta > 0:
			pk["hp"] = -1
			curados += 1
			total += falta
			r.append({"type": "poke-delta", "poke": poke_delta(pk)})
	r.push_front({"type": "joy-healed", "healed": curados, "hp": total})
	return r


# ============================================================================== depot

func _msg_depot_lista(d: Dictionary, chave_id: String) -> Array:
	var l: Array = []
	var ks := d.keys()
	ks.sort_custom(func(a, b): return int(a) < int(b))
	for k in ks:
		if int(d[k]) > 0:
			l.append({chave_id: int(k), "quantity": int(d[k])})
	return l


func _msg_depot(estado: Dictionary) -> Dictionary:
	var dep: Dictionary = estado.get("depot", {})
	return {"type": "depot", "items": _msg_depot_lista(dep.get("itens", {}), "itemId"),
		"balls": _msg_depot_lista(dep.get("bolas", {}), "ballId")}


func _pilhas(estado: Dictionary) -> int:
	var dep: Dictionary = estado["depot"]
	return dep["itens"].size() + dep["bolas"].size()


func _mover_depot(estado: Dictionary, cmd: Dictionary) -> Array:
	if not _npc_na_cidade(estado, "pokedepot"):
		return [_erro("Não há depot nesta cidade.")]
	estado["depot"] = estado.get("depot", {})
	estado["depot"]["itens"] = estado["depot"].get("itens", {})
	estado["depot"]["bolas"] = estado["depot"].get("bolas", {})
	if bool(cmd.get("all", false)):
		# C: {all: true} guarda tudo; vinculadas (Golden Idle Ball) ficam na BAG (E, regra do P04)
		var novas := 0
		for k in estado["itens"]:
			if not estado["depot"]["itens"].has(k):
				novas += 1
		for k in estado["bolas"]:
			if int(estado["bolas"][k]) > 0 and not bool(_bola(int(k)).get("bound", false)) and not estado["depot"]["bolas"].has(k):
				novas += 1
		if _pilhas(estado) + novas > int(p.capacidade_depot_pilhas):
			return [_erro("Depot cheio: nada foi guardado.")]
		for k in estado["itens"].keys():
			estado["depot"]["itens"][k] = int(estado["depot"]["itens"].get(k, 0)) + int(estado["itens"][k])
		estado["itens"].clear()
		for k in estado["bolas"].keys():
			if bool(_bola(int(k)).get("bound", false)) or int(estado["bolas"][k]) <= 0:
				continue
			estado["depot"]["bolas"][k] = int(estado["depot"]["bolas"].get(k, 0)) + int(estado["bolas"][k])
			estado["bolas"][k] = 0
		return [_msg_depot(estado), msg_inventario(estado), msg_balls(estado)]
	var guardar := String(cmd.get("dir", "")) in ["store", "in", "deposit"]
	var e_bola := cmd.has("ballId")
	var k := str(int(cmd.get("ballId" if e_bola else "itemId", -1)))
	var bag: Dictionary = estado["bolas" if e_bola else "itens"]
	var dep: Dictionary = estado["depot"]["bolas" if e_bola else "itens"]
	if e_bola and bool(_bola(int(k)).get("bound", false)):
		return [_erro("Este item vinculado permanece na BAG.")]
	var origem: Dictionary = bag if guardar else dep
	var q := int(origem.get(k, 0))
	if q <= 0:
		return [_erro("Não há unidades para transferir.")]
	if guardar and not dep.has(k) and _pilhas(estado) >= int(p.capacidade_depot_pilhas):
		return [_erro("Depot cheio.")]
	var destino: Dictionary = dep if guardar else bag
	destino[k] = int(destino.get(k, 0)) + q
	if e_bola and guardar:
		bag[k] = 0
	else:
		origem.erase(k)
	return [_msg_depot(estado), msg_balls(estado) if e_bola else msg_inventario(estado)]


func _mover_poke(estado: Dictionary, id: String, guardar: bool) -> Array:
	var pk := _poke(estado, id)
	if pk.is_empty():
		return [_erro("Pokémon não encontrado.")]
	if not _npc_na_cidade(estado, "pokedepot"):
		return [_erro("Não há depot nesta cidade.")]
	if guardar:
		if not bool(pk.get("team", false)):
			return [_erro("Este Pokémon não está no time.")]
		if bool(pk.get("starter", false)) and bool(p.starter_no_time):
			return [_erro("O Pokémon inicial permanece no time e não pode ser depositado.")]
		if _box(estado).size() >= int(p.capacidade_box):
			return [_erro("BOX cheia.")]
		pk["team"] = false
		var era_lider := bool(pk.get("leader", false))
		pk["leader"] = false
		var r: Array = []
		if era_lider:
			# E (P04): depositar o líder passa a liderança ao inicial (ou ao primeiro do time)
			var novo: Dictionary = {}
			for t in _time(estado):
				if bool(t.get("starter", false)):
					novo = t
			if novo.is_empty() and not _time(estado).is_empty():
				novo = _time(estado)[0]
			if not novo.is_empty():
				novo["leader"] = true
		_numerar_time(estado)
		for t in estado["pokes"]:
			if bool(t.get("team", false)) or t == pk:
				r.append({"type": "poke-delta", "poke": poke_delta(t)})
		return r
	if bool(pk.get("team", false)):
		return [_erro("Este Pokémon não está na BOX.")]
	if _time(estado).size() >= int(p.limite_time):
		return [_erro("Time cheio: máximo de %d Pokémon." % int(p.limite_time))]
	pk["team"] = true
	pk["slot"] = 99
	_numerar_time(estado)
	return [{"type": "poke-delta", "poke": poke_delta(pk)}]


# ============================================================================== mensagens de estado

static func msg_currency(estado: Dictionary) -> Dictionary:
	return {"type": "currency", "gold": int(estado.get("gold", 0))}


func msg_balls(estado: Dictionary) -> Dictionary:
	var counts := {}
	for k in estado.get("bolas", {}):
		counts[str(k)] = int(estado["bolas"][k])
	return {"type": "balls", "catalog": p.bolas_catalogo.duplicate(true), "counts": counts, "gold": int(estado.get("gold", 0)),
		"selected": int(estado.get("bola_selecionada", 1))}


static func msg_inventario(estado: Dictionary) -> Dictionary:
	var l: Array = []
	var ks: Array = estado.get("itens", {}).keys()
	ks.sort_custom(func(a, b): return int(a) < int(b))
	for k in ks:
		if int(estado["itens"][k]) > 0:
			l.append({"itemId": int(k), "quantity": int(estado["itens"][k])})
	return {"type": "inventory", "items": l}
