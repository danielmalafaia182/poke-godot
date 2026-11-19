extends RefCounted
## Bosses (ciclo 3). Puro e determinístico ("agora" em segundos unix; semente no comando). tratar(estado, cmd) → mensagens.
##
## Com fonte: os 87 bosses (A, snapshot bossCatalog.json: nome, categoria, nível, nomes dos drops); do cliente (C):
## requisito de nível do treinador, entrada paga com token, "se o time cair, o token daquela luta é perdido", Auto Boss
## (lutas em sequência, só fora de hunt, para na derrota ou quando acabam os tokens), Altar ("sacrifique um Shiny Card…
## para enfrentar um shiny lendário. A captura é muito rara") e o Shiny Card que o shiny selvagem pode dropar.
## Desenhado (classe 3, balanceamento.json "bosses", ferramentas/balanceamento/gerar_bosses.py): espécie, HP (× hp_mult
## da categoria), stats, custo da entrada, chances e quantidades dos drops, conteúdo dos baús, chance do altar.
## A luta é a mesma dos ginásios (sim/servico_ginasios.gd `lutar`: time do jogador contra um Pokémon só, com HP de boss).
##
## Estado: bosses: {itens: {"<nome do token/drop>": qtd}, recarga: {"<key>": ate_s}, historico: [..] (últimas 30)}
##         itens (BAG, ids do servidor como string) e gold — Rare Candy, Shiny Stone e pedras dos baús vão para a BAG.
## Comandos: bosses-get {agora, nivel}, boss-desafiar {key, agora, nivel, time, semente},
##           auto-boss {key, lutas, agora, nivel, time, semente}, altar-desafiar {itemId, agora, nivel, time, semente}

const Rng := preload("res://sim/rng.gd")
const Balanceamento := preload("res://sim/balanceamento.gd")
const Ginasios := preload("res://sim/servico_ginasios.gd")

const PARAMETROS := {
	"lista": [], "iv_boss": 25, "quality_boss": 1.3, "cadencia_boss_ms": 2000, "fator_dano_boss": 1.2, "baus": {},
	"altar_chance_captura": 0.03, "altar_especies": ["Raikou", "Entei", "Suicune"], "altar_nivel": 500,
	"auto_max_lutas": 50, "historico_max": 30,
}
var p: Dictionary = PARAMETROS.duplicate(true)
var dados
var gin
var _id_por_nome := {}


func _init(dados_jogo, parametros: Dictionary = {}) -> void:
	dados = dados_jogo
	Balanceamento.aplicar(p, "bosses")
	for k in parametros:
		p[k] = parametros[k]
	gin = Ginasios.new(dados_jogo)
	if dados != null:
		for id in dados.itens:
			_id_por_nome[String(dados.itens[id].get("nome", "")).to_lower()] = int(id)


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func boss(key: String) -> Dictionary:
	for b in p.lista:
		if String(b["key"]) == key:
			return b
	return {}


func _estado(estado: Dictionary) -> Dictionary:
	if not estado.has("bosses"):
		estado["bosses"] = {}
	var e: Dictionary = estado["bosses"]
	for k in ["itens", "recarga"]:
		if not e.has(k):
			e[k] = {}
	if not e.has("historico"):
		e["historico"] = []
	if not estado.has("itens"):
		estado["itens"] = {}
	return e


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	var e := _estado(estado)
	var agora := int(cmd.get("agora", 0))
	match String(cmd.get("type", "")):
		"bosses-get":
			return [msg_bosses(estado, agora, int(cmd.get("nivel", estado.get("nivel", 1))))]
		"boss-desafiar":
			return _desafiar(estado, cmd, agora)
		"auto-boss":
			return _auto(estado, cmd, agora)
		"altar-desafiar":
			return _altar(estado, cmd, agora)
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func msg_bosses(estado: Dictionary, agora: int, nivel: int) -> Dictionary:
	var e := _estado(estado)
	var l: Array = []
	for b in p.lista:
		var ent = b.get("entrada")
		var tem := int(e["itens"].get(String(ent[0]), 0)) if ent is Array else 0
		l.append({"key": String(b["key"]), "nome": String(b["nome"]), "categoria": String(b["categoria"]), "nivel": int(b["nivel"]),
			"speciesId": int(b["speciesId"]), "liberado": nivel >= int(b["nivel"]), "entrada": ent, "tem": tem,
			"recargaS": maxi(0, int(e["recarga"].get(String(b["key"]), 0)) - agora), "drops": b["drops"]})
	var cards: Array = []
	for k in estado["itens"]:
		var it: Dictionary = dados.itens.get(int(k), {}) if dados != null else {}
		if String(it.get("categoria", "")) == "card" and String(it.get("nome", "")).begins_with("Shiny ") and int(estado["itens"][k]) > 0:
			cards.append({"itemId": int(k), "nome": String(it["nome"]), "qtd": int(estado["itens"][k])})
	return {"type": "bosses", "bosses": l, "itens": e["itens"].duplicate(), "historico": e["historico"], "cards": cards}


