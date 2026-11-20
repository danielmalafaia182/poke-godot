extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var imgs: Array = []
	for i in range(1, a.size()):
		imgs.append(Image.load_from_file(a[i]))
	var w := 0
	var h := 0
	for im in imgs:
		w += im.get_width() + 4
		h = maxi(h, im.get_height())
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color("c9a86a"))
	var x := 0
	for im in imgs:
		im.convert(Image.FORMAT_RGBA8)
		out.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, 0))
		x += im.get_width() + 4
	out.save_png(a[0])
	quit()
