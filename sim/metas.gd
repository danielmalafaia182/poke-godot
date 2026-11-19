extends RefCounted
## Metas visíveis (classe 3; decisão do usuário no ciclo 2: no trecho 150–500 não se mexe no acesso, que é classe 1, e
## sim se mostram metas — próxima hunt recomendada, marcos de nível e de coleção). Puro: lê só dados/ e o estado passado.
##
## Hunt recomendada (E): entre as liberadas pelo nível do treinador (regras_acesso, C), as que o líder aguenta — o Power
## médio dos selvagens no nível da hunt (IV médio 16,5, Quality 1, a fórmula de stats C) até `metas_fator_poder` × o
## Power do líder —, a de maior XP base por abate (A: `experience` da espécie). A "próxima" é a de mais XP que ainda
## falta aguentar, com o nível do líder que a libera. Os números do critério ficam em balanceamento.json ("metas").

const Regras := preload("res://sim/regras.gd")
const Acesso := preload("res://sim/regras_acesso.gd")
const Balanceamento := preload("res://sim/balanceamento.gd")

const PARAMETROS := {
	"metas_fator_poder": 1.0,
	"metas_iv_selvagem": 16.5,
	"metas_s_extra_abate": 4.0,
	"metas_ganho_min": 0.05,
	"metas_busca_niveis": 100,
	"metas_marcos_nivel": [10, 25, 50, 80, 100, 150, 175, 200, 250, 300, 350, 400, 450, 500, 750, 1000, 1500, 2000],
	"metas_marcos_colecao": [1, 5, 10, 25, 50, 75, 100, 150, 200, 300, 400],
}

static var _poder_hunt := {}   # slug -> Power médio dos selvagens (cache por processo)
static var _cache_golpes := {}  # líder|nível|espécie|nível da hunt -> golpes por abate
static var _P: Dictionary = {}
static var _p: Dictionary = {}
static var _teto_xp := {}


static func parametros() -> Dictionary:
	return Balanceamento.aplicar(PARAMETROS.duplicate(true), "metas")


static func poder_especie(esp: Dictionary, nivel: int, iv: float = 16.5, qualidade: float = 1.0) -> int:
	var soma := 0.0
	for k in Regras.CHAVES_STATS:
		soma += Regras.stat_bruto(int(esp["base"][k]), 0, nivel, qualidade, k) + float(nivel) / 100.0 * 2.0 * iv * pow(qualidade, Regras.EXPOENTE_STAT[k])
	return Regras.js_round(soma * qualidade)


static func poder_lider(dados, lider: Dictionary) -> int:
	var esp: Dictionary = dados.especie(int(lider["speciesId"]))
	var nivel := Regras.nivel_por_xp(int(lider["xp"]))
	var q := float(lider.get("quality", 1.0))
	return Regras.power(Regras.calcular_stats(esp["base"], lider["ivs"], nivel, q), q)


static func poder_hunt(dados, slug: String) -> int:
	if _poder_hunt.has(slug):
		return _poder_hunt[slug]
	var h: Dictionary = dados.hunts[slug]
	var p := parametros()
	var soma := 0.0
	var n := 0
	for s in h.get("spawns", []):
		var e: Dictionary = dados.especie(int(s.get("pokeId", 0)))
		if e.is_empty():
			continue
		soma += poder_especie(e, int(h["nivel"]), float(p.metas_iv_selvagem))
		n += 1
	_poder_hunt[slug] = int(round(soma / maxi(1, n)))
	return _poder_hunt[slug]


static func xp_abate(dados, slug: String) -> float:
	## XP base médio por abate dos spawns (A: experience da espécie).
	var sp: Array = dados.hunts[slug].get("spawns", [])
	var soma := 0.0
	for s in sp:
		soma += float(dados.especie(int(s.get("pokeId", 0))).get("xpAbate", 0))
	return soma / maxi(1, sp.size())


static func _nivel_para_poder(dados, lider: Dictionary, alvo: float) -> int:
	## Menor nível do líder (com a espécie, IV e Quality atuais) cujo Power chega a `alvo`; -1 se nem no 3000.
	var esp: Dictionary = dados.especie(int(lider["speciesId"]))
	var q := float(lider.get("quality", 1.0))
	var lo := 1
	var hi := 3000
	if Regras.power(Regras.calcular_stats(esp["base"], lider["ivs"], hi, q), q) < alvo:
		return -1
	while lo < hi:
		var m := (lo + hi) / 2
		if Regras.power(Regras.calcular_stats(esp["base"], lider["ivs"], m, q), q) >= alvo:
			hi = m
		else:
			lo = m + 1
	return lo