func _pode(estado: Dictionary, b: Dictionary, agora: int, nivel: int) -> String:
	var e: Dictionary = estado["bosses"]
	if nivel < int(b["nivel"]):
		return "Requer nível %d." % int(b["nivel"])
	if int(e["recarga"].get(String(b["key"]), 0)) > agora:
		return "Aguarde %d s." % (int(e["recarga"][String(b["key"])]) - agora)
	var ent = b.get("entrada")
	if ent is Array and int(e["itens"].get(String(ent[0]), 0)) < int(ent[1]):
		return "Você não tem %s para pagar a entrada." % String(ent[0])
	return ""


func _lutar(b: Dictionary, time: Array, semente: int, shiny_nivel: int = -1) -> Dictionary:
	var g := {"time": [{"speciesId": int(b["speciesId"]), "nivel": shiny_nivel if shiny_nivel > 0 else int(b["nivel"])}],
		"hp_mult": int(b.get("hp_mult", 8)), "iv": int(p.iv_boss), "quality": float(p.quality_boss),
		"cadencia_ms": int(p.cadencia_boss_ms), "fator_dano": float(p.fator_dano_boss)}
	return gin.lutar(time, g, semente)


func _entregar(estado: Dictionary, nome: String, qtd: int, rng, saida: Array) -> void:
	## Rare Candy e Shiny Stone (existem no catálogo, A) vão para a BAG; baús abrem na hora (classe 3); o resto fica no
	## inventário de bosses (tokens, Heart Scale, Mystery Shard…: sem item no catálogo do snapshot).
	var bau: Dictionary = p.baus.get(nome, {})
	if not bau.is_empty():
		for _i in qtd:
			var o: Array = bau.get("ouro", [0, 0])
			var ouro := int(o[0]) + int(rng.randf() * (int(o[1]) - int(o[0]) + 1))
			estado["gold"] = int(estado.get("gold", 0)) + ouro
			saida.append({"nome": "Ouro", "qtd": ouro, "de": nome})
			var pedras: Array = []
			for id in dados.itens:
				if String(dados.itens[id].get("categoria", "")) == "stone":
					pedras.append(int(id))
			pedras.sort()
			for _j in int(bau.get("pedras", 0)):
				var pid: int = pedras[int(rng.randf() * pedras.size())]
				estado["itens"][str(pid)] = int(estado["itens"].get(str(pid), 0)) + 1
				saida.append({"nome": String(dados.itens[pid]["nome"]), "qtd": 1, "itemId": pid, "de": nome})
			if int(bau.get("rare_candy", 0)) > 0:
				_entregar(estado, "Rare Candy", int(bau["rare_candy"]), rng, saida)
		return
	var iid := int(_id_por_nome.get(nome.to_lower(), -1))
	if iid >= 0:
		estado["itens"][str(iid)] = int(estado["itens"].get(str(iid), 0)) + qtd
		saida.append({"nome": nome, "qtd": qtd, "itemId": iid})
	else:
		estado["bosses"]["itens"][nome] = int(estado["bosses"]["itens"].get(nome, 0)) + qtd
		saida.append({"nome": nome, "qtd": qtd})


func _uma(estado: Dictionary, b: Dictionary, time: Array, agora: int, semente: int, modo: String) -> Dictionary:
	var e: Dictionary = estado["bosses"]
	var ent = b.get("entrada")
	if ent is Array:
		e["itens"][String(ent[0])] = int(e["itens"].get(String(ent[0]), 0)) - int(ent[1])   # C: paga antes; perde se cair
	var r := _lutar(b, time, semente)
	var rng = Rng.new(semente * 31 + 7)
	var drops: Array = []
	if bool(r["venceu"]):
		for d in b["drops"]:
			if rng.randf() < float(d["chance"]):
				_entregar(estado, String(d["nome"]), int(d["min"]) + int(rng.randf() * (int(d["max"]) - int(d["min"]) + 1)), rng, drops)
	e["recarga"][String(b["key"])] = agora + int(b.get("recarga_s", 60))
	var h := {"key": String(b["key"]), "nome": String(b["nome"]), "venceu": bool(r["venceu"]), "ms": int(r["duracaoMs"]), "drops": drops,
		"modo": modo, "at": agora, "tokenPerdido": ent is Array and not bool(r["venceu"])}
	e["historico"].push_front(h)
	if (e["historico"] as Array).size() > int(p.historico_max):
		(e["historico"] as Array).resize(int(p.historico_max))
	r["drops"] = drops
	r["type"] = "boss-result"
	r["key"] = String(b["key"])
	return r


