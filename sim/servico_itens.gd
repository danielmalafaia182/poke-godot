extends RefCounted
## Fase 4, lote 3 (começo): itens de uso — Rare Candy e berries. Puro e determinístico (o "agora" vem no comando, em
## segundos unix). Mesmo contrato dos outros serviços: tratar(estado, cmd) → mensagens.
##
## Estado (o de ponte_cidade.estado_de: pokes[{id, speciesId, xp, team…}], itens {"<itemId>": qtd}) mais:
##   itens_uso: {candy: {"<pokeId>": nº de Rare Candies já usados}, berries: {"<pokeId>": [{itemId, efeito, pct, until}]}}
##
## Comandos (nomes do original, C: chunk 0gx72gz9qjk5j.js e textos 3vooh2axx98am.js):
##   use-candy {pokeId}            Rare Candy (90124) — C: "it goes up exactly 1 level right away. Each Pokémon takes at
##                                 most 10 Rare Candies. Pokémon in the depot, above level 100, or already at the limit
##                                 cannot receive it"; A (descrição do items.json): "exatamente a experiência que falta
##                                 para o próximo nível. Só em Pokémon do time".
##   use-berry {itemId, pokeId, agora}  C: "Pick the Pokémon that will eat this berry. It is consumed right away and the
##                                 effect lasts 30 minutes"; "already active ({{min}} min)"; "Identical berries do not
##                                 stack". Efeito e % saem da descrição do items.json (A).
##   berries-ativas {agora}        → {pokeId: [{efeito, pct, until}]} para a simulação (cfg.berries).
## Ciclo 6 (lote 3 descongelado; tabelas do cliente em dados/gerados/lote3.json, C):
##   tm-trade {tipo}               TM Researcher: 10× TM Disk Piece (AoE: 10× AoE TM Disk Piece) → 1 disco à escolha
##                                 (C: "trocando 10 peças por 1 disco").
##   tm-learn {pokeId, itemId}     canLearnTm (C): não Ditto; estágio final ou espécie isenta (TM_STAGE_EXEMPT); disco do
##                                 tipo do Pokémon ou AoE. Slots por classe: outro elemental substitui o elemental; o AoE
##                                 convive (C). O disco é consumido.
##   held-trade {oferta, semente}  Held Machine (C: HELD_MACHINE_OFFERS basic 20 tokens tiers 1–2, premium 50 tiers 2–3;
##                                 sorteia 1 held entre as famílias ativas × tiers, todos com a mesma chance).
##   held-equip {pokeId, itemId}   C: só no time; 1 held por slot (todas as famílias são do slot X); trocar DESTRÓI o
##                                 anterior.
##   para-sim                      → {helds {pokeId: itemId}, tms {pokeId: {elemental, aoe}}} (cfg da simulação).
## itens_uso ganha: held {pokeId: itemId}, tms {pokeId: {elemental: TIPO, aoe: bool}}.

const Regras := preload("res://sim/regras.gd")

const PARAMETROS := {
	"candy_id": 90124,                 # A: items.json "Rare Candy"
	"candy_max_por_pokemon": 10,       # C
	"candy_nivel_max": 100,            # C: "level 100 or below"
	"berry_duracao_s": 1800,           # C: "the effect lasts 30 minutes"
	# Nome do tipo na descrição (A, português) → tipo do jogo, comparado só pelas letras a–z ("Aço" → "ao", "Água" → "gua").
	# "Neutro" = golpes neutros dos bosses (C, talentos do Botânico: "Berry that protects from Neutral-type moves").
	"tipos_berry": {"ao": "STEEL", "drago": "DRAGON", "eltrico": "ELECTRIC", "fada": "FAIRY", "fantasma": "GHOST",
		"fogo": "FIRE", "gelo": "ICE", "inseto": "BUG", "lutador": "FIGHTING", "neutro": "NEUTRAL", "normal": "NORMAL",
		"noturno": "DARK", "pedra": "ROCK", "planta": "GRASS", "psquico": "PSYCHIC", "terra": "GROUND", "veneno": "POISON",
		"voador": "FLYING", "gua": "WATER"},
}

var p: Dictionary = PARAMETROS.duplicate(true)
var dados   # sim/dados_jogo.gd


