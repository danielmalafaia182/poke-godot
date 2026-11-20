extends Control
## Perfil (ciclo 4, item 7: igual ao original). Fonte C: componente do perfil no cliente (classes `.pf-*`: janela de 440 px
## com borda #9c7a34 e cabeça hexagonal com as joias turquesa, título em Cinzel dourado, avatar de 132 px, nome, VIP,
## "Nível N", barra de XP dourada com "atual / próximo XP", fichas de Rank/Pokédex/ouro/diamantes, os dois botões, as
## seções com linhas alternadas e o rodapé) e os textos window.profile do pacote. A: o vídeo do usuário
## (referencia_visual/quadros/13_perfil_outfit).
## Offline, o que é do servidor aparece como o original mostra para quem não tem: Diamantes 0, Pesca —, Bless "Sem Bless",
## Clã "Sem clã", Pontos de PokéLog 0, Rank e rankings de perfil "Em breve" (E). O resto vem do EstadoJogo.
## E: o fundo dos botões no original é /assets/evolution/lol-btn-frame.png (não baixado); aqui, uma moldura dourada.

const T := preload("res://textos.gd")
const PONTE := preload("res://ponte_cidade.gd")
const Regras := preload("res://sim/regras.gd")
const BARLOW: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const BARLOW_B: Font = preload("res://assets/interface/fiel/barlow_bold.ttf")
const CINZEL: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const POKEBOLA: Texture2D = preload("res://assets/original/profile/pokeball.png")
const ICONE_LOG: Texture2D = preload("res://assets/original/profile/capturelog.png")
const LARGURA := 440.0
const REF := 1880.0

signal log_capturas_solicitado
signal visual_solicitado
var janela: PanelContainer
var corpo: VBoxContainer
var rolagem: ScrollContainer
var avatar: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veu := ColorRect.new()   # C: .pf-overlay #02060eb8
	veu.color = Color("02060eb8")
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hide())
	add_child(veu)
	janela = PanelContainer.new()
	janela.name = "Janela"
	var s := StyleBoxFlat.new()   # C: .pf-window
	s.bg_color = Color("0d141c")
	s.border_color = Color("9c7a34")
	s.border_width_left = 2; s.border_width_right = 2; s.border_width_bottom = 2
	s.corner_radius_bottom_left = 12; s.corner_radius_bottom_right = 12
	s.shadow_color = Color(0, 0, 0, 0.72)
	s.shadow_size = 22
	janela.add_theme_stylebox_override("panel", s)
	add_child(janela)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	janela.add_child(col)
	col.add_child(_cabeca())
	rolagem = ScrollContainer.new()
	rolagem.name = "Rolagem"
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(rolagem)
	var mg := MarginContainer.new()
	for k in ["margin_left", "margin_right", "margin_top"]:
		mg.add_theme_constant_override(k, 16)
	mg.add_theme_constant_override("margin_bottom", 14)
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(mg)
	corpo = VBoxContainer.new()
	corpo.name = "Corpo"
	corpo.add_theme_constant_override("separation", 0)
	corpo.custom_minimum_size.x = LARGURA - 4 - 32
	mg.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func _cabeca() -> Control:
	## C: .pf-head — barra hexagonal escura com trilhos dourados, joias turquesa nas pontas, título e ×.
	var c := Control.new()
	c.name = "Cabeca"
	c.custom_minimum_size = Vector2(LARGURA - 4, 44)
	c.draw.connect(func() -> void:
		var w := c.size.x
		var h := c.size.y
		var k := 14.0
		var pts := PackedVector2Array([Vector2(k, 0), Vector2(w - k, 0), Vector2(w, k), Vector2(w, h - k), Vector2(w - k, h),
			Vector2(k, h), Vector2(0, h - k), Vector2(0, k)])
		c.draw_colored_polygon(pts, Color("08101a"))
		c.draw_line(Vector2(40, 1), Vector2(w - 40, 1), Color("f4e2a8"), 2.0)
		c.draw_line(Vector2(40, 4), Vector2(w - 40, 4), Color("d8b871"), 1.0)
		c.draw_line(Vector2(40, h - 1), Vector2(w - 40, h - 1), Color("7e5f28"), 2.0)
		c.draw_line(Vector2(40, h - 4), Vector2(w - 40, h - 4), Color("6a5223"), 1.0)
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("9c7a34"), 1.5)
		for x in [0.0, w]:   # C: .pf-gem (losango turquesa de 11 px)
			var cc := Vector2(x, h * 0.5)
			var g := PackedVector2Array([cc + Vector2(0, -7), cc + Vector2(7, 0), cc + Vector2(0, 7), cc + Vector2(-7, 0)])
			c.draw_colored_polygon(g, Color("0ac8b9"))
			c.draw_polyline(g + PackedVector2Array([g[0]]), Color("7fe6dd"), 1.0))
	var t := Label.new()
	t.name = "Titulo"
	t.text = T.t("window.profile.windowTitle").to_upper()
	var fv := FontVariation.new()
	fv.base_font = CINZEL
	fv.spacing_glyph = 2
	t.add_theme_font_override("font", fv)
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", Color("ddc082"))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	t.position = Vector2(46, 11)
	c.add_child(t)
	var x := Button.new()
	x.name = "Fechar"
	x.text = "×"
	x.flat = true
	x.tooltip_text = T.t("window.profile.close")
	x.add_theme_font_size_override("font_size", 20)
	x.add_theme_color_override("font_color", Color("9aa6b3"))
	x.add_theme_color_override("font_hover_color", Color("e2756b"))
	x.position = Vector2(LARGURA - 4 - 46 - 4, 6)
	x.pressed.connect(hide)
	c.add_child(x)
	return c


