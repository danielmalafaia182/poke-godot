extends RefCounted
const UI: Script = preload("res://estilo_ui_fiel.gd")
const TIPOS: Script = preload("res://tipos_pokemon.gd")
const ESTILO: Script = preload("res://estilo_team.gd")
const CHAVES: Array[String] = ["hp","atk","def","spAtk","spDef","speed"]
static func dados(pokemon: DadosPokemon) -> Dictionary:
	var atributos: Dictionary = pokemon.obter_atributos()
	var completos: bool = true
	for chave in CHAVES:
		if not atributos.has(chave): completos=false
	return {"atributos":atributos,"power":pokemon.obter_power() if completos else null,
		"iv_total":pokemon.obter_total_ivs(),"nivel":pokemon.nivel,"qualidade":pokemon.qualidade,
		"familia":null,"shiny":null,"held":null}
static func criar(pokemon: DadosPokemon, no_time: bool, lider: bool, inicial: bool) -> Control:
	var valores: Dictionary = dados(pokemon)
	var painel: PanelContainer = PanelContainer.new()
	painel.custom_minimum_size.x = 244
	painel.add_theme_stylebox_override("panel",UI.caixa(Color("08101cfa"),Color("c8aa6e"),10,10))
	var coluna: VBoxContainer = VBoxContainer.new()
	coluna.add_theme_constant_override("separation",4)
	painel.add_child(coluna)
	coluna.add_child(UI.texto(pokemon.especie.nome,13,Color("f0e6d2"),true))
	var tipos: HBoxContainer = HBoxContainer.new()
	tipos.add_theme_constant_override("separation",5)
	coluna.add_child(tipos)
	var base: Dictionary = preload("res://regras_pokemon.gd").obter_base(pokemon.especie.nome)
	for chave in ["type1","type2"]:
		var tipo: String = str(base.get(chave,""))
		if tipo.is_empty(): continue
		var badge: PanelContainer = PanelContainer.new()
		badge.add_theme_stylebox_override("panel",ESTILO.selo(TIPOS.cor(tipo)))
		badge.add_child(UI.texto(tipo,10,Color.WHITE,true))
		tipos.add_child(badge)
	if tipos.get_child_count()==0:
		tipos.add_child(UI.texto("TYPE —",9,Color("9aa6b3")))
	var status: String = "Active" if lider else ("Team" if no_time else "Stored")
	var status_linha: HBoxContainer = HBoxContainer.new()
	var selo_status: PanelContainer = PanelContainer.new()
	var cor_status: Color = Color("b389ff") if not no_time else Color("8effb0")
	var caixa_status: StyleBoxFlat = UI.caixa(Color("ffffff0f"),Color("8c5aff66") if not no_time else Color("2ee6a680"),9,7)
	caixa_status.content_margin_top=2
	caixa_status.content_margin_bottom=2
	selo_status.add_theme_stylebox_override("panel",caixa_status)
	selo_status.add_child(UI.texto(status+(" · Inicial protegido" if inicial else ""),10,cor_status,true))
	status_linha.add_child(selo_status)
	coluna.add_child(status_linha)
	var divisor: HSeparator = HSeparator.new()
	var linha_divisor: StyleBoxLine = StyleBoxLine.new()
	linha_divisor.color=Color("9975304d")
	linha_divisor.thickness=1
	divisor.add_theme_stylebox_override("separator",linha_divisor)
	coluna.add_child(divisor)
	var quality: Dictionary = ESTILO.qualidade(pokemon.qualidade)
	var resumo: RichTextLabel = rico("Lv [b]%d[/b]   Quality [color=#%s][b]%s[/b][/color] [font_size=9]×%.2f[/font_size]   IV [b]%d[/b][font_size=9]/192[/font_size]" % [pokemon.nivel,quality["cor"].to_html(false),quality["nome"],pokemon.qualidade,pokemon.obter_total_ivs()],10)
	resumo.name = "ResumoIV"
	resumo.custom_minimum_size.x = 224
	coluna.add_child(resumo)
	var grade: GridContainer = GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation",8)
	grade.add_theme_constant_override("v_separation",3)
	coluna.add_child(grade)
	var nomes: Array[String] = ["HP","Atk","Def","SpA","SpD","Spe"]
	for i in range(6):
		var valor: String = str(int(valores["atributos"][CHAVES[i]])) if valores["atributos"].has(CHAVES[i]) else "—"
		var texto: RichTextLabel = rico(nomes[i]+" [color=#f0e6d2][b]"+valor+"[/b][/color]",11)
		texto.custom_minimum_size.x=68
		texto.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		texto.name = "Atributo"+str(i)
		grade.add_child(texto)
	var power: Label = UI.texto("💪 Power "+(str(valores["power"]) if valores["power"]!=null else "—"),12,Color("5bf08a"),true)
	power.name = "Power"
	coluna.add_child(power)
	var ivs: Label = UI.texto("IVs %d / %d / %d / %d / %d / %d" % [pokemon.iv_hp,pokemon.iv_atk,pokemon.iv_def,pokemon.iv_sp_atk,pokemon.iv_sp_def,pokemon.iv_spd],9,Color("8a9aa9"))
	ivs.tooltip_text = "Ordem: HP, Atk, Def, SpA, SpD, Vel. IVs não são os atributos calculados."
	coluna.add_child(ivs)
	var pendentes: Label = UI.texto("Família — · Shiny — · Held —",9,Color("81909e"))
	pendentes.name = "Pendencias"
	coluna.add_child(pendentes)
	return painel

static func rico(conteudo: String, tamanho: int) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled=true
	label.fit_content=true
	label.scroll_active=false
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font",UI.TEXTO)
	label.add_theme_font_override("bold_font",UI.FORTE)
	label.add_theme_font_size_override("normal_font_size",tamanho)
	label.add_theme_font_size_override("bold_font_size",tamanho)
	label.add_theme_constant_override("line_separation",0)
	label.add_theme_color_override("default_color",Color("9aa6b3"))
	label.text=conteudo
	return label
