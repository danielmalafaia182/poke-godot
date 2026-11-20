extends Control
## Tutorial do Professor Carvalho (ciclo 4: igual ao original). Fonte C: componente do tutorial no cliente (chunk
## 0gx72gz9qjk5j.js `cC`: os 17 passos na ordem, com `target` destacado, `npc` com o caminho de pontos, `advance` que fecha
## o passo sozinho e `clearOak`), o CSS `.tutg-*` (véu #02060c9e, holofote com contorno #ffe08a, anel de 78 px no NPC,
## pontos de 9 px, mão apontando com o salto vertical, balão #fdfcf7 de 370 px a 208 px da direita e 238 px do pé, Oak de
## 310 px no canto, contagem, título, texto com <b> em #0b5cad, caixa de objetivo, CTA dourado, "Pular tutorial"), os
## textos window.tutorial do pacote e as artes professor_oak_cut.png e hand_pointer.png. A: o vídeo do usuário
## (referencia_visual/quadros/05_tutorial_cidade) confere a disposição.
## Passos de ação (C): nurse/depot/shop fecham ao abrir a janela do NPC; openMap ao abrir o mapa; firstHunt ao entrar na
## hunt; hunting no 1º abate; throwBall ao lançar uma bola pelo painel de captura; openInv ao abrir a mochila; usePotion ao
## usar uma Small Potion (duplo clique ou "Usar"). Fora do offline (E): o Mercado entre jogadores — o passo `market`
## aparece e só avança no clique.
## O passo atual vai no save (EstadoJogo.tutorial_passo: "" nunca começou, "fim" concluído); ⚙ → 🎓 Tutorial refaz.

const T := preload("res://textos.gd")
const BARLOW: Font = preload("res://assets/interface/fiel/barlow_regular.ttf")
const BARLOW_B: Font = preload("res://assets/interface/fiel/barlow_bold.ttf")
const OAK: Texture2D = preload("res://assets/original/images/professor_oak_cut.png")
const MAO: Texture2D = preload("res://assets/original/ui/hand_pointer.png")
const REF := 1880.0
const VEU := Color("02060c9e")          # C: .tutg-dim / box-shadow do holofote
const OURO := Color("ffe08a")           # C: contorno, anel e pontos
# C: os 17 passos (ordem do cliente). onde: cidade / hunt / ambos.
const PASSOS := [
	{"k": "welcome", "onde": "cidade"},
	{"k": "party", "onde": "cidade", "alvo": "party"},
	{"k": "menu", "onde": "cidade", "alvo": "dock"},
	{"k": "walk", "onde": "cidade"},
	{"k": "nurse", "onde": "cidade", "npc": "nurse", "acao": "npc"},
	{"k": "depot", "onde": "cidade", "npc": "depot", "acao": "npc"},
	{"k": "shop", "onde": "cidade", "npc": "mark", "acao": "npc"},
	{"k": "market", "onde": "cidade", "npc": "market"},
	{"k": "openMap", "onde": "cidade", "alvo": "dock-map", "acao": "map-open"},
	{"k": "firstHunt", "onde": "cidade", "acao": "in-hunt"},
	{"k": "hunting", "onde": "hunt", "acao": "first-kill"},
	{"k": "throwBall", "onde": "hunt", "alvo": "capture", "acao": "ball-thrown", "sem_oak": true},
	{"k": "openInv", "onde": "ambos", "alvo": "dock-inventory", "acao": "inv-open"},
	{"k": "usePotion", "onde": "ambos", "alvo": "inv-200", "acao": "potion-used"},
	{"k": "captureMgmt", "onde": "ambos", "alvo": "dock-usedballs"},
	{"k": "replay", "onde": "ambos", "alvo": "dock-config"},
	{"k": "done", "onde": "ambos", "final": true},
]
const OBJETIVO_PAINEL := {"nurse": "NurseJoy", "depot": "PainelDepot", "shop": "PainelLoja", "openMap": "MapaMundi", "openInv": "PainelInventario"}
const CELULAS_NPC := {"nurse": Vector2i(-3, -10), "depot": Vector2i(-8, -14), "mark": Vector2i(22, 8)}   # A: city-npcs de Cerulean

