extends SceneTree
## Placas do herói e do treinador no mesmo tile (E): a do treinador fica empilhada acima e não sobrepõe.
## Rodar: testes/rodar.sh res://testes/test_placas.gd
const Vista := preload("res://render/vista_hunt.gd")
var falhas := 0
var total := 0
func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))
func _initialize() -> void:
	for esc in [1.0, 2.25]:
		var h := Vector2(960, 500)
		var mesmo: Vector2 = Vista.empilhar_placa(h, h, esc)
		checar(is_equal_approx(mesmo.y, h.y - 16.0 * esc) and mesmo.x == h.x, "mesmo tile: treinador 16 px lógicos acima (esc %.2f)" % esc, str(mesmo))
		# a placa tem ~16 px lógicos de altura (nome 11 px + barra): empilhada, não sobrepõe
		checar(h.y - mesmo.y >= 16.0 * esc - 0.01, "sem sobreposição vertical (esc %.2f)" % esc)
		var longe: Vector2 = Vista.empilhar_placa(h + Vector2(32 * esc, 32 * esc), h, esc)
		checar(longe == h + Vector2(32 * esc, 32 * esc), "um tile na diagonal: posição própria (esc %.2f)" % esc)
		var lado: Vector2 = Vista.empilhar_placa(h + Vector2(32 * esc, 0), h, esc)
		checar(lado.y < h.y and lado.y > h.y - 16.0 * esc, "um tile ao lado: sobe só em parte (esc %.2f)" % esc, str(lado))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
