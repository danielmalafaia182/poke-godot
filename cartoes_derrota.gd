extends Control

# Novo: medidas, cores e agrupamento de kc-card/cF no cliente original.
# Apenas apresenta eventos; não concede XP, loot nem captura.
const ESTILO: Script = preload("res://estilo_hud_original.gd")
const UI: Script=preload("res://estilo_ui_fiel.gd")
const VISUAL: Script=preload("res://visual_pokemon.gd")
const RESULTADO: Script=preload("res://estilo_resultado_combate.gd")
const FONTE: Font = UI.FORTE
const TITULO: Font = UI.TITULO
var cartoes: Array[Dictionary] = []
var maximo_cartoes: int = 3
var pilha: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = FONTE
	theme.default_font_size = 12
	pilha = VBoxContainer.new()
	pilha.add_theme_constant_override("separation",10)
	add_child(pilha)

var total_exibidos: int=0
const MAX_EXIBICOES: int=30
const TEMPO_SAIDA_MS: int=220
func apresentar(evento: Dictionary) -> void:
	_process(0)
	# Nenhuma fila, substituição ou extensão do cartão em exibição.
	if not cartoes.is_empty() or total_exibidos>=MAX_EXIBICOES: return
	var agora: int=Time.get_ticks_msec()
	total_exibidos+=1
	cartoes.append({"inicio":agora,"ultimo":agora,"kills":1,"aberto":false,"evento":evento.duplicate(true)})
	_reconstruir()
func _iniciar_saida(registro: Dictionary) -> void:
	if registro.has("saida"): return
	registro["saida"]=Time.get_ticks_msec()
	if pilha.get_child_count()>0:
		pilha.get_child(0).create_tween().tween_property(pilha.get_child(0),"modulate:a",0.0,float(TEMPO_SAIDA_MS)/1000.0)
func _process(_delta: float) -> void:
	if cartoes.is_empty(): return
	var registro: Dictionary=cartoes[0]
	var agora: int=Time.get_ticks_msec()
	if registro.has("saida"):
		if agora-int(registro["saida"])>=TEMPO_SAIDA_MS:
			cartoes.clear()
			_reconstruir()
	elif agora-int(registro["ultimo"])>=(7000 if bool(registro["evento"].get("shiny",false)) else 4500):
		_iniciar_saida(registro)

func _rotulo(texto: String, tamanho: int = 12, cor: Color = Color("d7e2ee")) -> Label:
	var rotulo: Label = Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size",tamanho)
	rotulo.add_theme_color_override("font_color",cor)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rotulo

func _caixa(cor: String, borda: String, margem: int = 8) -> PanelContainer:
	var caixa: PanelContainer = PanelContainer.new()
	caixa.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var estilo: StyleBoxFlat = ESTILO.plano(Color(cor),Color(borda),10)
	estilo.set_content_margin_all(margem)
	caixa.add_theme_stylebox_override("panel",estilo)
	return caixa

func _linha_xp(nome: String, total: int, partes: Dictionary, pokemon: bool) -> PanelContainer:
	var linha: PanelContainer=PanelContainer.new()
	linha.mouse_filter=Control.MOUSE_FILTER_IGNORE
	linha.add_theme_stylebox_override("panel",RESULTADO.fundo("xp"))
	var coluna: VBoxContainer=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",4)
	linha.add_child(coluna)
	var topo: HBoxContainer=HBoxContainer.new()
	topo.add_theme_constant_override("separation",6)
	coluna.add_child(topo)
	topo.add_child(RESULTADO.icone(preload("res://assets/interface/loot/pokemon_xp.png") if pokemon else preload("res://assets/interface/hud/icon_profile_player.png"),16))
	var label: Label=_rotulo(nome,10,Color("d59a93") if pokemon else Color("d7e2ee"))
	label.add_theme_font_override("font",TITULO)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	topo.add_child(label)
	var ganho: Label=_rotulo("+%d" % total,18,Color("ff6b5e") if pokemon else Color.WHITE)
	ganho.add_theme_color_override("font_shadow_color",Color("ff6b5e40") if pokemon else Color("ffffff40"))
	ganho.add_theme_constant_override("shadow_outline_size",2)
	topo.add_child(ganho)
	var chips: HFlowContainer=HFlowContainer.new()
	chips.add_theme_constant_override("h_separation",4)
	chips.add_theme_constant_override("v_separation",3)
	coluna.add_child(chips)
	var cores: Dictionary={"base":"cfd8e2","vip":"7fd4ff","streak":"ff6a3d","boost":"ffcf3a","event":"c49bff"}
	for chave in partes:
		if chave!="base" and int(partes[chave])==0: continue
		var cor: Color=Color(cores.get(chave,"cfd8e2"))
		var fundo: Color=Color(cor.r,cor.g,cor.b,0.14)
		var borda: Color=Color(cor.r,cor.g,cor.b,0.32)
		var chip: PanelContainer=PanelContainer.new()
		var estilo: StyleBoxFlat=UI.caixa(fundo,borda,8,5)
		estilo.content_margin_top=0
		estilo.content_margin_bottom=0
		chip.add_theme_stylebox_override("panel",estilo)
		var texto: String="Base %d" % int(partes[chave]) if chave=="base" else ("💎 " if chave=="vip" else "")+"%s +%d" % [str(chave).to_upper(),int(partes[chave])]
		chip.add_child(_rotulo(texto,10,cor))
		chips.add_child(chip)
	return linha