var na_hunt := false
var raiz: Node                    # Interface da cidade ou o HUD da hunt
var veu: Array[ColorRect] = []    # 4 faixas em volta do holofote (ou a tela toda numa só)
var cartao: PanelContainer
var contador: Label
var titulo: Label
var texto: RichTextLabel
var objetivo: PanelContainer
var objetivo_txt: RichTextLabel
var continuar: Button
var comecar: Button
var pular_passo: Button
var pular: Button
var oak: TextureRect
var ponta: Polygon2D
var destaque: Panel
var mao: TextureRect
var trilha: Node2D
var _ultimo := "-"
var _novo_aberto := false
var _inventario_ligado: Object = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var v := ColorRect.new()
		v.name = "Veu%d" % i
		v.color = VEU
		v.mouse_filter = Control.MOUSE_FILTER_STOP
		v.gui_input.connect(_clique_veu)
		add_child(v)
		veu.append(v)
	destaque = Panel.new()
	destaque.name = "Destaque"
	var sd := StyleBoxFlat.new()   # C: .tutg-spot (radius 10, outline 2px #ffe08a, brilho)
	sd.bg_color = Color(0, 0, 0, 0)
	sd.border_color = OURO
	sd.set_border_width_all(2)
	sd.set_corner_radius_all(10)
	destaque.add_theme_stylebox_override("panel", sd)
	destaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(destaque)
	mao = TextureRect.new()
	mao.name = "Mao"
	mao.texture = MAO
	mao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mao.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mao)
	oak = TextureRect.new()
	oak.name = "Oak"
	oak.texture = OAK
	oak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	oak.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	oak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oak)
	ponta = Polygon2D.new()   # C: .tutg-bubble:after (triângulo de 12 px, 26 px acima do pé do balão)
	ponta.color = Color("fdfcf7")
	ponta.polygon = PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12)])
	add_child(ponta)
	cartao = PanelContainer.new()
	cartao.name = "CartaoTutorial"
	var s := StyleBoxFlat.new()   # C: .tutg-bubble
	s.bg_color = Color("fdfcf7")
	s.set_corner_radius_all(14)
	s.shadow_color = Color(0, 0, 0, 0.65)
	s.shadow_size = 20
	s.shadow_offset = Vector2(0, 12)
	s.content_margin_left = 16; s.content_margin_right = 16; s.content_margin_top = 14; s.content_margin_bottom = 12
	cartao.add_theme_stylebox_override("panel", s)
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	cartao.gui_input.connect(_clique_veu)   # C: clicar no balão continua (cursor pointer)
	add_child(cartao)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = 370 - 32
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(col)
	contador = _rotulo(10.5, Color("98a2b3"), 0.06)
	contador.name = "Contador"
	col.add_child(contador)
	titulo = _rotulo(16, Color("14202e"), 0)
	titulo.name = "Titulo"
	col.add_child(_espaco(2))
	col.add_child(titulo)
	col.add_child(_espaco(6))
	texto = _rich(13, Color("1c2430"), BARLOW)
	texto.name = "Texto"
	texto.add_theme_constant_override("line_separation", 7)   # C: line-height 1.55
	col.add_child(texto)
	objetivo = PanelContainer.new()
	objetivo.name = "Objetivo"
	var so := StyleBoxFlat.new()   # C: .tutg-goal
	so.bg_color = Color("c8a24e24")
	so.border_color = Color("d9bd7a")
	so.set_border_width_all(1)
	so.set_corner_radius_all(8)
	so.content_margin_left = 10; so.content_margin_right = 10; so.content_margin_top = 7; so.content_margin_bottom = 7
	objetivo.add_theme_stylebox_override("panel", so)
	objetivo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mg := MarginContainer.new()
	mg.add_theme_constant_override("margin_top", 9)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mg.add_child(objetivo)
	col.add_child(mg)
	objetivo_txt = _rich(12, Color("6b4a12"), BARLOW_B)
	objetivo.add_child(objetivo_txt)
	col.add_child(_espaco(10))
	continuar = _botao("Continuar", Color("b8860b"), 10.5, 0.14)   # C: .tutg-cta
	continuar.pressed.connect(avancar)
	col.add_child(continuar)
	comecar = Button.new()   # C: .tutg-finish
	comecar.name = "Comecar"
	comecar.text = T.t("window.tutorial.startJourneyBtn")
	comecar.add_theme_font_override("font", BARLOW_B)
	comecar.add_theme_font_size_override("font_size", 14)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		comecar.add_theme_color_override(c, Color("1a1206"))
	for estado in ["normal", "hover", "pressed"]:
		var sf := StyleBoxFlat.new()
		sf.bg_color = Color("d7b76e") if estado == "normal" else Color("e6cd8e")
		sf.set_corner_radius_all(9)
		sf.content_margin_top = 11; sf.content_margin_bottom = 11
		comecar.add_theme_stylebox_override(estado, sf)
	comecar.pressed.connect(avancar)
	col.add_child(comecar)
	pular_passo = _botao("PularPasso", Color("b8860b"), 10.5, 0.14)
	pular_passo.text = T.t("window.tutorial.skipStep")
	pular_passo.pressed.connect(avancar)
	col.add_child(pular_passo)
	pular = _botao("PularTutorial", Color("98a2b3"), 11, 0)   # C: .tutg-skip
	pular.text = T.t("window.tutorial.skipTutorial")
	pular.pressed.connect(func() -> void: _definir("fim"))
	col.add_child(pular)
	resized.connect(_ajustar)
	_mostrar()


