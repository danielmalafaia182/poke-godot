extends Button
signal visual_alterado
const UI: Script=preload("res://estilo_ui_fiel.gd")
const ESTILO: Script=preload("res://estilo_mapa_fiel.gd")
var dados: Dictionary
var sobre: bool=false
var circulo: TextureRect
var rotulo_nivel: Label
func configurar(registro: Dictionary, textura: Texture2D, nivel: int) -> void:
	dados=registro
	text=""
	focus_mode=Control.FOCUS_NONE
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if dados["implementado"] else Control.CURSOR_HELP
	for estado in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(estado,StyleBoxEmpty.new())
	var nome: String=str(dados["name"])
	var largura: float=maxf(56,ceilf(UI.TITULO.get_string_size(nome,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)+6)
	size=Vector2(largura,84 if int(dados["level"])>0 else 70)
	circulo=TextureRect.new()
	circulo.texture=ESTILO.circulo(dados["implementado"],false)
	circulo.position=Vector2((largura-64)*0.5,-6)
	circulo.size=Vector2(64,64)
	circulo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	circulo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(circulo)
	var imagem: TextureRect=TextureRect.new()
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	imagem.texture=textura
	imagem.position=Vector2((largura-42)*0.5,5)
	imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	imagem.size=Vector2(42,42)
	imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(imagem)
	imagem.set_deferred("size",Vector2(42,42))
	var titulo: Label=UI.texto(nome,12,Color("f0e6d2"),true)
	titulo.add_theme_font_override("font",UI.TITULO)
	titulo.position=Vector2(0,55)
	titulo.size.x=largura
	titulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_outline_color",Color.BLACK)
	titulo.add_theme_constant_override("outline_size",2)
	add_child(titulo)
	if int(dados["level"])>0:
		var lv: Label=UI.texto("Lv %d" % int(dados["level"]),11,Color("63d873") if nivel>=int(dados["level"]) else Color("e5645a"),true)
		rotulo_nivel=lv
		lv.add_theme_font_override("font",UI.TITULO)
		lv.position=Vector2(0,70)
		lv.size.x=largura
		lv.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		lv.add_theme_color_override("font_outline_color",Color.BLACK)
		lv.add_theme_constant_override("outline_size",2)
		add_child(lv)
	tooltip_text=nome+" · Lv "+str(int(dados["level"]))+( " — entrar na caça" if dados["implementado"] else " — referência do original; destino ainda não implementado")
	mouse_entered.connect(_sobre.bind(true))
	mouse_exited.connect(_sobre.bind(false))
func _sobre(valor: bool) -> void:
	sobre=valor
	circulo.texture=ESTILO.circulo(dados["implementado"],sobre)
	z_index=3 if sobre else 2
	visual_alterado.emit()

func atualizar_nivel(nivel: int) -> void:
	if rotulo_nivel!=null: rotulo_nivel.add_theme_color_override("font_color",Color("63d873") if nivel>=int(dados["level"]) else Color("e5645a"))

func _make_custom_tooltip(_texto: String) -> Object:
	var painel: PanelContainer=PanelContainer.new()
	painel.custom_minimum_size.x=228
	painel.add_theme_stylebox_override("panel",UI.caixa(Color("08101cfa"),Color("c8aa6e"),8,9))
	var coluna: VBoxContainer=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",5)
	painel.add_child(coluna)
	var nome: Label=UI.texto(str(dados["name"]),13,Color("f0e6d2"),true)
	nome.add_theme_font_override("font",UI.TITULO)
	coluna.add_child(nome)
	coluna.add_child(UI.texto("Lv %d" % int(dados["level"]),11,Color("c8aa6e"),true))
	var tipos: HBoxContainer=HBoxContainer.new()
	tipos.add_theme_constant_override("separation",5)
	coluna.add_child(tipos)
	for campo in ["type1","type2"]:
		var tipo: String=str(dados.get(campo,""))
		if tipo.is_empty(): continue
		var selo: PanelContainer=PanelContainer.new()
		selo.add_theme_stylebox_override("panel",UI.caixa(preload("res://tipos_pokemon.gd").cor(tipo).darkened(0.25),Color("ffffff33"),6,4))
		selo.add_child(UI.texto(tipo,9,Color.WHITE,true))
		tipos.add_child(selo)
	if bool(dados["implementado"]):
		coluna.add_child(UI.texto(("%d XP base · Clique para caçar" % int(preload("res://catalogo_hunts.gd").obter(str(dados["name"]))["xp"])),11,Color("8ad49f")))
	else:
		coluna.add_child(UI.texto("Caça indisponível nesta versão.",11,Color("9aa6b3")))
	return painel
