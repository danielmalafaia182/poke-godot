extends Control
## Quests, Tasks & Dailys (fase 4, item 3): Daily Gift, Daily Kill, Daily Catch e as tarefas de NPC por cidade, como
## as janelas do original (C; formatos A, G5/G7). Só desenha e manda comandos: regras em sim/servico_diarias.gd
## (EstadoJogo.diarias_tratar).

const ESTILO: Script = preload("res://estilo_hud_original.gd")
const ABAS := ["Daily Gift", "Daily Kill", "Daily Catch", "Quests & Tasks"]
var janela: PanelContainer
var corpo: VBoxContainer
var conteudo: VBoxContainer
var aba := 0
var cidade_tarefas := ""
var aviso := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.6)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sombra)
	sombra.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			hide())
	janela = PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	corpo = VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 8)
	janela.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func abrir(qual: int = 0) -> void:
	aba = qual
	aviso = ""
	show()
	atualizar()


func _ajustar() -> void:
	janela.size = Vector2(minf(760, size.x - 32), minf(620, size.y - 32))
	janela.position = (size - janela.size) * 0.5


func _rotulo(pai: Control, t: String, cor: Color = Color("f0e6d2")) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	pai.add_child(l)
	return l


func _agora() -> int:
	return int(Time.get_unix_time_from_system())


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func _enviar(cmd: Dictionary) -> void:
	cmd["agora"] = _agora()
	var r: Dictionary = _ej().diarias_tratar(cmd)
	aviso = String(r.get("erro", r.get("aviso", "")))
	atualizar()


static func _tempo(ms: int) -> String:
	var s := maxi(0, ms / 1000)
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]


func atualizar() -> void:
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	var cab := HBoxContainer.new()
	corpo.add_child(cab)
	var t := Label.new()
	t.text = "Quests, Tasks & Dailys"
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	var x := Button.new()
	x.text = "×"
	x.pressed.connect(hide)
	cab.add_child(x)
	var abas := HBoxContainer.new()
	corpo.add_child(abas)
	for i in ABAS.size():
		var b := Button.new()
		b.name = "Aba%d" % i
		b.text = ABAS[i]
		b.toggle_mode = true
		b.button_pressed = i == aba
		b.pressed.connect(func() -> void:
			aba = i
			aviso = ""
			atualizar())
		abas.add_child(b)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	corpo.add_child(rolagem)
	conteudo = VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(conteudo)
	match aba:
		0: _aba_gift()
		1: _aba_kill()
		2: _aba_catch()
		3: _aba_tarefas()
	if not aviso.is_empty():
		_rotulo(corpo, aviso, Color("f0c040"))
	_ajustar()
	call_deferred("_ajustar")


func _aba_gift() -> void:
	var g: Dictionary = _ej().diarias_tratar({"type": "daily-get", "agora": _agora()})["msg"]
	_rotulo(conteudo, "Volte todo dia e colete os 28 prêmios do mês. Dia %d/%d" % [mini(int(g["nextDay"]), int(g["total"])), int(g["total"])], Color("b9c3cf"))
	var grade := GridContainer.new()
	grade.columns = 7
	conteudo.add_child(grade)
	for r in g["rewards"]:
		var l := Label.new()
		l.custom_minimum_size = Vector2(98, 46)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = "%d%s\n%s ×%d%s" % [int(r["day"]), " VIP" if r.get("tag") != null else "", String(r["label"]), int(r["qty"]), " ✓" if bool(r["claimed"]) else ""]
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("f0c040") if bool(r["current"]) else (Color("6f7a86") if bool(r["claimed"]) or bool(r["locked"]) else Color("f0e6d2")))
		grade.add_child(l)
	var b := Button.new()
	b.name = "ColetarGift"
	b.text = "🎁 Coletar" if bool(g["canClaim"]) else ("Já coletado hoje" if bool(g["claimedToday"]) else ("Exclusivo VIP (ative o VIP em ⚙)" if bool(g["blockedByVip"]) else "Calendário completo"))
	b.disabled = not bool(g["canClaim"])
	b.pressed.connect(func() -> void: _enviar({"type": "daily-claim"}))
	conteudo.add_child(b)