func abrir() -> void:
	show()
	atualizar()


func atualizar() -> void:
	if corpo == null:
		return
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	montar()
	_ajustar()


func pokedex() -> Array:
	## [capturadas, total]: espécies diferentes (normal e shiny contam uma vez) no time, na BOX e no log; total = espécies
	## que aparecem em alguma hunt (as que dá para capturar).
	var ej: Node = get_node("/root/EstadoJogo")
	var dados = PONTE.dados()
	var tem := {}
	for pk in ej.time_pokemon + ej.pokemons_capturados:
		if pk != null and pk.especie != null:
			tem[String(pk.especie.nome)] = true
	for e in ej.log_capturas:
		tem[String(e.get("especie", ""))] = true
	var todas := {}
	for h in dados.hunts.values():
		for s in h.get("spawns", []):
			todas[String(dados.especie(int(s.get("pokeId", 0))).get("nome", ""))] = true
	var c := 0
	for k in tem:
		if todas.has(k):
			c += 1
	return [c, todas.size()]


func montar() -> void:
	var ej: Node = get_node("/root/EstadoJogo")
	var nivel := int(ej.nivel_treinador)
	var xp := int(ej.experiencia_treinador_acumulada)
	var base_xp := Regras.xp_total_para_nivel(nivel)
	var prox_xp := Regras.xp_total_para_nivel(nivel + 1)
	var pd := pokedex()
	# cabeçalho (C: .pf-header): avatar 132 px + nome, VIP/nível, barra de XP, fichas
	var cab := HBoxContainer.new()
	cab.name = "Cabecalho"
	cab.add_theme_constant_override("separation", 12)
	corpo.add_child(cab)
	var av := PanelContainer.new()
	var sa := StyleBoxFlat.new()
	sa.bg_color = Color("1a1710")
	sa.border_color = Color("8a6f3a")
	sa.set_border_width_all(1)
	sa.set_corner_radius_all(8)
	av.add_theme_stylebox_override("panel", sa)
	av.custom_minimum_size = Vector2(132, 132)
	cab.add_child(av)
	avatar = TextureRect.new()
	avatar.name = "Avatar"
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	avatar.texture = _textura_treinador()
	av.add_child(avatar)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	cab.add_child(info)
	var nome := HBoxContainer.new()
	nome.add_theme_constant_override("separation", 7)
	info.add_child(nome)
	var ico := TextureRect.new()
	ico.texture = POKEBOLA
	ico.custom_minimum_size = Vector2(19, 19)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	nome.add_child(ico)
	nome.add_child(_label(String(ej.nome_treinador), CINZEL, 17, Color("f0e6d2"), "Nome"))
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 10)
	info.add_child(meta)
	if bool(ej.vip):   # C: .pf-vip-badge
		var vb := PanelContainer.new()
		var sv := StyleBoxFlat.new()
		sv.bg_color = Color("dcbc6e")
		sv.set_corner_radius_all(4)
		sv.content_margin_left = 9; sv.content_margin_right = 9; sv.content_margin_top = 2; sv.content_margin_bottom = 2
		vb.add_theme_stylebox_override("panel", sv)
		vb.add_child(_label("💎 VIP", BARLOW_B, 10, Color("1a1206")))
		meta.add_child(vb)
	var lv := RichTextLabel.new()
	lv.bbcode_enabled = true
	lv.fit_content = true
	lv.autowrap_mode = TextServer.AUTOWRAP_OFF
	lv.scroll_active = false
	lv.add_theme_font_override("normal_font", BARLOW)
	lv.add_theme_font_override("bold_font", BARLOW_B)
	lv.add_theme_font_size_override("normal_font_size", 12)
	lv.add_theme_font_size_override("bold_font_size", 12)
	lv.add_theme_color_override("default_color", Color("cfd8e2"))
	lv.text = "%s [b][color=#e8c98a]%d[/color][/b]" % [T.t("window.profile.levelPrefix"), nivel]
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(lv)
	info.add_child(_barra_xp(xp - base_xp, maxi(1, prox_xp - base_xp)))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 5)
	info.add_child(chips)
	chips.add_child(_chip("🏆 " + T.t("window.profile.soon")))
	chips.add_child(_chip("📕 " + T.t("window.profile.pokedexChip", {"count": pd[0], "total": pd[1]})))
	chips.add_child(_chip("$ " + _n(int(ej.ouro)), Color("7ee6a4")))
	chips.add_child(_chip("💎 0", Color("9fd8ff")))
	_linha_dourada(corpo, 10)
	# botões (C: .pf-btn-row .pf-outfits-btn)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 8)
	corpo.add_child(br)
	br.add_child(_botao_moldura(T.t("window.profile.customizeOutfit").trim_prefix("👕 ").to_upper(), null, "PersonalizarOutfit", func() -> void: visual_solicitado.emit()))
	br.add_child(_botao_moldura(T.t("window.profile.captureLogBtn").to_upper(), ICONE_LOG, "AbrirLog", func() -> void: log_capturas_solicitado.emit()))
	# seções (C: .pf-section, .pf-row, linhas pares mais claras; valor em .acc dourado)
	_secao(T.t("window.profile.sectionGeneral"), [
		[T.t("window.profile.rowLevel"), str(nivel), true],
		[T.t("window.profile.rowExperience"), T.t("window.profile.xpValue", {"xp": _n(xp)}), false],
		[T.t("window.profile.rowGold"), "$ " + _n(int(ej.ouro)), false],
		[T.t("window.profile.rowDiamonds"), "💎 0", false],
		[T.t("window.profile.rowFishing"), "—", false],
		[T.t("window.profile.rowVip"), T.t("window.profile.vipActive") if bool(ej.vip) else T.t("window.profile.vipNo"), true],
		[T.t("window.profile.rowBless"), T.t("window.profile.noBless"), false],
		[T.t("window.profile.rowClan"), T.t("window.profile.noClan"), true]])
	_secao(T.t("window.profile.sectionProgression"), [
		[T.t("window.profile.rowTotalCatches"), _n(int(ej.capturas_total)), true],
		[T.t("window.profile.rowPokedex"), "%d/%d" % [pd[0], pd[1]], false],
		["", "", false, float(pd[0]) / maxf(1.0, float(pd[1]))],
		[T.t("window.profile.rowPokelogPoints"), "0", false],
		[T.t("window.profile.rowTrainerRank"), T.t("window.profile.soon"), false],
		[T.t("window.profile.rowHuntTime"), _duracao(int(ej.tempo_caca_s)), false]])
	_secao(T.t("window.profile.sectionRankings"), [
		[T.t("window.profile.rankNightmare"), "0", false], [T.t("window.profile.rankStylist"), "0", false],
		[T.t("window.profile.rankEngineer"), "0", false], [T.t("window.profile.rankProfessor"), "0", false]])
	_secao(T.t("window.profile.sectionPvp"), [
		[T.t("window.profile.pvpScore"), "0", false], [T.t("window.profile.pvpWins"), "0", false],
		[T.t("window.profile.pvpLosses"), "0", false]])
	_linha_dourada(corpo, 14)
	var rod := _label(T.t("window.profile.footer", {"name": String(ej.nome_treinador)}), BARLOW, 11, Color("7c8794"), "Rodape")
	rod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corpo.add_child(rod)


