extends SceneTree
## Multiplicador de XP por região (classe 3, proposta do ciclo 2; balanceamento.json combate.xp_regiao, padrão 1):
## com 1 a parcela `event` é 0 e a saída é a de sempre; com 2 na região da hunt, event = base em todo abate e o XP da
## espécie (base) não muda.

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")
const B := preload("res://sim/balanceamento.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func rodar(dados, mapa, mult: Dictionary) -> Array:
	var jogo := {"slug": "larvitar", "hunt": "larvitar", "equipe": [{"id": "g", "nome": "Golem", "xp": Regras.xp_total_para_nivel(250),
		"ivs": {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}, "quality": 1.5, "hp": -1}],
		"auto_potion": true, "penalizar": false, "inventario": [{"itemId": 203, "quantity": 999}]}
	var cfg := CenarioJogo.configurar(jogo, dados, 5, 0)
	if not mult.is_empty():
		cfg["parametros"]["xp_regiao"] = mult
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	var partes: Array = []
	for t in 600:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			if String(m.get("type", "")) == "field-kill":
				partes.append(m["xpParts"])
	return partes


func _init() -> void:
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar("larvitar", Fontes.ler_mapa("larvitar"), Fontes.ler_colisao())
	var v = B.valor("combate", "xp_regiao", {})
	checar(v is Dictionary and float(v.get("kanto", 0)) == 1.0 and float(v.get("orre", 0)) == 10.0 and float(v.get("nightmare", 0)) == 1.0, "balanceamento.json: Orre ×10, Nightmare e Kanto ×1 (decisão do ciclo 3)")
	var p1 := rodar(dados, mapa, {})
	checar(not p1.is_empty() and p1.all(func(x): return int(x["event"]) == 0), "padrão: parcela event 0 em todo abate", "%d abates" % p1.size())
	var area := String(dados.hunts["larvitar"]["area"])
	var p2 := rodar(dados, mapa, {area: 2.0})
	checar(p2.size() == p1.size() and p2.all(func(x): return int(x["event"]) == int(x["base"])), "×2 na região: event = base, base igual", "%d abates" % p2.size())
	var p3 := rodar(dados, mapa, {"nightmare": 5.0})
	checar(p3.all(func(x): return int(x["event"]) == 0), "multiplicador de outra região não vale aqui")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
