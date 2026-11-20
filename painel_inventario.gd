extends Control
## Mochila (ciclo 4, item 3: igual ao original). Fonte C: componente do inventário no cliente (classes `.inv-bag`,
## `.inv-tabs`/`.dep-tab`, `.inv-status`, `.inv-grid`, `.inv-slot`, `.inv-tip`; textos window.inventory do pacote) e as
## artes /assets/inventory/bag_{top,mid,bottom}.webp e tab_{all,poke,ball,item}.png. A: o vídeo do usuário
## (referencia_visual/quadros/24_mochila) — a versão atual tem também a linha de busca, categoria e ordenação.
##   - mochila desenhada de 354 px (topo, meio repetido, base), título "Inventário" e o × vermelho;
##   - 4 abas com ícone de 32 px: Tudo, Pokémon, Pokébolas, Itens (a ativa em dourado);
##   - status "N/6 Pokémon · M itens" (a mensagem de uma ação cobre a linha por 2,5 s, .inv-flash);
##   - grade de 6 colunas de 38 px (mínimo 30 casas): primeiro a equipe (sprite, "Nv", ⚔ no líder, ★ no resto),
##     depois as bolas e os itens com a quantidade (9999+);
##   - dica ao passar o mouse (nome ×qtd, categoria, preço de NPC, descrição; Pokémon: tipos, nível, Ativo/Equipe);
##   - duplo clique: poção cura o líder (C: use-heal na hunt, na cidade direto); Pokémon da equipe vai para o Box
##     (C: poke-store); clique numa berry ou Rare Candy abre a janela de uso.
## Só desenha o EstadoJogo e manda os comandos.

const T := preload("res://textos.gd")
const LOOT: Script = preload("res://regras_loot.gd")
const PONTE := preload("res://ponte_cidade.gd")
const BARLOW: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const BARLOW_B: Font = preload("res://assets/interface/fiel/barlow_bold.ttf")
const CINZEL: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const TOPO: Texture2D = preload("res://assets/original/inventory/bag_top.webp")
const MEIO: Texture2D = preload("res://assets/original/inventory/bag_mid.webp")
const BASE: Texture2D = preload("res://assets/original/inventory/bag_bottom.webp")
const ICONES_ABA := {"all": "tab_all", "poke": "tab_poke", "ball": "tab_ball", "item": "tab_item"}
const ABAS := [["all", "tabAll"], ["poke", "tabPokemon"], ["ball", "tabBalls"], ["item", "tabItems"]]
const CATS := [["ball", "catBall"], ["heal", "catHeal"], ["loot", "catLoot"], ["stone", "catStone"], ["berry", "catBerry"], ["held", "catHeld"], ["outros", "catItem"]]
const ICONES_BOLA := {1: "pokeball", 2: "greatball", 3: "superball", 4: "ultraball", 5: "masterball", 6: "idleball", 7: "idleball_gold"}
const LARGURA := 354.0
const REF := 1880.0