func _textura_treinador() -> Texture2D:
	var ej: Node = get_node("/root/EstadoJogo")
	var o = preload("res://render/outfits.gd").padrao()
	var vis: Dictionary = ej.visual if ej.visual is Dictionary else {}
	var ou: Dictionary = o.obter(int(vis.get("looktype", 5759)), vis.get("cores", {}))
	var q: Dictionary = o.quadro(ou, 2, 0) if not ou.is_empty() else {}
	if q.is_empty():
		return null
	var img: Image = (q["tex"] as Texture2D).get_image().get_region(q["rect"])
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


func _label(t: String, f: Font, tam: int, cor: Color, nome: String = "") -> Label:
	var l := Label.new()
	if nome != "":
		l.name = nome
	l.text = t
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	return l


func _barra_xp(atual: int, total: int) -> Control:
	## C: .pf-bar.pf-xpbar — 15 px, fundo escuro, preenchimento dourado, texto "atual / próximo XP" no meio.
	var c := Control.new()
	c.name = "BarraXP"
	c.custom_minimum_size = Vector2(0, 15)
	var frac := clampf(float(atual) / float(total), 0.0, 1.0)
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0e141d")
		sb.border_color = Color(0, 0, 0, 0.65)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		c.draw_style_box(sb, r)
		if frac > 0.0:
			var sf := StyleBoxFlat.new()
			sf.bg_color = Color("d6b35e")
			sf.set_corner_radius_all(6)
			c.draw_style_box(sf, Rect2(Vector2(1, 1), Vector2((c.size.x - 2) * frac, c.size.y - 2)))
			c.draw_rect(Rect2(Vector2(1, 1), Vector2((c.size.x - 2) * frac, (c.size.y - 2) * 0.45)), Color(1, 1, 1, 0.25)))
	var l := _label(T.t("window.profile.xpBarLabel", {"current": _n(atual), "next": _n(total)}), BARLOW_B, 10, Color("1a1206"))
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.2))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(l)
	return c


