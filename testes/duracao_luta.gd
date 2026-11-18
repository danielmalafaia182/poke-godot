extends SceneTree
## Duração da luta (s por abate, pelos golpes do aliado × 1,6 s) do time de uma gravação em outras hunts, para escolher a
## hunt de uma gravação de "luta média" (item 5 de 18/11). Uso: testes/rodar.sh res://testes/duracao_luta.gd
##   --estado dados/testes/estado_kangaskhan_venusaur_m2.json --nivel 80 [--minutos 4]
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")

func _init() -> void:
	var a := {"estado": "dados/testes/estado_kangaskhan_venusaur_m2.json", "nivel": "80", "minutos": "4", "area": "kanto"}
	var ar := OS.get_cmdline_user_args()
	for i in ar.size():
		if String(ar[i]).begins_with("--") and i + 1 < ar.size():
			a[String(ar[i]).substr(2)] = ar[i + 1]
	var dados = DadosJogo.carregar()
	var est := Fontes.raiz_projeto() + "/" + String(a["estado"])
	var slugs: Array = []
	for s in dados.hunts:
		if int(dados.hunts[s]["nivel"]) == int(a["nivel"]) and String(dados.hunts[s]["area"]) == String(a["area"]):
			slugs.append(s)
	slugs.sort()
	for s in slugs:
		var cfg := Cenario.de_estado(est, dados, 3, s)
		cfg["entrada_nova"] = false
		var sim = Simulacao.new(cfg, dados, MapaHunt.carregar(s, Fontes.ler_mapa(s), Fontes.ler_colisao()))
		sim.iniciar()
		for t in int(float(a["minutos"]) * 300):
			sim.passo()
			if sim.encerrada:
				break
		var ab := int(sim.estatisticas["abates"])
		print("LUTA %s abates %d  golpes/abate %.1f  s de luta/abate %.1f  kos %d" % [s, ab, float(sim.estatisticas["hits_aliado"]) / maxf(1, ab),
			1.6 * float(sim.estatisticas["hits_aliado"]) / maxf(1, ab), int(sim.estatisticas["kos"])])
	quit(0)
