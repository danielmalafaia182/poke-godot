extends PanelContainer
## Painel de captura da hunt (ciclo 4: igual ao original, C: componente `cap-panel` do cliente e o CSS `.cap-*`; textos
## hud.captureBar do pacote). Só desenha e manda o comando:
##   - aparece só enquanto há selvagem capturável (lista `pending`, A: 20 s depois do abate) ou uma mensagem de resultado;
##   - cabeçalho "Capturar" + "N selvagens" (o tamanho da lista pendente) + link da loja;
##   - fichas das bolas com estoque (a escolhida em destaque), linhas com sprite, nome, nível e "Lançar";
##   - lançar trava 4 s ("Aguarde Ns"); o resultado aparece 2,5 s ("Capturou… / … escapou").
## O controlador (caca_sim.gd) manda os pendentes e o resultado; `lancar(pending_id, ball_id)` vai para a sim (catch).

const T := preload("res://textos.gd")
const CINZEL: Font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
const BARLOW_B: Font = preload("res://assets/interface/fiel/barlow_bold.ttf")
const ICONES := {1: "pokeball", 2: "greatball", 3: "superball", 4: "ultraball", 5: "masterball", 6: "idleball", 7: "idleball_gold"}

var controlador: Node
var pendentes: Array = []
var bola_escolhida := 0
var flash := ""
var _flash_ate := 0
var _livre_ms := 0
var _lancados := {}
var _outfits = null
var _col: VBoxContainer
var _assinatura := ""


func _ready() -> void:
	name = "PainelCaptura"
	var s := StyleBoxFlat.new()   # C: linear-gradient(#101823f7, #090e15f7); border 2px #785a28; radius 10; padding 9
	s.bg_color = Color("0d141df7")
	s.border_color = Color("785a28")
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(9)
	add_theme_stylebox_override("panel", s)
	custom_minimum_size.x = 264
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 7)
	add_child(_col)
	_outfits = preload("res://render/outfits.gd").padrao()
	EstadoJogo.estoque_bolas_alterado.connect(func() -> void: _assinatura = ""; desenhar())
	desenhar()


func receber_pendentes(lista: Array) -> void:
	pendentes = lista.duplicate(true)
	var ids := {}
	for e in pendentes:
		ids[int(e["id"])] = true
	for k in _lancados.keys():
		if not ids.has(k):
			_lancados.erase(k)
	_assinatura = ""
	desenhar()


func receber_resultado(msg: Dictionary) -> void:
	if msg.get("pendingId") == null and bool(msg.get("auto", true)):
		return
	flash = T.t("hud.captureBar.flashCaptured", {"species": String(msg.get("speciesName", "")), "ball": String(msg.get("ballName", ""))}) if bool(msg.get("success", false)) \
		else T.t("hud.captureBar.flashEscaped", {"species": String(msg.get("speciesName", ""))})
	_flash_ate = Time.get_ticks_msec() + 2500
	if msg.has("cooldownMs"):
		_livre_ms = Time.get_ticks_msec() + int(msg["cooldownMs"])
	_assinatura = ""
	desenhar()


func bolas_com_estoque() -> Array:
	var r: Array = []
	for id in [1, 2, 3, 4, 5, 6, 7]:
		if EstadoJogo.obter_quantidade_bola(id) > 0 and id != 5:   # C: a Master Ball não entra no lançamento rápido (E: só pelo Auto-Helper)
			r.append(id)
	return r


func lancar(pending_id: int, ball_id: int = -1) -> void:
	var b := ball_id if ball_id > 0 else bola_escolhida
	if b <= 0 or _lancados.has(pending_id) or Time.get_ticks_msec() < _livre_ms:
		return
	_lancados[pending_id] = true
	_livre_ms = Time.get_ticks_msec() + 4000   # C: o cliente trava 4 s na hora do lançamento
	if controlador != null and controlador.has_method("lancar_bola"):
		controlador.lancar_bola(pending_id, b)
	_assinatura = ""
	desenhar()


