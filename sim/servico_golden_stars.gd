extends RefCounted
## Golden Stars / Poke Slot Machine (ciclo 7, backlog). Puro e determinístico; tratar(estado, cmd) → mensagens.
##
## Medido (A, G9): estrela ativa {speciesId, bonusType, pct, rarity, startedAt, expiresAt} dura 6 h; rolagem grátis a
## cada 12 h (freeRollAt); 9 candidatos por rolagem; slots 2 e 3 travados (10.000.000 de ouro, VIP, ou 5 cartas por 24 h).
## Do cliente (C, window.goldenStars.*): bônus exp ("você e seu Pokémon recebem N% a mais de experiência ao derrotar X"),
## loot, damage, defense, critChance, critDamage ("um crítico causa 50% a mais", held), shiny, catch — só valem contra a
## espécie da estrela; a parcela de XP no cartão de abate é `star` ("Slot Bônus"); ações roll, pick (sorteio),
## pick-species (escolha direta), reroll, unlock-perm, unlock-temp.
## Classe 3 (balanceamento.json "golden_stars", padrões abaixo): espécies candidatas (as das hunts liberadas pelo nível do
## treinador), raridade e pct de cada bônus (A viu 10 e 13), custo da rolagem paga, da escolha direta e do reroll.
##
## Estado: estrelas {slots: [estrela|{}]×3, liberados: [bool]×3, temp_ate: [s]×3, freeRollAt, candidatos: [speciesId]}.
## Comandos: gs-get {agora}; gs-roll {agora, semente, nivel}; gs-pick {slot, idx (-1 = sorteio), agora, semente};
## gs-unlock {slot, modo: "perm"|"temp"}. para_sim(estado, agora) → [{speciesId, bonus, pct}] (cfg.estrelas).

const Balanceamento := preload("res://sim/balanceamento.gd")
const Rng := preload("res://sim/rng.gd")
const BONUS := ["exp", "loot", "damage", "defense", "critChance", "critDamage", "shiny", "catch"]

var p := {
	"duracao_s": 21600,          # A: 6 h
	"roll_gratis_s": 43200,      # A: 12 h
	"candidatos": 9,             # A
	"perm_ouro": 10000000,       # A
	"temp_cartas": 5,            # A
	"temp_s": 86400,             # A: 24 h
	"roll_pago_ouro": 100000,
	"raridade": [["comum", 10, 60], ["rara", 13, 30], ["épica", 16, 10]],   # [nome, pct, peso] — A viu 10 e 13
}
var dados


func _init(dados_jogo) -> void:
	dados = dados_jogo
	var b: Dictionary = Balanceamento.secao("golden_stars")
	for k in b:
		p[k] = b[k]


static func _erro(t: String) -> Dictionary:
	return {"type": "error", "message": t}


func _est(estado: Dictionary) -> Dictionary:
	if not estado.has("estrelas"):
		estado["estrelas"] = {}
	var e: Dictionary = estado["estrelas"]
	if not e.has("slots"):
		e["slots"] = [{}, {}, {}]
		e["liberados"] = [true, false, false]
		e["temp_ate"] = [0, 0, 0]
		e["freeRollAt"] = 0
		e["candidatos"] = []
	return e


