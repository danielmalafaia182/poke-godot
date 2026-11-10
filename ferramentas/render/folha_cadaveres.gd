extends SceneTree
const Fontes := preload("res://sim/fontes.gd")
func _initialize() -> void:
	var snap := Fontes.pasta_snapshot()
	var d = Fontes.ler_json(snap + "/game/corpses/corpses.json")
	var paginas := []
	for p in d["pages"]:
		var img := Image.new()
		var ok := false
		for base in [snap, Fontes.raiz_projeto() + "/poke-local/public"]:
			var c: String = base + String(p)
			if FileAccess.file_exists(c) and img.load_webp_from_buffer(FileAccess.get_file_as_bytes(c)) == OK:
				ok = true
				break
		img.convert(Image.FORMAT_RGBA8)
		paginas.append(img if ok else null)
	var ids: Array = d["assets"].keys()
	var de := int(OS.get_cmdline_user_args()[0])
	var n := 80
	var folha := Image.create_empty(10 * 70, 8 * 70, false, Image.FORMAT_RGBA8)
	folha.fill(Color(0.25, 0.3, 0.25))
	var lista := []
	for i in range(de, mini(de + n, ids.size())):
		var a: Dictionary = d["assets"][ids[i]]
		var f: Dictionary = a["frames"][0]
		var pg = paginas[int(f["page"])]
		var k := i - de
		if pg != null:
			folha.blit_rect(pg, Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"])), Vector2i((k % 10) * 70 + 3, (k / 10) * 70 + 3))
		lista.append("%d:%s(%dx%d)" % [k, ids[i], int(a["width"]), int(a["height"])])
	folha.save_png(ProjectSettings.globalize_path("res://saida_testes/folha_cadaveres_%d.png" % de))
	print("FOLHA ", " ".join(lista))
	quit(0)