func _init(dados_jogo, parametros: Dictionary = {}) -> void:
	dados = dados_jogo
	for k in parametros:
		p[k] = parametros[k]


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


static func _sem_acento(t: String) -> String:
	## Só as letras a–z, minúsculas: "Água" vira "gua".
	var r := ""
	for c in t.to_lower():
		if c >= "a" and c <= "z":
			r += c
	return r


func efeito_berry(item_id: int) -> Dictionary:
	## {efeito: tipo do golpe | "heal", pct} pela descrição do items.json (A); {} se não reconhecer.
	var it: Dictionary = dados.itens.get(item_id, {})
	if String(it.get("categoria", "")) != "berry":
		return {}
	var d := String(it.get("descricao", ""))
	var re := RegEx.new()
	re.compile("\\(\\+(\\d+)% de cura\\)")
	var m := re.search(d)
	if m != null:
		return {"efeito": "heal", "pct": int(m.get_string(1))}
	re.compile("tipo (\\S+) \\((\\d+)% de redu")
	m = re.search(d)
	if m == null:
		return {}
	var nome := _sem_acento(m.get_string(1))
	if not p.tipos_berry.has(nome):
		return {}
	return {"efeito": String(p.tipos_berry[nome]), "pct": int(m.get_string(2))}


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	if not estado.has("itens_uso"):
		estado["itens_uso"] = {}
	for k in ["candy", "berries", "held", "tms"]:
		if not estado["itens_uso"].has(k):
			estado["itens_uso"][k] = {}
	match String(cmd.get("type", "")):
		"use-candy":
			return _candy(estado, String(cmd.get("pokeId", "")))
		"use-berry":
			return _berry(estado, int(cmd.get("itemId", -1)), String(cmd.get("pokeId", "")), int(cmd.get("agora", 0)))
		"berries-ativas":
			return [{"type": "berries-ativas", "berries": berries_ativas(estado, int(cmd.get("agora", 0)))}]
		"tm-trade":
			return _tm_trade(estado, String(cmd.get("tipo", "")))
		"tm-learn":
			return _tm_learn(estado, String(cmd.get("pokeId", "")), int(cmd.get("itemId", -1)))
		"held-trade":
			return _held_trade(estado, String(cmd.get("oferta", "basic")), int(cmd.get("semente", 1)))
		"held-equip":
			return _held_equip(estado, String(cmd.get("pokeId", "")), int(cmd.get("itemId", -1)))
		"para-sim":
			return [{"type": "para-sim", "helds": (estado["itens_uso"]["held"] as Dictionary).duplicate(),
				"tms": (estado["itens_uso"]["tms"] as Dictionary).duplicate(true)}]
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func _poke(estado: Dictionary, id: String) -> Dictionary:
	for pk in estado.get("pokes", []):
		if String(pk.get("id", "")) == id:
			return pk
	return {}


func _msg_inventario(estado: Dictionary) -> Dictionary:
	var itens: Array = []
	for k in estado.get("itens", {}):
		if int(estado["itens"][k]) > 0:
			itens.append({"itemId": int(k), "quantity": int(estado["itens"][k])})
	return {"type": "inventory", "items": itens}


func _gastar(estado: Dictionary, item_id: int) -> bool:
	var k := str(item_id)
	if int(estado.get("itens", {}).get(k, 0)) <= 0:
		return false
	estado["itens"][k] = int(estado["itens"][k]) - 1
	if int(estado["itens"][k]) <= 0:
		estado["itens"].erase(k)
	return true


func _candy(estado: Dictionary, id: String) -> Array:
	var pk := _poke(estado, id)
	if pk.is_empty():
		return [_erro("Pokémon não encontrado.")]
	if not bool(pk.get("team", false)):
		return [_erro("Só em Pokémon do time.")]   # A/C
	var nivel := Regras.nivel_por_xp(int(pk["xp"]))
	if nivel > int(p.candy_nivel_max):
		return [_erro("Já passou do nível %d." % int(p.candy_nivel_max))]
	var usados := int(estado["itens_uso"]["candy"].get(id, 0))
	if usados >= int(p.candy_max_por_pokemon):
		return [_erro("Limite de %d Rare Candies atingido." % int(p.candy_max_por_pokemon))]
	if not _gastar(estado, int(p.candy_id)):
		return [_erro("Sem Rare Candy na mochila.")]
	var ganho := Regras.xp_total_para_nivel(nivel + 1) - int(pk["xp"])   # A: "exatamente a experiência que falta"
	pk["xp"] = int(pk["xp"]) + ganho
	estado["itens_uso"]["candy"][id] = usados + 1
	# E: formato da resposta (não gravado); o cliente mostra "🍬 {{name}} reached level {{level}}!" (C)
	return [{"type": "candy-used", "pokeId": id, "xpGained": ganho, "level": nivel + 1, "used": usados + 1,
		"max": int(p.candy_max_por_pokemon)}, _msg_inventario(estado)]


