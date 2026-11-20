extends SceneTree
## Folhas de contato dos quadros de referência (referencia_visual/quadros/brutos): 20 miniaturas por folha (5×4), na
## ordem dos arquivos, para separar os quadros por tela. Saída: referencia_visual/quadros/folhas/folha_NN.png e
## folhas/indice.txt (folha → arquivos).
## Ciclo 5: com argumento (`-- <pasta>`, ex. teste_ciclo4), usa referencia_visual/<pasta>/quadros (sem "brutos").
func _init() -> void:
	var raiz := ProjectSettings.globalize_path("res://referencia_visual/quadros")
	var brutos := "/brutos"
	if OS.get_cmdline_user_args().size() > 0:
		raiz = ProjectSettings.globalize_path("res://referencia_visual/" + OS.get_cmdline_user_args()[0] + "/quadros")
		brutos = ""
	var d := DirAccess.open(raiz + brutos)
	var arqs: Array = Array(d.get_files()).filter(func(f): return f.ends_with(".png"))
	arqs.sort()
	DirAccess.make_dir_recursive_absolute(raiz + "/folhas")
	var idx := FileAccess.open(raiz + "/folhas/indice.txt", FileAccess.WRITE)
	var W := 384
	var H := 216
	var n := 0
	for i in range(0, arqs.size(), 20):
		var folha := Image.create(W * 5, H * 4, false, Image.FORMAT_RGB8)
		var nomes: Array = []
		for j in 20:
			if i + j >= arqs.size():
				break
			var img := Image.load_from_file(raiz + brutos + "/" + arqs[i + j])
			img.convert(Image.FORMAT_RGB8)
			img.resize(W - 4, H - 4, Image.INTERPOLATE_BILINEAR)
			folha.blit_rect(img, Rect2i(0, 0, W - 4, H - 4), Vector2i((j % 5) * W + 2, (j / 5) * H + 2))
			nomes.append(arqs[i + j])
		folha.save_png(raiz + "/folhas/folha_%02d.png" % n)
		idx.store_line("folha_%02d: %s" % [n, " ".join(PackedStringArray(nomes))])
		n += 1
	idx.close()
	print("FOLHAS ", n)
	quit(0)