func _liberado(e: Dictionary, i: int, agora: int, vip: bool) -> bool:
	return bool(e["liberados"][i]) or int(e["temp_ate"][i]) > agora or (vip and i == 1)


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	var e := _est(estado)
	var agora := int(cmd.get("agora", 0))
	match String(cmd.get("type", "")):
		"gs-get":
			return [_msg(estado, agora)]
		"gs-roll":
			var pago := agora < int(e["freeRollAt"])
			if pago:
				if int(estado.get("gold", 0)) < int(p.roll_pago_ouro):
					return [_erro("Próxima rolagem grátis em %d min." % ((int(e["freeRollAt"]) - agora) / 60))]
				estado["gold"] = int(estado["gold"]) - int(p.roll_pago_ouro)
			else:
				e["freeRollAt"] = agora + int(p.roll_gratis_s)
			var pool := _pool(int(cmd.get("nivel", estado.get("nivel", 1))))
			var rng = Rng.new(int(cmd.get("semente", agora)))
			var c: Array = []
			while c.size() < mini(int(p.candidatos), pool.size()):
				var sid: int = pool[int(rng.randf() * pool.size()) % pool.size()]
				if not sid in c:
					c.append(sid)
			e["candidatos"] = c
			return [{"type": "gs-rolled", "candidatos": c, "pago": pago}, _msg(estado, agora)]
		"gs-pick":
			var i := int(cmd.get("slot", 0))
			if i < 0 or i > 2 or not _liberado(e, i, agora, bool(estado.get("vip", false))):
				return [_erro("Slot travado.")]
			var c: Array = e["candidatos"]
			if c.is_empty():
				return [_erro("Role primeiro.")]
			var rng = Rng.new(int(cmd.get("semente", agora)) * 31 + i)
			var idx := int(cmd.get("idx", -1))
			if idx < 0 or idx >= c.size():
				idx = int(rng.randf() * c.size()) % c.size()   # C: "Escolheu (sorteio)"
			var bonus: String = BONUS[int(rng.randf() * BONUS.size()) % BONUS.size()]
			var o := rng.randf() * 100.0
			var rar: Array = p.raridade[0]
			for r in p.raridade:
				if o < float(r[2]):
					rar = r
					break
				o -= float(r[2])
			var estrela := {"speciesId": int(c[idx]), "bonusType": bonus, "pct": int(rar[1]), "rarity": String(rar[0]), "startedAt": agora,
				"expiresAt": agora + int(p.duracao_s)}
			e["slots"][i] = estrela
			e["candidatos"] = []
			return [{"type": "gs-picked", "slot": i, "star": estrela.duplicate()}, _msg(estado, agora)]
		"gs-unlock":
			var i := int(cmd.get("slot", 1))
			if i < 1 or i > 2:
				return [_erro("Slot inválido.")]
			if String(cmd.get("modo", "perm")) == "perm":
				if int(estado.get("gold", 0)) < int(p.perm_ouro):
					return [_erro("Precisa de %d de ouro." % int(p.perm_ouro))]
				estado["gold"] = int(estado["gold"]) - int(p.perm_ouro)
				e["liberados"][i] = true
			else:
				var cartas := _cartas(estado)
				if cartas.size() < int(p.temp_cartas):
					return [_erro("Precisa de %d cartas." % int(p.temp_cartas))]
				for k in cartas.slice(0, int(p.temp_cartas)):
					estado["itens"][k] = int(estado["itens"][k]) - 1
					if int(estado["itens"][k]) <= 0:
						estado["itens"].erase(k)
				e["temp_ate"][i] = agora + int(p.temp_s)
			return [{"type": "gs-unlocked", "slot": i}, _msg(estado, agora)]
	return [_erro("comando desconhecido: " + String(cmd.get("type", "")))]


func _cartas(estado: Dictionary) -> Array:
	var r: Array = []
	for k in estado.get("itens", {}):
		if String(dados.itens.get(int(k), {}).get("categoria", "")) == "card":
			for _i in int(estado["itens"][k]):
				r.append(k)
	return r


func _pool(nivel: int) -> Array:
	var vistos := {}
	for s in dados.hunts:
		if int(dados.hunts[s].get("nivel", 0)) <= nivel:
			for x in dados.hunts[s].get("spawns", []):
				vistos[int(x.get("pokeId", 0))] = true
	vistos.erase(0)
	var r: Array = vistos.keys()
	r.sort()
	return r


func para_sim(estado: Dictionary, agora: int) -> Array:
	var e := _est(estado)
	var r: Array = []
	for st in e["slots"]:
		if not (st as Dictionary).is_empty() and int(st["expiresAt"]) > agora:
			r.append({"speciesId": int(st["speciesId"]), "bonus": String(st["bonusType"]), "pct": float(st["pct"])})
	return r


func _msg(estado: Dictionary, agora: int) -> Dictionary:
	var e := _est(estado)
	return {"type": "golden-stars", "slots": e["slots"].duplicate(true), "liberados": [_liberado(e, 0, agora, bool(estado.get("vip", false))),
		_liberado(e, 1, agora, bool(estado.get("vip", false))), _liberado(e, 2, agora, bool(estado.get("vip", false)))],
		"freeRollAt": int(e["freeRollAt"]), "candidatos": (e["candidatos"] as Array).duplicate()}