func _berry(estado: Dictionary, item_id: int, id: String, agora: int) -> Array:
	var ef := efeito_berry(item_id)
	if ef.is_empty():
		return [_erro("Item não é uma berry conhecida.")]
	var pk := _poke(estado, id)
	if pk.is_empty() or not bool(pk.get("team", false)):
		return [_erro("Escolha um Pokémon do time.")]   # C: "Used on 1 Pokémon in your team"
	var lista: Array = (estado["itens_uso"]["berries"].get(id, []) as Array).filter(func(b): return int(b["until"]) > agora * 1000)
	for b in lista:
		if int(b["itemId"]) == item_id:
			var resta := (int(b["until"]) - agora * 1000) / 60000
			return [_erro("Já ativa (%d min)." % resta)]   # C: "Identical berries do not stack"
	if not _gastar(estado, item_id):
		return [_erro("Sem essa berry na mochila.")]
	var ate := (agora + int(p.berry_duracao_s)) * 1000
	lista.append({"itemId": item_id, "efeito": String(ef["efeito"]), "pct": int(ef["pct"]), "until": ate})
	estado["itens_uso"]["berries"][id] = lista
	return [{"type": "berry-used", "pokeId": id, "itemId": item_id, "efeito": String(ef["efeito"]), "pct": int(ef["pct"]), "until": ate},
		_msg_inventario(estado)]


func berries_ativas(estado: Dictionary, agora: int) -> Dictionary:
	var r := {}
	for id in estado.get("itens_uso", {}).get("berries", {}):
		var l: Array = []
		for b in estado["itens_uso"]["berries"][id]:
			if int(b["until"]) > agora * 1000:
				l.append({"efeito": String(b["efeito"]), "pct": int(b["pct"]), "until": int(b["until"])})
		if not l.is_empty():
			r[String(id)] = l
	return r


# ------------------------------------------------------------------ TMs e held items (ciclo 6, C: dados/gerados/lote3.json)

func _l3() -> Dictionary:
	return dados.lote3


func disco_do_tipo(tipo: String) -> int:
	for k in _l3().get("tm_tipo_item", {}):
		if String(_l3()["tm_tipo_item"][k]) == tipo.to_upper():
			return int(k)
	return -1


func pode_aprender(pk: Dictionary, item_id: int) -> String:
	## "" = pode; senão o motivo (canLearnTm, C).
	var tipo := String(_l3().get("tm_tipo_item", {}).get(str(item_id), ""))
	if tipo == "":
		return "Isso não é um TM Disk."
	var sid := int(pk.get("speciesId", 0))
	var esp: Dictionary = dados.especie(sid)
	if String(esp.get("nome", "")) == "Ditto":
		return "Ditto não pode aprender TMs."   # C: tmBlockedLearner
	var final_: bool = esp.get("evolui") == null   # C: finalStage (sem evolução seguinte)
	if not final_ and not float(sid) in (_l3().get("tm_estagio_isento", []) as Array).map(func(x): return float(x)):
		return "Só Pokémon de estágio final aprendem TMs."
	if tipo != "AOE" and not tipo in Regras.tipos_de(esp):
		return "O disco precisa ser do tipo do Pokémon."
	return ""


