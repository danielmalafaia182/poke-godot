extends "res://janela_base.gd"
## Pokédex (C: window.pokedex; textos do pacote original). Espécies que aparecem em alguma hunt, com busca por nome ou
## número, filtro capturado/não capturado e por tipo, e o detalhe: tipos, nível da hunt, abates da espécie (Streak),
## evolução, stats base e se já capturou (normal/shiny). Contadores Capturados / Não capturados / Total.
## Fica de fora (E): o "Bônus de Captura +25% XP" por abates — o número de abates e o XP vêm do servidor, sem gravação.

const PONTE := preload("res://ponte_cidade.gd")
var busca := ""
var filtro := ""        # "", "cap", "nao"
var tipo := ""
var selecionado := -1
signal todos_shinys_solicitado


func _ready() -> void:
	tamanho = Vector2(730, 790)   # A: no vídeo a Pokédex ocupa ~730 × 800 px de 1880
	super._ready()


func especies() -> Array:
	## [{id, nome, tipos, nivel_hunt, capturado, shiny, abates}] em ordem de número.
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var nivel := {}
	for h in dados.hunts.values():
		for s in h.get("spawns", []):
			var id := int(s.get("pokeId", 0))
			nivel[id] = mini(int(nivel.get(id, 1 << 30)), int(h["nivel"]))
	var tem := {}
	var tem_sh := {}
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk != null and pk.especie != null:
			(tem_sh if pk.shiny else tem)[String(pk.especie.nome)] = true
	for e in ej.log_capturas:
		(tem_sh if bool(e.get("shiny", false)) else tem)[String(e.get("especie", ""))] = true
	var abates: Dictionary = ej.streak.get("bySpecies", {})
	var r: Array = []
	var ids := nivel.keys()
	ids.sort()
	for id in ids:
		var e: Dictionary = dados.especie(int(id))
		if e.is_empty():
			continue
		var nome := String(e["nome"])
		r.append({"id": int(id), "nome": nome, "tipos": e.get("tipos", []), "nivel_hunt": int(nivel[id]), "capturado": tem.has(nome) or tem_sh.has(nome),
			"shiny": tem_sh.has(nome), "abates": int(abates.get(str(int(id)), 0)), "esp": e})
	return r


func contagem() -> Dictionary:
	var l := especies()
	var c := 0
	for e in l:
		c += 1 if bool(e["capturado"]) else 0
	return {"capturados": c, "total": l.size()}


