extends SceneTree
## Captura de shiny (ciclo 4, item 5). Regra (C, barra de captura do cliente): chance = min(1, shinyBase(tier) × catchRate
## da bola), sem o medidor de investimento; catchRate (A: balls.catalog) Poké 1, Great 2, Super 3, Ultra 4, Idle 5,
## Master 255; shinyBase por tier é classe 3 (dados/balanceamento.json: o servidor não mostra o valor).
## Confere: a sim usa a tabela do balanceamento; a chance por bola é tier × bola; sorteando 40.000 lançamentos de Poké
## Ball num shiny do tier C na própria sim, a taxa observada fica dentro de 3 desvios de 1%. Imprime a tabela por bola.
## Rodar: testes/rodar.sh res://testes/test_shiny_captura.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar("rattata", Fontes.ler_mapa("rattata"), Fontes.ler_colisao())
	var jogo := {"slug": "rattata", "hunt": "Rattata", "equipe": [{"id": "b", "nome": "Bulbasaur", "xp": 100,
		"ivs": {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}, "quality": 1.0, "hp": -1}],
		"auto_catch": false, "auto_potion": false, "penalizar": false, "bolas": {1: 50000}, "inventario": []}
	var sim = Simulacao.new(CenarioJogo.configurar(jogo, dados, 11, 0), dados, mapa)
	sim.iniciar()
	var bal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/balanceamento.json"))["combate"]["captura_shiny_base"]["valor"]
	checar(sim.p.captura_shiny_base == bal, "a sim usa o shinyBase por tier do balanceamento (classe 3)", str(sim.p.captura_shiny_base))
	var bolas := [[1, "Poké"], [2, "Great"], [3, "Super"], [4, "Ultra"], [6, "Idle"], [5, "Master"]]
	var linha: String = "tier | " + " | ".join(bolas.map(func(b): return String(b[1])))
	print(linha)
	var certo := true
	for tier in ["A", "B", "C", "D", "E"]:
		var l: String = tier + "    | "
		var cs: Array = []
		for b in bolas:
			var c: float = Regras.chance_captura_shiny(int(b[0]), tier, sim.p)
			cs.append("%.1f%%" % (100.0 * c))
			if not is_equal_approx(c, minf(1.0, float(bal[tier]) * float(sim.p.captura_eficiencia[str(b[0])]))):
				certo = false
		print(l + " | ".join(cs))
	checar(certo, "chance = shinyBase(tier) × catchRate em todas as bolas")
	# Monte Carlo pela sim: shiny do tier C (Rattata não tem forma shiny; usa um tier C conhecido do cliente)
	var sid := -1
	for k in dados.shiny:
		if String(dados.shiny[k].get("tier", "")) == "C":
			sid = int(k)
			break
	var m := {"especie": dados.especie(sid), "species_id": sid, "shiny": true, "pos": Vector2i(0, 0)}
	var n := 40000
	sim.balls["counts"]["1"] = n + 10
	var ok := 0
	for i in n:
		sim._saida = []
		sim._lancar_bola(m, "1", -1)
		for reg in sim._saida:
			var msg: Dictionary = reg.get("msg", reg)
			if String(msg.get("type", "")) == "catch-result" and bool(msg["success"]):
				ok += 1
	var esperado := float(n) * float(bal["C"])
	var dp := sqrt(esperado * (1.0 - float(bal["C"])))
	checar(absf(ok - esperado) <= 3.0 * dp, "Poké Ball num shiny tier C pela sim: %d em %d (esperado %.0f ± %.0f)" % [ok, n, esperado, dp])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
