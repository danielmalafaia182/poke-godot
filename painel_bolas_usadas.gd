extends "res://janela_base.gd"
## Gerenciamento de Captura (C: window.usedBalls; textos do pacote original). Desenha o medidor de captura por espécie
## (EstadoJogo.medidor_captura, o mesmo da sim: C /api/game/used-balls; A goldSpent = ouro desde a última captura).
## Ciclo 5 (decisão do usuário: uma coluna por bola, como o original). Pelo quadro do original (A, vídeo; lado a lado em
## dados/relatorios/teste_ciclo4/):
##   - colunas #, retrato, Nome, uma por bola (A: used-balls `ballTypes`; 5 visíveis, "Mostrar todas as Poké Bolas" mostra
##     também a Golden Idle e a Master), Tentativas mais recentes (dourado) e Tentativas totais (azul);
##   - a célula da bola é o ícone e a contagem (A: `balls` {ballId: tentativas}, nunca zera); vazia quando 0;
##   - na 1ª aba as linhas normais e shiny ficam intercaladas pela Pokédex (a shiny com o nome dourado, sem o #);
##     a 2ª aba só as shiny;
##   - busca e a caixa "Mostrar todas" no rodapé.
## Saves de antes guardam só o total: a diferença aparece na dica do total. O ouro gasto e o preço do NPC ficam na dica
## das tentativas recentes (C: priceSpentTip).

const PONTE := preload("res://ponte_cidade.gd")
const Outfits := preload("res://render/outfits.gd")
const BOLAS := [[1, "pokeball"], [2, "greatball"], [3, "superball"], [4, "ultraball"], [6, "idleball"], [7, "idleball_gold"], [5, ""]]
const VISIVEIS := 5
const L_NUM := 56
const L_RET := 40
const L_NOME := 190
const L_BOLA := 74
const L_TENT := 92

var busca := ""
var todas := false
var _outfits = null
var _fila: Array = []   # [TextureRect, looktype]


func _ready() -> void:
	tamanho = Vector2(980, 660)   # A: no vídeo o Gerenciamento de Captura ocupa ~980 × 660 px de 1880
	aba = "normal"
	super._ready()
	# rodapé fixo (fora da rolagem): busca à esquerda, "Mostrar todas as Poké Bolas" à direita
	var rod := HBoxContainer.new()
	rod.name = "Rodape"
	rod.add_theme_constant_override("separation", 12)
	rolagem.get_parent().add_child(rod)
	var campo := LineEdit.new()
	campo.name = "Busca"
	campo.placeholder_text = "🔍  " + T.t("window.usedBalls.searchPlaceholder")
	campo.custom_minimum_size = Vector2(300, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b131d")
	sb.border_color = Color("2a3a4c")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	campo.add_theme_stylebox_override("normal", sb)
	campo.add_theme_stylebox_override("focus", sb)
	campo.text_changed.connect(func(t: String) -> void:
		busca = t
		_preencher())
	rod.add_child(campo)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rod.add_child(esp)
	var cx := CheckBox.new()
	cx.name = "MostrarTodas"
	cx.text = T.t("window.usedBalls.showAllBalls")
	cx.add_theme_color_override("font_color", Color("c8b89a"))
	cx.toggled.connect(func(v: bool) -> void:
		todas = v
		_preencher())
	rod.add_child(cx)


func linhas() -> Array:
	## [{id, nome, shiny, recentes, total, gasto, bolas, preco, looktype, capturado}] pela Pokédex, a normal antes da shiny.
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var donos := {}
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk != null and pk.especie != null:
			donos["%s|%s" % [String(pk.especie.nome), str(pk.shiny)]] = true
	for e in ej.log_capturas:
		donos["%s|%s" % [String(e.get("especie", "")), str(bool(e.get("shiny", false)))]] = true
	var r: Array = []
	for k in ej.medidor_captura:
		var ks := String(k)
		var shiny := ks.ends_with("s")
		var id := int(ks.trim_suffix("s"))
		var m: Dictionary = ej.medidor_captura[k]
		var esp: Dictionary = dados.especie(id)
		var nome := String(esp.get("nome", "#%d" % id))
		r.append({"id": id, "nome": nome, "shiny": shiny, "recentes": int(m.get("tentativas", 0)), "total": int(m.get("total", 0)),
			"gasto": int(m.get("gasto", 0)), "bolas": (m.get("bolas", {}) as Dictionary).duplicate(), "preco": int(esp.get("precoNpc", 0)),
			"looktype": int(esp.get("looktype", 0)), "capturado": donos.has("%s|%s" % [nome, str(shiny)])})
	r.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]) or (int(a["id"]) == int(b["id"]) and not bool(a["shiny"]) and bool(b["shiny"])))
	return r


