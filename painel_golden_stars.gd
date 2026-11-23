extends "res://janela_base.gd"
## Poke Slot Machine / Golden Stars (ciclo 8; sim/servico_golden_stars.gd). Pelo cliente (C, window.goldenStars.*): 3
## slots (estrela ativa com o bônus e o tempo; travados com desbloqueio permanente ou de 24 h), Roll (grátis a cada 12 h),
## candidatos com Escolha direta (paga) ou Escolheu (sorteio), Trocar bônus.

var slot := 0
var aviso := ""


func _ready() -> void:
	tamanho = Vector2(820, 620)
	super._ready()


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func _cmd(c: Dictionary) -> void:
	c["agora"] = int(Time.get_unix_time_from_system())
	c["semente"] = int(Time.get_ticks_usec() % 2147483647)
	var r: Dictionary = _ej().estrela(c)
	aviso = String(r.get("erro", ""))
	atualizar()


func montar() -> void:
	titulo.text = T.t("hud.world.menu.goldenStars", {}, "Poke Slot Machine")
	var agora := int(Time.get_unix_time_from_system())
	var r: Dictionary = _ej().estrela({"type": "gs-get", "agora": agora})
	var d = preload("res://ponte_cidade.gd").dados()
	for i in 3:
		var linha := HBoxContainer.new()
		corpo.add_child(linha)
		var st: Dictionary = r["slots"][i]
		var lib := bool(r["liberados"][i])
		var ativo := not st.is_empty() and int(st["expiresAt"]) > agora
		var sel := CheckBox.new()
		sel.name = "Slot_%d" % i
		sel.disabled = not lib
		sel.button_pressed = slot == i
		sel.toggled.connect(func(v: bool) -> void:
			if v:
				slot = i
				atualizar())
		linha.add_child(sel)
		var t := Label.new()
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not lib:
			t.text = "Slot %d: travado" % (i + 1)
		elif ativo:
			var nome := String(d.especie(int(st["speciesId"])).get("nome", "?"))
			t.text = "Slot %d · %s %s — %s · %d min" % [i + 1, T.t("window.goldenStars.active"), nome, T.t("window.goldenStars.bonusDesc." + String(st["bonusType"]), {"pct": int(st["pct"]), "name": nome}), (int(st["expiresAt"]) - agora) / 60]
		else:
			t.text = "Slot %d: livre" % (i + 1)
		linha.add_child(t)
		if not lib:
			for m in [["perm", T.t("window.goldenStars.action.unlock-perm")], ["temp", T.t("window.goldenStars.action.unlock-temp")]]:
				var b := Button.new()
				b.name = "Unlock_%d_%s" % [i, m[0]]
				b.text = String(m[1])
				b.pressed.connect(func() -> void: _cmd({"type": "gs-unlock", "slot": i, "modo": String(m[0])}))
				linha.add_child(b)
		elif ativo:
			var rb := Button.new()
			rb.name = "Reroll_%d" % i
			rb.text = T.t("window.goldenStars.action.reroll-bonus")
			rb.pressed.connect(func() -> void: _cmd({"type": "gs-reroll-bonus", "slot": i}))
			linha.add_child(rb)
	var cand: Array = r["candidatos"]
	var livre := agora >= int(r["freeRollAt"])
	var roll := Button.new()
	roll.name = "Roll"
	roll.text = "🎰 %s%s" % [T.t("window.goldenStars.action.roll"), "" if livre else " (%d min para o grátis)" % ((int(r["freeRollAt"]) - agora) / 60)]
	roll.pressed.connect(func() -> void: _cmd({"type": "gs-roll"}))
	corpo.add_child(roll)
	if not cand.is_empty():
		rotulo("Candidatos — clique para a escolha direta (paga) ou sorteie:", Color("9fc0e8"))
		var g := HFlowContainer.new()
		corpo.add_child(g)
		for idx in cand.size():
			var b := Button.new()
			b.name = "Cand_%d" % idx
			b.text = String(d.especie(int(cand[idx])).get("nome", "?"))
			b.tooltip_text = T.t("window.goldenStars.action.pick-species")
			b.pressed.connect(func() -> void: _cmd({"type": "gs-pick", "slot": slot, "idx": idx}))
			g.add_child(b)
		var sb := Button.new()
		sb.name = "Sortear"
		sb.text = "⭐ " + T.t("window.goldenStars.action.pick")
		sb.pressed.connect(func() -> void: _cmd({"type": "gs-pick", "slot": slot, "idx": -1}))
		corpo.add_child(sb)
	if aviso != "":
		rotulo(aviso, Color("f0c040"))