static func ritmo(dados, slug: String, lider: Dictionary, nivel_lider: int = -1) -> Dictionary:
	## Estimativa de XP/min do líder na hunt (E): por espécie dos spawns, o golpe que a sim escolheria (Regras, A/F) e o
	## dano médio (aleatório 0,925) contra o selvagem de IV médio no nível da hunt; tempo por abate = golpes × 1,6 s (A:
	## cadência do aliado) + `metas_s_extra_abate` (classe 3: andar até o próximo e respawn).
	if _P.is_empty():
		_P = Regras.PARAMETROS.duplicate(true)
		Balanceamento.aplicar(_P, "combate")
		_p = parametros()
	var el: Dictionary = dados.especie(int(lider["speciesId"]))
	var nl := nivel_lider if nivel_lider > 0 else Regras.nivel_por_xp(int(lider["xp"]))
	var q := float(lider.get("quality", 1.0))
	var chave_l := "%d|%s|%.4f|%d" % [int(lider["speciesId"]), str(lider["ivs"]), q, nl]
	var sl: Dictionary = {}
	var h: Dictionary = dados.hunts[slug]
	var nh := int(h["nivel"])
	var iv := int(round(float(_p.metas_iv_selvagem)))
	var ivs := {"hp": iv, "atk": iv, "def": iv, "spAtk": iv, "spDef": iv, "speed": iv}
	var tempo := 0.0
	var xp := 0.0
	var n := 0
	for s in h.get("spawns", []):
		var ew: Dictionary = dados.especie(int(s.get("pokeId", 0)))
		if ew.is_empty():
			continue
		var ck := chave_l + "|%d|%d" % [int(ew["id"]), nh]
		if not _cache_golpes.has(ck):
			if sl.is_empty():
				sl = Regras.calcular_stats(el["base"], lider["ivs"], nl, q)
			var sw := Regras.calcular_stats_dano(ew["base"], ivs, nh, 1.0, "continuo")
			var hp := Regras.hp_combate_selvagem(Regras.stat(int(ew["base"]["hp"]), iv, nh, 1.0, "hp"), _P)
			var g := Regras.escolher_golpe(el, nl, sl, ew, sw, _P)
			var golpes := 99.0
			if not g.is_empty():
				var esp := String(g["categoria"]) == "SPECIAL"
				var d := Regras.dano(nl, int(g["poder"]), float(sl["spAtk" if esp else "atk"]), float(sw["spDef" if esp else "def"]), bool(g["stab"]), float(g["eff"]), false, 0.925, _P)
				golpes = ceilf(float(hp) / maxf(1.0, float(d)))
			if _cache_golpes.size() > 200000:
				_cache_golpes.clear()
			_cache_golpes[ck] = golpes
		tempo += float(_cache_golpes[ck]) * float(int(_P.ataque_aliado_ticks) * int(_P.tick_ms)) / 1000.0 + float(_p.metas_s_extra_abate)
		xp += float(ew.get("xpAbate", 0))
		n += 1
	if n == 0:
		return {"abates_min": 0.0, "xp_min": 0.0}
	var am := 60.0 / (tempo / n)
	return {"abates_min": snappedf(am, 0.01), "xp_min": snappedf(am * xp / n, 1.0)}


static func _teto_xp_min(dados, slug: String) -> float:
	## Maior XP/min possível na hunt (tudo em 1 golpe): serve para descartar hunts sem rodar a estimativa.
	if not _teto_xp.has(slug):
		if _P.is_empty():
			_P = Regras.PARAMETROS.duplicate(true)
			Balanceamento.aplicar(_P, "combate")
			_p = parametros()
		_teto_xp[slug] = xp_abate(dados, slug) * 60.0 / (float(int(_P.ataque_aliado_ticks) * int(_P.tick_ms)) / 1000.0 + float(_p.metas_s_extra_abate))
	return float(_teto_xp[slug])


static func _melhor(dados, slugs: Array, lider: Dictionary, nl: int, teto_poder: float, piso_xp_min: float = 0.0) -> Dictionary:
	var melhor := {}
	for slug in slugs:
		if not dados.hunts.has(slug) or (dados.hunts[slug].get("spawns", []) as Array).is_empty():
			continue
		if float(poder_hunt(dados, slug)) > teto_poder:
			continue
		var limite := maxf(piso_xp_min, float(melhor.get("xp_min", 0.0)))
		if limite > 0.0 and _teto_xp_min(dados, slug) <= limite:
			continue
		var r := ritmo(dados, slug, lider, nl)
		if melhor.is_empty() or float(r["xp_min"]) > float(melhor["xp_min"]):
			var h: Dictionary = dados.hunts[slug]
			melhor = {"slug": slug, "nome": String(h["nome"]), "area": String(h.get("area", "")), "nivel": int(h["nivel"]),
				"xp_abate": snappedf(xp_abate(dados, slug), 0.1), "poder": poder_hunt(dados, slug), "xp_min": r["xp_min"], "abates_min": r["abates_min"]}
	return melhor