func montar() -> void:
	titulo.text = T.t("window.pokedex.title", {}, "Pokédex")
	var lista_toda := especies()
	var cont := contagem()
	# A (vídeo, 14_pokedex): 4 quadros de contagem — Capturados x/total, Não capturados, Bloqueados, Desbloqueados. Os dois
	# últimos são o bônus de +25% de XP por abates da espécie (servidor; E: offline nenhum desbloqueado).
	var quadros_cont := HBoxContainer.new()
	quadros_cont.name = "Contagem"
	quadros_cont.add_theme_constant_override("separation", 10)
	corpo.add_child(quadros_cont)
	var nao := int(cont["total"]) - int(cont["capturados"])
	for par in [["%d[font_size=11][color=#8a93a0]/%d[/color][/font_size]" % [int(cont["capturados"]), int(cont["total"])], T.t("window.pokedex.statsCaught")],
			[str(nao), T.t("window.pokedex.statsUncaught")], [str(int(cont["total"])), T.t("window.pokedex.statsLocked")], ["0", T.t("window.pokedex.statsUnlocked")]]:
		var qc := _quadro_contagem(String(par[0]), String(par[1]))
		quadros_cont.add_child(qc)
		_textos_contagem.append(qc.find_child("Valor", true, false))
	# A (vídeo): busca na largura toda e o filtro de tipo à direita (o original não tem os filtros capturado/não capturado
	# na barra; ficam como botões discretos ao lado, E). Busca e filtros só escondem cartões: nada é reconstruído.
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 8)
	corpo.add_child(barra)
	var campo := LineEdit.new()
	campo.name = "Busca"
	campo.placeholder_text = T.t("window.pokedex.searchPlaceholder")
	campo.text = busca
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo.add_theme_stylebox_override("normal", _caixa_campo())
	campo.add_theme_stylebox_override("focus", _caixa_campo(true))
	campo.text_changed.connect(func(t: String) -> void:
		busca = t
		_filtrar())
	barra.add_child(campo)
	for par in [["cap", "✓", T.t("window.pokedex.filterCaughtTip")], ["nao", "✗", T.t("window.pokedex.filterUncaughtTip")]]:
		var b := Button.new()
		b.name = "Filtro_" + String(par[0])
		b.text = String(par[1])
		b.tooltip_text = String(par[2])
		b.toggle_mode = true
		b.button_pressed = filtro == par[0]
		var chave := String(par[0])
		b.pressed.connect(func() -> void:
			filtro = "" if filtro == chave else chave
			for irmao in barra.get_children():
				if String(irmao.name).begins_with("Filtro_"):
					(irmao as Button).button_pressed = filtro == String(irmao.name).trim_prefix("Filtro_")
			_filtrar())
		barra.add_child(b)
	var tipos := OptionButton.new()
	tipos.name = "Tipo"
	tipos.add_item(T.t("window.pokedex.allTypes"))
	var todos := {}
	for e in lista_toda:
		for t in e["tipos"]:
			todos[String(t)] = true
	var tl := todos.keys()
	tl.sort()
	for t in tl:
		tipos.add_item(String(t).capitalize())
		if String(t) == tipo:
			tipos.select(tipos.item_count - 1)
	tipos.item_selected.connect(func(i: int) -> void:
		tipo = "" if i == 0 else String(tl[i - 1])
		_filtrar())
	barra.add_child(tipos)
	var bs := botao("✨", func() -> void: todos_shinys_solicitado.emit(), "TodosShinys", barra)
	bs.tooltip_text = T.t("window.allPokes.title", {}, "Todos os Shinys")
	_caixa_detalhe = VBoxContainer.new()
	_caixa_detalhe.name = "CaixaDetalhe"
	corpo.add_child(_caixa_detalhe)
	_caixa_detalhe.visible = selecionado >= 0
	if selecionado >= 0:
		_detalhe(lista_toda)
	if _grade == null:
		_grade = GridContainer.new()   # A (vídeo): 7 colunas de cartões
		_grade.name = "Grade"
		_grade.columns = 7
		_grade.add_theme_constant_override("h_separation", 8)
		_grade.add_theme_constant_override("v_separation", 8)
		for e in lista_toda:
			var b := _cartao(e)
			var id := int(e["id"])
			b.pressed.connect(func() -> void:
				selecionado = id
				atualizar())
			_grade.add_child(b)
			_cartoes[id] = b
	_dados_cartoes = lista_toda
	corpo.add_child(_grade)
	_vazio = rotulo(T.t("window.pokedex.empty"), Color("c8b89a"))
	_filtrar()


var _grade: GridContainer = null
var _cartoes := {}            # id -> Button (montados uma vez; a busca só esconde)
var _dados_cartoes: Array = []
var _vazio: Label = null
var _fila_sprites: Array = []  # [TextureRect, looktype]: sprites atribuídos aos poucos (C: o original também carrega aos poucos)


func atualizar() -> void:
	## Ciclo 5: a janela é montada uma vez (453 cartões); depois só mudam as contagens, o detalhe e o filtro — tirar e
	## pôr a grade na árvore refazia tema e layout de tudo (~150 ms a cada abertura).
	if _grade == null or not _grade.is_inside_tree():
		super.atualizar()
		return
	titulo.text = T.t("window.pokedex.title", {}, "Pokédex")
	var lista_toda := especies()
	var cap := 0
	for e in lista_toda:
		cap += 1 if bool(e["capturado"]) else 0
	_textos_contagem[0].text = "[center]%d[font_size=11][color=#8a93a0]/%d[/color][/font_size][/center]" % [cap, lista_toda.size()]
	_textos_contagem[1].text = "[center]%d[/center]" % (lista_toda.size() - cap)
	_textos_contagem[2].text = "[center]%d[/center]" % lista_toda.size()
	_atualizar_cartoes(lista_toda)
	for c in _caixa_detalhe.get_children():
		_caixa_detalhe.remove_child(c)
		c.queue_free()
	_caixa_detalhe.visible = selecionado >= 0
	if selecionado >= 0:
		_detalhe(lista_toda)
	_filtrar()
	_ajustar()


var _textos_contagem: Array = []
var _caixa_detalhe: VBoxContainer = null


