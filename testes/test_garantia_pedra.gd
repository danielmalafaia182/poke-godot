extends SceneTree
## Garantia de pedra de evolução (classe 3, decisão do usuário no ciclo 2; balanceamento.json `pedra_garantia_fator` 3):
## se a pedra não cai em fator × os abates esperados para ela, cai no próximo; cair zera a conta; o contador atravessa
## instâncias (vai no save). Larvitar: Rock Stone com chance 0,0016 por abate (A, tabela).
## Rodar: testes/rodar.sh res://testes/test_garantia_pedra.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const B := preload("res://sim/balanceamento.gd")
const ROCK := 109

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func rodar(dados, mapa, minutos: int, fator: float, garantia: Dictionary) -> Dictionary:
	var jogo := {"slug": "larvitar", "hunt": "larvitar", "equipe": [{"id": "g", "nome": "Golem", "xp": Regras.xp_total_para_nivel(250),
		"ivs": {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}, "quality": 1.5, "hp": -1}],
		"auto_potion": true, "penalizar": false, "inventario": [{"itemId": 203, "quantity": 999}], "garantia_pedras": garantia}
	var cfg := CenarioJogo.configurar(jogo, dados, 3, 0)
	if fator >= 0.0:
		cfg["parametros"]["pedra_garantia_fator"] = fator
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	var abates := 0
	var desde := 0
	var maior_intervalo := 0
	var pedras := 0
	var garantidas := 0
	var primeira := -1
	for t in minutos * 300:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			if String(m.get("type", "")) == "field-kill":
				abates += 1
				desde += 1
				for it in m.get("loot", []):
					if int(it["itemId"]) == ROCK:
						pedras += 1
						garantidas += 1 if it.get("garantida", false) else 0
						maior_intervalo = maxi(maior_intervalo, desde)
						desde = 0
						if primeira < 0:
							primeira = abates
	return {"abates": abates, "pedras": pedras, "garantidas": garantidas, "maior": maior_intervalo, "primeira": primeira, "garantia": sim.garantia_pedras}


func _init() -> void:
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar("larvitar", Fontes.ler_mapa("larvitar"), Fontes.ler_colisao())
	checar(float(B.valor("combate", "pedra_garantia_fator", 0)) == 3.0, "balanceamento.json: fator 3 (decisão do usuário)")
	var p := 0.0
	for e in dados.especie(246)["loot"]:
		if int(e.get("itemId", -1)) == ROCK:
			p = float(e["chanceBruta"]) / 100000.0
	# fator pequeno para o teste caber em poucos minutos: 0,05 → garantia a cada ~31 abates sem pedra
	var r := rodar(dados, mapa, 20, 0.05, {})
	var limite := int(ceil(0.05 / p)) + 1
	checar(r["garantidas"] > 0 and r["maior"] <= limite, "nunca passa do limite sem pedra (fator × 1/p abates)", "%d pedras (%d garantidas) em %d abates; maior intervalo %d, limite %d" % [r["pedras"], r["garantidas"], r["abates"], r["maior"], limite])
	var r0 := rodar(dados, mapa, 20, 0.0, {})
	checar(r0["garantidas"] == 0, "fator 0 desliga a garantia", "%d pedras naturais" % r0["pedras"])
	var r1 := rodar(dados, mapa, 2, 0.05, {str(ROCK): 0.05})
	checar(r1["primeira"] == 1, "o contador atravessa instâncias: com a conta no limite, a pedra cai no 1º abate", "1ª pedra no abate %d" % r1["primeira"])
	checar(r["garantia"].has(str(ROCK)), "a sim devolve o contador para o save")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
