class_name CartaoPokemonDepot
extends Button
const UI: Script = preload("res://estilo_ui_fiel.gd")
const VISUAL: Script = preload("res://visual_pokemon.gd")
const TIPOS: Script = preload("res://tipos_pokemon.gd")
const ESTILO: Script = preload("res://estilo_team.gd")
const FICHA: Script = preload("res://ficha_pokemon_depot.gd")
var pokemon: DadosPokemon
var no_time: bool
var lider: bool
var inicial: bool
func configurar(individuo: DadosPokemon, guardar: bool, ativo: bool, protegido: bool) -> void:
	pokemon = individuo
	no_time = guardar
	lider = ativo
	inicial = protegido
	custom_minimum_size.y = 50
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var estilo: StyleBoxTexture = preload("res://estilo_depot_fiel.gd").cartao(lider)
	add_theme_stylebox_override("normal",estilo)
	add_theme_stylebox_override("hover",preload("res://estilo_depot_fiel.gd").cartao(lider,true))
	add_theme_stylebox_override("pressed",estilo)
	add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	tooltip_text = "Inicial: permanece no TEAM." if inicial else ("Store in the BOX" if no_time else "Send to the team")
	var linha: HBoxContainer = HBoxContainer.new()
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 8
	linha.offset_right = -8
	linha.offset_top = 5
	linha.offset_bottom = -5
	linha.add_theme_constant_override("separation",7)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(linha)
	var icone: Control = Control.new()
	icone.custom_minimum_size = Vector2(32,36)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(icone)
	var retrato: TextureRect = TextureRect.new()
	retrato.texture = VISUAL.retrato_frente(pokemon.especie.nome)
	if retrato.texture==null: retrato.texture=pokemon.especie.textura
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if retrato.texture!=null:
		var escala: float = minf(28.0/retrato.texture.get_width(),30.0/retrato.texture.get_height())
		retrato.size = retrato.texture.get_size()*escala
		retrato.position = ((Vector2(32,36)-retrato.size)*0.5).floor()
	icone.add_child(retrato)
	var textos: VBoxContainer = VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	textos.add_theme_constant_override("separation",2)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(textos)
	var nome: Label = UI.texto(pokemon.especie.nome+(" ⚔" if lider else ""),12,Color("fff4dc"),true)
	nome.clip_text = true
	textos.add_child(nome)
	var detalhes: HBoxContainer = HBoxContainer.new()
	detalhes.add_theme_constant_override("separation",3)
	detalhes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(detalhes)
	detalhes.add_child(UI.texto("Lv %d · IV %d/192 ·" % [pokemon.nivel,pokemon.obter_total_ivs()],10,Color("9fb0c8"),true))
	var q: Dictionary = ESTILO.qualidade(pokemon.qualidade)
	detalhes.add_child(UI.texto(q["nome"],10,q["cor"],true))
	var seta: Label = UI.texto("" if inicial else ("→" if no_time else "←"),17,Color("c8aa6e"))
	linha.add_child(seta)
func _make_custom_tooltip(_for_text: String) -> Object:
	return FICHA.criar(pokemon,no_time,lider,inicial)
