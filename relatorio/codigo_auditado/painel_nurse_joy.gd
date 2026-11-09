extends Control

# Novo: fluxo do cliente: Talk -> descrição -> Heal Team; cura validada pela cidade.
signal cura_solicitada
const ESTILO: Script = preload("res://estilo_hud_original.gd")
var janela: PanelContainer
var curar: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tema: Theme = Theme.new()
	tema.default_font = preload("res://assets/interface/depot/barlow_semibold.ttf")
	tema.default_font_size = 13
	theme = tema
	var sombra: ColorRect = ColorRect.new()
	sombra.color = Color(0,0,0,0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			hide()
	)
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel",ESTILO.moldura())
	add_child(janela)
	var corpo: VBoxContainer = VBoxContainer.new()
	corpo.add_theme_constant_override("separation",12)
	janela.add_child(corpo)
	var cabecalho: HBoxContainer = HBoxContainer.new()
	corpo.add_child(cabecalho)
	var icone: TextureRect = TextureRect.new()
	icone.texture = preload("res://assets/interface/hud/nurse.png")
	icone.custom_minimum_size = Vector2(48,48)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cabecalho.add_child(icone)
	var nome: Label = Label.new()
	nome.text = "Nurse Joy"
	nome.add_theme_font_override("font",preload("res://assets/interface/depot/cinzel.ttf"))
	nome.add_theme_font_size_override("font_size",18)
	nome.add_theme_color_override("font_color",Color("f0e6d2"))
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(nome)
	var fechar: Button = Button.new()
	fechar.text = "×"
	fechar.pressed.connect(hide)
	cabecalho.add_child(fechar)
	var descricao: Label = Label.new()
	descricao.text = "Cura todos os Pokémon da sua equipe."
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descricao.add_theme_color_override("font_color",Color("b9c3cf"))
	corpo.add_child(descricao)
	curar = Button.new()
	curar.text = "Heal Team"
	curar.custom_minimum_size.y = 38
	curar.add_theme_color_override("font_color",Color("1a1206"))
	curar.add_theme_stylebox_override("normal",ESTILO.plano(Color("d3b36b"),Color("6a5223"),8))
	curar.add_theme_stylebox_override("hover",ESTILO.plano(Color("e6cd8e"),Color("997530"),8))
	curar.pressed.connect(func() -> void: cura_solicitada.emit())
	corpo.add_child(curar)
	resized.connect(_ajustar)
	hide()

func abrir() -> void:
	show()
	_ajustar()
	call_deferred("_ajustar")

func _ajustar() -> void:
	janela.size = Vector2(340,190).max(janela.get_combined_minimum_size())
	janela.position = (size-janela.size)*0.5
