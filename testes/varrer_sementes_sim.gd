extends SceneTree
## Varre sementes na simulação da cena nova (caca_sim usa esta mesma sim) com o time do test_movimento_selvagens:
## o Larvitar inicial (IVs/Quality do larvitar_inicial.tres) no nível 1, na hunt do Geodude, por N segundos.
## Uso: testes/rodar.sh res://testes/varrer_sementes_sim.gd -- --sementes 40 --segundos 60 [--slug geodude] [--nivel 1]

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const CenarioJogo := preload("res://sim/cenario_jogo.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")


func _arg(nome: String, padrao: String) -> String:
	var a := OS.get_cmdline_user_args()
	for i in a.size() - 1:
		if a[i] == "--" + nome:
			return a[i + 1]
	return padrao


func _init() -> void:
	var n := int(_arg("sementes", "40"))
	var seg := int(_arg("segundos", "60"))
	var slug := _arg("slug", "geodude")
	var nivel := int(_arg("nivel", "1"))
	var encher := _arg("encher_hp", "0") == "1"
	var formula := _arg("formula", "")   # como o test_movimento_selvagens: HP do aliado cheio a cada passo
	var larv: DadosPokemon = load("res://dados/pokemons/larvitar_inicial.tres")
	var especie_heroi := _arg("heroi", "Larvitar")   # outra espécie: IV 16 / Quality 1,0 (indivíduo mediano)
	var dados = DadosJogo.carregar()
	var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
	var ivs := {"hp": larv.iv_hp, "atk": larv.iv_atk, "def": larv.iv_def, "spAtk": larv.iv_sp_atk, "spDef": larv.iv_sp_def, "speed": larv.iv_spd}
	var q := larv.qualidade
	if especie_heroi != "Larvitar":
		ivs = {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}
		q = 1.0
	var jogo := {"slug": slug, "hunt": "Geodude", "equipe": [{"id": "h", "nome": especie_heroi, "xp": Regras.xp_total_para_nivel(nivel),
		"ivs": ivs, "quality": q, "hp": -1}], "auto_catch": false, "auto_potion": false, "penalizar": false, "bolas": {}}
	var danos := {}
	var sem_abate := 0
	for s in range(1, n + 1):
		var cfg := CenarioJogo.configurar(jogo, dados, s, 0)
		if formula != "":
			cfg["parametros"]["formula_dano"] = formula   # variante da fórmula (sim/regras.gd PARAMETROS.formula_dano)
		var sim = Simulacao.new(cfg, dados, mapa)
		sim.iniciar()
		var primeiro := -1
		var msgs_alvo := 0
		var dist_min := 999
		for t in seg * 5:
			if encher:
				sim.equipe[0]["hp"] = int(sim.equipe[0]["max_hp"])
			var _lote: Array = []
			for reg in sim.passo():
				_lote.append(reg.get("msg", reg) if reg is Dictionary else reg)   # passo() devolve registros {t, msg}
			for m in _lote:
				if String(m.get("type", "")) == "field-kill" and primeiro < 0:
					primeiro = t
				if String(m.get("type", "")) == "field":
					for h in m.get("hits", []):
						if int(h["slot"]) >= 0:
							var k := "%s→%d" % [h["move"], int(h["amount"])]
							danos[k] = int(danos.get(k, 0)) + 1
			if sim.heroi.get("alvo", -1) is int and int(sim.heroi["alvo"]) >= 0:
				msgs_alvo += 1
		var ab := int(sim.estatisticas["abates"])
		if ab == 0:
			sem_abate += 1
		print("SEMENTE %d abates=%d primeiro_abate_s=%s hits_aliado=%d hp=%d/%d" % [s, ab,
			("%.1f" % (primeiro * 0.2)) if primeiro >= 0 else "-", int(sim.estatisticas["hits_aliado"]),
			int(sim.equipe[0]["hp"]), int(sim.equipe[0]["max_hp"])])
	print("DANOS do aliado (golpe→dano: vezes): ", danos)
	print("SEM_ABATE %d de %d (slug %s, nível %d, %d s, HP cheio %s, fórmula %s)" % [sem_abate, n, slug, nivel, seg, encher, formula if formula != "" else "atual"])
	quit(0)
