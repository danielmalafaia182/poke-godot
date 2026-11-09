extends SceneTree
## Hunt simulada desenhada pela vista do cliente (render/vista_hunt.gd), em processo e em tempo real, numa janela.
## Mede o frame time (média, p50, p95, p99, máx) e salva capturas. Rodar com janela 1920×1080:
##   testes/rodar_janela.sh res://testes/ver_hunt.gd --slug rhydon --segundos 60 --saida saida_testes/hunt_rhydon
## O save real nunca é tocado (rodar_janela.sh isola o APPDATA; a simulação não usa user://).

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Vista := preload("res://render/vista_hunt.gd")

var args := {"slug": "rhydon", "segundos": "60", "saida": "saida_testes/hunt", "estado": "dados/testes/estado_rhydon_venusaur_1h.json",
	"semente": "1", "capturas": "5,20,40", "aquecimento": "3"}
var sim: RefCounted
var vista: Node2D
var t0 := 0.0
var proximo_tick := 0.0
var tempos: PackedFloat64Array = PackedFloat64Array()
var capturas: Array = []
var _ultimo_us := 0
var mensagens := 0
var _descartar := false
var capturas_feitas := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			args[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	for c in String(args["capturas"]).split(",", false):
		capturas.append(float(c))
	# janela sem borda de 1920×1080 na origem: a área de desenho é exatamente 1920×1080 (com borda, a barra de título
	# tira ~20 px da altura)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var dados = DadosJogo.carregar()
	var slug := String(args["slug"])
	var cfg := Cenario.de_estado(Fontes.raiz_projeto() + "/" + String(args["estado"]), dados, int(args["semente"]),
		"" if slug == "rhydon" else slug)
	cfg["inicio_ms"] = int(Time.get_unix_time_from_system() * 1000.0)
	cfg["entrada_nova"] = true
	var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
	sim = Simulacao.new(cfg, dados, mapa)
	vista = Vista.new()
	get_root().add_child(vista)
	var t := Time.get_ticks_msec()
	for m in sim.iniciar():
		_entregar(m)
	print("mapa e simulação prontos em %d ms" % (Time.get_ticks_msec() - t))
	t0 = Time.get_ticks_msec() / 1000.0
	proximo_tick = Time.get_ticks_msec() + 200.0
	_ultimo_us = Time.get_ticks_usec()


func _entregar(m: Dictionary) -> void:
	vista.receber(m["msg"] if m.has("msg") else m)
	mensagens += 1


func _process(_d: float) -> bool:
	var agora_us := Time.get_ticks_usec()
	var dt_ms := (agora_us - _ultimo_us) / 1000.0
	_ultimo_us = agora_us
	var agora := float(Time.get_ticks_msec())
	while agora >= proximo_tick:
		for m in sim.passo():
			_entregar(m)
		proximo_tick += 200.0
	var dec := agora / 1000.0 - t0
	if dec >= float(args["aquecimento"]) and not _descartar:
		tempos.append(dt_ms)
	_descartar = false
	if not capturas.is_empty() and dec >= float(capturas[0]):
		var seg := int(capturas.pop_front())
		var img := get_root().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://") + "%s_%ds.png" % [String(args["saida"]), seg])
		_descartar = true      # o quadro seguinte paga a leitura da GPU e o PNG: não entra na medição
		capturas_feitas += 1
	if dec >= float(args["segundos"]):
		_relatorio()
		return true
	return false


func _relatorio() -> void:
	var v := Array(tempos)
	v.sort()
	var n := v.size()
	var soma := 0.0
	for x in v:
		soma += x
	var p := func(q: float) -> float: return v[mini(n - 1, int(q * n))]
	var r := {"slug": args["slug"], "janela": [get_root().size.x, get_root().size.y], "quadros": n,
		"media_ms": soma / maxf(1, n), "p50_ms": p.call(0.5), "p95_ms": p.call(0.95), "p99_ms": p.call(0.99), "max_ms": v[n - 1],
		"fps_medio": 1000.0 / (soma / maxf(1, n)), "acima_16_7ms": v.filter(func(x): return x > 16.7).size(),
		"sprites_no_ar": vista.mapa.estatisticas["sprites_carregados"], "abates": sim.estatisticas["abates"],
		"mensagens": mensagens, "capturas_excluidas": capturas_feitas, "outfits_substituidos": vista.outfits.trocas,
		"renderer": RenderingServer.get_video_adapter_name(), "vsync": DisplayServer.window_get_vsync_mode()}
	print(JSON.stringify(r))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://") + String(args["saida"]) + "_frametime.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
