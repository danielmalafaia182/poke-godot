extends Control
## "Enquanto você estava fora…" (Modo Soneca, fase 4), como a janela do original (C; campos do relatório A, G6): hunt
## da amostra, tempo fora (teto de 24 h), abates da amostra e estimados, XP da amostra (já entregue), itens consumidos,
## desmaio, o Pokémon líder e o botão Coletar (+XP, 50% da taxa pelo tempo fora). O turbo com diamantes não existe
## offline (E). Contas em sim/servico_jogador.gd.

const ESTILO: Script = preload("res://estilo_hud_original.gd")
var janela: PanelContainer
var corpo: VBoxContainer
var relatorio: Dictionary = {}
var resultado: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	janela.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func abrir(rel: Dictionary) -> void:
	relatorio = rel
	show()
	_montar()


func abrir_aviso(aviso: Dictionary) -> void:
	## A (G6b): offline-notice {kind: "cancelled", reason: "reconnect", ms, kills, xp, pokeXp}: voltou antes dos 5 min.
	relatorio = {}
	show()
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	_rotulo("💤 Soneca cancelada")
	_rotulo("Você voltou depois de %s, antes dos 5 minutos da amostra. O que já rodou ficou: %d abates, +%d XP." % [
		_duracao(int(aviso.get("ms", 0)) / 1000), int(aviso.get("kills", 0)), int(aviso.get("xp", 0))], Color("b9c3cf"))
	var b := Button.new()
	b.name = "Ok"
	b.text = "OK"
	b.pressed.connect(hide)
	corpo.add_child(b)
	_ajustar()
	call_deferred("_ajustar")


func _ajustar() -> void:
	janela.size = Vector2(440, 220).max(janela.get_combined_minimum_size())
	janela.position = (size - janela.size) * 0.5


func _rotulo(t: String, cor: Color = Color("f0e6d2")) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	corpo.add_child(l)


static func _duracao(s: int) -> String:
	var h := s / 3600
	var m := (s % 3600) / 60
	return "%dh %dmin" % [h, m] if h > 0 else ("%dmin" % m if m > 0 else "%ds" % maxi(1, s))


func _montar() -> void:
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	var r: Dictionary = relatorio["report"]
	_rotulo("💤 Enquanto você estava fora…")
	var poke: Dictionary = r.get("poke", {}) if r.get("poke") is Dictionary else {}
	var nome := ""
	if poke.has("speciesId"):
		var esp = preload("res://ponte_cidade.gd").especie_por_id(int(poke["speciesId"]))
		nome = "%s Lv.%d" % [esp.nome if esp != null else "#" + str(poke["speciesId"]), int(poke.get("level", 1))]
	_rotulo("Seu líder%s caçou em %s; fora há %s%s." % [(" " + nome) if nome != "" else "", r["sample"]["slug"], _duracao(int(r["seconds"])),
		" (máx. 24h)" if not (r.get("cappedAt") is bool) else ""])
	_rotulo("Amostra de 5 min: %d abates, +%d XP (já recebidos) · ~%d abates estimados no tempo fora" % [int(r["sample"]["kills"]),
		int(r["sample"]["xpSample"]), int(r["estKills"])], Color("b9c3cf"))
	if bool(r["sample"]["fainted"]):
		_rotulo("⚠️ Seu líder desmaiou durante a soneca — a caçada parou ali e o rendimento reflete isso.", Color("ff8c7a"))
	var usados: Dictionary = r["sample"].get("itemsUsed", {})
	if not usados.is_empty():
		var partes: Array = []
		for k in usados:
			partes.append("%s ×%d" % [String(preload("res://ponte_cidade.gd").dados().itens.get(int(k), {}).get("nome", "#" + str(k))), int(usados[k])])
		_rotulo("Itens consumidos na soneca: " + ", ".join(partes), Color("b9c3cf"))
	var b := Button.new()
	b.name = "Coletar"
	b.text = "Coletar +%d XP (50%%)" % int(r["xp50"])
	b.pressed.connect(func() -> void:
		resultado = get_node("/root/EstadoJogo").coletar_offline(int(Time.get_unix_time_from_system()))
		hide())
	corpo.add_child(b)
	_rotulo("O XP vai para o treinador E para o Pokémon líder. A taxa vem da amostra real de 5 minutos.", Color("8a96a3"))
	_ajustar()
	call_deferred("_ajustar")