func _atualizar_cartoes(lista_toda: Array) -> void:
	## Captura nova desde a última abertura: só o cartão dela é trocado.
	for e in lista_toda:
		var b: Button = _cartoes.get(int(e["id"]))
		if b != null and bool(b.get_meta("capturado", false)) != bool(e["capturado"]):
			var novo := _cartao(e)
			var id := int(e["id"])
			novo.pressed.connect(func() -> void:
				selecionado = id
				atualizar())
			_grade.add_child(novo)
			_grade.move_child(novo, b.get_index())
			b.queue_free()
			_cartoes[id] = novo
	_dados_cartoes = lista_toda


func _filtrar() -> void:
	var n := 0
	for e in _dados_cartoes:
		var b: Button = _cartoes.get(int(e["id"]))
		if b == null:
			continue
		var ok := true
		if filtro == "cap" and not bool(e["capturado"]) or filtro == "nao" and bool(e["capturado"]):
			ok = false
		elif tipo != "" and not (tipo in e["tipos"]):
			ok = false
		elif busca != "" and String(e["nome"]).to_lower().find(busca.to_lower()) < 0 and str(int(e["id"])) != busca.trim_prefix("#"):
			ok = false
		b.visible = ok
		n += 1 if ok else 0
	if _vazio != null:
		_vazio.visible = n == 0