func _desafiar(estado: Dictionary, cmd: Dictionary, agora: int) -> Array:
	var b := boss(String(cmd.get("key", "")))
	if b.is_empty():
		return [_erro("Boss inválido.")]
	var motivo := _pode(estado, b, agora, int(cmd.get("nivel", estado.get("nivel", 1))))
	if motivo != "":
		return [_erro(motivo)]
	var time: Array = cmd.get("time", [])
	if time.is_empty():
		return [_erro("Time vazio.")]
	return [_uma(estado, b, time, agora, int(cmd.get("semente", agora)), "manual")]


func _auto(estado: Dictionary, cmd: Dictionary, agora: int) -> Array:
	## C: "A luta se renova sozinha até acabar a fila ou os tokens"; "Se o time cair, o token daquela luta é perdido e o
	## Auto Boss para". Fora de hunt (quem chama garante). A recarga entre lutas conta no tempo (as lutas são em sequência).
	var b := boss(String(cmd.get("key", "")))
	if b.is_empty():
		return [_erro("Boss inválido.")]
	var n := clampi(int(cmd.get("lutas", 1)), 1, int(p.auto_max_lutas))
	var t := agora
	var lutas: Array = []
	var fim := "concluido"
	var semente := int(cmd.get("semente", agora))
	for i in n:
		var motivo := _pode(estado, b, t, int(cmd.get("nivel", estado.get("nivel", 1))))
		if motivo != "":
			if t > agora and int(estado["bosses"]["recarga"].get(String(b["key"]), 0)) > t:
				t = int(estado["bosses"]["recarga"][String(b["key"])])
				motivo = _pode(estado, b, t, int(cmd.get("nivel", estado.get("nivel", 1))))
			if motivo != "":
				fim = "sem_token" if motivo.begins_with("Você não tem") else "erro"
				break
		var r := _uma(estado, b, cmd.get("time", []), t, semente + i * 7919, "auto")
		t += int(r["duracaoMs"]) / 1000
		lutas.append({"venceu": r["venceu"], "ms": r["duracaoMs"], "drops": r["drops"]})
		if not bool(r["venceu"]):
			fim = "derrota"
			break
	var vit := 0
	for l in lutas:
		vit += 1 if bool(l["venceu"]) else 0
	return [{"type": "auto-boss-result", "key": String(b["key"]), "lutas": lutas, "vitorias": vit, "fim": fim, "ate": t}, msg_bosses(estado, t, int(cmd.get("nivel", 1)))]


func _altar(estado: Dictionary, cmd: Dictionary, agora: int) -> Array:
	var iid := int(cmd.get("itemId", -1))
	var it: Dictionary = dados.itens.get(iid, {})
	if String(it.get("categoria", "")) != "card" or int(estado["itens"].get(str(iid), 0)) <= 0:
		return [_erro("Escolha um Shiny Card que você tem.")]
	estado["itens"][str(iid)] = int(estado["itens"][str(iid)]) - 1   # C: o card é sacrificado (consumido mesmo se perder)
	var semente := int(cmd.get("semente", agora))
	var rng = Rng.new(semente * 13 + 5)
	var nomes: Array = p.altar_especies
	var nome := String(nomes[int(rng.randf() * nomes.size())])
	var sid := -1
	for id in dados.especies:
		if String(dados.especies[id]["nome"]) == nome:
			sid = int(id)
	var b := {"speciesId": sid, "nivel": int(p.altar_nivel), "hp_mult": 12}
	var r := _lutar(b, cmd.get("time", []), semente)
	r["type"] = "altar-result"
	r["especie"] = nome
	r["speciesId"] = sid
	r["capturado"] = bool(r["venceu"]) and rng.randf() < float(p.altar_chance_captura)
	return [r]


func card_do_shiny(nome_especie: String) -> int:
	## Id do "Shiny <Espécie> Card" do catálogo (A: 52 cards), ou -1.
	return int(_id_por_nome.get(("shiny %s card" % nome_especie).to_lower(), -1))
