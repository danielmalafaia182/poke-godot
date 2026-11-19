extends RefCounted
## Fase 4, lote 4 (começo): ginásios (insígnias) e catálogo de bosses. Puro e determinístico ("agora" no comando, em
## segundos unix). tratar(estado, cmd) → mensagens.
##
## O que tem fonte e entrou:
##   - Insígnias (C, janela Gym Rewards): "A badge LASTS 48h — beat the leader again to renew it. Each ACTIVE badge grants
##     +1% XP and +1% chance of an extra drop roll"; 18 ginásios ("Defeat all 18 gyms — Kanto and Johto"); a janela conta
##     8 em Kanto e 10 na outra região (C: `total: "kanto" === e ? 8 : 10`). O efeito na hunt está na simulação
##     (cfg.insignias → parcela `gym` e rolagem extra; PARAMETROS insignia_pct_*).
##   - Ginásios conhecidos (A, mensagens gym-global gravadas): spikemuth DARK (NPC Piers), cerulean WATER, mahogany ICE
##     (NPC Pryce), pewter ROCK.
##   - Bosses (A, snapshot game/bossCatalog.json): 87, com nome, categoria, nível e nomes dos drops (sem HP, golpes nem
##     chances); os drops ganham o id pelo nome no catálogo de itens.
## O que NÃO entrou (vem do servidor, não gravado): a lista dos 18 líderes com times, a luta de ginásio, a disputa de
## liderança e o pagamento diário (online), a luta de boss (HP, golpes, rounds), as fichas de entrada e as chances de drop.
## Enquanto a luta não existe, a insígnia entra pelo comando `insignia-ganha` (E: é o resultado de vencer o líder).
##
## Ciclo 3 (classe 3, balanceamento.json "ginasios"; times e regras desenhados): luta automática time × time.
##   - Cada lado tem um ativo; o do jogador ataca a cada 1600 ms (A: cadência do aliado), o do líder a cada
##     `cadencia_lider_ms`; golpe = o que a sim escolheria (Regras.escolher_golpe, A/F) e dano pela fórmula da sim
##     (Regras.dano, aleatório 0,85–1,00) sem o ×1,8 do selvagem; HP de combate 12 × stat nos dois lados (o do aliado, A).
##   - Desmaiou, entra o próximo (o jogador na ordem do time, o líder na ordem dele, o ás por último). Sem poção.
##   - Vencer dá a insígnia por 48 h (C) ou renova; perder bloqueia novo desafio por `recarga_derrota_s`.
##   - Desbloqueio pelo nível do treinador (classe 3). Vencer os 18 alguma vez = Campeão dos Ginásios (C: outfit).
##
## Estado: ginasios: {insignias: {"<gymId>": until_ms}, vencidos: {"<gymId>": true}, recarga: {"<gymId>": ate_s}}
## Comandos: ginasios-get {agora}, insignia-ganha {gymId, agora}, bosses-get,
##           ginasio-desafiar {gymId, agora, nivel, time: [{speciesId, xp, ivs, quality}], semente}

const Regras := preload("res://sim/regras.gd")
const Rng := preload("res://sim/rng.gd")
const Balanceamento := preload("res://sim/balanceamento.gd")

const PARAMETROS := {
	"insignia_duracao_s": 48 * 3600,   # C: "A badge LASTS 48h"
	"ginasios_total": 18,              # C
	"ginasios_por_regiao": {"kanto": 8, "outra": 10},   # C (a 2ª região é Johto no texto; a lista vem do servidor)
	"lista": [],                      # classe 3: dados/balanceamento.json ginasios.lista
	"iv_lider": 20, "quality_lider": 1.15, "cadencia_lider_ms": 2000, "fator_dano_lider": 1.0,
	"recarga_derrota_s": 60, "luta_max_s": 600,
	"ginasios_conhecidos": {"spikemuth": {"tipo": "DARK", "lider_npc": "Piers"}, "cerulean": {"tipo": "WATER"},
		"mahogany": {"tipo": "ICE", "lider_npc": "Pryce"}, "pewter": {"tipo": "ROCK"}},   # A: gym-global
}

var p: Dictionary = PARAMETROS.duplicate(true)
var dados
var bosses: Array = []