signal usar_solicitado
signal pocao_usada
signal aberto
var controlador: Node = null   # na hunt: caca_sim (a poção vai para a sim pelo use-heal)
var aba := "all"
var categoria := ""            # "" = todas
var ordem := 0                 # 0 servidor, 1 nome, 2 quantidade
var bolsa: Control
var grade: GridContainer
var status_poke: Label
var status_itens: Label
var flash: Label
var busca: LineEdit
var cat_botao: OptionButton
var dica: PanelContainer
var dica_txt: RichTextLabel
var _botoes_aba := {}
var _outfits = null
var _flash_ate := 0
var _looktype_por_nome := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veu := ColorRect.new()   # C: .inv-overlay #0009
	veu.color = Color(0, 0, 0, 0.6)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hide())
	add_child(veu)
	bolsa = Control.new()
	bolsa.name = "Bolsa"
	bolsa.mouse_filter = Control.MOUSE_FILTER_STOP
	bolsa.draw.connect(_desenhar_bolsa)
	add_child(bolsa)
	var col := VBoxContainer.new()
	col.name = "Coluna"
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = LARGURA
	bolsa.add_child(col)
	# título (C: .inv-bag .inv-title: margem 17/16, 46 px, texto em 186 px com 107 de largura; × em (308, 27,5))
	var cab := Control.new()
	cab.custom_minimum_size = Vector2(LARGURA, 17 + 46)
	col.add_child(cab)
	var tit := Label.new()
	tit.name = "Titulo"
	tit.text = T.t("window.inventory.title", {}, "Inventário").to_upper()
	tit.add_theme_font_override("font", CINZEL)
	tit.add_theme_font_size_override("font_size", 12)
	tit.add_theme_color_override("font_color", Color("e8d7bd"))
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tit.position = Vector2(16 + 186 - 2, 17)
	tit.size = Vector2(107, 30)
	cab.add_child(tit)
	var x := Button.new()
	x.name = "Fechar"
	x.text = "×"
	x.flat = true
	x.tooltip_text = T.t("window.inventory.close", {}, "Fechar")
	x.add_theme_font_size_override("font_size", 20)
	for c in ["font_color", "font_pressed_color"]:
		x.add_theme_color_override(c, Color("c92216"))
	x.add_theme_color_override("font_hover_color", Color("ff5140"))
	x.position = Vector2(308 - 12, 27.5 - 14)
	x.size = Vector2(24, 28)
	x.pressed.connect(hide)
	cab.add_child(x)
	# abas (C: grade de 4, margem 20/29/28, 58 px, intervalo 7)
	var mg_abas := MarginContainer.new()
	for k in [["margin_top", 20], ["margin_left", 28], ["margin_right", 29]]:
		mg_abas.add_theme_constant_override(k[0], k[1])
	col.add_child(mg_abas)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 7)
	abas.custom_minimum_size.y = 58
	mg_abas.add_child(abas)
	for a in ABAS:
		var b := Button.new()
		b.name = "Aba_" + String(a[0])
		b.flat = true
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 1)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := TextureRect.new()
		var at := AtlasTexture.new()   # tab_poke é uma tira de 8 quadros; o CSS final mostra o 1º (animation: none)
		at.atlas = load("res://assets/original/inventory/%s.png" % ICONES_ABA[a[0]])
		at.region = Rect2(0, 0, 32, 32)
		ic.texture = at
		ic.custom_minimum_size = Vector2(32, 32)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.name = "Icone"
		v.add_child(ic)
		var l := Label.new()
		l.name = "Texto"
		l.text = T.t("window.inventory." + String(a[1]))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", BARLOW_B)
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		var chave := String(a[0])
		b.pressed.connect(func() -> void:
			aba = chave
			atualizar())
		abas.add_child(b)
		_botoes_aba[chave] = b
	# status (C: margem 5/48, 26 px, 1fr 44px 1fr, 10,5 px #8a93a0)
	var mg_st := MarginContainer.new()
	for k in [["margin_top", 5], ["margin_left", 48], ["margin_right", 48]]:
		mg_st.add_theme_constant_override(k[0], k[1])
	col.add_child(mg_st)
	var st := HBoxContainer.new()
	st.custom_minimum_size.y = 26
	st.add_theme_constant_override("separation", 44)
	mg_st.add_child(st)
	status_poke = _rotulo_status()
	st.add_child(status_poke)
	status_itens = _rotulo_status()
	st.add_child(status_itens)
	flash = Label.new()
	flash.name = "Flash"
	flash.add_theme_font_override("font", BARLOW_B)
	flash.add_theme_font_size_override("font_size", 11)
	flash.add_theme_color_override("font_color", Color("e8d7bd"))
	flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flash.clip_text = true
	flash.visible = false
	mg_st.add_child(flash)
	# busca, categoria e ordem (A: versão atual, no vídeo)
	var mg_f := MarginContainer.new()
	for k in [["margin_top", 8], ["margin_left", 44], ["margin_right", 44]]:
		mg_f.add_theme_constant_override(k[0], k[1])
	col.add_child(mg_f)
	var fl := HBoxContainer.new()
	fl.add_theme_constant_override("separation", 6)
	mg_f.add_child(fl)
	busca = LineEdit.new()
	busca.name = "Busca"
	busca.placeholder_text = "🔎 " + T.t("window.inventory.searchPlaceholder", {}, "Buscar...")
	busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	busca.add_theme_font_override("font", BARLOW)
	busca.add_theme_font_size_override("font_size", 11)
	busca.add_theme_stylebox_override("normal", _caixa())
	busca.add_theme_stylebox_override("focus", _caixa(true))
	busca.text_changed.connect(func(_t: String) -> void: atualizar())
	fl.add_child(busca)
	cat_botao = OptionButton.new()
	cat_botao.name = "Categoria"
	cat_botao.custom_minimum_size.x = 96
	cat_botao.clip_text = true
	cat_botao.fit_to_longest_item = false
	cat_botao.add_theme_font_override("font", BARLOW_B)
	cat_botao.add_theme_font_size_override("font_size", 11)
	cat_botao.add_theme_stylebox_override("normal", _caixa())
	cat_botao.add_theme_stylebox_override("hover", _caixa(true))
	cat_botao.add_item(T.t("window.inventory.category", {}, "Categoria"))
	for c in CATS:
		cat_botao.add_item(T.t("window.inventory." + String(c[1])))
	cat_botao.item_selected.connect(func(i: int) -> void:
		categoria = "" if i == 0 else String(CATS[i - 1][0])
		atualizar())
	fl.add_child(cat_botao)
	var ord := Button.new()
	ord.name = "Ordem"
	ord.text = "⇅"
	ord.tooltip_text = "Ordem: padrão → nome → quantidade"
	ord.add_theme_stylebox_override("normal", _caixa())
	ord.add_theme_stylebox_override("hover", _caixa(true))
	ord.add_theme_stylebox_override("pressed", _caixa(true))
	ord.pressed.connect(func() -> void:
		ordem = (ordem + 1) % 3
		atualizar())
	fl.add_child(ord)
	# grade (C: margem 11/42 + padding 4/6, 6 colunas de 38 px, intervalo 6; mínimo 30 casas; base 66 px)
	var mg_g := MarginContainer.new()
	for k in [["margin_top", 11], ["margin_left", 48], ["margin_right", 48], ["margin_bottom", 66]]:
		mg_g.add_theme_constant_override(k[0], k[1])
	col.add_child(mg_g)
	var rol := ScrollContainer.new()
	rol.name = "Rolagem"
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rol.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	mg_g.add_child(rol)
	grade = GridContainer.new()
	grade.name = "Grade"
	grade.columns = 6
	grade.add_theme_constant_override("h_separation", 6)
	grade.add_theme_constant_override("v_separation", 6)
	rol.add_child(grade)
	# dica (C: .inv-tip)
	dica = PanelContainer.new()
	dica.name = "Dica"
	var sd := StyleBoxFlat.new()
	sd.bg_color = Color("08101cfa")
	sd.border_color = Color("c8aa6e")
	sd.set_border_width_all(1)
	sd.set_corner_radius_all(10)
	sd.content_margin_left = 10; sd.content_margin_right = 10; sd.content_margin_top = 8; sd.content_margin_bottom = 8
	sd.shadow_color = Color(0, 0, 0, 0.8)
	sd.shadow_size = 12
	dica.add_theme_stylebox_override("panel", sd)
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.visible = false
	dica.custom_minimum_size.x = 210
	add_child(dica)
	dica_txt = RichTextLabel.new()
	dica_txt.bbcode_enabled = true
	dica_txt.fit_content = true
	dica_txt.scroll_active = false
	dica_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica_txt.add_theme_font_override("normal_font", BARLOW)
	dica_txt.add_theme_font_override("bold_font", BARLOW_B)
	dica_txt.add_theme_font_size_override("normal_font_size", 11)
	dica_txt.add_theme_font_size_override("bold_font_size", 13)
	dica.add_child(dica_txt)
	_outfits = preload("res://render/outfits.gd").padrao()
	for e in PONTE.dados().especies.values():
		_looktype_por_nome[String(e.get("nome", e.get("name", ""))).to_lower()] = int(e.get("looktype", 0))
	resized.connect(_ajustar)
	hide()


