extends Control
# Catálogo original para apresentação; somente destinos implementados podem viajar.
@export var acesso_hunts_sem_limite: bool=true
@export var destinos: Array[DadosDestinoCaca]=[]
const UI: Script=preload("res://estilo_ui_fiel.gd")
const ESTILO: Script=preload("res://estilo_mapa_fiel.gd")
const TIPOS: Script=preload("res://tipos_pokemon.gd")
const MARCADOR: Script=preload("res://marcador_mapa_fiel.gd")
const ORDEM: Array[String]=["STEEL","WATER","DRAGON","ELECTRIC","FAIRY","GHOST","FIRE","ICE","BUG","FIGHTING","NORMAL","ROCK","GRASS","PSYCHIC","DARK","GROUND","POISON","FLYING"]
var janela: PanelContainer
var buscas: LineEdit
var nivel_de: LineEdit
var nivel_ate: LineEdit
var contador: Label
var aviso: Label
var navegacao: Control
var imagem_mapa: TextureRect
var marcadores: Dictionary[Button,Dictionary]={}
var botoes_tipos: Dictionary={}
var botoes_regioes: Array[Button]=[]
var tipo_selecionado: String=""
var catalogo: Array[Dictionary]=[]
var _primeira_abertura: bool=true
var _iniciando_visao: bool=false
var _arrastando_janela: bool=false
var _janela_movida: bool=false
var _offset_arrasto: Vector2
func _ready() -> void:
	preload("res://tela_jogo.gd").aplicar(get_window())
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var tema: Theme=Theme.new()
	tema.default_font=UI.TEXTO
	tema.default_font_size=12
	tema.set_stylebox("panel","TooltipPanel",StyleBoxEmpty.new())
	theme=tema
	var sombra: ColorRect=ColorRect.new()
	sombra.color=Color("020509b3")
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed: hide()
	)
	janela=PanelContainer.new()
	janela.add_theme_stylebox_override("panel",ESTILO.janela())
	add_child(janela)
	var coluna: VBoxContainer=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",0)
	janela.add_child(coluna)
	_cabecalho(coluna)
	_regioes(coluna)
	_filtros(coluna)
	_tipos(coluna)
	navegacao=preload("res://mapa_navegacao.gd").new()
	navegacao.name="RolagemMapa"
	navegacao.custom_minimum_size.y=90
	navegacao.size_flags_vertical=Control.SIZE_EXPAND_FILL
	imagem_mapa=TextureRect.new()
	imagem_mapa.name="ImagemMapa"
	imagem_mapa.texture=preload("res://assets/interface/mapa/hunts.png")
	imagem_mapa.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	imagem_mapa.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	imagem_mapa.size=imagem_mapa.texture.get_size()
	imagem_mapa.mouse_filter=Control.MOUSE_FILTER_IGNORE
	navegacao.add_child(imagem_mapa)
	coluna.add_child(navegacao)
	navegacao.visao_alterada.connect(_reposicionar_marcadores)
	_criar_marcadores()
	EstadoJogo.perfil_alterado.connect(_atualizar_perfil)
	aviso=UI.texto("",12,Color("e8c98a"),true)
	aviso.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_stylebox_override("normal",UI.caixa(Color("08121af5"),Color("997530"),8,8))
	aviso.hide()
	add_child(aviso)
	resized.connect(_ajustar)
	visibility_changed.connect(_visibilidade)
	_ajustar()
	_aplicar_filtros()
	call_deferred("_inicializar_visao")
func _botao(texto: String, tamanho: int=12) -> Button:
	var b: Button=Button.new()
	b.text=texto
	b.add_theme_font_override("font",UI.FORTE)
	b.add_theme_font_size_override("font_size",tamanho)
	b.add_theme_color_override("font_color",Color("e8c98a"))
	b.add_theme_stylebox_override("normal",ESTILO.botao())
	b.add_theme_stylebox_override("hover",UI.caixa(Color("1a2c3c"),Color("c8aa6e"),7,4))
	b.add_theme_stylebox_override("pressed",UI.caixa(Color("071019"),Color("c8aa6e"),7,4))
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.focus_mode=Control.FOCUS_NONE
	return b