func _espaco(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _fonte(espaco_em: float, tam: float) -> Font:
	var fv := FontVariation.new()
	fv.base_font = BARLOW_B
	fv.variation_embolden = 0.35   # C: font-weight 800–900
	fv.spacing_glyph = int(round(espaco_em * tam))
	return fv


func _rotulo(tam: float, cor: Color, espaco_em: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _fonte(espaco_em, tam))
	l.add_theme_font_size_override("font_size", int(round(tam)))
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rich(tam: int, cor: Color, f: Font) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", f)
	r.add_theme_font_override("bold_font", BARLOW_B)
	r.add_theme_font_size_override("normal_font_size", tam)
	r.add_theme_font_size_override("bold_font_size", tam)
	r.add_theme_color_override("default_color", cor)
	return r


func _botao(nome: String, cor: Color, tam: float, espaco_em: float) -> Button:
	var b := Button.new()
	b.name = nome
	b.flat = true
	b.add_theme_font_override("font", _fonte(espaco_em, tam))
	b.add_theme_font_size_override("font_size", int(round(tam)))
	b.add_theme_color_override("font_color", cor)
	b.add_theme_color_override("font_hover_color", cor.darkened(0.25))
	b.add_theme_color_override("font_pressed_color", cor.darkened(0.25))
	return b


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func passo() -> String:
	return String(_ej().tutorial_passo)


static func indice(k: String) -> int:
	for i in PASSOS.size():
		if String(PASSOS[i]["k"]) == k:
			return i
	return -1


func _definir(p: String) -> void:
	_ej().tutorial_passo = p
	_ej().solicitar_salvamento()
	_mostrar()


func reiniciar() -> void:
	_definir("welcome")


func avancar() -> void:
	var i := indice(passo())
	_definir("fim" if i < 0 or i + 1 >= PASSOS.size() else String(PASSOS[i + 1]["k"]))


func _passo_de_clique() -> bool:
	var i := indice(passo())
	return i >= 0 and not PASSOS[i].has("acao") and not bool(PASSOS[i].get("final", false))


func _clique_veu(ev: InputEvent) -> void:
	## C: o véu e o balão têm cursor pointer: nos passos sem ação, clicar continua.
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _passo_de_clique():
		accept_event()
		avancar()


func _vars() -> Dictionary:
	var lider = _ej().obter_lider()
	var tem := lider != null and lider.especie != null
	var starter := String(lider.especie.nome) if tem else T.t("window.tutorial.starterFallback")
	var tipo := String(lider.especie.tipo_primario).to_lower() if tem else "grass"
	var hunt: String = {"grass": "Geodude", "water": "Geodude", "fire": "Paras"}.get(tipo, "Geodude")   # C: cy
	var why := T.t("window.tutorial.why." + tipo) if T.tem("window.tutorial.why." + tipo) else ""
	return {"starter": starter, "hunt": hunt, "why": why}


static func azul(s: String, cor: String = "#0b5cad") -> String:
	## <b>x</b> → negrito na cor do CSS (.tutg-text b #0b5cad; .tutg-goal b #1c2430)
	return s.replace("<b>", "[color=%s][b]" % cor).replace("</b>", "[/b][/color]").replace("<br>", "\n")


func _mostrar() -> void:
	var p := passo()
	var i := indice(p)
	var onde := String(PASSOS[i]["onde"]) if i >= 0 else ""
	visible = i >= 0 and (onde == "ambos" or (onde == "hunt") == na_hunt)
	_limpar_trilha()
	if not visible:
		return
	var d: Dictionary = PASSOS[i]
	contador.text = "%d / %d" % [i + 1, PASSOS.size()]
	titulo.text = T.t("window.tutorial.step.%s.title" % p)
	texto.text = azul(T.t("window.tutorial.step.%s.text" % p, _vars()))
	var gol := ""
	if d.has("npc") and String(d["npc"]) != "market":
		gol = T.t("window.tutorial.goalWalkFollowDots", {"npcName": T.t("window.tutorial.npc." + String(d["npc"]))})
	elif T.tem("window.tutorial.step.%s.goal" % p):
		gol = T.t("window.tutorial.step.%s.goal" % p, {"hunt": String(_vars()["hunt"])})
	objetivo.get_parent().visible = gol != ""
	objetivo_txt.text = azul(gol, "#1c2430")
	var acao := d.has("acao")
	var final := bool(d.get("final", false))
	continuar.visible = not acao and not final
	continuar.text = T.t("window.tutorial.clickToContinue")
	comecar.visible = final
	pular_passo.visible = acao
	pular.visible = not final
	oak.visible = not bool(d.get("sem_oak", false))
	if d.has("npc") and not na_hunt:
		_desenhar_trilha(String(d["npc"]))
	_ajustar()


func _ajustar() -> void:
	if cartao == null:
		return
	var f := maxf(0.5, size.x / REF)
	var oak_h := minf(310.0 * f, 0.38 * size.y)   # C: .tutg-oak height min(310px, 38vh), bottom 0, right 6px
	oak.size = Vector2(oak_h * float(OAK.get_width()) / OAK.get_height(), oak_h)
	oak.position = Vector2(size.x - oak.size.x - 6.0 * f, size.y - oak_h)
	cartao.scale = Vector2(f, f)
	cartao.size = Vector2.ZERO
	cartao.reset_size()
	var w := cartao.size.x * f
	var h := cartao.size.y * f
	var dir := size.x - 208.0 * f   # C: .tutg-bubble right 208px, bottom min(238px, 30vh)
	var pe := minf(238.0 * f, 0.3 * size.y)
	cartao.position = Vector2(dir - w, size.y - pe - h)
	ponta.visible = oak.visible
	ponta.position = Vector2(dir, size.y - pe - (26.0 + 12.0) * f)
	ponta.scale = Vector2(f, f)


func _menu() -> Node:
	var dock := raiz.find_child("DockOriginal", true, false) if raiz != null else null
	return dock.get_parent() if dock != null else null


func alvo() -> Control:
	var i := indice(passo())
	if i < 0 or not PASSOS[i].has("alvo") or raiz == null:
		return null
	var menu := _menu()
	var botoes: Dictionary = menu.botoes if menu != null and "botoes" in menu else {}
	match String(PASSOS[i]["alvo"]):
		"party":
			return raiz.find_child("PainelTime", true, false) as Control
		"dock":
			return raiz.find_child("DockOriginal", true, false) as Control
		"dock-map":
			return botoes.get("map")
		"dock-inventory":
			return botoes.get("inventory")
		"dock-usedballs":
			return botoes.get("usedballs")
		"dock-config":
			var c := botoes.get("config") as Control
			return c if c != null and c.is_visible_in_tree() else raiz.find_child("Configuracoes", true, false) as Control
		"capture":
			return raiz.find_child("PainelCaptura", true, false) as Control
		"inv-200":
			return raiz.find_child("I_200", true, false) as Control
	return null


func _posicionar_veu(buraco: Rect2, ligado: bool) -> void:
	## C: sem alvo, .tutg-dim na tela toda; com alvo, o holofote (box-shadow 100vmax) deixa o alvo aceso e clicável.
	for v in veu:
		v.visible = ligado
	if not ligado:
		return
	if buraco.size == Vector2.ZERO:
		veu[0].position = Vector2.ZERO
		veu[0].size = size
		for k in range(1, 4):
			veu[k].visible = false
		return
	var a := buraco.position
	var b := buraco.end
	veu[0].position = Vector2.ZERO; veu[0].size = Vector2(size.x, maxf(0.0, a.y))
	veu[1].position = Vector2(0, b.y); veu[1].size = Vector2(size.x, maxf(0.0, size.y - b.y))
	veu[2].position = Vector2(0, a.y); veu[2].size = Vector2(maxf(0.0, a.x), buraco.size.y)
	veu[3].position = Vector2(b.x, a.y); veu[3].size = Vector2(maxf(0.0, size.x - b.x), buraco.size.y)


func _desenhar_trilha(npc: String) -> void:
	## C: "siga os pontos" (.tutg-dot 9 px #ffe08a pulsando) do herói até o NPC, e o anel de 78 px (.tutg-ring) nele.
	if not CELULAS_NPC.has(npc):
		return
	var cena := get_tree().current_scene
	if cena == null or not ("personagem" in cena) or cena.personagem == null or not ("cenario" in cena) or cena.cenario == null:
		return
	var cam := caminho(cena.cenario, cena.personagem.celula, CELULAS_NPC[npc])
	if cam.size() < 2:
		return
	trilha = Node2D.new()
	trilha.name = "TrilhaTutorial"
	trilha.z_index = 50
	trilha.set_meta("pontos", cam)
	trilha.set_meta("npc", CELULAS_NPC[npc])
	var t := trilha
	t.draw.connect(func() -> void:
		var pts: Array = t.get_meta("pontos")
		var fase := Time.get_ticks_msec() / 1000.0
		for k in range(pts.size() - 1, 0, -2):   # A (vídeo, v1_00123): um ponto a cada 2 casas, até o NPC
			var c := Vector2(pts[k]) * 32.0 + Vector2(16, 16)
			t.draw_circle(c + Vector2(0, 1), 5.5, Color(0, 0, 0, 0.6))
			t.draw_circle(c, 6.5, Color(OURO, 0.25))
			t.draw_circle(c, 4.5, Color(OURO, 0.45 + 0.55 * (0.5 + 0.5 * sin(TAU * fase / 1.1))))
		var centro := Vector2(t.get_meta("npc")) * 32.0 + Vector2(16, 16)
		var r := 39.0 * (1.0 + 0.06 * (1.0 + sin(TAU * fase / 1.2)))
		t.draw_arc(centro, r + 3.0, 0, TAU, 48, Color(OURO, 0.35), 6.0)
		t.draw_arc(centro, r, 0, TAU, 48, OURO, 3.0))
	cena.cenario.add_child(trilha)


static func caminho(cen: Object, de: Vector2i, para: Vector2i) -> Array:
	## Busca em largura a partir do herói; destino = a célula alcançável mais perto do NPC (Chebyshev; os NPCs da cidade
	## ficam atrás do balcão e se clica por cima dele), e entre essas a de caminho mais curto. [] se nada perto.
	var fila: Array = [de]
	var veio := {de: de}
	var fim := de
	var melhor := maxi(absi(de.x - para.x), absi(de.y - para.y))
	var n := 0
	while not fila.is_empty() and n < 40000:
		n += 1
		var c: Vector2i = fila.pop_front()
		var dist := maxi(absi(c.x - para.x), absi(c.y - para.y))
		if dist < melhor and c != para:
			melhor = dist
			fim = c
		for dlt in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + dlt
			if not veio.has(v) and cen.celula_transitavel(v):
				veio[v] = c
				fila.append(v)
	if melhor > 3:
		return []
	var r: Array = [fim]
	while r[0] != de:
		r.push_front(veio[r[0]])
	return r


func _limpar_trilha() -> void:
	if trilha != null and is_instance_valid(trilha):
		trilha.queue_free()
	trilha = null


func ao_abate() -> void:
	ao_evento("first-kill")


func ao_evento(ev: String) -> void:
	## Ações que fecham o passo (C: advance): first-kill, ball-thrown, inv-open, potion-used.
	var i := indice(passo())
	if i >= 0 and String(PASSOS[i].get("acao", "")) == ev:
		avancar()


func _ligar_inventario() -> void:
	var inv := raiz.find_child("PainelInventario", true, false) if raiz != null else null
	if inv != null and inv != _inventario_ligado and inv.has_signal("pocao_usada"):
		inv.pocao_usada.connect(func() -> void: ao_evento("potion-used"))
		_inventario_ligado = inv


func _process(_d: float) -> void:
	var p := passo()
	var novo := raiz != null and raiz.get_node_or_null("PainelNovoJogo") != null
	if p != _ultimo or novo != _novo_aberto:
		_ultimo = p
		_novo_aberto = novo
		_mostrar()
		if novo:
			visible = false
	if na_hunt and p == "firstHunt":
		_definir("hunting")
		return
	_ligar_inventario()
	var a := alvo() if visible else null
	var com_alvo := a != null and a.is_visible_in_tree()
	var buraco := Rect2()
	if com_alvo:
		var r := a.get_global_rect()
		buraco = Rect2(r.position - get_global_rect().position - Vector2(4, 4), r.size + Vector2(8, 8))
	_posicionar_veu(buraco, visible and (com_alvo or _passo_de_clique() or bool(PASSOS[maxi(0, indice(p))].get("final", false))))
	destaque.visible = com_alvo
	mao.visible = com_alvo
	if com_alvo:
		var fase := Time.get_ticks_msec() / 1000.0
		var cresce := 2.0 * (0.5 + 0.5 * sin(TAU * fase / 1.4))   # C: tutg-glow (outline-offset 0 → 4 px)
		destaque.position = buraco.position - Vector2(cresce, cresce)
		destaque.size = buraco.size + Vector2(cresce, cresce) * 2.0
		var f := maxf(0.5, size.x / REF)
		mao.size = Vector2(48, 48) * f
		var salto := lerpf(8.0, -2.0, 0.5 + 0.5 * sin(TAU * fase / 1.0)) * f   # C: tutg-bounce-y (margin-top 8 → −2)
		mao.position = Vector2(buraco.get_center().x, buraco.end.y) - mao.size * 0.5 + Vector2(0, salto)
	if trilha != null and is_instance_valid(trilha):
		trilha.queue_redraw()
	if not visible or raiz == null:
		return
	if OBJETIVO_PAINEL.has(p):
		var painel := raiz.find_child(String(OBJETIVO_PAINEL[p]), true, false) as CanvasItem
		if painel != null and painel.is_visible_in_tree():
			avancar()
