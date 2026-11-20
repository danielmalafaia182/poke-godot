extends Control

# Novo: fluxo do cliente: Talk -> descrição -> Heal Team; cura validada pela cidade.
# Ciclo 4 (C: CSS .npc-dialog/.npc-dlg-*, catálogo c5 e o texto hud.world.npcAction.healTeam; A: vídeo, quadro v1_00123):
# janela de 340 px, ícone /assets/npc/nurse.png de 48 px, nome em Cinzel 18 #f0e6d2, descrição 13 px #b9c3cf, botão
# dourado centralizado (padding 9×18, raio 8) "💊 Curar equipe"; medidas em px da tela de 1880 do original.
signal cura_solicitada
const ESTILO: Script = preload("res://estilo_hud_original.gd")
const T := preload("res://textos.gd")
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
	icone.texture = preload("res://assets/original/npc/nurse.png")
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
	curar.text = T.t("hud.world.npcAction.healTeam", {}, "💊 Heal team")
	curar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	curar.add_theme_font_override("font", preload("res://assets/interface/fiel/barlow_bold.ttf"))
	curar.add_theme_font_size_override("font_size", 14)
	curar.add_theme_color_override("font_color",Color("1a1206"))
	for estado in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = ESTILO.plano(Color("d7b76e") if estado == "normal" else Color("e6cd8e"), Color("6a5223"), 8)
		sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 9; sb.content_margin_bottom = 9
		curar.add_theme_stylebox_override(estado, sb)
	curar.add_theme_color_override("font_hover_color",Color("1a1206"))
	curar.pressed.connect(func() -> void: cura_solicitada.emit())
	corpo.add_child(curar)
	resized.connect(_ajustar)
	hide()

func abrir() -> void:
	show()
	_ajustar()
	call_deferred("_ajustar")

func _ajustar() -> void:
	var f := maxf(0.5, size.x / 1880.0)   # o original mede em px da tela de 1880
	janela.scale = Vector2(f, f)
	janela.size = Vector2(340,0).max(janela.get_combined_minimum_size())
	janela.position = ((size-janela.size*f)*0.5).round()
