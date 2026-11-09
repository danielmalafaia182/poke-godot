extends RefCounted
## Configuração da simulação a partir do save do jogo (o que a cena de hunt extrai do EstadoJogo), no mesmo formato
## de sim/cenario.gd. Puro: recebe um Dictionary, não lê autoload nem user://.
##
## Entrada (`jogo`):
##   hunt: nome da espécie da hunt (EstadoJogo.especie_caca.nome) — o slug vem de dados/gerados/hunts.json
##   equipe: [{id, nome, xp, ivs{hp,atk,def,spAtk,spDef,speed}, quality, hp (−1 = cheio), shiny?}]   (ordem do time)
##   treinador_xp, inventario [{itemId, quantity}], bolas {id: qtd}, auto_catch, bola_auto_catch,
##   auto_potion, pocao_id (0 = "Automatic (best)"), limite_pocao (%)
## O que é de jogo e não foi observado no original fica marcado: VIP desligado (E: offline), entrada nova sempre
## (A: entrar pelo mapa é entrada nova → penalidade de XP nos primeiros abates).

const Fontes := preload("res://sim/fontes.gd")

const ESTADOS_COM_CADAVER := ["dados/testes/estado_rhydon_venusaur.json", "dados/testes/estado_rhydon_venusaur_1h.json"]


static func slug_da_hunt(dados: RefCounted, nome: String) -> String:
	## Hunt da espécie: a que tem esse nome em dados/gerados/hunts.json (área kanto primeiro).
	var achou := ""
	for s in dados.hunts:
		var h: Dictionary = dados.hunts[s]
		if String(h.get("nome", "")) == nome:
			if String(h.get("area", "")) == "kanto":
				return String(s)
			if achou == "":
				achou = String(s)
	return achou


static func disponivel(dados: RefCounted, nome: String) -> bool:
	## A simulação roda a hunt se há slug, mapa e hunt-config no snapshot.
	var s := slug_da_hunt(dados, nome)
	if s == "":
		return false
	var pasta := Fontes.pasta_snapshot()
	return FileAccess.file_exists(pasta + "/game/maps/%s.json" % s) and FileAccess.file_exists(pasta + "/api/hunt-config/%s.json" % s)


static func id_especie(dados: RefCounted, nome: String) -> int:
	for id in dados.especies:
		if String(dados.especies[id].get("nome", "")) == nome:
			return int(id)
	return -1


static func cadaveres_observados() -> Dictionary:
	## A: corpo de cada espécie visto nas gravações (o creatures.json não traz o id do cadáver).
	var r := {}
	for c in ESTADOS_COM_CADAVER:
		var caminho: String = Fontes.raiz_projeto() + "/" + String(c)
		if FileAccess.file_exists(caminho):
			var e = Fontes.ler_json(caminho)
			if e is Dictionary:
				for k in e.get("cadaveres", {}):
					r[k] = e["cadaveres"][k]
	return r


static func configurar(jogo: Dictionary, dados: RefCounted, semente: int, agora_ms: int) -> Dictionary:
	var slug := slug_da_hunt(dados, String(jogo["hunt"]))
	var hc: Dictionary = Fontes.ler_hunt_config(slug)
	var hunt: Dictionary = dados.hunts.get(slug, {})
	var equipe: Array = []
	for m in jogo.get("equipe", []):
		var sid := id_especie(dados, String(m["nome"]))
		if sid < 0:
			push_error("espécie do time sem dados na simulação: " + String(m["nome"]))
			continue
		var e := {"id": String(m.get("id", "")), "speciesId": sid, "xp": int(m["xp"]), "ivs": m["ivs"],
			"quality": float(m["quality"]), "shiny": bool(m.get("shiny", false)), "leader": equipe.is_empty(),
			"starter": false, "sellValue": 0}
		if int(m.get("hp", -1)) >= 0:
			e["hp"] = int(m["hp"])
		equipe.append(e)
	var counts := {}
	var catalogo: Array = []
	for id in jogo.get("bolas", {}):
		counts[str(int(id))] = int(jogo["bolas"][id])
		catalogo.append({"id": int(id), "name": String(jogo.get("nomes_bolas", {}).get(id, "Ball %d" % int(id)))})
	var parametros := {}
	if jogo.has("limite_pocao"):
		parametros["pocao_limiar"] = float(jogo["limite_pocao"]) / 100.0   # E: o limite é do jogador (Auto-Helper)
	return {
		"slug": slug,
		"semente": semente,
		"inicio_ms": agora_ms,
		"hunt_key": "%s:%d" % [slug, agora_ms],
		"nivel_selvagem": int(hunt.get("nivel", 1)),
		"inicio": hc.get("start", {"x": 0, "y": 0}),
		"spawns": hc.get("spawns", []),
		"entrada_nova": true,
		"vip": false,
		"auto_catch": bool(jogo.get("auto_catch", false)),
		"bola_auto_catch": int(jogo.get("bola_auto_catch", 0)),
		"auto_potion": bool(jogo.get("auto_potion", false)),
		"pocao_fixa": int(jogo.get("pocao_id", 0)),
		"equipe": equipe,
		"treinador": {"xp": int(jogo.get("treinador_xp", 0))},
		"inventario": jogo.get("inventario", []),
		"balls": {"catalog": catalogo, "counts": counts, "selected": int(jogo.get("bola_auto_catch", 0))},
		"cadaveres": cadaveres_observados(),
		"parametros": parametros,
	}
