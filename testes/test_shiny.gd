extends SceneTree
## Shiny (ciclo 2): taxa de aparição A (1/260 nas espécies com forma shiny, 0 nas outras e no lock), captura com o
## Auto-Catch Shiny (bola própria, filtro de nomes nos dois modos, C) e o shinyBase por tier (classe 3).
## Rodar: testes/rodar.sh res://testes/test_shiny.gd

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


func rodar(dados, mapa, slug: String, minutos: int, extra: Dictionary, semente: int) -> Dictionary:
	var jogo := {"slug": slug, "hunt": slug, "equipe": [{"id": "g", "nome": "Golem", "xp": Regras.xp_total_para_nivel(250),
		"ivs": {"hp": 32, "atk": 32, "def": 32, "spAtk": 32, "spDef": 32, "speed": 32}, "quality": 1.5, "hp": -1}],
		"auto_potion": true, "penalizar": false, "bolas": {3: 5000, 6: 500}, "inventario": [{"itemId": 203, "quantity": 999}]}
	for k in extra:
		jogo[k] = extra[k]
	var cfg := CenarioJogo.configurar(jogo, dados, semente, 0)
	for k in extra.get("parametros", {}):
		cfg["parametros"][k] = extra["parametros"][k]
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	var r := {"abates": 0, "shiny": 0, "bolas": {}, "capturas_shiny": 0, "shiny_no_lock": 0, "tentativas_shiny": 0}
	var ult := {}
	for t in minutos * 300:
		for reg in sim.passo():
			var m: Dictionary = reg.get("msg", reg)
			match String(m.get("type", "")):
				"field":
					ult = m
				"field-kill":
					r["abates"] += 1
					if bool(m.get("shiny", false)):
						r["shiny"] += 1
						if "debuff" in m.get("xpParts", {}):
							r["shiny_no_lock"] += 1
				"catch-result":
					var b := str(int(m["ballId"]))
					r["bolas"][b] = int(r["bolas"].get(b, 0)) + 1
					if b == "6":
						r["tentativas_shiny"] += 1
						r["capturas_shiny"] += 1 if bool(m["success"]) else 0
	return r


func _init() -> void:
	var dados = DadosJogo.carregar()
	checar(dados.shiny.size() == 190 and dados.shiny.has(246) and String(dados.shiny[246]["tier"]) != "", "tabela de shiny do cliente: 190 espécies com forma, com tier")
	var larv = MapaHunt.carregar("larvitar", Fontes.ler_mapa("larvitar"), Fontes.ler_colisao())
	# taxa: Larvitar (com forma) em 6 × 30 min; esperado ~1/260 por abate
	var ab := 0
	var sh := 0
	for s in 6:
		var r := rodar(dados, larv, "larvitar", 30, {}, 100 + s)
		ab += int(r["abates"])
		sh += int(r["shiny"])
	var esperado := ab / 260.0
	checar(absf(sh - esperado) <= 3.0 * sqrt(esperado) + 1.0, "taxa de shiny na Larvitar ~1/260 por abate (A)", "%d em %d abates; esperado %.1f" % [sh, ab, esperado])
	# lock: nenhum shiny aparece durante o lock de entrada (chance alta para testar)
	var rl := rodar(dados, larv, "larvitar", 2, {"penalizar": true, "parametros": {"shiny_chance": 0.5}}, 7)
	checar(int(rl["shiny_no_lock"]) == 0 and int(rl["shiny"]) > 0, "nenhum shiny durante o lock (C); depois dele aparecem", "%d shinies, %d no lock" % [int(rl["shiny"]), int(rl["shiny_no_lock"])])
	# Auto-Catch Shiny: só shinies com a bola shiny quando o Auto-Catch normal está desligado (A: M3)
	var r2 := rodar(dados, larv, "larvitar", 5, {"auto_catch": false, "auto_catch_shiny": true, "bola_auto_catch_shiny": 6, "parametros": {"shiny_chance": 0.3}}, 9)
	checar(int(r2["bolas"].get("3", 0)) == 0 and int(r2["tentativas_shiny"]) == int(r2["shiny"]) and int(r2["shiny"]) > 0,
		"Auto-Catch desligado e Shiny ligado: só shinies recebem bola, a Idle Ball", str(r2["bolas"]))
	var r3 := rodar(dados, larv, "larvitar", 5, {"auto_catch": true, "bola_auto_catch": 3, "auto_catch_shiny": true, "bola_auto_catch_shiny": 6, "parametros": {"shiny_chance": 0.3}}, 9)
	checar(int(r3["bolas"].get("3", 0)) + int(r3["bolas"].get("6", 0)) == int(r3["abates"]) and int(r3["tentativas_shiny"]) == int(r3["shiny"]),
		"os dois ligados: Super Ball nos comuns, Idle Ball nos shinies", str(r3["bolas"]))
	var r4 := rodar(dados, larv, "larvitar", 5, {"auto_catch": true, "bola_auto_catch": 3, "auto_catch_shiny": true, "bola_auto_catch_shiny": 6, "auto_catch_nomes": "pidgey", "parametros": {"shiny_chance": 0.3}}, 9)
	checar(r4["bolas"].is_empty(), "o filtro de nomes vale para os dois modos (C)", str(r4["bolas"]))
	# shinyBase por tier (classe 3): Idle Ball (catchRate 5) × base do tier da Larvitar
	var tier := String(dados.shiny[246]["tier"])
	var p := Regras.PARAMETROS.duplicate(true)
	preload("res://sim/balanceamento.gd").aplicar(p, "combate")
	var ch := Regras.chance_captura_shiny(6, tier, p)
	checar(ch > 0.0 and ch < 0.2 and Regras.chance_captura_shiny(5, tier, p) == 1.0, "captura do shiny: base do tier × catchRate (Idle %.1f%%), Master Ball garante" % (100 * ch))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