func _cabecalho(coluna: VBoxContainer) -> void:
	var cab: Control=Control.new()
	cab.custom_minimum_size.y=46
	cab.mouse_default_cursor_shape=Control.CURSOR_DRAG
	coluna.add_child(cab)
	var fundo: NinePatchRect=NinePatchRect.new()
	fundo.texture=preload("res://assets/interface/depot/cabecalho.svg")
	fundo.patch_margin_left=24
	fundo.patch_margin_right=24
	fundo.patch_margin_top=8
	fundo.patch_margin_bottom=8
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.offset_left=-14
	fundo.offset_right=14
	fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cab.add_child(fundo)
	var linha: HBoxContainer=HBoxContainer.new()
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left=8
	linha.offset_right=-10
	linha.add_theme_constant_override("separation",6)
	linha.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cab.add_child(linha)
	var icone: TextureRect=preload("res://estilo_resultado_combate.gd").icone(preload("res://assets/interface/hud/icon_map_globe_lens.png"),22)
	icone.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	linha.add_child(icone)
	var titulo: Label=UI.texto("Map · Kanto",18,Color("e8c98a"),true)
	titulo.add_theme_font_override("font",UI.TITULO)
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	titulo.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	linha.add_child(titulo)
	for simbolo in ["−","+","×"]:
		var b: Button=_botao(simbolo,16)
		b.custom_minimum_size=Vector2(28,28)
		b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		linha.add_child(b)
		if simbolo=="×":
			b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
			b.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
			b.add_theme_color_override("font_color",Color("9aa7b5"))
			b.add_theme_font_size_override("font_size",22)
			b.pressed.connect(_on_fechar_pressed)
		else: b.pressed.connect(func() -> void: navegacao.zoom_centro(1.2 if simbolo=="+" else 1.0/1.2))
	cab.gui_input.connect(_arrastar_janela)
func _regioes(coluna: VBoxContainer) -> void:
	var painel: PanelContainer=PanelContainer.new()
	painel.add_theme_stylebox_override("panel",UI.caixa(Color("08121a"),Color("99753047"),0,0))
	coluna.add_child(painel)
	var linha: HBoxContainer=HBoxContainer.new()
	linha.alignment=BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation",14)
	painel.add_child(preload("res://estilo_resultado_combate.gd").margem(linha,14,10,14,8))
	for regiao in ["kanto","outland","orre","nightmare"]:
		var b: Button=Button.new()
		b.custom_minimum_size=Vector2(150,72)
		b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if regiao=="kanto" else Control.CURSOR_HELP
		for estado in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(estado,StyleBoxEmpty.new())
		var imagem: TextureRect=TextureRect.new()
		imagem.texture=load("res://assets/interface/mapa/fiel/"+regiao+".png")
		imagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagem.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(imagem)
		linha.add_child(b)
		botoes_regioes.append(b)
		b.tooltip_text="Kanto" if regiao=="kanto" else regiao.capitalize()+" — região ainda não implementada no protótipo"
		b.pressed.connect(func() -> void:
			if regiao!="kanto": _mostrar_aviso(regiao.capitalize()+": região ainda não implementada.")
		)
func _campo(placeholder: String, largura: float) -> LineEdit:
	var e: LineEdit=LineEdit.new()
	e.placeholder_text=placeholder
	e.custom_minimum_size=Vector2(largura,28)
	e.add_theme_font_size_override("font_size",12)
	e.add_theme_color_override("font_color",Color("e6edf3"))
	e.add_theme_stylebox_override("normal",UI.caixa(Color("040a0e"),Color("9975304d"),7,6))
	e.add_theme_stylebox_override("focus",UI.caixa(Color("08131b"),Color("c8aa6e"),7,6))
	e.text_changed.connect(func(_s: String) -> void: _aplicar_filtros())
	return e
