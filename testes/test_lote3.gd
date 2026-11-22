extends SceneTree
## Lote 3 descongelado (ciclo 6): TMs e held items pelas regras do cliente (C; dados/gerados/lote3.json).
## Serviço (sim/servico_itens.gd): TM Researcher (10 peças → 1 disco), canLearnTm, slots por classe, Held Machine
## (custo e tiers da oferta), equipar só no time e trocar destrói o anterior.
## Simulação: X-Experience vira a parcela `held` (floor da base), X-Attack aumenta o dano, X-Vitality o HP, X-Block reduz
## o dano recebido, TM elemental acerta ≥ 2 selvagens com o golpe de 300, AoE TM espirra o golpe normal em vários;
## sem held nem TM a saída é idêntica à de antes.

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const Itens := preload("res://sim/servico_itens.gd")
const JsonCanonico := preload("res://sim/json_canonico.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _id(dados, nome: String) -> int:
	for k in dados.especies:
		if String(dados.especies[k]["nome"]) == nome:
			return int(k)
	return -1


func rodar(dados, mapa, extra: Dictionary, minutos: float = 3.0) -> Dictionary:
	var jogo := {"slug": "rhydon", "hunt": "rhydon", "equipe": [{"id": "v", "nome": "Venusaur", "xp": Regras.xp_total_para_nivel(140),
		"ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1}],
		"auto_potion": true, "penalizar": false, "inventario": [{"itemId": 203, "quantity": 2000}]}
	for k in extra:
		jogo[k] = extra[k]
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 7, 0), dados, mapa)
	sim.iniciar()
	var r := {"msgs": [], "held": [], "dano_dado": 0, "golpes": 0, "dano_rec": 0, "golpes_rec": 0, "tm_hits": 0, "tm_disparos": 0, "splash": 0, "abates": 0, "rec": []}
	for t in int(minutos * 300):
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			r["msgs"].append(m)
			match String(m.get("type", "")):
				"field-kill":
					r["abates"] += 1
					r["held"].append([int(m["xpParts"]["base"]), int(m["xpParts"].get("held", -1)), int(m["pokeXp"]["parts"].get("held", -1))])
				"field":
					var por_campo := {}
					for h in m.get("hits", []):
						if int(h["slot"]) < 0:
							r["dano_rec"] += int(h["amount"])
							r["rec"].append(int(h["amount"]))
							r["golpes_rec"] += 1
						elif String(h["move"]) == "Petal Bloom":
							r["tm_hits"] += 1
						else:
							r["dano_dado"] += int(h["amount"])
							r["golpes"] += 1
							por_campo[String(h["move"])] = int(por_campo.get(String(h["move"]), 0)) + 1
					for k in por_campo:
						if int(por_campo[k]) >= 2:
							r["splash"] += 1
	r["max_hp"] = int(sim.equipe[0]["max_hp"])
	return r


func _init() -> void:
	var dados = DadosJogo.carregar()
	var l3: Dictionary = dados.lote3
	checar(l3.get("helds", {}).size() == 64 and l3.get("tm_tipo_item", {}).size() == 19 and int(l3.get("tm_pecas_por_disco", 0)) == 10,
		"lote3.json do cliente: 64 helds, 19 discos, 10 peças por disco")
	var s = Itens.new(dados)
	var ven := _id(dados, "Venusaur")
	var bul := _id(dados, "Bulbasaur")
	var est := {"pokes": [{"id": "v", "speciesId": ven, "xp": 0, "team": true}, {"id": "b", "speciesId": bul, "xp": 0, "team": true},
		{"id": "x", "speciesId": ven, "xp": 0, "team": false}], "itens": {"59194": 25, "40530": 9, "13115": 70}}
	checar(String(s.tratar(est, {"type": "tm-trade", "tipo": "AOE"})[0]["type"]) == "error", "TM Researcher: 9 peças AoE não bastam (10)")
	var r1: Array = s.tratar(est, {"type": "tm-trade", "tipo": "GRASS"})
	checar(String(r1[0]["type"]) == "tm-traded" and int(est["itens"]["59194"]) == 15 and int(est["itens"]["59203"]) == 1, "10× TM Disk Piece → 1 Grass-Type TM Disk")
	s.tratar(est, {"type": "tm-trade", "tipo": "FIRE"})
	checar(String(s.tratar(est, {"type": "tm-learn", "pokeId": "v", "itemId": 59201})[0]["type"]) == "error", "Venusaur não aprende o disco de Fogo (tipo)")
	checar(String(s.tratar(est, {"type": "tm-learn", "pokeId": "b", "itemId": 59203})[0]["type"]) == "error", "Bulbasaur não aprende (não é estágio final)")
	checar(String(s.tratar(est, {"type": "tm-learn", "pokeId": "v", "itemId": 59203})[0]["type"]) == "tm-learned" and String(est["itens_uso"]["tms"]["v"]["elemental"]) == "GRASS",
		"Venusaur aprende o Grass-Type TM Disk")
	est["itens"]["40575"] = 1
	s.tratar(est, {"type": "tm-learn", "pokeId": "v", "itemId": 40575})
	checar(bool(est["itens_uso"]["tms"]["v"].get("aoe", false)) and String(est["itens_uso"]["tms"]["v"]["elemental"]) == "GRASS", "AoE TM convive com o elemental (slots por classe)")
	est["itens"]["59207"] = 1
	var r2: Array = s.tratar(est, {"type": "tm-learn", "pokeId": "v", "itemId": 59207})
	checar(String(est["itens_uso"]["tms"]["v"]["elemental"]) == "POISON" and String(r2[0]["replaced"]) == "GRASS" and bool(est["itens_uso"]["tms"]["v"]["aoe"]),
		"outro elemental (Veneno) substitui o de Planta; o AoE fica")
	var pool_b: Array = s.pool_maquina("basic")
	var tiers := {}
	for i in pool_b:
		tiers[int(l3["helds"][str(i)]["tier"])] = true
	checar(pool_b.size() == 16 and tiers.keys().size() == 2 and tiers.has(1) and tiers.has(2), "Held Machine básica: 8 famílias × tiers 1–2", str(pool_b.size()))
	var r3: Array = s.tratar(est, {"type": "held-trade", "oferta": "premium", "semente": 3})
	checar(String(r3[0]["type"]) == "held-traded" and int(est["itens"]["13115"]) == 20 and int(r3[0]["tier"]) in [2, 3], "premium: 50 Devoted Tokens, held de tier 2–3", str(r3[0]))
	checar(String(s.tratar(est, {"type": "held-trade", "oferta": "premium", "semente": 4})[0]["type"]) == "error", "sem tokens, a máquina recusa")
	var item1 := int(r3[0]["itemId"])
	checar(String(s.tratar(est, {"type": "held-equip", "pokeId": "x", "itemId": item1})[0]["type"]) == "error", "held só em Pokémon do time")
	s.tratar(est, {"type": "held-equip", "pokeId": "v", "itemId": item1})
	est["itens"]["13136"] = 1
	var r4: Array = s.tratar(est, {"type": "held-equip", "pokeId": "v", "itemId": 13136})
	checar(int(est["itens_uso"]["held"]["v"]) == 13136 and int(r4[0]["destroyed"]) == item1 and not est["itens"].has(str(item1)), "trocar o held destrói o anterior (não volta à mochila)")

	var mapa = MapaHunt.carregar("rhydon", Fontes.ler_mapa("rhydon"), Fontes.ler_colisao())
	var base := rodar(dados, mapa, {})
	var vazio := rodar(dados, mapa, {"helds": {}, "tms": {}})
	checar(JsonCanonico.texto(base["msgs"]) == JsonCanonico.texto(vazio["msgs"]), "sem held nem TM: saída idêntica")
	var xp := rodar(dados, mapa, {"helds": {"v": 13269}})   # X-Experience
	var vxp := float(l3["helds"]["13269"]["value"]) if String(l3["helds"].get("13269", {}).get("family", "")) == "EXPERIENCE" else -1.0
	var ok_xp: bool = vxp > 0 and not (xp["held"] as Array).is_empty()
	for h in xp["held"]:
		ok_xp = ok_xp and int(h[1]) == int(floor(float(h[0]) * vxp / 100.0 + 1e-9)) and int(h[2]) == int(h[1])
	checar(ok_xp, "X-Experience: parcela held = floor(base × %s%%) no treinador e no Pokémon" % str(vxp), str(xp["held"].slice(0, 2)))
	var atk_id := -1
	var vit_id := -1
	var blk_id := -1
	for k in l3["helds"]:
		var h: Dictionary = l3["helds"][k]
		if int(h["tier"]) == 8:
			match String(h["family"]):
				"ATTACK": atk_id = int(k)
				"VITALITY": vit_id = int(k)
				"BLOCK": blk_id = int(k)
	var at := rodar(dados, mapa, {"helds": {"v": atk_id}})
	checar(float(at["dano_dado"]) / at["golpes"] > float(base["dano_dado"]) / base["golpes"] * 1.05, "X-Attack tier 8: dano médio por golpe maior",
		"%.0f × %.0f" % [float(at["dano_dado"]) / at["golpes"], float(base["dano_dado"]) / base["golpes"]])
	var vt := rodar(dados, mapa, {"helds": {"v": vit_id}}, 0.1)
	checar(int(vt["max_hp"]) == Regras.js_round(float(base["max_hp"]) * (1.0 + float(l3["helds"][str(vit_id)]["value"]) / 100.0)), "X-Vitality: HP máximo × (1 + valor%)",
		"%d × %d" % [vt["max_hp"], base["max_hp"]])
	var bl := rodar(dados, mapa, {"helds": {"v": blk_id}}, 15.0)
	var b15 := rodar(dados, mapa, {}, 15.0)
	var med: Array = (b15["rec"] as Array).duplicate()
	med.sort()
	var corte := float(med[med.size() / 2]) * 0.2
	var peq_b := (b15["rec"] as Array).filter(func(x): return float(x) < corte).size()
	var peq_x := (bl["rec"] as Array).filter(func(x): return float(x) < corte).size()
	var frac := float(peq_x) / maxi(1, (bl["rec"] as Array).size())
	checar(peq_b == 0 and frac > 0.03 and frac < 0.10, "X-Block tier 8: ~6% dos golpes recebidos caem a 10% (bloqueio)", "%d de %d (%.1f%%); sem held %d" % [peq_x, (bl["rec"] as Array).size(), frac * 100.0, peq_b])
	var tm := rodar(dados, mapa, {"tms": {"v": {"elemental": "GRASS"}}})
	checar(int(tm["tm_hits"]) >= 2, "TM elemental (Petal Bloom, 300): acerta selvagens no quadro", "%d golpes do TM" % tm["tm_hits"])
	checar(int(tm["abates"]) >= int(base["abates"]), "TM elemental: abates ≥ sem TM", "%d × %d" % [tm["abates"], base["abates"]])
	var aoe := rodar(dados, mapa, {"tms": {"v": {"aoe": true}}})
	checar(int(aoe["splash"]) > 0 and int(base["splash"]) == 0, "AoE TM: o golpe normal acerta 2+ selvagens no mesmo field", "%d × %d" % [aoe["splash"], base["splash"]])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