func _init(dados_jogo, catalogo_bosses: Array = [], parametros: Dictionary = {}) -> void:
	dados = dados_jogo
	Balanceamento.aplicar(p, "ginasios")
	for k in parametros:
		p[k] = parametros[k]
	var por_nome := {}
	if dados != null:
		for id in dados.itens:
			por_nome[String(dados.itens[id].get("nome", "")).to_lower()] = int(id)
	for b in catalogo_bosses:
		var drops: Array = []
		for n in b.get("drops", []):
			drops.append({"name": String(n), "itemId": int(por_nome.get(String(n).to_lower(), -1))})
		bosses.append({"key": String(b.get("key", "")), "name": String(b.get("name", "")), "category": String(b.get("category", "")),
			"level": int(b.get("level", 0)), "drops": drops})


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	if not estado.has("ginasios"):
		estado["ginasios"] = {}
	if not estado["ginasios"].has("insignias"):
		estado["ginasios"]["insignias"] = {}
	var agora := int(cmd.get("agora", 0))
	match String(cmd.get("type", "")):
		"ginasios-get":
			return [msg_ginasios(estado, agora)]
		"insignia-ganha":
			var id := String(cmd.get("gymId", ""))
			if id.is_empty():
				return [_erro("Ginásio inválido.")]
			estado["ginasios"]["insignias"][id] = (agora + int(p.insignia_duracao_s)) * 1000   # C: vencer de novo renova
			return [msg_ginasios(estado, agora)]
		"bosses-get":
			return [{"type": "bosses", "bosses": bosses}]
		"ginasio-desafiar":
			return _desafiar(estado, cmd, agora)
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func ativas(estado: Dictionary, agora: int) -> int:
	var n := 0
	for id in estado.get("ginasios", {}).get("insignias", {}):
		if int(estado["ginasios"]["insignias"][id]) > agora * 1000:
			n += 1
	return mini(n, int(p.ginasios_total))


func msg_ginasios(estado: Dictionary, agora: int) -> Dictionary:
	## E (formato próprio; o original manda `/api/game/gyms` com {gyms, details, regions}, não gravado).
	var lista: Array = []
	for id in estado["ginasios"]["insignias"]:
		var ate := int(estado["ginasios"]["insignias"][id])
		lista.append({"gymId": String(id), "until": ate, "active": ate > agora * 1000})
	var n := ativas(estado, agora)
	var gyms: Array = []
	var nivel := int(estado.get("nivel", 1))
	for g in p.lista:
		var gid := String(g["id"])
		var ate := int(estado["ginasios"]["insignias"].get(gid, 0))
		var rec := int(estado["ginasios"].get("recarga", {}).get(gid, 0))
		gyms.append({"id": gid, "regiao": String(g["regiao"]), "tipo": String(g["tipo"]), "lider": String(g["lider"]), "insignia": String(g["insignia"]),
			"nivelTreinador": int(g["nivel_treinador"]), "time": g["time"], "liberado": nivel >= int(g["nivel_treinador"]),
			"ativa": ate > agora * 1000, "ate": ate, "recargaS": maxi(0, rec - agora), "vencido": estado["ginasios"].get("vencidos", {}).has(gid)})
	return {"type": "ginasios", "badges": lista, "active": n, "max": int(p.ginasios_total), "xpPct": n, "dropPct": n,
		"conhecidos": p.ginasios_conhecidos, "gyms": gyms, "campeao": (estado["ginasios"].get("vencidos", {}) as Dictionary).size() >= int(p.ginasios_total)}


func ginasio(gid: String) -> Dictionary:
	for g in p.lista:
		if String(g["id"]) == gid:
			return g
	return {}


func _desafiar(estado: Dictionary, cmd: Dictionary, agora: int) -> Array:
	var gid := String(cmd.get("gymId", ""))
	var g := ginasio(gid)
	if g.is_empty():
		return [_erro("Ginásio inválido.")]
	if int(cmd.get("nivel", estado.get("nivel", 1))) < int(g["nivel_treinador"]):
		return [_erro("Você precisa ser nível %d para desafiar %s." % [int(g["nivel_treinador"]), String(g["lider"])])]
	var gs: Dictionary = estado["ginasios"]
	if not gs.has("recarga"):
		gs["recarga"] = {}
	if not gs.has("vencidos"):
		gs["vencidos"] = {}
	if int(gs["recarga"].get(gid, 0)) > agora:
		return [_erro("Aguarde %d s para desafiar de novo." % (int(gs["recarga"][gid]) - agora))]
	var time: Array = cmd.get("time", [])
	if time.is_empty():
		return [_erro("Time vazio.")]
	var r := lutar(time, g, int(cmd.get("semente", agora)))
	if bool(r["venceu"]):
		gs["insignias"][gid] = (agora + int(p.insignia_duracao_s)) * 1000
		var novo: bool = not gs["vencidos"].has(gid)
		gs["vencidos"][gid] = true
		r["badgeEarned"] = true
		r["primeira"] = novo
		r["championOutfit"] = novo and (gs["vencidos"] as Dictionary).size() >= int(p.ginasios_total)
	else:
		gs["recarga"][gid] = agora + int(p.recarga_derrota_s)
		r["badgeEarned"] = false
	r["type"] = "gym-result"
	r["gymId"] = gid
	return [r, msg_ginasios(estado, agora)]


