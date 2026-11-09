extends RefCounted
# Alterações visuais da cidade: HP/EXP arredondados, fonte Barlow e texto proporcional à altura.

# Novo: HP e EXP usam o mesmo desenho no HUD e na janela TEAM.
static func criar(pokemon: DadosPokemon, experiencia: bool = false, altura: int = 9) -> ProgressBar:
	var barra: ProgressBar = ProgressBar.new()
	barra.custom_minimum_size.y = altura
	barra.show_percentage = false
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.max_value = 100.0 if experiencia else float(pokemon.obter_vida_maxima())
	barra.value = float(pokemon.experiencia_percentual) if experiencia else float(pokemon.obter_vida_atual())
	var estilo: Script = preload("res://estilo_hud_original.gd")
	barra.add_theme_stylebox_override("background",estilo.plano(Color("0a0f16"),Color("000000d9"),5))
	# Alteração: HP e EXP usam cápsulas com brilho e pontas arredondadas.
	barra.add_theme_stylebox_override("fill",estilo.capsula(experiencia,altura))
	if experiencia:
		barra.tooltip_text = "Curva de XP do cliente original. A caça concede a recompensa confirmada ao líder."
	var texto: Label = Label.new()
	texto.text = "EXP %d%%" % roundi(pokemon.experiencia_percentual) if experiencia else "%d/%d" % [pokemon.obter_vida_atual(),pokemon.obter_vida_maxima()]
	texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.add_theme_font_override("font",preload("res://assets/interface/depot/barlow_semibold.ttf"))
	texto.add_theme_font_size_override("font_size",6 if altura < 8 else (8 if altura < 12 else 11))
	texto.add_theme_color_override("font_outline_color",Color.BLACK)
	texto.add_theme_constant_override("outline_size",2)
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(texto)
	return barra

# Atualiza os controles existentes, sem criar estilos, texturas ou nós.
static func atualizar(barra: ProgressBar, pokemon: DadosPokemon, experiencia: bool = false) -> void:
	if experiencia:
		barra.max_value = 100.0
		barra.value = pokemon.experiencia_percentual
	else:
		barra.max_value = pokemon.obter_vida_maxima()
		barra.value = pokemon.obter_vida_atual()
	var texto: Label = barra.get_child(0) as Label
	texto.text = "EXP %d%%" % roundi(pokemon.experiencia_percentual) if experiencia else "%d/%d" % [pokemon.obter_vida_atual(),pokemon.obter_vida_maxima()]