func _nivel(placeholder: String) -> Control:
	var linha: HBoxContainer=HBoxContainer.new()
	linha.add_theme_constant_override("separation",0)
	var campo: LineEdit=_campo(placeholder,38)
	if placeholder=="from": nivel_de=campo
	else: nivel_ate=campo
	linha.add_child(campo)
	var setas: VBoxContainer=VBoxContainer.new()
	setas.add_theme_constant_override("separation",0)
	linha.add_child(setas)
	for direcao in [1,-1]:
		var b: Button=_botao("▴" if direcao==1 else "▾",7)
		b.custom_minimum_size=Vector2(14,14)
		var estilo: StyleBoxFlat=UI.caixa(Color("15222d"),Color("384552"),2,0)
		b.add_theme_stylebox_override("normal",estilo)
		setas.add_child(b)
		b.pressed.connect(func() -> void:
			var valor: int=int(campo.text) if campo.text.is_valid_int() else 0
			campo.text=str(maxi(0,valor+direcao))
			_aplicar_filtros()
		)
	return linha
func _filtros(coluna: VBoxContainer) -> void:
	var painel: PanelContainer=PanelContainer.new()
	painel.add_theme_stylebox_override("panel",UI.caixa(Color("00000047"),Color("99753047"),0,0))
	coluna.add_child(painel)
	var linha: HFlowContainer=HFlowContainer.new()
	linha.add_theme_constant_override("h_separation",10)
	linha.add_theme_constant_override("v_separation",5)
	painel.add_child(preload("res://estilo_resultado_combate.gd").margem(linha,12,8,12,8))
	buscas=_campo("Search hunt...",220)
	linha.add_child(buscas)
	var lv: HBoxContainer=HBoxContainer.new()
	lv.add_theme_constant_override("separation",5)
	lv.add_child(UI.texto("Lv",12))
	lv.add_child(_nivel("from"))
	lv.add_child(UI.texto("–",12))
	lv.add_child(_nivel("to"))
	linha.add_child(lv)
	contador=UI.texto("",11,Color("c8aa6e"),true)
	contador.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	linha.add_child(contador)
	var limpar: Button=_botao("Clear",11)
	limpar.custom_minimum_size=Vector2(54,26)
	linha.add_child(limpar)
	limpar.pressed.connect(limpar_filtros)
func _tipos(coluna: VBoxContainer) -> void:
	var painel: PanelContainer=PanelContainer.new()
	painel.add_theme_stylebox_override("panel",UI.caixa(Color("00000035"),Color("99753047"),0,0))
	coluna.add_child(painel)
	var grade: GridContainer=GridContainer.new()
	grade.columns=9
	grade.add_theme_constant_override("h_separation",5)
	grade.add_theme_constant_override("v_separation",6)
	painel.add_child(preload("res://estilo_resultado_combate.gd").margem(grade,12,6,12,8))
	for tipo in ORDEM:
		var b: Button=Button.new()
		b.text=tipo
		b.icon=TIPOS.icone(tipo)
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",13)
		b.add_theme_constant_override("h_separation",3)
		b.add_theme_font_override("font",UI.FORTE)
		b.add_theme_font_size_override("font_size",8)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.custom_minimum_size=Vector2(0,19)
		b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void:
			tipo_selecionado="" if tipo_selecionado==tipo else tipo
			_aplicar_filtros()
		)
		grade.add_child(b)
		botoes_tipos[tipo]=b
func _criar_marcadores() -> void:
	var dados: Dictionary=_ler_json_mapa("res://dados/referencias/mapa_kanto.json")
	if dados.is_empty():return
	var atlas_dados: Dictionary=_ler_json_mapa("res://assets/interface/mapa/fiel/marker-atlas.json")
	if atlas_dados.is_empty():return
	var textura: Texture2D=preload("res://assets/interface/mapa/fiel/marker-atlas-72c2c2858beb.png")
	for registro in dados["hunts"]:
		registro["implementado"] = not preload("res://catalogo_hunts.gd").obter(str(registro["name"])).is_empty()
		catalogo.append(registro)
		var celula: Array=atlas_dados["slots"][str(int(registro["looktype"]))]
		var icone: AtlasTexture=AtlasTexture.new()
		icone.atlas=textura
		icone.region=Rect2(Vector2(float(celula[0]),float(celula[1]))*64,Vector2(64,64))
		var marcador: Button=MARCADOR.new()
		imagem_mapa.add_child(marcador)
		marcador.configurar(registro,icone,100000 if acesso_hunts_sem_limite else EstadoJogo.nivel_treinador)
		marcador.visual_alterado.connect(_reposicionar_um.bind(marcador))
		marcador.pressed.connect(_selecionar_registro.bind(registro))
		marcadores[marcador]=registro
