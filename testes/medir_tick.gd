extends SceneTree
## Mede o tempo de cada tick da simulação (sem gravar), para comparar o p99 do tick entre versões.
## Uso: testes/rodar.sh res://testes/medir_tick.gd --estado dados/testes/estado_rhydon_venusaur_1h.json --segundos 1800

const Sim := preload("res://testes/rodar_sim.gd")
const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")


func _init() -> void:
	var a: Dictionary = Sim.argumentos()
	var segundos := int(a.get("segundos", "1800"))
	var t0 := Time.get_ticks_usec()
	var dados = DadosJogo.carregar()
	var cfg := Cenario.de_estado(Sim.caminho_absoluto(String(a["estado"])), dados, 1)
	var mapa = MapaHunt.carregar(cfg["slug"], Fontes.ler_mapa(cfg["slug"]), Fontes.ler_colisao())
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	var carga_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var tempos := PackedFloat64Array()
	for i in segundos * 5:
		var u := Time.get_ticks_usec()
		sim.passo()
		tempos.append((Time.get_ticks_usec() - u) / 1000.0)
	var v := Array(tempos)
	v.sort()
	var n := v.size()
	var soma := 0.0
	for x in v:
		soma += x
	print("TICK carga_ms=%.1f ticks=%d media_ms=%.3f p50=%.3f p99=%.3f max=%.3f" % [carga_ms, n, soma / n, v[n / 2], v[int(0.99 * n)], v[n - 1]])
	quit(0)