func _chip(t: String, cor: Color = Color("e6eefc")) -> Control:
	var p := PanelContainer.new()   # C: .pf-chip
	var s := StyleBoxFlat.new()
	s.bg_color = Color("161e28")
	s.border_color = Color("2c3a4c")
	s.border_width_top = 1; s.border_width_bottom = 1; s.border_width_left = 1; s.border_width_right = 1
	s.set_corner_radius_all(999)
	s.content_margin_left = 9; s.content_margin_right = 9; s.content_margin_top = 2; s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.add_child(_label(t, BARLOW_B, 10, cor))
	return p


func _botao_moldura(t: String, icone: Texture2D, nome: String, acao: Callable) -> Button:
	var b := Button.new()   # C: .pf-outfits-btn (Cinzel 10,5 px, maiúsculas, #ead9c0)
	b.name = nome
	b.text = t
	b.icon = icone
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 18)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fv := FontVariation.new()
	fv.base_font = CINZEL
	fv.spacing_glyph = 1
	b.add_theme_font_override("font", fv)
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color("ead9c0"))
	b.add_theme_color_override("font_hover_color", Color("fff3dc"))
	for estado in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("1a1f26") if estado == "normal" else Color("242b35")
		s.border_color = Color("b8985a")
		s.set_border_width_all(2)
		s.set_corner_radius_all(3)
		s.content_margin_top = 12; s.content_margin_bottom = 12; s.content_margin_left = 8; s.content_margin_right = 8
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 3
		b.add_theme_stylebox_override(estado, s)
	b.pressed.connect(acao)
	return b