func montar() -> void:
	titulo.text = T.t("window.usedBalls.title", {}, "Gerenciamento de Captura")
	botao_aba("normal", T.t("window.usedBalls.tabBalls"))
	botao_aba("shiny", T.t("window.usedBalls.tabShiny"))
	var cab := HBoxContainer.new()
	cab.name = "Cabecalho"
	cab.add_theme_constant_override("separation", 0)
	corpo.add_child(cab)
	var lista := VBoxContainer.new()
	lista.name = "Lista"
	lista.add_theme_constant_override("separation", 0)
	corpo.add_child(lista)
	_preencher()


func _bolas_visiveis() -> Array:
	return BOLAS if todas else BOLAS.slice(0, VISIVEIS)


func _icone_bola(id: int, nome_arq: String, tam: float) -> Control:
	if nome_arq == "":
		var lm := Label.new()   # A: a Master Ball vem sem ícone (iconUrl null)
		lm.text = "M"
		lm.add_theme_color_override("font_color", Color("c88cff"))
		lm.add_theme_font_size_override("font_size", int(tam * 0.7))
		lm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return lm
	var ic := TextureRect.new()
	ic.texture = load("res://assets/original/markitems/%s.png" % nome_arq)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(tam, tam)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.name = "Ic_%d" % id
	return ic