func _lutador(m: Dictionary, nivel: int, ivs: Dictionary, q: float, lado: String) -> Dictionary:
	var e: Dictionary = dados.especie(int(m["speciesId"]))
	var st := Regras.calcular_stats(e["base"], ivs, nivel, q)
	var hp := Regras.hp_combate_aliado(int(st["hp"]))
	var sd: Dictionary = st
	if lado == "b":
		sd = Regras.calcular_stats_dano(e["base"], ivs, nivel, q, "continuo")
	return {"esp": e, "nivel": nivel, "stats": st, "dano": sd, "hp": hp, "max": hp, "nome": String(e.get("nome", "")), "speciesId": int(m["speciesId"])}


func lutar(time: Array, g: Dictionary, semente: int) -> Dictionary:
	## Luta automática (puro, determinístico pela semente). Devolve {venceu, log[{t, lado, nome, alvo, golpe, dano, eff,
	## hp, max, ko}], times {a, b}, duracaoMs}.
	var rng = Rng.new(semente)
	var P: Dictionary = Regras.PARAMETROS.duplicate(true)
	Balanceamento.aplicar(P, "combate")
	var passo_a := int(P.ataque_aliado_ticks) * int(P.tick_ms)
	var passo_b := int(g.get("cadencia_ms", p.cadencia_lider_ms))   # boss: sobrescreve (servico_bosses.gd)
	var a: Array = []
	for m in time:
		var nv := Regras.nivel_por_xp(int(m["xp"])) if m.has("xp") else int(m.get("nivel", 1))
		a.append(_lutador(m, nv, m["ivs"], float(m.get("quality", 1.0)), "a"))
	var b: Array = []
	var iv := int(g.get("iv", p.iv_lider))
	var ivs := {"hp": iv, "atk": iv, "def": iv, "spAtk": iv, "spDef": iv, "speed": iv}
	for m in g["time"]:
		var x := _lutador(m, int(m["nivel"]), ivs, float(g.get("quality", p.quality_lider)), "b")
		x["hp"] = int(x["hp"]) * int(g.get("hp_mult", 1))
		x["max"] = x["hp"]
		b.append(x)
	var fator_b := float(g.get("fator_dano", p.fator_dano_lider))
	var ia := 0
	var ib := 0
	var t := 0
	var prox_a := passo_a
	var prox_b := passo_b
	var log: Array = []
	var teto := int(p.luta_max_s) * 1000
	while ia < a.size() and ib < b.size() and t <= teto:
		var lado := "a" if prox_a <= prox_b else "b"
		var de: Dictionary = a[ia] if lado == "a" else b[ib]
		var para: Dictionary = b[ib] if lado == "a" else a[ia]
		if lado == "a":
			t = prox_a
			prox_a += passo_a
		else:
			t = prox_b
			prox_b += passo_b
		var gol := Regras.escolher_golpe(de["esp"], int(de["nivel"]), de["dano"], para["esp"], para["dano"], P)
		var dano := 1
		var nome_g := "Struggle"
		var eff := 1.0
		if not gol.is_empty():
			var esp := String(gol["categoria"]) == "SPECIAL"
			nome_g = String(gol["nome"])
			eff = float(gol["eff"])
			dano = Regras.dano(int(de["nivel"]), int(gol["poder"]), float(de["dano"]["spAtk" if esp else "atk"]), float(para["dano"]["spDef" if esp else "def"]),
				bool(gol["stab"]), eff, false, 0.85 + 0.15 * rng.randf(), P)
			if lado == "b":
				dano = maxi(1, int(round(dano * fator_b)))
		para["hp"] = maxi(0, int(para["hp"]) - dano)
		var ko := int(para["hp"]) == 0
		log.append({"t": t, "lado": lado, "nome": de["nome"], "alvo": para["nome"], "golpe": nome_g, "dano": dano, "eff": eff, "hp": para["hp"], "max": para["max"], "ko": ko})
		if ko:
			if lado == "a":
				ib += 1
				prox_b = t + passo_b   # o próximo do líder entra e ataca no ritmo dele
			else:
				ia += 1
				prox_a = t + passo_a
	return {"venceu": ib >= b.size() and ia < a.size(), "log": log, "times": {"a": _resumo(a), "b": _resumo(b)}, "duracaoMs": t}


static func _resumo(l: Array) -> Array:
	var r: Array = []
	for x in l:
		r.append({"nome": x["nome"], "speciesId": x["speciesId"], "nivel": x["nivel"], "hp": x["hp"], "max": x["max"]})
	return r
