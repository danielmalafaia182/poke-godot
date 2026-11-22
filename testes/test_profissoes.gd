extends SceneTree
## Profissões (ciclo 6): serviço (sim/servico_profissoes.gd) e efeitos na simulação.
## A: parcela mentor = 0,5% da base por nível acima de 200 de diferença, teto 60% (gravações livres, conta B).
## C: bônus de captura +3% por rank (até ×1,18 no S); só Botânico e Prestígio disponíveis; rank de cada carreira salvo.

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const Prof := preload("res://sim/servico_profissoes.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func kills(dados, slug: String, nivel_t: int, nivel_p: int, extra: Dictionary, minutos: float = 2.0) -> Array:
	var jogo := {"slug": slug, "hunt": slug, "equipe": [{"id": "g", "nome": "Golem", "xp": Regras.xp_total_para_nivel(nivel_p),
		"ivs": {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}, "quality": 1.5, "hp": -1}],
		"treinador_xp": Regras.xp_total_para_nivel(nivel_t), "auto_potion": true, "penalizar": false, "inventario": [{"itemId": 204, "quantity": 999}]}
	for k in extra:
		jogo[k] = extra[k]
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 3, 0), dados, MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao()))
	sim.iniciar()
	var r: Array = []
	for t in int(minutos * 300):
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			if String(m.get("type", "")) in ["field-kill", "profession-herb"]:
				r.append(m)
	return r


func _init() -> void:
	var dados = DadosJogo.carregar()
	var s = Prof.new(dados)
	var est := {"gold": 10000, "itens": {}}
	checar(String(s.tratar(est, {"type": "prof-escolher", "prof": "scientist"})[0]["type"]) == "error", "Cientista: em breve (C)")
	s.tratar(est, {"type": "prof-escolher", "prof": "botanist"})
	checar(s.rank(est) == "E" and absf(s.bonus_captura(est) - 0.03) < 1e-9, "Botânico começa no rank E, captura +3%")
	checar(String(s.tratar(est, {"type": "prof-subir", "especies": 0})[0]["type"]) == "error", "subir sem os requisitos: recusado (C: rankUpNotReady)")
	for t in Regras.TABELA_TIPOS:
		est["profissao"]["abates_tipo"][String(t)] = 60
	est["profissao"]["ervas"] = 50
	for i in 5:
		s.tratar(est, {"type": "prof-craft", "tipo": "ROCK"})
	checar(int(est["profissao"]["berries_craftadas"]) == 2 and int(est["gold"]) == 0, "craft: 10 ervas + 5000 de ouro por berry (2 até acabar o ouro)", str(est["profissao"]["berries_craftadas"]))
	est["profissao"]["berries_craftadas"] = 5
	var r: Array = s.tratar(est, {"type": "prof-subir", "especies": 5})
	checar(String(r[0]["type"]) == "prof-rank" and s.rank(est) == "D" and absf(s.bonus_captura(est) - 0.06) < 1e-9, "requisitos completos: rank D, captura +6%")
	est["profissao"]["ranks"]["botanist"] = "S"
	checar(absf(s.bonus_captura(est) - 0.18) < 1e-9 and s.mentor_teto(est) == 60.0, "rank S: captura ×1,18 (C) e teto do mentor 60% (A)")
	s.tratar(est, {"type": "prof-escolher", "prof": "prestige"})
	s.tratar(est, {"type": "prof-escolher", "prof": "botanist"})
	checar(s.rank(est) == "S", "trocar e voltar: o rank da carreira fica salvo (C)")

	# mentor na simulação (A): treinador 649, Pokémon 387 → 31%; 639 e 427 → 6%; 639 e 450 → 0
	var para: Dictionary = s.para_sim(est)
	for caso in [[649, 387, 0.31], [639, 427, 0.06], [639, 450, 0.0]]:
		var ks := kills(dados, "rhydon", caso[0], caso[1], para, 1.0)
		var ok := not ks.is_empty()
		for m in ks:
			if String(m["type"]) == "field-kill":
				ok = ok and int(m["pokeXp"]["parts"]["mentor"]) == Regras.js_round(float(m["pokeXp"]["parts"]["base"]) * float(caso[2]))
		checar(ok, "mentor treinador %d × Pokémon %d = %d%% da base (A)" % [caso[0], caso[1], int(caso[2] * 100)])
	var sem := kills(dados, "rhydon", 649, 387, {}, 1.0)
	checar(sem.all(func(m): return String(m["type"]) != "field-kill" or int(m["pokeXp"]["parts"]["mentor"]) == 0), "sem profissão: mentor 0 (como antes)")
	var bot := para.duplicate(true)
	bot["profissao"]["erva_chance"] = 1.0
	var ervas := kills(dados, "rhydon", 300, 300, bot, 1.0).filter(func(m): return String(m["type"]) == "profession-herb").size()
	checar(ervas > 0, "Botânico: Fresh Herbs nas hunts", "%d ervas" % ervas)
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