func _tm_trade(estado: Dictionary, tipo: String) -> Array:
	var item := disco_do_tipo(tipo)
	if item < 0:
		return [_erro("Disco desconhecido: " + tipo)]
	var peca := int(_l3().get("tm_peca_aoe_id" if tipo.to_upper() == "AOE" else "tm_peca_id", 0))
	var n := int(_l3().get("tm_pecas_por_disco", 10))
	if int(estado.get("itens", {}).get(str(peca), 0)) < n:
		return [_erro("Você precisa de %d× %s" % [n, String(dados.itens.get(peca, {}).get("nome", "peça"))])]
	estado["itens"][str(peca)] = int(estado["itens"][str(peca)]) - n
	if int(estado["itens"][str(peca)]) <= 0:
		estado["itens"].erase(str(peca))
	estado["itens"][str(item)] = int(estado["itens"].get(str(item), 0)) + 1
	return [{"type": "tm-traded", "itemId": item, "name": String(dados.itens.get(item, {}).get("nome", "")), "pieces": n}, _msg_inventario(estado)]


func _tm_learn(estado: Dictionary, id: String, item_id: int) -> Array:
	var pk := _poke(estado, id)
	if pk.is_empty():
		return [_erro("Pokémon não encontrado.")]
	var motivo := pode_aprender(pk, item_id)
	if motivo != "":
		return [_erro(motivo)]
	if not _gastar(estado, item_id):
		return [_erro("Sem esse disco na mochila.")]
	var tipo := String(_l3()["tm_tipo_item"][str(item_id)])
	var t: Dictionary = estado["itens_uso"]["tms"].get(id, {})
	var antes := String(t.get("elemental", ""))
	if tipo == "AOE":
		t["aoe"] = true
	else:
		t["elemental"] = tipo   # C: outro elemental substitui o atual; o AoE fica
	estado["itens_uso"]["tms"][id] = t
	return [{"type": "tm-learned", "pokeId": id, "itemId": item_id, "tm": tipo, "replaced": antes if antes != tipo and tipo != "AOE" else ""}, _msg_inventario(estado)]


func pool_maquina(oferta: String) -> Array:
	var o: Dictionary = _l3().get("held_maquina", {}).get(oferta, {})
	var ativos: Array = _l3().get("held_ativos", [])
	var r: Array = []
	for k in _l3().get("helds", {}):
		var h: Dictionary = _l3()["helds"][k]
		if String(h["family"]) in ativos and float(h["tier"]) in (o.get("tiers", []) as Array).map(func(x): return float(x)):
			r.append(int(k))
	r.sort()
	return r


func _held_trade(estado: Dictionary, oferta: String, semente: int) -> Array:
	var o: Dictionary = _l3().get("held_maquina", {}).get(oferta, {})
	if o.is_empty():
		return [_erro("Oferta desconhecida.")]
	var tok := str(int(_l3().get("held_token_id", 13115)))
	var custo := int(o["cost"])
	if int(estado.get("itens", {}).get(tok, 0)) < custo:
		return [_erro("Você precisa de %d× Devoted Token" % custo)]
	var pool := pool_maquina(oferta)
	var rng = preload("res://sim/rng.gd").new(semente)
	var item: int = pool[int(rng.randf() * pool.size()) % pool.size()]   # C: todos com a mesma chance
	estado["itens"][tok] = int(estado["itens"][tok]) - custo
	if int(estado["itens"][tok]) <= 0:
		estado["itens"].erase(tok)
	estado["itens"][str(item)] = int(estado["itens"].get(str(item), 0)) + 1
	var h: Dictionary = _l3()["helds"][str(item)]
	return [{"type": "held-traded", "itemId": item, "name": String(dados.itens.get(item, {}).get("nome", "")), "tier": int(h["tier"]),
		"family": String(h["family"]), "cost": custo}, _msg_inventario(estado)]


func _held_equip(estado: Dictionary, id: String, item_id: int) -> Array:
	var pk := _poke(estado, id)
	if pk.is_empty():
		return [_erro("Pokémon não encontrado.")]
	if not bool(pk.get("team", false)):
		return [_erro("Só dá pra equipar em um Pokémon do seu time.")]   # C: helds.how1
	if not _l3().get("helds", {}).has(str(item_id)):
		return [_erro("Isso não é um held item.")]
	if not _gastar(estado, item_id):
		return [_erro("Sem esse held na mochila.")]
	var antes := int(estado["itens_uso"]["held"].get(id, 0))
	estado["itens_uso"]["held"][id] = item_id   # C: trocar DESTRÓI o anterior (não volta para a mochila)
	return [{"type": "held-equipped", "pokeId": id, "itemId": item_id, "destroyed": antes}, _msg_inventario(estado)]
