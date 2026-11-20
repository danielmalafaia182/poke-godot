extends Control
## Avisos da HUD da hunt (ciclo 2; textos do pacote original, C: hud.levelUp, hud.shinyAnnounce, hud.boost,
## hud.slideNotice):
##   - aviso deslizante no topo (um por vez, fila curta; some sozinho em `DURACAO` s ou no ✕): subida de nível do treinador
##     e do Pokémon, shiny que apareceu e shiny capturado;
##   - barra de boosts (embaixo do dock): penalidade de entrada (shinylock) com a contagem, boosts de XP/loot e o Tipo do
##     Dia, com o texto do efeito no tooltip.
## Só desenha: quem chama é hud_caca.gd, com o que a cena da hunt (caca_sim.gd) recebe da simulação.

const T := preload("res://textos.gd")
const ESTILO: Script = preload("res://estilo_hud_original.gd")
const DURACAO := 4.0
const FILA_MAX := 4
var fila: Array = []
var cartao: PanelContainer
var texto: Label
var restante := 0.0
var barra: HBoxContainer
var boosts: Array = []   # [{key, until(ms do relógio da sim), pct, nome?}]
var relogio_ms: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao = PanelContainer.new()
	cartao.name = "AvisoDeslizante"
	cartao.add_theme_stylebox_override("panel", ESTILO.moldura())
	cartao.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cartao)
	var h := HBoxContainer.new()
	cartao.add_child(h)
	texto = Label.new()
	texto.add_theme_font_size_override("font_size", 18)
	texto.add_theme_color_override("font_color", Color("ffe080"))
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texto)
	var x := Button.new()
	x.text = "✕"
	x.flat = true
	x.tooltip_text = T.t("hud.slideNotice.dismissAria", {}, "Fechar")
	x.pressed.connect(func() -> void: restante = 0.0)
	h.add_child(x)
	cartao.hide()
	barra = HBoxContainer.new()
	barra.name = "BarraBoosts"
	barra.add_theme_constant_override("separation", 6)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(barra)
	resized.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	cartao.size = Vector2(minf(620.0, size.x - 40.0), 0)
	cartao.position = Vector2((size.x - cartao.size.x) * 0.5, 120)
	barra.reset_size()
	barra.position = Vector2(round((size.x - barra.size.x) * 0.5), 74)   # C: .bi-wrap top 74 px, centrado


func avisar(t: String) -> void:
	if fila.size() >= FILA_MAX:
		fila.pop_front()
	fila.append(t)


func nivel_treinador(nivel: int) -> void:
	avisar("%s  %s — %s" % [T.t("hud.levelUp.title", {}, "LEVEL UP!"), T.t("hud.levelUp.playerUp"), T.t("hud.levelUp.level", {"level": nivel})])


func nivel_pokemon(nome: String, nivel: int) -> void:
	avisar("%s  %s — %s" % [T.t("hud.levelUp.title", {}, "LEVEL UP!"), T.t("hud.levelUp.pokemonUp", {"name": nome}), T.t("hud.levelUp.level", {"level": nivel})])


func shiny_apareceu(nome: String) -> void:
	avisar("✨ %s %s!" % [T.t("hud.shinyAnnounce.shinyWord", {}, "SHINY"), nome])


func shiny_capturado(treinador: String, nome: String) -> void:
	avisar("%s  %s %s %s %s" % [T.t("hud.shinyAnnounce.title"), treinador, T.t("hud.shinyAnnounce.captured"), T.t("hud.shinyAnnounce.shinyWord"), nome])


func definir_boosts(lista: Array) -> void:
	boosts = lista.duplicate(true)
	_desenhar_boosts()


func _efeito(key: String, pct: int) -> String:
	return T.sem_html(T.t("hud.boost.effect." + key, {"pct": pct}, key))


# C (oh/bi-chip do cliente): ícone, classe (cor da borda) e rótulo de cada boost.
const BOOST_ICONE := {"xp": "exp", "pokexp": "boost", "loot": "loot", "capture": "catch", "shinycharm": "shinysecretlure",
	"borage": "shinysecretlure", "shinylock": "shinysecretlure", "discord": "boost", "stream": "icon_stream_bonus"}
const BOOST_CLASSE := {"xp": Color("ffcf3a"), "pokexp": Color("6fd3ff"), "loot": Color("5bf08a"), "capture": Color("ff9d5c"),
	"shinylock": Color("e05252"), "evento": Color("ffdf6b")}


func _desenhar_boosts() -> void:
	## C: .bi-wrap (centrado, 74 px do topo) com uma .bi-chip por boost/evento: fundo #080c14d9, borda pela classe, raio
	## 10, ícone de 16 px e o tempo restante ("m:ss"; com horas, "Nh MMm"); o shinylock é .debuff (vermelho, ícone cinza).
	for c in barra.get_children():
		barra.remove_child(c)
		c.queue_free()
	var agora := int(relogio_ms.call()) if relogio_ms.is_valid() else 0
	for b in boosts:
		var ate := int(b.get("until", 0))
		if ate > 0 and agora > 0 and ate <= agora:
			continue
		var key := String(b.get("key", ""))
		var evento := bool(b.get("evento", false))
		var resto := maxi(0, (ate - agora) / 1000) if ate > 0 and agora > 0 else -1
		var tempo := ""
		if resto >= 3600:
			tempo = "%dh %02dm" % [resto / 3600, (resto % 3600) / 60]
		elif resto >= 0:
			tempo = "%d:%02d" % [resto / 60, resto % 60]
		var chip := PanelContainer.new()
		chip.name = "Boost_" + key
		var cor: Color = BOOST_CLASSE.get("evento" if evento else key, Color("3a4f72"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("080c14d9")
		sb.border_color = cor
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 5; sb.content_margin_right = 8; sb.content_margin_top = 3; sb.content_margin_bottom = 3
		sb.shadow_color = Color(cor, 0.3)
		sb.shadow_size = 6
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = (String(b.get("nome", "")) + "
" if b.has("nome") else "") + (String(b.get("desc", "")) if b.has("desc") else _efeito(key, int(b.get("pct", 0))))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		chip.add_child(h)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(16, 16)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var caminho := ""
		if evento and String(b.get("tipo", "")) != "":
			caminho = "res://assets/original/types/%s.png" % String(b["tipo"])
		elif BOOST_ICONE.has(key):
			caminho = "res://assets/original/topmenu/%s.png" % String(BOOST_ICONE[key])
		if caminho != "" and ResourceLoader.exists(caminho):
			ic.texture = load(caminho)
		if key == "shinylock":
			ic.modulate = Color(0.75, 0.75, 0.75)   # C: .debuff → ícone cinza
		h.add_child(ic)
		var l := Label.new()
		l.name = "Tempo"
		l.text = tempo if tempo != "" else String(b.get("nome", key))
		l.add_theme_font_override("font", preload("res://assets/interface/fiel/barlow_bold.ttf"))
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("ffb4b4") if key == "shinylock" else Color("cfe0f5"))
		h.add_child(l)
		barra.add_child(chip)
	barra.reset_size()
	barra.position = Vector2(round((size.x - barra.size.x) * 0.5), 74)


func _process(d: float) -> void:
	if restante > 0.0:
		restante -= d
		if restante <= 0.0:
			cartao.hide()
	elif not fila.is_empty():
		texto.text = String(fila.pop_front())
		restante = DURACAO
		cartao.show()
	if Engine.get_process_frames() % 30 == 0 and not boosts.is_empty():
		_desenhar_boosts()