func corresponde(registro: Dictionary) -> bool:
	var busca: String=_normalizar(buscas.text.strip_edges())
	if not busca.is_empty() and not _normalizar(str(registro["name"])).contains(busca): return false
	if not tipo_selecionado.is_empty() and tipo_selecionado not in [registro["type1"],registro["type2"]]: return false
	for par in [[nivel_de,true],[nivel_ate,false]]:
		var texto: String=par[0].text.strip_edges()
		if texto.is_empty(): continue
		if not texto.is_valid_int() or int(texto)<0: return false
		if bool(par[1]) and int(registro["level"])<int(texto): return false
		if not bool(par[1]) and int(registro["level"])>int(texto): return false
	return true
func _aplicar_filtros() -> void:
	if contador==null: return
	var quantidade: int=0
	for marcador in marcadores:
		var atende: bool=corresponde(marcadores[marcador])
		marcador.set_meta("atende_filtro",atende)
		if atende: quantidade+=1
		_reposicionar_um(marcador)
	contador.text="%d of %d" % [quantidade,catalogo.size()]
	for tipo in botoes_tipos:
		var ativo: bool=tipo_selecionado==tipo
		var cor: Color=TIPOS.cor(tipo)
		var b: Button=botoes_tipos[tipo]
		var fundo: Color=cor.darkened(0.25) if ativo else cor.lerp(Color("283340"),0.6)
		b.add_theme_stylebox_override("normal",UI.caixa(fundo,Color("ffffff99") if ativo else Color("111923"),3,2))
		b.add_theme_color_override("font_color",Color.WHITE if ativo else Color("a8adb5"))
		b.add_theme_color_override("icon_normal_color",Color.WHITE if ativo else Color("ffffff80"))
		b.add_theme_stylebox_override("hover",UI.caixa(fundo.lightened(0.1),Color("c8aa6e"),3,2))
		b.add_theme_stylebox_override("pressed",UI.caixa(cor,Color("ffffff99"),3,2))
func _reposicionar_um(marcador: Button) -> void:
	if navegacao==null or not is_instance_valid(imagem_mapa): return
	var dados: Dictionary=marcadores.get(marcador,{})
	if dados.is_empty(): return
	var escala: float=clampf(navegacao.zoom/0.6,0.4,1.25)*(1.14 if marcador.sobre else 1.0)
	marcador.scale=Vector2.ONE*escala/navegacao.zoom
	var pixel: Vector2=Vector2(float(dados["pixel"][0]),float(dados["pixel"][1]))
	marcador.position=pixel-marcador.size*marcador.scale*0.5
	var tela: Vector2=imagem_mapa.position+pixel*navegacao.zoom
	marcador.visible=bool(marcador.get_meta("atende_filtro",true)) and Rect2(Vector2.ZERO,navegacao.size).grow(100).has_point(tela)
func _reposicionar_marcadores() -> void:
	for marcador in marcadores: _reposicionar_um(marcador)
func limpar_filtros() -> void:
	buscas.text=""
	nivel_de.text=""
	nivel_ate.text=""
	tipo_selecionado=""
	_aplicar_filtros()
func _selecionar_registro(dados: Dictionary) -> void:
	if not bool(dados["implementado"]):
		_mostrar_aviso(str(dados["name"])+": caça ainda não implementada.")
		return
	if not acesso_hunts_sem_limite and EstadoJogo.nivel_treinador<int(dados["level"]):
		_mostrar_aviso("Requer nível %d do treinador." % int(dados["level"]))
		return
	for destino in destinos:
		if destino!=null and destino.especie!=null and destino.especie.nome==dados["name"]:
			_on_destino_pressed(destino)
			return
	var especie: DadosEspecie=preload("res://especies_importadas.gd").obter_especies().get(str(dados["name"]))
	if especie!=null:
		var novo: DadosDestinoCaca=DadosDestinoCaca.new()
		novo.especie=especie
		_on_destino_pressed(novo)