func _linha_dourada(pai: Control, topo: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, topo + 3)
	c.draw.connect(func() -> void:
		c.draw_line(Vector2(0, topo), Vector2(c.size.x, topo), Color("e8cd8dcc"), 1.0)
		c.draw_line(Vector2(0, topo + 2), Vector2(c.size.x, topo + 2), Color("6a5223d9"), 1.0))
	pai.add_child(c)


func _secao(titulo: String, linhas: Array) -> void:
	var t := _label(titulo, CINZEL, 14, Color("f0e6d2"))
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_top", 11)
	mg.add_child(t)
	corpo.add_child(mg)
	_linha_dourada(corpo, 2)
	var i := 0
	for ln in linhas:
		if ln.size() > 3:   # barra de progresso (Pokédex)
			var bar := Control.new()
			bar.custom_minimum_size = Vector2(0, 12)
			var fr: float = ln[3]
			bar.draw.connect(func() -> void:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color("0e141d")
				sb.set_corner_radius_all(6)
				bar.draw_style_box(sb, Rect2(Vector2(0, 2), Vector2(bar.size.x, 8)))
				var sf := StyleBoxFlat.new()
				sf.bg_color = Color("d6b35e")
				sf.set_corner_radius_all(6)
				bar.draw_style_box(sf, Rect2(Vector2(0, 2), Vector2(bar.size.x * clampf(fr, 0.0, 1.0), 8))))
			corpo.add_child(bar)
			continue
		var p := PanelContainer.new()
		var s := StyleBoxFlat.new()   # C: .pf-row (as pares levemente mais claras)
		s.bg_color = Color(1, 1, 1, 0.03) if i % 2 == 1 else Color(0, 0, 0, 0)
		s.set_corner_radius_all(5)
		s.content_margin_left = 6; s.content_margin_right = 6; s.content_margin_top = 3; s.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", s)
		var h := HBoxContainer.new()
		p.add_child(h)
		var l := _label(String(ln[0]), BARLOW, 12, Color("9fb0c2"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var v := _label(String(ln[1]), BARLOW_B, 12, Color("e8c98a") if bool(ln[2]) else Color("e6eefc"))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)
		corpo.add_child(p)
		i += 1


func _ajustar() -> void:
	if janela == null:
		return
	var f := maxf(0.5, size.x / REF)
	janela.scale = Vector2(f, f)
	var alto := minf(size.y / f * 0.86, (corpo.get_combined_minimum_size().y if corpo != null else 400.0) + 44 + 30)
	janela.size = Vector2(LARGURA, alto)
	rolagem.custom_minimum_size.y = alto - 44
	janela.position = ((size - janela.size * f) * 0.5).round()


static func _n(v: int) -> String:
	var s := str(absi(v))
	var r := ""
	while s.length() > 3:
		r = "." + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + r


static func _duracao(seg: int) -> String:
	var h := seg / 3600
	var m := (seg % 3600) / 60
	return "%dh %02dmin" % [h, m] if h > 0 else "%d min" % m