func _rotulo_status() -> Label:
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.add_theme_font_override("font", BARLOW_B)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("8a93a0"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	return l


func _caixa(foco: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("060b13")
	s.border_color = Color("c8aa6e") if foco else Color("2a3a4e")
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 7; s.content_margin_right = 7; s.content_margin_top = 3; s.content_margin_bottom = 3
	return s


func _desenhar_bolsa() -> void:
	## C: background bag_top (topo, 100% da largura) + bag_bottom (base) + bag_mid repetido no meio.
	var w := LARGURA
	var h := bolsa.size.y
	var e := w / float(TOPO.get_width())
	var ht := TOPO.get_height() * e
	var hb := BASE.get_height() * e
	var hm := MEIO.get_height() * e
	var y := 0.0
	while y < h - 4.0:   # C: bag_mid repete por baixo do topo e da base (repeat-y no fundo da caixa toda)
		var alt := minf(hm, h - 4.0 - y)
		bolsa.draw_texture_rect_region(MEIO, Rect2(0, y, w, alt), Rect2(0, 0, MEIO.get_width(), alt / e))
		y += hm
	bolsa.draw_texture_rect(TOPO, Rect2(0, 0, w, ht), false)
	bolsa.draw_texture_rect(BASE, Rect2(0, h - hb, w, hb), false)


func _ajustar() -> void:
	if bolsa == null:
		return
	var f := maxf(0.5, size.x / REF)
	var col := bolsa.get_node("Coluna") as Control
	col.reset_size()
	var alto := maxf(306.0, col.get_combined_minimum_size().y)   # C: min-height 306px
	alto = minf(alto, size.y / f * 0.88)                          # C: max-height 88vh
	bolsa.size = Vector2(LARGURA, alto)
	col.size = bolsa.size
	bolsa.scale = Vector2(f, f)
	bolsa.position = ((size - bolsa.size * f) * 0.5).round()
	bolsa.queue_redraw()


func abrir() -> void:
	show()
	atualizar()
	aberto.emit()


func itens() -> Dictionary:
	## categoria -> [{id (do servidor), nome, qtd, preco, desc}] (filtro de categoria e testes)
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var cidade = PONTE.servico()
	var r := {}
	for c in CATS:
		r[c[0]] = []
	for id in ej.estoque_bolas:
		if int(ej.estoque_bolas[id]) > 0:
			var b: Dictionary = ej.obter_dados_bola(int(id))
			r["ball"].append({"id": int(id), "nome": String(b.get("nome", "Ball")), "qtd": int(ej.estoque_bolas[id]), "preco": int(b.get("preco", 0))})
	for id in ej.estoque_pocoes:
		if int(ej.estoque_pocoes[id]) > 0:
			var it: Dictionary = dados.itens.get(int(id), {})
			r["heal"].append({"id": int(id), "nome": String(ej.obter_dados_pocao(int(id)).get("nome", "Potion")), "qtd": int(ej.estoque_pocoes[id]),
				"preco": int(it.get("precoNpc", 0)), "desc": String(it.get("descricao", ""))})
	for interno in ej.inventario.estoque_materiais:
		var q := int(ej.inventario.estoque_materiais[interno])
		if q <= 0:
			continue
		var sid: int = LOOT.id_original(int(interno))
		var it: Dictionary = dados.itens.get(sid, {})
		var cat := String(it.get("categoria", "loot"))
		if not r.has(cat):
			cat = "outros"
		r[cat].append({"id": sid, "nome": String(it.get("nome", str(sid))), "qtd": q, "preco": cidade.preco_venda(sid), "desc": String(it.get("descricao", ""))})
	return r


func celulas() -> Array:
	## C: equipe primeiro (kind poke), depois bolas e itens; a aba filtra pelo kind.
	var ej: Node = get_node("/root/EstadoJogo")
	var r: Array = []
	var lider = ej.obter_lider()
	for p in ej.time_pokemon:
		r.append({"kind": "poke", "p": p, "nome": String(p.especie.nome) if p.especie != null else "?", "lider": p == lider, "qtd": 1})
	var tudo := itens()
	for c in CATS:
		for e in tudo[c[0]]:
			var x: Dictionary = e.duplicate()
			x["kind"] = "ball" if c[0] == "ball" else "item"
			x["cat"] = String(c[0])
			r.append(x)
	var filtro := busca.text.strip_edges().to_lower() if busca != null else ""
	r = r.filter(func(e: Dictionary) -> bool:
		if aba != "all" and String(e["kind"]) != aba:
			return false
		if categoria != "" and String(e.get("cat", "")) != categoria:
			return false
		return filtro == "" or String(e["nome"]).to_lower().find(filtro) >= 0)
	if ordem == 1:
		r.sort_custom(func(a, b): return String(a["nome"]) < String(b["nome"]))
	elif ordem == 2:
		r.sort_custom(func(a, b): return int(a.get("qtd", 0)) > int(b.get("qtd", 0)))
	return r


func atualizar() -> void:
	if grade == null:
		return
	var ej: Node = get_node("/root/EstadoJogo")
	for k in _botoes_aba:
		var on: bool = k == aba
		var b: Button = _botoes_aba[k]
		b.button_pressed = on
		(b.find_child("Texto", true, false) as Label).add_theme_color_override("font_color", Color("ffdf5e") if on else Color("8fa0b3"))
		(b.find_child("Icone", true, false) as CanvasItem).modulate = Color(1.15, 1.15, 1.1) if on else Color(0.9, 0.9, 0.9)
		var s := StyleBoxFlat.new()   # C: .dep-tab.on (brilho dourado por dentro)
		s.bg_color = Color(1, 0.87, 0.37, 0.10) if on else Color(0, 0, 0, 0)
		s.set_corner_radius_all(6)
		for estado in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(estado, s)
	var total := 0
	for c in itens().values():
		for e in c:
			total += int(e["qtd"])
	status_poke.text = T.t("window.inventory.countPoke", {"teamCount": ej.time_pokemon.size()})
	status_itens.text = T.t("window.inventory.countItems", {"itemCount": total, "itemLabel": T.t("window.inventory.itemSingular" if total == 1 else "window.inventory.itemPlural")})
	for c in grade.get_children():
		grade.remove_child(c)
		c.queue_free()
	var lista := celulas()
	var n := maxi(30, 6 * int(ceil(lista.size() / 6.0)))
	for i in n:
		grade.add_child(_casa(lista[i] if i < lista.size() else {}))
	var rol := grade.get_parent() as ScrollContainer
	rol.custom_minimum_size = Vector2(6 * 38 + 5 * 6, minf(grade.get_combined_minimum_size().y, 10 * 44 - 6))
	_ajustar()


func _casa(e: Dictionary) -> Control:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(38, 38)
	var s := StyleBoxFlat.new()   # C: .inv-slot (fundo escuro, bordas 050910/14202f/2a3a4e, raio 7)
	s.bg_color = Color("09101a")
	s.border_color = Color("14202f")
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	if String(e.get("kind", "")) == "poke":   # C: .inv-team / .inv-leader
		s.bg_color = Color("1f1c12")
		s.border_color = Color("ffdf5e") if bool(e["lider"]) else Color(0.78, 0.67, 0.43, 0.65)
	c.add_theme_stylebox_override("panel", s)
	if e.is_empty():
		c.name = "Vazia"
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return c
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var ic := TextureRect.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.position = Vector2(4, 4)
	ic.size = Vector2(30, 30)   # C: .inv-ico 78%
	c.add_child(ic)
	match String(e["kind"]):
		"poke":
			var p = e["p"]
			c.name = "P_%d" % (get_node("/root/EstadoJogo").time_pokemon as Array).find(p)
			ic.position = Vector2(3, 3)
			ic.size = Vector2(32, 32)
			var o: Dictionary = _outfits.obter(int(_looktype_por_nome.get(String(e["nome"]).to_lower(), 0)))
			var q: Dictionary = _outfits.quadro(o, 3, 0) if not o.is_empty() else {}
			if not q.is_empty():
				var at := AtlasTexture.new()
				at.atlas = q["tex"]
				at.region = q["rect"]
				ic.texture = at
			elif p.especie != null:
				ic.texture = p.especie.textura
			_selo(c, T.t("window.inventory.lvShort", {"level": int(p.nivel)}), Color("7fe6dd"), 9)
			_marca(c, "⚔" if bool(e["lider"]) else "★", Color("ffdf5e") if bool(e["lider"]) else Color("f0d78a"))
			c.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
					var erro: String = get_node("/root/EstadoJogo").mover_pokemon_depot(p, true)
					_mostrar_flash(erro if erro != "" else "📦 %s → Box" % String(e["nome"]))
					atualizar())
		"ball":
			c.name = "B_%d" % int(e["id"])
			ic.texture = load("res://assets/interface/bolas/%s.png" % ICONES_BOLA.get(int(e["id"]), "pokeball"))
			_qtd(c, int(e["qtd"]))
		_:
			c.name = "I_%d" % int(e["id"])
			var cat: Dictionary = LOOT.obter(LOOT.id_interno(int(e["id"])))
			if String(e.get("cat", "")) == "heal":
				var pc: Dictionary = get_node("/root/EstadoJogo").obter_dados_pocao(int(e["id"]))
				ic.texture = load("res://assets/interface/pocoes/%s.png" % String(pc.get("icone", "small_potion")))
			elif not cat.is_empty():
				ic.texture = LOOT.textura(String(cat.get("icone", "")))
			_qtd(c, int(e["qtd"]))
			var iid := int(e["id"])
			var cat_e := String(e.get("cat", ""))
			var nome := String(e["nome"]).to_lower()
			c.gui_input.connect(func(ev: InputEvent) -> void:
				if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
					return
				if cat_e == "heal" and ev.double_click:   # C: duplo clique na poção cura o líder
					usar_pocao(iid)
				elif cat_e == "berry" or nome.find("rare candy") >= 0:
					hide()
					usar_solicitado.emit())
	c.mouse_entered.connect(func() -> void: _mostrar_dica(e, c))
	c.mouse_exited.connect(func() -> void: dica.visible = false)
	return c


func _qtd(c: Control, q: int) -> void:
	if q > 1:   # C: .inv-qty (só acima de 1; "9999+")
		_selo(c, "9999+" if q > 9999 else str(q), Color.WHITE, 10)


func _selo(c: Control, t: String, cor: Color, tam: int) -> void:
	var l := Label.new()
	l.name = "Selo"
	l.text = t
	l.add_theme_font_override("font", BARLOW_B)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size = Vector2(36, 14)
	l.position = Vector2(0, 38 - 14)
	c.add_child(l)


func _marca(c: Control, t: String, cor: Color) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(2, -1)
	c.add_child(l)


func _mostrar_dica(e: Dictionary, c: Control) -> void:
	var t := ""
	if String(e["kind"]) == "poke":
		var p = e["p"]
		t = "[b][color=#f0e6d2]%s[/color][/b]\n" % String(e["nome"])
		if p.especie != null:
			var tipos := String(p.especie.tipo_primario)
			if String(p.especie.tipo_secundario) != "":
				tipos += " / " + String(p.especie.tipo_secundario)
			t += "[color=#9aa6b3]%s[/color]\n" % tipos
		t += "[color=#9aa6b3]%s · IV %d · Power %d[/color]\n" % [T.t("window.inventory.lvShort", {"level": int(p.nivel)}), int(p.obter_total_ivs()), int(p.obter_power())]
		t += "[color=#cfe0f5]%s[/color]" % T.t("window.inventory.chipActive" if bool(e["lider"]) else "window.inventory.chipTeam")
	else:
		t = "[b][color=#f0e6d2]%s[/color][/b]%s\n" % [String(e["nome"]), (" [color=#9aa6b3]×%s[/color]" % _milhar(int(e["qtd"]))) if int(e["qtd"]) > 1 else ""]
		var cats := {"ball": "catBall", "heal": "catHeal", "loot": "catLoot", "stone": "catStone", "berry": "catBerry", "held": "catHeld", "outros": "catItem"}
		t += "[color=#9aa6b3]%s[/color]" % T.t("window.inventory." + String(cats.get(String(e.get("cat", "outros")), "catItem"))).to_upper()
		if int(e.get("preco", 0)) > 0:
			t += "\n[color=#e8c98a][b]%s[/b][/color]" % T.t("window.inventory.price", {"price": _milhar(int(e["preco"]))})
		if String(e.get("desc", "")) != "":
			t += "\n[color=#b7c1cd]%s[/color]" % String(e["desc"])
		if String(e.get("cat", "")) == "heal":
			t += "\n[color=#ffdf5e]%s[/color]" % T.t("window.inventory.itemTitleHeal", {"name": String(e["nome"])})
	dica_txt.text = t
	dica.visible = true
	dica.size = Vector2.ZERO
	dica.reset_size()
	var f := bolsa.scale.x
	var r := c.get_global_rect()
	var pos := r.position - get_global_rect().position + Vector2(r.size.x + 8, 0)
	dica.scale = Vector2(f, f)
	if pos.x + dica.size.x * f > size.x:
		pos.x = r.position.x - get_global_rect().position.x - dica.size.x * f - 8
	dica.position = pos


static func _milhar(v: int) -> String:
	var s := str(v)
	var r := ""
	while s.length() > 3:
		r = "." + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return s + r


func _mostrar_flash(t: String) -> void:
	## C: .inv-flash — a mensagem cobre a linha de status por um instante.
	flash.text = t
	flash.visible = true
	_flash_ate = Time.get_ticks_msec() + 2500


func usar_pocao(pid: int) -> String:
	## C (tutorial "Use uma potion"): duplo clique numa Small Potion cura o líder na hora, até o valor da poção. Na hunt
	## a cura passa pela sim (use-heal); na cidade, direto no líder.
	var ej: Node = get_node("/root/EstadoJogo")
	var motivo := ""
	var antes := 0
	var lider = ej.obter_lider()
	if lider != null:
		antes = lider.obter_vida_atual()
	if controlador != null and controlador.has_method("usar_pocao"):
		controlador.usar_pocao(pid)
	else:
		motivo = ej.usar_pocao_no_lider(pid)
	if motivo == "":
		pocao_usada.emit()
		var curou: int = (lider.obter_vida_atual() - antes) if lider != null else 0
		_mostrar_flash(T.t("window.inventory.healMsg", {"name": String(ej.obter_dados_pocao(pid).get("nome", "")), "healed": curou}))
	else:
		_mostrar_flash(motivo)
	atualizar()
	return motivo


func _process(_d: float) -> void:
	if flash == null:
		return
	if flash.visible and Time.get_ticks_msec() > _flash_ate:
		flash.visible = false
	status_poke.visible = not flash.visible
	status_itens.visible = not flash.visible