func _reconstruir() -> void:
	for filho in pilha.get_children():
		pilha.remove_child(filho)
		filho.queue_free()
	for registro in cartoes:
		var evento: Dictionary=registro["evento"]
		var painel: PanelContainer=PanelContainer.new()
		painel.add_theme_stylebox_override("panel",RESULTADO.fundo("card"))
		painel.custom_minimum_size.x=minf(340,get_viewport_rect().size.x-20)
		pilha.add_child(painel)
		var coluna: VBoxContainer=VBoxContainer.new()
		coluna.add_theme_constant_override("separation",0)
		painel.add_child(coluna)
		var cabecalho: HBoxContainer=HBoxContainer.new()
		cabecalho.add_theme_constant_override("separation",8)
		coluna.add_child(RESULTADO.margem(cabecalho,9,7,9,9))
		var rosto: PanelContainer=_caixa("0000004d","2a3442",2)
		rosto.custom_minimum_size=Vector2(32,32)
		rosto.add_theme_stylebox_override("panel",UI.caixa(Color("0000004d"),Color("2a3442"),16,2))
		rosto.add_child(RESULTADO.icone(VISUAL.icone_reduzido(str(evento["speciesName"]),28),28))
		cabecalho.add_child(rosto)
		var nome: Label=_rotulo(str(evento["speciesName"]),13,Color.WHITE)
		nome.add_theme_font_override("font",TITULO)
		nome.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		cabecalho.add_child(nome)
		var derrotado: Label=_rotulo("DEFEATED",11,Color("8aa6c8"))
		derrotado.add_theme_font_override("font",UI.TEXTO)
		derrotado.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		derrotado.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		cabecalho.add_child(derrotado)
		if int(registro["kills"])>1:
			var combo: Label=_rotulo("×%d" % int(registro["kills"]),13,Color("ff6a3d"))
			combo.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			cabecalho.add_child(combo)
		var separador: HSeparator=HSeparator.new()
		var traco: StyleBoxLine=StyleBoxLine.new()
		traco.color=Color("e8cd8d")
		traco.thickness=1
		separador.add_theme_stylebox_override("separator",traco)
		separador.custom_minimum_size.y=3
		coluna.add_child(separador)
		var corpo: PanelContainer=_caixa("00000047","2a3442",8)
		var linhas: VBoxContainer=VBoxContainer.new()
		linhas.add_theme_constant_override("separation",6)
		corpo.add_child(linhas)
		linhas.add_child(_linha_xp("TRAINER",int(evento["xpGained"]),evento["xpParts"],false))
		linhas.add_child(_linha_xp("POKÉMON",int(evento["pokeXp"]["xpGained"]),evento["pokeXp"]["parts"],true))
		coluna.add_child(RESULTADO.margem(corpo,8,8,8,8))
		if not evento.get("loot",[]).is_empty():
			var loot: VBoxContainer=VBoxContainer.new()
			loot.add_theme_constant_override("separation",5)
			coluna.add_child(RESULTADO.margem(loot,9,0,9,9))
			loot.add_child(_rotulo("LOOT",11,Color("8aa6c8")))
			var itens: HFlowContainer=HFlowContainer.new()
			itens.add_theme_constant_override("h_separation",5)
			itens.add_theme_constant_override("v_separation",5)
			loot.add_child(itens)
			var loot_ordenado: Array=evento["loot"].duplicate(true)
			loot_ordenado.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a["itemId"])<int(b["itemId"]))
			for item in loot_ordenado:
				itens.add_child(_chip_loot(item))
		# Um clique expande; o seguinte descarta. Nunca concede recompensa.
		painel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
				if bool(registro.get("aberto",false)): _iniciar_saida(registro)
				else: registro["aberto"]=true
		)
		painel.modulate.a=0
		painel.create_tween().tween_property(painel,"modulate:a",1.0,0.26)

func _chip_loot(item: Dictionary) -> PanelContainer:
	var dados: Dictionary=preload("res://regras_loot.gd").obter(int(item["itemId"]))
	var chip: PanelContainer=PanelContainer.new()
	chip.mouse_filter=Control.MOUSE_FILTER_PASS
	chip.tooltip_text="%d %s" % [int(item["qty"]),str(item["name"])]
	chip.add_theme_stylebox_override("panel",RESULTADO.fundo("rare" if bool(dados.get("raro",false)) else "item"))
	var linha: HBoxContainer=HBoxContainer.new()
	linha.add_theme_constant_override("separation",4)
	linha.mouse_filter=Control.MOUSE_FILTER_IGNORE
	chip.add_child(linha)
	var caminho: String=str(dados.get("icone",item.get("icon","")))
	var tex_icone: Texture2D=preload("res://regras_loot.gd").textura(caminho)   # res:// ou ícone do snapshot
	if tex_icone!=null: linha.add_child(RESULTADO.icone(tex_icone,22))
	linha.add_child(_rotulo(str(int(item["qty"])),12,Color("ffe89a")))
	var nome: Label=_rotulo(str(item["name"]),11,Color("ffe1a3") if bool(dados.get("raro",false)) else Color("cfe0f5"))
	nome.add_theme_font_override("font",UI.TEXTO)
	var largura: float=minf(UI.TEXTO.get_string_size(nome.text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x,69-FONTE.get_string_size(str(int(item["qty"])),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)
	nome.custom_minimum_size.x=largura
	nome.clip_text=true
	nome.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	linha.add_child(nome)
	return chip
