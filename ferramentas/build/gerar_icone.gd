extends SceneTree
## Ícone do jogo (ciclo 3): a Poké Ball aberta do HUD original (assets/interface/hud/pokeball_open_v2.png) em 256/128/64/48/32/16
## px (PNG). O .ico é montado por ferramentas/build/montar_ico.py com esses PNGs.
func _init() -> void:
	var img := Image.load_from_file("res://assets/interface/hud/pokeball_open_v2.png")
	for t in [256, 128, 64, 48, 32, 16]:
		var c := img.duplicate()
		c.resize(t, t, Image.INTERPOLATE_LANCZOS if t > 128 else Image.INTERPOLATE_CUBIC)
		c.save_png(ProjectSettings.globalize_path("res://assets/interface/icone/icone_%d.png" % t))
	quit(0)