func _aba_kill() -> void:
	var k: Dictionary = _ej().diarias_tratar({"type": "daily-kill-get", "agora": _agora()})["msg"]
	if bool(k["locked"]):
		_rotulo(conteudo, "Daily Kill libera no nível %d do treinador." % int(k["minLevel"]), Color("ff8c7a"))
		return
	_rotulo(conteudo, "Faixa %s · reseta em %s · prêmio: %s" % [String(k["tierLabel"]), _tempo(int(k["resetAt"]) - _agora() * 1000), ", ".join(k["rewardText"])], Color("b9c3cf"))
	for i in (k["options"] as Array).size():
		var o: Dictionary = k["options"][i]
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s — %d/%d abates · +%d XP" % [String(o["name"]), int(o["have"]), int(o["qty"]), int(o["xp"])]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", Color("f0c040") if i == int(k["pickedIdx"]) else Color("f0e6d2"))
		h.add_child(l)
		if int(k["pickedIdx"]) < 0:
			var b := Button.new()
			b.name = "Escolher%d" % i
			b.text = "Escolher"
			b.pressed.connect(func() -> void: _enviar({"type": "daily-kill-pick", "idx": i}))
			h.add_child(b)
		conteudo.add_child(h)
	if int(k["pickedIdx"]) >= 0:
		var b := Button.new()
		b.name = "ColetarKill"
		b.text = "Prêmio coletado" if bool(k["claimed"]) else "🎁 Coletar +%d XP" % int(k["reward"]["xp"])
		b.disabled = bool(k["claimed"]) or not bool(k["options"][int(k["pickedIdx"])]["done"])
		b.pressed.connect(func() -> void: _enviar({"type": "daily-kill-claim"}))
		conteudo.add_child(b)


func _aba_catch() -> void:
	var c: Dictionary = _ej().diarias_tratar({"type": "daily-catch-get", "agora": _agora()})["msg"]
	var soma := 0
	for cl in c["claims"]:
		soma += int(cl["xp"])
	_rotulo(conteudo, "Capturas premiadas %d/%d · XP ganho hoje %d · faixas liberadas %d · reseta em %s" % [int(c["used"]), int(c["total"]), soma,
		(c["tiers"] as Array).size(), _tempo(int(c["resetAt"]) - _agora() * 1000)], Color("b9c3cf"))
	for s in int(c["total"]):
		var cl: Dictionary = {}
		for x in c["claims"]:
			if int(x["slot"]) == s + 1:
				cl = x
		_rotulo(conteudo, "Slot %d: %s" % [s + 1, ("%s (%s) +%d XP" % [String(cl["name"]), String(cl["tierLabel"]), int(cl["xp"])]) if not cl.is_empty() else "livre — capture um Pokémon da tabela"])
	if (c["tiers"] as Array).is_empty():
		_rotulo(conteudo, "Nenhuma faixa liberada no seu nível ainda.", Color("ff8c7a"))
	for t in c["tiers"]:
		var nomes: Array = []
		for e in t["species"]:
			nomes.append(String(e["name"]))
		_rotulo(conteudo, "%s (Nv. %d+): %s" % [String(t["label"]), int(t["minLevel"]), ", ".join(nomes)], Color("8a96a3"))


func _aba_tarefas() -> void:
	var tk: Dictionary = _ej().diarias_tratar({"type": "tasks-get"})["msg"]
	if cidade_tarefas.is_empty():
		cidade_tarefas = String(tk["cities"][0])
	var sel := OptionButton.new()
	sel.name = "Cidade"
	for i in (tk["cities"] as Array).size():
		sel.add_item(String(tk["cities"][i]))
		if String(tk["cities"][i]) == cidade_tarefas:
			sel.select(i)
	sel.item_selected.connect(func(i: int) -> void:
		cidade_tarefas = String(tk["cities"][i])
		atualizar())
	conteudo.add_child(sel)
	for t in tk["tasks"]:
		if String(t["city"]) != cidade_tarefas:
			continue
		var partes: Array = []
		for g in t["goalProgress"]:
			partes.append("%s %s %d/%d" % [{"kill": "derrotar", "capture": "capturar", "deliver": "entregar"}.get(String(g["kind"]), ""), String(g["name"]), int(g["have"]), int(g["qty"])])
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s: %s · +%d XP%s" % [String(t["npc"]), "; ".join(partes), int(t["xp"]), (" · +💲%d" % int(t["cash"])) if int(t["cash"]) > 0 else ""]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", Color("6f7a86") if bool(t["claimed"]) else Color("f0e6d2"))
		h.add_child(l)
		if not bool(t["claimed"]):
			var b := Button.new()
			b.name = "Entregar_" + String(t["id"])
			b.text = "Entregar"
			b.disabled = not bool(t["complete"])
			b.pressed.connect(func() -> void: _enviar({"type": "tasks-claim", "taskId": String(t["id"])}))
			h.add_child(b)
		conteudo.add_child(h)
