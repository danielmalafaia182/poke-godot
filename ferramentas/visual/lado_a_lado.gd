extends SceneTree
## Lado a lado (ciclo 4): o quadro do original (sem a moldura do navegador: corta 40 px à esquerda e 86 px em cima) e o
## print do nosso jogo, na mesma altura, lado a lado, com uma faixa de 6 px. Salva em JPG (qualidade 0.85).
## Uso: godot --headless --path . --script res://ferramentas/visual/lado_a_lado.gd -- <original.png> <nosso.png> <saida.jpg>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var orig := Image.load_from_file(a[0])
	orig = orig.get_region(Rect2i(40, 86, orig.get_width() - 40, orig.get_height() - 86))
	var nosso := Image.load_from_file(a[1])
	var h := 720
	orig.resize(int(orig.get_width() * float(h) / orig.get_height()), h, Image.INTERPOLATE_LANCZOS)
	nosso.resize(int(nosso.get_width() * float(h) / nosso.get_height()), h, Image.INTERPOLATE_LANCZOS)
	orig.convert(Image.FORMAT_RGB8)
	nosso.convert(Image.FORMAT_RGB8)
	var out := Image.create(orig.get_width() + nosso.get_width() + 6, h, false, Image.FORMAT_RGB8)
	out.fill(Color("c9a86a"))
	out.blit_rect(orig, Rect2i(Vector2i.ZERO, orig.get_size()), Vector2i.ZERO)
	out.blit_rect(nosso, Rect2i(Vector2i.ZERO, nosso.get_size()), Vector2i(orig.get_width() + 6, 0))
	out.save_jpg(a[2], 0.85)
	print("LADO A LADO ", a[2])
	quit(0)
