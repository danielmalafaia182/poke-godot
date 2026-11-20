extends SceneTree
## Recorte ampliado (vizinho mais próximo) para comparar nitidez: -- <entrada> <saida> x y w h fator
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0]).get_region(Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5])))
	img.resize(img.get_width() * int(a[6]), img.get_height() * int(a[6]), Image.INTERPOLATE_NEAREST)
	img.save_png(a[1])
	quit()
