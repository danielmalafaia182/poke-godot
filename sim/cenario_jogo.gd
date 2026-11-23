extends RefCounted
## Configuração da simulação a partir do save do jogo (o que a cena de hunt extrai do EstadoJogo), no mesmo formato
## de sim/cenario.gd. Puro: recebe um Dictionary, não lê autoload nem user://.
##
## Entrada (`jogo`):
##   hunt: nome da espécie da hunt (EstadoJogo.especie_caca.nome) — o slug vem de dados/gerados/hunts.json
##   equipe: [{id, nome, xp, ivs{hp,atk,def,spAtk,spDef,speed}, quality, hp (−1 = cheio), shiny?}]   (ordem do time)
##   treinador_xp, inventario [{itemId, quantity}], bolas {id: qtd}, auto_catch, bola_auto_catch,
##   auto_potion, pocao_id (0 = "Automatic (best)"), limite_pocao (%), lider (índice do líder no time),
##   penalizar (bool: lock de entrada; quem decide é a cena, pela regra B-relatada em estado_jogo.gd), ms_desde_saida
##   (o minuto do lock conta da saída do lugar anterior, F), medidor_captura (EstadoJogo.medidor_captura)
## O que é de jogo e não foi observado no original fica marcado: vip (bool, E: opção do jogador, padrão desligado); sem bônus de captura de
## guild nem boosts (E: offline).

const Fontes := preload("res://sim/fontes.gd")


static func penalizar_entrada(sessao_expirada: bool, ultima_hunt: String, slug: String) -> bool:
	## Lock de entrada (boost shinylock): hunt diferente da última penaliza e a mesma hunt de novo (pela cidade) não
	## (A, gravação T1); qualquer hunt depois que a sessão expirou penaliza (B-relatado, não gravado).
	return sessao_expirada or ultima_hunt != slug


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


static func disponivel(dados: RefCounted, nome: String, slug: String = "") -> bool:
	## A simulação roda a hunt se há slug, mapa e hunt-config no snapshot.
	var s := slug if slug != "" else slug_da_hunt(dados, nome)
	if s == "":
		return false
	var pasta := Fontes.pasta_snapshot()
	return Fontes.existe(pasta + "/game/maps/%s.json" % s) and Fontes.existe(pasta + "/api/hunt-config/%s.json" % s)


static func id_especie(dados: RefCounted, nome: String) -> int:
	for id in dados.especies:
		if String(dados.especies[id].get("nome", "")) == nome:
			return int(id)
	return -1


static func cadaveres_observados(shiny: bool = false) -> Dictionary:
	## A: cadáver de cada espécie visto nas gravações (dados/corpos_por_especie.json, mantido por
	## ferramentas/gravador/atualizar_corpos.py). O cliente original não tem essa tabela: o servidor manda o id.
	var d = Fontes.ler_json(Fontes.pasta_dados() + "/corpos_por_especie.json")
	var r := {}
	if d is Dictionary:
		var g: Dictionary = d.get("shiny" if shiny else "normal", {})
		for k in g:
			r[k] = int(g[k]["corpo"])
	if shiny:
		# C (SHINY_BY_DEX): o cliente tem o cadáver shiny de parte das espécies; vale onde a gravação não mostrou (A primeiro)
		var t = Fontes.ler_json(Fontes.pasta_dados() + "/gerados/shiny.json") if FileAccess.file_exists(Fontes.pasta_dados() + "/gerados/shiny.json") else null
		if t is Dictionary:
			for k in t:
				if t[k].get("cadaver") != null and not r.has(k):
					r[k] = int(t[k]["cadaver"])
	return r


static func configurar(jogo: Dictionary, dados: RefCounted, semente: int, agora_ms: int) -> Dictionary:
	var slug := String(jogo.get("slug", "")) if String(jogo.get("slug", "")) != "" else slug_da_hunt(dados, String(jogo["hunt"]))
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
		"area": String(hunt.get("area", "")),
		"inicio": hc.get("start", {"x": 0, "y": 0}),
		"spawns": hc.get("spawns", []),
		"entrada_nova": bool(jogo.get("penalizar", true)),
		"ms_desde_saida": int(jogo.get("ms_desde_saida", 0)),
		"medidor_captura": (jogo.get("medidor_captura", {}) as Dictionary).duplicate(true),
		"garantia_pedras": (jogo.get("garantia_pedras", {}) as Dictionary).duplicate(true),
		"bonus_captura": 0.0,
		"helds": (jogo.get("helds", {}) as Dictionary).duplicate(),
		"mentor": (jogo.get("mentor", {}) as Dictionary).duplicate(),       # ciclo 6: profissões (sim/servico_profissoes.gd para_sim)
		"profissao": (jogo.get("profissao", {}) as Dictionary).duplicate(),
		"bonus_captura_prof": float(jogo.get("bonus_captura_prof", 0.0)),
		"estrelas": (jogo.get("estrelas", []) as Array).duplicate(true),
		"ditto": (jogo.get("ditto", {}) as Dictionary).duplicate(),   # ciclo 8: {pokeId: espécie copiada}   # ciclo 7: Golden Stars ativas [{speciesId, bonus, pct}]        # ciclo 6 (lote 3): {pokeId: itemId do held}
		"tms": (jogo.get("tms", {}) as Dictionary).duplicate(true),         # ciclo 6: {pokeId: {elemental, aoe}}
		"vip": bool(jogo.get("vip", false)),   # E: opção do jogador (padrão desligado); ligada, +50% da XP base (A)
		"ativo_inicial": int(jogo.get("lider", 0)),
		"auto_catch": bool(jogo.get("auto_catch", false)),
		"bola_auto_catch": int(jogo.get("bola_auto_catch", 0)),
		"auto_catch_nomes": String(jogo.get("auto_catch_nomes", "")),   # C: filtro de nomes do Auto-Helper
		"auto_catch_shiny": bool(jogo.get("auto_catch_shiny", false)),   # C: Auto-Catch Shiny (bola própria)
		"bola_auto_catch_shiny": int(jogo.get("bola_auto_catch_shiny", 0)),
		"auto_potion": bool(jogo.get("auto_potion", false)),
		"pocao_fixa": int(jogo.get("pocao_id", 0)),
		"equipe": equipe,
		"treinador": {"xp": int(jogo.get("treinador_xp", 0))},
		"inventario": jogo.get("inventario", []),
		"balls": {"catalog": catalogo, "counts": counts, "selected": int(jogo.get("bola_auto_catch", 0))},
		"cadaveres": cadaveres_observados(),
		"cadaveres_shiny": cadaveres_observados(true),
		"parametros": parametros,
	}