func desenhar() -> void:
	var com_flash := flash != "" and Time.get_ticks_msec() < _flash_ate
	visible = not pendentes.is_empty() or com_flash   # C: sem pendente nem mensagem, o painel não aparece
	if not visible:
		return
	var bolas := bolas_com_estoque()
	if not bola_escolhida in bolas:
		bola_escolhida = int(bolas[0]) if not bolas.is_empty() else 0
	var resto := maxi(0, _livre_ms - Time.get_ticks_msec())
	var assin := "%s|%s|%d|%s|%d" % [str(pendentes.map(func(e): return e["id"])), str(bolas.map(func(id): return EstadoJogo.obter_quantidade_bola(id))), bola_escolhida, flash if com_flash else "", int(ceil(resto / 1000.0))]
	if assin == _assinatura:
		return
	_assinatura = assin
	for c in _col.get_children():
		_col.remove_child(c)
		c.queue_free()
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 8)
	_col.add_child(cab)
	var t := _texto(T.t("hud.captureBar.title", {}, "Capturar"), 15, Color("f0e6d2"), CINZEL)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	var cont := PanelContainer.new()
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0, 0, 0, 0.35)
	sc.border_color = Color("6a5223")
	sc.set_border_width_all(1)
	sc.set_corner_radius_all(7)
	sc.content_margin_left = 7; sc.content_margin_right = 7; sc.content_margin_top = 2; sc.content_margin_bottom = 2
	cont.add_theme_stylebox_override("panel", sc)
	cont.name = "Contagem"
	cont.add_child(_texto(T.t("hud.captureBar.wildCount", {"count": pendentes.size()}), 11, Color("e8c98a"), BARLOW_B))
	cab.add_child(cont)
	if com_flash:
		var f := _texto(flash, 12, Color("f5eecf"), BARLOW_B)
		f.name = "Flash"
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_col.add_child(f)
	if bolas.is_empty():
		_col.add_child(_texto(T.t("hud.captureBar.noBalls"), 12.5, Color("c89bff"), BARLOW_B))
	else:
		var fichas := HFlowContainer.new()
		fichas.add_theme_constant_override("h_separation", 5)
		fichas.add_theme_constant_override("v_separation", 5)
		_col.add_child(fichas)
		for id in bolas:
			var b := Button.new()
			b.name = "Bola_%d" % id
			b.toggle_mode = true
			b.button_pressed = id == bola_escolhida
			b.icon = load("res://assets/interface/bolas/%s.png" % ICONES[id])
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 22)
			b.text = "∞" if bool(EstadoJogo.obter_dados_bola(id).get("infinita", false)) else str(EstadoJogo.obter_quantidade_bola(id))
			b.tooltip_text = String(EstadoJogo.obter_dados_bola(id).get("nome", ""))
			b.add_theme_font_override("font", BARLOW_B)
			b.add_theme_font_size_override("font_size", 12)
			var on: bool = id == bola_escolhida
			for estado in ["normal", "hover", "pressed"]:
				var st := StyleBoxFlat.new()
				st.bg_color = Color("c8aa6e2e") if on else Color("ffffff0a")
				st.border_color = Color("c8aa6e") if (on or estado == "hover") else Color("3a4a5c")
				st.set_border_width_all(1)
				st.set_corner_radius_all(999)
				st.content_margin_left = 4; st.content_margin_right = 8; st.content_margin_top = 3; st.content_margin_bottom = 3
				b.add_theme_stylebox_override(estado, st)
			b.add_theme_color_override("font_color", Color("f0e6d2") if on else Color("cfd8e2"))
			var bid: int = id
			b.pressed.connect(func() -> void:
				bola_escolhida = bid
				_assinatura = ""
				desenhar())
			fichas.add_child(b)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 5)
	_col.add_child(lista)
	if pendentes.is_empty():
		lista.add_child(_texto(T.t("hud.captureBar.noneWaiting"), 12, Color("8a93a0")))
	for e in pendentes:
		var linha := PanelContainer.new()
		linha.name = "Pendente_%d" % int(e["id"])
		var sl := StyleBoxFlat.new()
		var sh: bool = bool(e.get("shiny", false))
		sl.bg_color = Color("ffd55e12") if sh else Color("ffffff05")
		sl.border_color = Color("ffd55e80") if sh else Color("ffffff0d")
		sl.set_border_width_all(1)
		sl.set_corner_radius_all(8)
		sl.content_margin_left = 7; sl.content_margin_right = 7; sl.content_margin_top = 5; sl.content_margin_bottom = 5
		linha.add_theme_stylebox_override("panel", sl)
		lista.add_child(linha)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 9)
		linha.add_child(h)
		var ico := TextureRect.new()
		ico.custom_minimum_size = Vector2(32, 32)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var esp: Dictionary = preload("res://ponte_cidade.gd").dados().especie(int(e["pokeId"]))
		var o: Dictionary = _outfits.obter(int(esp.get("looktype", 0)))
		var q: Dictionary = _outfits.quadro(o, 3, 0)
		if not q.is_empty():
			var at := AtlasTexture.new()
			at.atlas = q["tex"]
			at.region = q["rect"]
			ico.texture = at
		h.add_child(ico)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		h.add_child(info)
		var nome := ("✨ " if sh else "") + String(e.get("name", ""))
		if sh and e.has("shinyBase"):
			var cr := float(preload("res://sim/regras.gd").PARAMETROS.captura_eficiencia.get(str(bola_escolhida), 1)) if bola_escolhida > 0 else 1.0
			nome += "  " + T.t("hud.captureBar.tierChance", {"tier": "", "pct": "%.3f" % (100.0 * minf(1.0, float(e["shinyBase"]) * cr))})
		info.add_child(_texto(nome, 13, Color("eaf0f6"), BARLOW_B))
		info.add_child(_texto(T.t("hud.captureBar.level", {"level": int(e.get("level", 1))}), 11, Color("9fd0ff")))
		var lb := Button.new()
		lb.name = "Lancar_%d" % int(e["id"])
		lb.text = T.t("hud.captureBar.cooldownBtn", {"s": int(ceil(resto / 1000.0))}) if resto > 0 else T.t("hud.captureBar.throwBtn")
		lb.disabled = bola_escolhida <= 0 or _lancados.has(int(e["id"])) or resto > 0
		lb.add_theme_font_override("font", BARLOW_B)
		lb.add_theme_font_size_override("font_size", 12)
		var pid := int(e["id"])
		lb.pressed.connect(func() -> void: lancar(pid))
		h.add_child(lb)


func _texto(t: String, tam: float, cor: Color, f: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", int(round(tam)))
	l.add_theme_color_override("font_color", cor)
	if f != null:
		l.add_theme_font_override("font", f)
	return l


func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 12 == 0:
		desenhar()   # contagem do "Aguarde Ns" e o fim da mensagem
	if visible and get_parent() is Control:
		reset_size()
		position = (get_parent() as Control).size - size * scale - Vector2(8, 8)   # C: canto inferior direito
