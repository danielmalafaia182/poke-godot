extends SceneTree
## Capturas no começo do jogo novo (Bulbasaur Lv.1, hunt do Geodude, Auto-Catch com Poké Ball): a curva de chance das 50
## primeiras tentativas pelo medidor da sim (chance = min(1, c·v/P·(1 + k·investido/P)), c 0,814, k 1,14, v = 5 de ouro,
## P = precoNpc do Geodude) e 20 sementes da simulação (bolas jogadas e capturas × o esperado pela curva).
## Rodar: testes/rodar.sh res://testes/test_captura_jogo_novo.gd

const Regras := preload("res://sim/regras.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var dados = DadosJogo.carregar()
	var preco := float(dados.especie(74).get("precoNpc", 0))
	var v := Regras.valor_bola(1)
	checar(preco == 300.0 and v == 5.0, "Geodude: precoNpc 300 (A: snapshot); Poké Ball vale 5 de ouro no medidor (A: priceGold)", "%.0f, %.0f" % [preco, v])
	var esperado := 0.0
	var p_zero := 1.0
	var linha := []
	for n in range(1, 51):
		var c := Regras.chance_captura(1, v * (n - 1), preco)
		esperado += c
		p_zero *= (1.0 - c)
		if n in [1, 10, 20, 30, 40, 50]:
			linha.append("%d: %.2f%%" % [n, 100.0 * c])
	print("CURVA (tentativa: chance, sem captura antes): ", ", ".join(linha))
	print("ESPERADO em 50 tentativas: %.2f capturas; chance de nenhuma: %.0f%%" % [esperado, 100.0 * p_zero])
	checar(absf(Regras.chance_captura(1, 0.0, preco) - 0.814 * 5.0 / 300.0) < 1e-9, "1ª tentativa = 0,814 × 5/300 = 1,36%")
	checar(esperado > 0.8 and esperado < 1.2 and p_zero > 0.3, "em 50 Poké Balls espera-se ~1 captura; 0 capturas tem ~1/3 de chance (não é improvável)")
	# 20 sementes da sim
	var mapa = MapaHunt.carregar("geodude", Fontes.ler_mapa("geodude"), Fontes.ler_colisao())
	var jogo := {"slug": "geodude", "hunt": "Geodude", "equipe": [{"id": "b", "nome": "Bulbasaur", "xp": 0,
		"ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1}],
		"auto_catch": true, "bola_auto_catch": 1, "auto_potion": true, "penalizar": false, "bolas": {1: 100}, "inventario": [{"itemId": 200, "quantity": 100}]}
	var bolas := 0
	var caps := 0
	var esp_sim := 0.0
	var coluna_ok := true
	for s in range(1, 21):
		var cfg := CenarioJogo.configurar(jogo, dados, s, 0)
		var sim = Simulacao.new(cfg, dados, mapa)
		sim.iniciar()
		var inv := 0.0
		for t in 600 * 5:
			for reg in sim.passo():
				var m: Dictionary = reg.get("msg", reg)
				if String(m.get("type", "")) == "catch-result" and int(m.get("ballId", 0)) == 1:
					bolas += 1
					esp_sim += Regras.chance_captura(1, inv, preco)
					inv += v
					if bool(m["success"]):
						caps += 1
						inv = 0.0
		for k in sim.medidor:   # ciclo 5: tentativas por bola (A: used-balls `balls`) somam o total
			var mk: Dictionary = sim.medidor[k]
			var soma := 0
			for bb in mk.get("bolas", {}):
				soma += int(mk["bolas"][bb])
			coluna_ok = coluna_ok and soma == int(mk["total"])
	checar(coluna_ok, "medidor: as tentativas por bola somam o total de cada espécie")
	var sd := sqrt(esp_sim)
	print("SIM: %d Poké Balls jogadas em 20 × 10 min, %d capturas, esperado %.1f" % [bolas, caps, esp_sim])
	checar(bolas > 20 * 30, "as bolas são de fato jogadas (1 por abate)", "%d" % bolas)
	checar(absf(caps - esp_sim) <= 3.0 * sd + 1.0, "capturas da sim dentro do esperado pela curva (±3σ)", "%d × %.1f" % [caps, esp_sim])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
