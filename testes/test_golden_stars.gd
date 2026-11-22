extends SceneTree
## Golden Stars (ciclo 7): serviço (sim/servico_golden_stars.gd; A: 6 h, rolagem grátis a cada 12 h, 9 candidatos, slots
## 2 e 3 travados por 10.000.000 de ouro ou 5 cartas por 24 h) e efeitos na simulação (C: só contra a espécie da estrela;
## parcela de XP `star`).

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const GS := preload("res://sim/servico_golden_stars.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func rodar(dados, estrelas: Array) -> Array:
	var jogo := {"slug": "rhydon", "hunt": "rhydon", "equipe": [{"id": "v", "nome": "Venusaur", "xp": Regras.xp_total_para_nivel(140),
		"ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1}],
		"auto_potion": true, "penalizar": false, "inventario": [{"itemId": 203, "quantity": 2000}], "estrelas": estrelas}
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 7, 0), dados, MapaHunt.carregar("rhydon", Fontes.ler_mapa("rhydon"), Fontes.ler_colisao()))
	sim.iniciar()
	var r: Array = []
	for t in 900:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			if String(m.get("type", "")) == "field-kill":
				r.append(m)
	return r


func _init() -> void:
	var dados = DadosJogo.carregar()
	var s = GS.new(dados)
	var est := {"gold": 0, "itens": {}, "vip": false}
	var r: Array = s.tratar(est, {"type": "gs-roll", "agora": 1000, "nivel": 100, "semente": 3})
	checar(String(r[0]["type"]) == "gs-rolled" and (r[0]["candidatos"] as Array).size() == 9 and int(est["estrelas"]["freeRollAt"]) == 1000 + 43200,
		"rolagem grátis: 9 candidatos, próxima em 12 h (A)")
	checar(String(s.tratar(est, {"type": "gs-roll", "agora": 2000, "nivel": 100})[0]["type"]) == "error", "antes de 12 h, sem ouro: recusado")
	checar(String(s.tratar(est, {"type": "gs-pick", "slot": 1, "agora": 2000, "semente": 1})[0]["type"]) == "error", "slot 2 travado")
	var pk: Array = s.tratar(est, {"type": "gs-pick", "slot": 0, "idx": -1, "agora": 2000, "semente": 1})
	var st: Dictionary = pk[0].get("star", {})
	checar(String(pk[0]["type"]) == "gs-picked" and int(st["expiresAt"]) - int(st["startedAt"]) == 21600 and String(st["bonusType"]) in GS.BONUS,
		"estrela no slot 1: dura 6 h (A), bônus do cliente", str(st))
	checar(s.para_sim(est, 2000).size() == 1 and s.para_sim(est, 2000 + 21600).is_empty(), "a estrela vale na hunt até expirar")
	est["gold"] = 10000000
	s.tratar(est, {"type": "gs-unlock", "slot": 1, "modo": "perm"})
	checar(bool(est["estrelas"]["liberados"][1]) and int(est["gold"]) == 0, "slot 2 liberado com 10.000.000 de ouro (A)")

	var rhydon := 112
	var base := rodar(dados, [])
	var xp := rodar(dados, [{"speciesId": rhydon, "bonus": "exp", "pct": 13.0}])
	var ok := not xp.is_empty()
	for m in xp:
		if int(m["speciesId"]) == rhydon:
			ok = ok and int(m["xpParts"].get("star", 0)) == int(floor(float(m["xpParts"]["base"]) * 0.13 + 1e-9)) and int(m["pokeXp"]["parts"].get("star", 0)) == int(m["xpParts"]["star"])
	checar(ok and base.all(func(m): return not m["xpParts"].has("star")), "estrela exp 13%: parcela star = floor(base × 13%) nas duas linhas; sem estrela, sem parcela")
	var outra := rodar(dados, [{"speciesId": 1, "bonus": "exp", "pct": 13.0}])
	checar(outra.all(func(m): return not m["xpParts"].has("star")), "estrela de outra espécie não vale aqui (C)")
	var dano := rodar(dados, [{"speciesId": rhydon, "bonus": "damage", "pct": 50.0}])
	checar(dano.size() > base.size(), "estrela damage 50% contra o Rhydon: mais abates em 3 min", "%d × %d" % [dano.size(), base.size()])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
