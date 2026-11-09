extends SceneTree
## Desenha um mapa com render/mapa_renderizador.gd numa janela e salva uma captura (inspeção visual).
## Uso: testes/rodar_janela.sh res://testes/ver_mapa.gd -- --slug rhydon --x -2 --y 1 --saida saida_testes/mapa.png

const Renderizador := preload("res://render/mapa_renderizador.gd")

var r: Node2D
var quadros := 0
var args := {"slug": "rhydon", "x": "-2", "y": "1", "saida": "saida_testes/mapa.png", "escala": "2.4"}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			args[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	get_root().size = Vector2i(1920, 1080)
	var t0 := Time.get_ticks_msec()
	r = Renderizador.new()
	get_root().add_child(r)
	var centro := Vector2(float(args["x"]), float(args["y"]))
	r.carregar(String(args["slug"]), centro)
	var esc := float(args["escala"])
	r.tiles_visiveis = Vector2(1920, 1080) / (32.0 * esc)
	r.definir_centro(centro)
	r.scale = Vector2(esc, esc)
	r.position = Vector2(960, 540) - (centro * 32.0 + Vector2(16, 16)) * esc
	print("carregado em %d ms; sprites no ar: %d; chunks: %d; páginas: %s" % [Time.get_ticks_msec() - t0,
		r.estatisticas["sprites_carregados"], r.estatisticas["chunks"], str(r.paginas_necessarias())])


func _process(_d: float) -> bool:
	quadros += 1
	if quadros == 30:
		var img := get_root().get_texture().get_image()
		var caminho := ProjectSettings.globalize_path("res://") + String(args["saida"])
		img.save_png(caminho)
		print("captura: ", caminho)
		return true
	return false
