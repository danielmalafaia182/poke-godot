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
	barra.position = Vector2((size.x - 600.0) * 0.5, 70)
	barra.size = Vector2(600, 28)


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


func _desenhar_boosts() -> void:
	for c in barra.get_children():
		barra.remove_child(c)
		c.queue_free()
	var agora := int(relogio_ms.call()) if relogio_ms.is_valid() else 0
	for b in boosts:
		var ate := int(b.get("until", 0))
		if ate > 0 and agora > 0 and ate <= agora:
			continue
		var l := Label.new()
		var key := String(b.get("key", ""))
		var resto := maxi(0, (ate - agora) / 1000) if ate > 0 and agora > 0 else -1
		var nome := String(b.get("nome", ""))
		if nome == "":
			nome = {"shinylock": "🔒 Shiny lock", "xp": "⭐ XP +%d%%" % int(b.get("pct", 0)), "loot": "🎁 Loot +%d%%" % int(b.get("pct", 0)),
				"pokexp": "⭐ Poké XP +%d%%" % int(b.get("pct", 0)), "capture": "🎯 Captura ×2"}.get(key, key)
		var tempo := ""
		if resto >= 3600:
			tempo = "  %dh%02d" % [resto / 3600, (resto % 3600) / 60]
		elif resto >= 0:
			tempo = "  %d:%02d" % [resto / 60, resto % 60]
		l.text = nome + tempo
		l.tooltip_text = String(b.get("desc", "")) if b.has("desc") else _efeito(key, int(b.get("pct", 0)))
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.add_theme_color_override("font_color", Color("ff9a8a") if key == "shinylock" else Color("9fe0a0"))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		barra.add_child(l)


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
