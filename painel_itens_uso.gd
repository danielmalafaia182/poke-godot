extends Control
## Itens de uso (fase 4, lote 3): Rare Candy e berries da BAG num Pokémon do time, como no original (C: escolher o
## Pokémon; candy +1 nível, até 10 por Pokémon, nível ≤ 100; berry consumida na hora, 30 min, a mesma não acumula).
## Só desenha e manda comandos: regras em sim/servico_itens.gd (EstadoJogo.usar_item).

const ESTILO: Script = preload("res://estilo_hud_original.gd")
const LOOT: Script = preload("res://regras_loot.gd")
var janela: PanelContainer
var corpo: VBoxContainer
var item_escolhido := -1
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
	corpo.add_theme_constant_override("separation", 6)
	janela.add_child(corpo)
	resized.connect(_ajustar)
	hide()


func abrir() -> void:
	item_escolhido = -1
	aviso = ""
	show()
	atualizar()


func _ajustar() -> void:
	janela.size = Vector2(minf(620, size.x - 32), 0).max(janela.get_combined_minimum_size())
	janela.position = (size - janela.size) * 0.5


func _rotulo(t: String, cor: Color = Color("f0e6d2")) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", cor)
	corpo.add_child(l)


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func _usaveis() -> Array:
	## [{id, nome, qtd, texto}] — Rare Candy e berries que estão na BAG.
	var ej := _ej()
	var sv = ej.servico_itens()
	var r: Array = []
	for interno in ej.inventario.estoque_materiais:
		var q := int(ej.inventario.estoque_materiais[interno])
		if q <= 0:
			continue
		var id: int = LOOT.id_original(int(interno))
		var nome := String(preload("res://ponte_cidade.gd").dados().itens.get(id, {}).get("nome", ""))
		if id == int(sv.p.candy_id):
			r.append({"id": id, "nome": nome, "qtd": q, "texto": "+1 nível (até o nível 100, no máximo 10 por Pokémon)"})
			continue
		var ef: Dictionary = sv.efeito_berry(id)
		if not ef.is_empty():
			var t := "+%d%% de cura das poções" % int(ef["pct"]) if ef["efeito"] == "heal" else "−%d%% de dano de golpes %s" % [int(ef["pct"]), String(ef["efeito"])]
			r.append({"id": id, "nome": nome, "qtd": q, "texto": t + " por 30 min"})
	return r


func atualizar() -> void:
	for c in corpo.get_children():
		corpo.remove_child(c)
		c.queue_free()
	var cab := HBoxContainer.new()
	corpo.add_child(cab)
	var t := Label.new()
	t.text = "Usar itens"
	t.add_theme_font_size_override("font_size", 18)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	var x := Button.new()
	x.text = "×"
	x.pressed.connect(hide)
	cab.add_child(x)
	var lista := _usaveis()
	if lista.is_empty():
		_rotulo("Nenhum Rare Candy ou berry na mochila.", Color("b9c3cf"))
	for it in lista:
		var b := Button.new()
		b.name = "Item_%d" % int(it["id"])
		b.toggle_mode = true
		b.button_pressed = int(it["id"]) == item_escolhido
		b.text = "%s ×%d — %s" % [String(it["nome"]), int(it["qtd"]), String(it["texto"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			item_escolhido = int(it["id"])
			aviso = ""
			atualizar())
		corpo.add_child(b)
	if item_escolhido >= 0:
		_rotulo("Escolha o Pokémon do time:", Color("b9c3cf"))
		var ej := _ej()
		var at: Dictionary = ej.berries_ativas(int(Time.get_unix_time_from_system()))
		for pk in ej.time_pokemon:
			var h := Button.new()
			h.name = "Poke_" + pk.id_persistente
			var extra := ""
			if at.has(pk.id_persistente):
				extra = " · %d berry(s) ativa(s)" % (at[pk.id_persistente] as Array).size()
			h.text = "%s Lv.%d · candies %d/10%s" % [pk.especie.nome, pk.nivel, int(ej.itens_uso.get("candy", {}).get(pk.id_persistente, 0)), extra]
			h.pressed.connect(func() -> void:
				var cmd := {"type": "use-candy", "pokeId": pk.id_persistente} if item_escolhido == int(ej.servico_itens().p.candy_id) else {"type": "use-berry", "itemId": item_escolhido, "pokeId": pk.id_persistente}
				var r: Dictionary = ej.usar_item(cmd)
				if r.has("erro"):
					aviso = String(r["erro"])
				elif String(r.get("type", "")) == "candy-used":
					aviso = "🍬 %s chegou ao nível %d!" % [pk.especie.nome, int(r["level"])]
				else:
					aviso = "🫐 %s comeu a berry!" % pk.especie.nome
				atualizar())
			corpo.add_child(h)
	if not aviso.is_empty():
		_rotulo(aviso, Color("f0c040"))
	_ajustar()
	call_deferred("_ajustar")