func _caixa_campo(foco: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1118")
	sb.border_color = Color("c8aa6e") if foco else Color("2a3646")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _process(_d: float) -> void:
	if _fila_sprites.is_empty() or not visible:
		return
	var t0 := Time.get_ticks_usec()
	while not _fila_sprites.is_empty() and Time.get_ticks_usec() - t0 < 4000:   # até 4 ms por quadro
		var par: Array = _fila_sprites.pop_front()
		var ic: TextureRect = par[0]
		if not is_instance_valid(ic):
			continue
		var o: Dictionary = _outfits.obter(int(par[1]))
		var q: Dictionary = _outfits.quadro(o, 3, 0) if not o.is_empty() else {}
		if not q.is_empty():
			var at := AtlasTexture.new()
			at.atlas = q["tex"]
			at.region = q["rect"]
			ic.texture = at


const COR_TIPO := {"normal": "a8a77a", "fire": "ee8130", "water": "6390f0", "electric": "f7d02c", "grass": "7ac74c",
	"ice": "96d9d6", "fighting": "c22e28", "poison": "a33ea1", "ground": "e2bf65", "flying": "a98ff3", "psychic": "f95587",
	"bug": "a6b91a", "rock": "b6a136", "ghost": "735797", "dragon": "6f35fc", "dark": "705746", "steel": "b7b7ce", "fairy": "d685ad"}
var _outfits = null


func _quadro_contagem(valor: String, rotulo_txt: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1118")
	sb.border_color = Color("c8aa6e")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_override("normal_font", BARLOW_B)
	r.add_theme_font_size_override("normal_font_size", 18)
	r.name = "Valor"
	r.text = "[center]" + valor + "[/center]"
	v.add_child(r)
	var l := Label.new()
	l.text = rotulo_txt.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", BARLOW_B)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color("8a93a0"))
	v.add_child(l)
	return p


func _cartao(e: Dictionary) -> Button:
	## A (vídeo): cartão com o sprite, "#001", o nome, o ✓ verde dos capturados e a borda de baixo na cor do tipo.
	if _outfits == null:
		_outfits = preload("res://render/outfits.gd").padrao()
	var cap := bool(e["capturado"])
	var b := Button.new()
	b.name = "P_%d" % int(e["id"])
	b.custom_minimum_size = Vector2(90, 86)
	b.clip_contents = true
	var tipo0 := String((e["tipos"] as Array)[0]) if not (e["tipos"] as Array).is_empty() else "normal"
	for estado in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0e151e") if estado == "normal" else Color("16202b")
		sb.border_color = Color("2a3646") if estado == "normal" else Color("c8aa6e")
		sb.set_border_width_all(1)
		sb.border_width_bottom = 2
		sb.border_color = sb.border_color if estado != "normal" else Color(COR_TIPO.get(tipo0, "8a93a0"))
		sb.set_corner_radius_all(7)
		b.add_theme_stylebox_override(estado, sb)
	var ic := TextureRect.new()   # o sprite cabe no alto do cartão (encolhe os grandes; C: o original encaixa)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(19, 6)
	ic.size = Vector2(52, 44)
	_fila_sprites.append([ic, int((e["esp"] as Dictionary).get("looktype", 0))])
	b.set_meta("capturado", cap)
	ic.modulate = Color.WHITE if cap else Color(0.12, 0.14, 0.18, 0.9)   # não capturado: silhueta escura
	b.add_child(ic)
	var num := Label.new()
	num.text = "#%03d" % int(e["id"])
	num.add_theme_font_override("font", BARLOW_B)
	num.add_theme_font_size_override("font_size", 9)
	num.add_theme_color_override("font_color", Color("cfd8e2") if cap else Color("6c7684"))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.position = Vector2(0, 50)
	num.size = Vector2(90, 12)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(num)
	var nm := Label.new()
	nm.text = String(e["nome"])
	nm.add_theme_font_override("font", BARLOW_B)
	nm.add_theme_font_size_override("font_size", 11)
	nm.add_theme_color_override("font_color", Color("f0e6d2") if cap else Color("8a93a0"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	nm.position = Vector2(2, 63)
	nm.size = Vector2(86, 16)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nm)
	if cap:
		var ck := Label.new()
		ck.text = "✓"
		ck.add_theme_font_override("font", BARLOW_B)
		ck.add_theme_font_size_override("font_size", 11)
		ck.add_theme_color_override("font_color", Color.WHITE)
		var sc := StyleBoxFlat.new()
		sc.bg_color = Color("3cb04a")
		sc.set_corner_radius_all(9)
		sc.content_margin_left = 4
		sc.content_margin_right = 4
		ck.add_theme_stylebox_override("normal", sc)
		ck.position = Vector2(70, 3)
		ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ck)
	if bool(e["shiny"]):
		var sh := Label.new()
		sh.text = "✨"
		sh.add_theme_font_size_override("font_size", 10)
		sh.position = Vector2(4, 2)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sh)
	b.tooltip_text = "#%03d %s" % [int(e["id"]), String(e["nome"])]
	return b


func _detalhe(lista: Array) -> void:
	var e: Dictionary = {}
	for x in lista:
		if int(x["id"]) == selecionado:
			e = x
	if e.is_empty():
		return
	var esp: Dictionary = e["esp"]
	var caixa := PanelContainer.new()
	caixa.name = "Detalhe"
	_caixa_detalhe.add_child(caixa)
	var col := VBoxContainer.new()
	caixa.add_child(col)
	rotulo("#%03d %s  ·  %s  %s" % [int(e["id"]), String(e["nome"]), " / ".join(PackedStringArray((e["tipos"] as Array).map(func(t): return String(t).capitalize()))),
		T.t("window.pokedex.huntLevel", {"level": int(e["nivel_hunt"])})], Color.WHITE, 16, col)
	rotulo((T.t("window.pokedex.caughtTag") if bool(e["capturado"]) else T.t("window.pokedex.notCaughtTag")) + ("   ✨ " + T.t("window.pokedex.shinyPrefix") if bool(e["shiny"]) else ""),
		Color("9fe0a0") if bool(e["capturado"]) else Color("ff9a8a"), 0, col)
	rotulo(T.t("window.pokedex.killsProgress", {"kills": n(e["abates"]), "total": "—"}).replace("/—", ""), Color("c8b89a"), 0, col)
	var ev: Dictionary = esp.get("evolui", {}) if esp.get("evolui") is Dictionary else {}
	if not ev.is_empty():
		var alvo: Dictionary = PONTE.dados().especie(int(ev.get("para", 0)))
		rotulo(T.t("window.pokedex.evolvesTo", {"name": String(alvo.get("nome", "?"))}) + T.t("window.pokedex.evolveLevelSuffix", {"level": int(ev.get("nivel", 0))}), Color("c8b89a"), 0, col)
	else:
		rotulo(T.t("window.pokedex.noEvolve"), Color("c8b89a"), 0, col)
	var b: Dictionary = esp.get("base", {})
	var st := []
	for par in [["hp", "baseHp"], ["atk", "baseAtk"], ["def", "baseDef"], ["spAtk", "baseSpAtk"], ["spDef", "baseSpDef"], ["speed", "baseSpeed"]]:
		st.append("%s %d" % [T.t("window.pokedex.stat." + String(par[1])), int(b.get(par[0], 0))])
	rotulo(T.t("window.pokedex.statsTitle") + ":  " + "  ".join(PackedStringArray(st)), Color("c8b89a"), 0, col)
	botao(T.t("window.pokedex.back"), func() -> void:
		selecionado = -1
		atualizar(), "Voltar", col)