func _on_destino_pressed(destino: DadosDestinoCaca) -> void:
	if destino==null or destino.especie==null or preload("res://catalogo_hunts.gd").obter(destino.especie.nome).is_empty(): return
	EstadoJogo.especie_caca=destino.especie
	get_tree().change_scene_to_file("res://Caca.tscn")
func _on_busca_text_changed(_texto: String) -> void: _aplicar_filtros()
func _on_fechar_pressed() -> void: hide()
func _mostrar_aviso(texto: String) -> void:
	aviso.text=texto
	aviso.position=janela.position+Vector2(12,janela.size.y-70)
	aviso.size=Vector2(janela.size.x-24,50)
	aviso.show()
func _ajustar() -> void:
	if janela==null: return
	janela.size=Vector2(minf(704,maxf(280,size.x-40)),minf(900,maxf(330,size.y*0.92)))
	for b in botoes_regioes: b.custom_minimum_size=Vector2(minf(150,(janela.size.x-70)/4),minf(72,(janela.size.x-70)/4*205.0/450.0))
	if not _janela_movida: janela.position=((size-janela.size)*0.5).floor()
	else: _limitar_janela()
	if aviso!=null: aviso.hide()
func _limitar_janela() -> void:
	janela.position=Vector2(clampf(janela.position.x,14,maxf(14,size.x-janela.size.x-14)),clampf(janela.position.y,2,maxf(2,size.y-janela.size.y)))
func _arrastar_janela(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
		_arrastando_janela=e.pressed
		_offset_arrasto=e.global_position-janela.position
	elif e is InputEventMouseMotion and _arrastando_janela:
		_janela_movida=true
		janela.position=e.global_position-_offset_arrasto
		_limitar_janela()
func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and not e.pressed: _arrastando_janela=false
func _unhandled_key_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
func _visibilidade() -> void:
	if visible:
		_ajustar()
		call_deferred("_inicializar_visao")
func _inicializar_visao() -> void:
	if not _primeira_abertura or _iniciando_visao or not is_visible_in_tree(): return
	_iniciando_visao=true
	navegacao.modulate.a=0
	# O modal nasce oculto na cidade; o enquadramento só usa medidas finais visíveis.
	for i in range(3): await get_tree().process_frame
	_iniciando_visao=false
	if not is_inside_tree() or not is_visible_in_tree(): return
	navegacao.centralizar(Vector2(761,409))
	_primeira_abertura=false
	navegacao.modulate.a=1

func _atualizar_perfil() -> void:
	for marcador in marcadores: marcador.atualizar_nivel(100000 if acesso_hunts_sem_limite else EstadoJogo.nivel_treinador)
func _normalizar(texto: String) -> String:
	var valor: String=texto.to_lower()
	for par in [["áàâãä","a"],["éèêë","e"],["íìîï","i"],["óòôõö","o"],["úùûü","u"],["ç","c"]]:
		for letra in par[0]: valor=valor.replace(letra,par[1])
	return valor

func _ler_json_mapa(caminho: String) -> Dictionary:
	var arquivo: FileAccess=FileAccess.open(caminho,FileAccess.READ)
	if arquivo==null:
		push_error("Arquivo necessário ao mapa ausente ou ilegível: "+caminho)
		return {}
	var leitor: JSON=JSON.new()
	var erro: Error=leitor.parse(arquivo.get_as_text())
	if erro!=OK:
		push_error("JSON inválido em %s, linha %d: %s" % [caminho,leitor.get_error_line(),leitor.get_error_message()])
		return {}
	if not leitor.data is Dictionary:
		push_error("Objeto JSON esperado em: "+caminho)
		return {}
	return leitor.data
