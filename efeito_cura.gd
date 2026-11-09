extends Node2D

# Novo: feedback visual do protótipo. Não consome item nem modifica a vida.
func configurar(cura: int) -> void:
	z_index = 120
	var texto: Label = Label.new()
	texto.text = "+" + str(cura) + " HP"
	texto.position = Vector2(-60.0, -60.0)
	texto.size = Vector2(120.0, 26.0)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_color_override("font_color", Color("6dff95"))
	texto.add_theme_color_override("font_outline_color", Color.BLACK)
	texto.add_theme_constant_override("outline_size", 4)
	texto.add_theme_font_size_override("font_size", 18)
	add_child(texto)
	var animacao: Tween = create_tween()
	animacao.set_parallel(true)
	animacao.tween_property(texto, "position:y", -94.0, 0.8)
	animacao.tween_property(texto, "modulate:a", 0.0, 0.5).set_delay(0.3)
	animacao.chain().tween_callback(queue_free)