func _celula(pai: Control, largura: int, alinhar: int = HORIZONTAL_ALIGNMENT_LEFT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(largura, 0)
	h.alignment = BoxContainer.ALIGNMENT_CENTER if alinhar == HORIZONTAL_ALIGNMENT_CENTER else (BoxContainer.ALIGNMENT_END if alinhar == HORIZONTAL_ALIGNMENT_RIGHT else BoxContainer.ALIGNMENT_BEGIN)
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	pai.add_child(h)
	return h


func _texto(pai: Control, t: String, cor: Color, tam: int, negrito: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", cor)
	l.add_theme_font_size_override("font_size", tam)
	if negrito:
		l.add_theme_constant_override("outline_size", 0)
		l.add_theme_font_override("font", BARLOW_B)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	pai.add_child(l)
	return l




func _preencher() -> void:
	var lista: VBoxContainer = corpo.get_node_or_null("Lista")
	var cab: HBoxContainer = corpo.get_node_or_null("Cabecalho")
	if lista == null or cab == null:
		return
	for no in [lista, cab]:
		for c in no.get_children():
			no.remove_child(c)
			c.queue_free()
	_fila.clear()
	var bolas := _bolas_visiveis()
	var dourado := Color("f0c040")
	# cabeçalho: #, (retrato), NOME, ícones das bolas, MOST RECENT / TOTAL em duas linhas
	_texto(_celula(cab, L_NUM), "#", Color("8a9bb0"), 11, true)
	_celula(cab, L_RET)
	_texto(_celula(cab, L_NOME), T.t("window.usedBalls.colName").to_upper(), Color("8a9bb0"), 11, true)
	for b in bolas:
		var c := _celula(cab, L_BOLA, HORIZONTAL_ALIGNMENT_CENTER)
		c.name = "Bola_%d" % int(b[0])
		c.tooltip_text = String(get_node("/root/EstadoJogo").obter_dados_bola(int(b[0])).get("nome", "Master Ball"))
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.add_child(_icone_bola(int(b[0]), String(b[1]), 16))
	for par in [[T.t("window.usedBalls.recentAttempts"), T.t("window.usedBalls.recentAttemptsTip"), dourado], [T.t("window.usedBalls.totalAttempts"), T.t("window.usedBalls.totalAttemptsTip"), Color("7fb2ff")]]:
		var c := _celula(cab, L_TENT, HORIZONTAL_ALIGNMENT_RIGHT)
		c.tooltip_text = String(par[1])
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var l := _texto(c, String(par[0]).to_upper(), par[2], 10, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = L_TENT - 6
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var achou := false
	var par_linha := 0
	for e in linhas():
		if aba == "shiny" and not bool(e["shiny"]):
			continue
		if busca != "" and String(e["nome"]).to_lower().find(busca.to_lower()) < 0 and str(int(e["id"])) != busca.trim_prefix("#").lstrip("0"):
			continue
		achou = true
		var shiny := bool(e["shiny"])
		var fundo := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1d1b14") if shiny else (Color("101a26") if par_linha % 2 == 0 else Color("0c1520"))
		sb.border_color = Color("1c2836")
		sb.border_width_bottom = 1
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		fundo.add_theme_stylebox_override("panel", sb)
		par_linha += 1
		lista.add_child(fundo)
		var h := HBoxContainer.new()
		h.name = "L_%d%s" % [int(e["id"]), "s" if shiny else ""]
		h.add_theme_constant_override("separation", 0)
		h.custom_minimum_size.y = 36
		fundo.add_child(h)
		_texto(_celula(h, L_NUM), "" if shiny else "#%03d" % int(e["id"]), Color("6f8197"), 11)
		var cr := _celula(h, L_RET, HORIZONTAL_ALIGNMENT_CENTER)
		var ret := TextureRect.new()
		ret.custom_minimum_size = Vector2(32, 32)
		ret.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ret.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ret.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cr.add_child(ret)
		if int(e["looktype"]) > 0:
			_fila.append([ret, int(e["looktype"])])
		var cn := _celula(h, L_NOME)
		var nome := _texto(cn, ("Shiny " if shiny else "") + String(e["nome"]) + ("  ✓" if bool(e["capturado"]) else ""), dourado if shiny else Color("f0e6d2"), 12, true)
		nome.tooltip_text = T.t("window.usedBalls.alreadyCaught") if bool(e["capturado"]) else T.t("window.usedBalls.notCaught")
		nome.mouse_filter = Control.MOUSE_FILTER_STOP
		var soma := 0
		for b in BOLAS:
			soma += int((e["bolas"] as Dictionary).get(str(int(b[0])), 0))
		for b in bolas:
			var q := int((e["bolas"] as Dictionary).get(str(int(b[0])), 0))
			var cb := _celula(h, L_BOLA, HORIZONTAL_ALIGNMENT_CENTER)
			if q > 0:
				cb.add_child(_icone_bola(int(b[0]), String(b[1]), 13))
			var lb := _texto(cb, n(q) if q > 0 else "", Color("c8b89a"), 11)
			lb.name = "B_%d" % int(b[0])
		var crec := _celula(h, L_TENT, HORIZONTAL_ALIGNMENT_RIGHT)
		crec.tooltip_text = T.t("window.usedBalls.priceSpentTip", {"price": n(e["preco"]), "spent": n(e["gasto"])})
		crec.mouse_filter = Control.MOUSE_FILTER_STOP
		_texto(crec, n(e["recentes"]), dourado, 12, true)
		var ctot := _celula(h, L_TENT, HORIZONTAL_ALIGNMENT_RIGHT)
		_texto(ctot, n(e["total"]), Color("7fb2ff"), 12, true).name = "Total"
		if soma < int(e["total"]):
			ctot.tooltip_text = "%d tentativa(s) de antes da contagem por bola" % (int(e["total"]) - soma)
			ctot.mouse_filter = Control.MOUSE_FILTER_STOP
	if not achou:
		rotulo(T.t("window.usedBalls.emptyShiny") if aba == "shiny" else T.t("window.usedBalls.emptyCaptures"), Color("c8b89a"), 0, lista)


func _process(_d: float) -> void:
	## Retratos aos poucos (o outfit de cada espécie é lido do pacote na 1ª vez).
	if _fila.is_empty() or not visible:
		return
	if _outfits == null:
		_outfits = Outfits.padrao()
	var t0 := Time.get_ticks_usec()
	while not _fila.is_empty() and Time.get_ticks_usec() - t0 < 4000:
		var par: Array = _fila.pop_front()
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
