extends SceneTree
## Roda a simulação headless e grava JSONL no formato do gravador.
## Uso: testes/rodar.sh res://testes/rodar_sim.gd --estado dados/testes/estado_rhydon_venusaur.json \
##        --segundos 3600 --semente 1 --saida saida_testes/sim_rhydon.jsonl

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Gravador := preload("res://sim/gravador_jsonl.gd")


static func argumentos() -> Dictionary:
	var a := {"estado": "dados/testes/estado_rhydon_venusaur.json", "segundos": "3600", "semente": "1", "saida": "saida_testes/sim.jsonl"}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i].begins_with("--") and i + 1 < args.size():
			a[args[i].substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
	return a


static func caminho_absoluto(c: String) -> String:
	if c.is_absolute_path() or c.begins_with("res://") or c.begins_with("user://"):
		return ProjectSettings.globalize_path(c) if c.begins_with("res://") else c
	return Fontes.raiz_projeto() + "/" + c


static func ler_params(texto: String) -> Dictionary:
	## "chave=valor,chave2=valor2" → sobrescreve PARAMETROS (só para experimentos de sensibilidade).
	var r := {}
	for par in texto.split(",", false):
		var kv := par.split("=")
		if kv.size() == 2:
			r[kv[0].strip_edges()] = str_to_var(kv[1].strip_edges())
	return r


static func simular(estado: String, segundos: int, semente: int, params: Dictionary = {}) -> Dictionary:
	var dados = DadosJogo.carregar()
	var cfg := Cenario.de_estado(caminho_absoluto(estado), dados, semente)
	cfg["parametros"] = params
	var mapa = MapaHunt.carregar(cfg["slug"], Fontes.ler_mapa(cfg["slug"]), Fontes.ler_colisao())
	var sim = Simulacao.new(cfg, dados, mapa)
	var grav = Gravador.new("sim-%s-%d" % [cfg["slug"], semente])
	grav.adicionar(sim.iniciar())
	var ticks := segundos * 1000 / int(sim.p.tick_ms)
	for i in ticks:
		grav.adicionar(sim.passo())
	return {"sim": sim, "gravador": grav, "cfg": cfg}


func _init() -> void:
	var a := argumentos()
	var t0 := Time.get_ticks_msec()
	var r := simular(a["estado"], int(a["segundos"]), int(a["semente"]), ler_params(a.get("params", "")))
	var dt := Time.get_ticks_msec() - t0
	var saida := caminho_absoluto(a["saida"])
	r["gravador"].salvar(saida)
	print("simulados %s s em %d ms (%d linhas) -> %s" % [a["segundos"], dt, r["gravador"].linhas.size(), saida])
	print("estatísticas: ", r["sim"].estatisticas)
	quit(0)