static func recomendacao(dados, hunts_lista: Array, nivel_treinador: int, lider: Dictionary) -> Dictionary:
	## {atual, proxima {… , nivel_lider, ganho_pct}, regiao {próxima região: nível, melhor hunt dela}, poder_lider}.
	## atual = entre as liberadas que o líder aguenta (Power médio dos selvagens ≤ fator × Power do líder), a de maior
	## XP/min estimado. proxima = a primeira troca de hunt que vale ≥ `metas_ganho_min` subindo o líder (de 5 em 5 níveis
	## até +`metas_busca_niveis`), no mesmo nível de treinador.
	var p := parametros()
	var nl := Regras.nivel_por_xp(int(lider["xp"]))
	var pl := poder_lider(dados, lider)
	var lib := Acesso.hunts_liberadas(hunts_lista, nivel_treinador)
	var atual := _melhor(dados, lib, lider, nl, float(pl) * float(p.metas_fator_poder))
	var prox := {}
	if not atual.is_empty():
		var esp: Dictionary = dados.especie(int(lider["speciesId"]))
		var q := float(lider.get("quality", 1.0))
		var passo := 5
		var alvo := nl + passo
		while alvo <= nl + int(p.metas_busca_niveis):
			var pa := Regras.power(Regras.calcular_stats(esp["base"], lider["ivs"], alvo, q), q)
			var base := float(ritmo(dados, String(atual["slug"]), lider, alvo)["xp_min"])
			var m := _melhor(dados, lib, lider, alvo, float(pa) * float(p.metas_fator_poder), base * (1.0 + float(p.metas_ganho_min)))
			if not m.is_empty() and String(m["slug"]) != String(atual["slug"]) and float(m["xp_min"]) >= base * (1.0 + float(p.metas_ganho_min)):
				prox = m
				prox["nivel_lider"] = alvo
				prox["ganho_pct"] = int(round((float(m["xp_min"]) / maxf(1.0, base) - 1.0) * 100.0))
				break
			alvo += passo
		if prox.is_empty():
			# sem troca de hunt: o próximo salto na própria hunt (o nível em que um golpe a menos derruba o selvagem)
			alvo = nl + 1
			var x0 := float(atual["xp_min"])
			while alvo <= nl + int(p.metas_busca_niveis):
				var r := ritmo(dados, String(atual["slug"]), lider, alvo)
				if float(r["xp_min"]) >= x0 * (1.0 + float(p.metas_ganho_min)):
					prox = atual.duplicate()
					prox["xp_min"] = r["xp_min"]
					prox["abates_min"] = r["abates_min"]
					prox["nivel_lider"] = alvo
					prox["salto"] = true
					prox["ganho_pct"] = int(round((float(r["xp_min"]) / maxf(1.0, x0) - 1.0) * 100.0))
					break
				alvo += 1
	var regiao := {}
	for r in [["outland", 150], ["orre", 500], ["nightmare", 2000]]:
		if nivel_treinador < int(r[1]):
			var slugs: Array = []
			for h in hunts_lista:
				if String(h.get("area", "")) == String(r[0]):
					slugs.append(String(h["slug"]))
			regiao = {"area": r[0], "nivel_treinador": r[1], "melhor": _melhor(dados, slugs, lider, nl, float(pl) * float(p.metas_fator_poder))}
			break
	return {"atual": atual, "proxima": prox, "regiao": regiao, "poder_lider": pl}


static func marco_nivel(nivel: int) -> Dictionary:
	## {anterior, proximo (-1 no fim), xp_proximo} pelos marcos de balanceamento.json; o desbloqueio de região (C) entra
	## como rótulo no marco.
	var p := parametros()
	var ant := 1
	var prox := -1
	for m in p.metas_marcos_nivel:
		if int(m) <= nivel:
			ant = int(m)
		elif prox < 0:
			prox = int(m)
	return {"anterior": ant, "proximo": prox, "rotulo": rotulo_nivel(prox)}


static func rotulo_nivel(nivel: int) -> String:
	match nivel:
		150:
			return "Outland"
		500:
			return "Orre"
		2000:
			return "Nightmare"
	return ""


static func colecao(dados, especies_capturadas: Array, hunts_lista: Array, nivel_treinador: int) -> Dictionary:
	## Espécies diferentes capturadas (normal e shiny contam uma vez), o próximo marco e o progresso nas espécies das hunts
	## liberadas (a "Pokédex da região").
	var p := parametros()
	var vistas := {}
	for s in especies_capturadas:
		vistas[int(s)] = true
	var n := vistas.size()
	var prox := -1
	for m in p.metas_marcos_colecao:
		if int(m) > n:
			prox = int(m)
			break
	var regiao := {}
	for slug in Acesso.hunts_liberadas(hunts_lista, nivel_treinador):
		for s in dados.hunts.get(slug, {}).get("spawns", []):
			regiao[int(s.get("pokeId", 0))] = true
	var tem := 0
	for k in regiao:
		if vistas.has(k):
			tem += 1
	return {"especies": n, "proximo": prox, "liberadas_total": regiao.size(), "liberadas_capturadas": tem}


static func resumo(dados, hunts_lista: Array, treinador_xp: int, lider: Dictionary, especies_capturadas: Array) -> Dictionary:
	var nt := Regras.nivel_por_xp(treinador_xp)
	var mn := marco_nivel(nt)
	var falta := 0
	if int(mn["proximo"]) > 0:
		falta = maxi(0, Regras.xp_total_para_nivel(int(mn["proximo"])) - treinador_xp)
	return {"nivel_treinador": nt, "marco": mn, "xp_falta": falta, "hunt": recomendacao(dados, hunts_lista, nt, lider),
		"colecao": colecao(dados, especies_capturadas, hunts_lista, nt)}
