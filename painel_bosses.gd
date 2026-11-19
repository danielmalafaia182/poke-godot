extends "res://janela_base.gd"
## Bosses (C: window.bosses — abas Bosses e Altar, Auto Boss e histórico; textos do pacote original). Só desenha e manda
## os comandos: a luta, os drops e o Auto Boss são calculados na sim (sim/servico_bosses.gd, via EstadoJogo.boss_comando).
## Auto Boss só fora de hunt (C): na hunt o botão fica desligado.

const PONTE := preload("res://ponte_cidade.gd")
var na_hunt := false
var resultado: Dictionary = {}
var categoria := ""
var lutas_auto := 5


func _ready() -> void:
	tamanho = Vector2(760, 640)
	aba = "bosses"
	super._ready()


func _agora() -> int:
	return int(Time.get_unix_time_from_system())


func comando(cmd: Dictionary) -> Dictionary:
	cmd["agora"] = _agora()
	resultado = get_node("/root/EstadoJogo").boss_comando(cmd)
	atualizar()
	return resultado


func montar() -> void:
	titulo.text = T.t("window.bosses.title", {}, "Bosses")
	botao_aba("bosses", T.t("window.bosses.tabBosses", {}, "Bosses"))
	botao_aba("altar", T.t("window.bosses.tabAltar", {}, "Altar"))
	botao_aba("hist", T.t("window.bosses.auto.histTitle", {}, "Histórico"))
	var info: Dictionary = get_node("/root/EstadoJogo").bosses_info(_agora())
	if not resultado.is_empty():
		_montar_resultado()
	var itens: Dictionary = info["itens"]
	var linha_itens: Array = []
	for k in itens:
		if int(itens[k]) > 0:
			linha_itens.append("%d× %s" % [int(itens[k]), String(k)])
	rotulo(("Tokens e drops: " + ", ".join(PackedStringArray(linha_itens))) if not linha_itens.is_empty() else "Sem tokens ainda — os bosses Especiais têm entrada grátis e dropam Boss Token.", Color("c8b89a"))
	if aba == "altar":
		_montar_altar(info)
	elif aba == "hist":
		_montar_hist(info)
	else:
		_montar_lista(info)


func _montar_resultado() -> void:
	if resultado.has("erro"):
		rotulo(String(resultado["erro"]), Color("ff9a8a"))
		return
	var tipo := String(resultado.get("type", ""))
	if tipo == "auto-boss-result":
		var fim := String(resultado["fim"])
		var msg = {"concluido": T.t("window.bosses.auto.sumDone"), "derrota": T.t("window.bosses.auto.sumLost"), "sem_token": T.t("window.bosses.auto.sumNoToken")}.get(fim, T.t("window.bosses.auto.sumError"))
		rotulo("%s — %s: %d · %s: %d" % [T.t("window.bosses.auto.title"), String(msg), (resultado["lutas"] as Array).size(), T.t("window.bosses.auto.wins"), int(resultado["vitorias"])], Color("f0c040"), 16)
		var tot := {}
		for l in resultado["lutas"]:
			for d in l["drops"]:
				tot[String(d["nome"])] = int(tot.get(String(d["nome"]), 0)) + int(d["qtd"])
		rotulo(T.t("window.bosses.auto.sumLoot") + ": " + (", ".join(PackedStringArray(tot.keys().map(func(k): return "%d× %s" % [tot[k], k]))) if not tot.is_empty() else T.t("window.bosses.auto.sumNoLoot")), Color("9fe0a0"))
		return
	var ok := bool(resultado.get("venceu", false))
	if tipo == "altar-result":
		rotulo(("Vitória contra ✨ %s! " % String(resultado["especie"])) + (T.t("window.bosses.caughtShiny") + " " + T.t("window.bosses.sentToStorage", {"name": String(resultado["especie"])}) if bool(resultado["capturado"]) else (T.t("window.bosses.shinyEscaped") if ok else T.t("window.bosses.shinyResisted"))),
			Color("ffe080") if bool(resultado["capturado"]) else Color("ff9a8a"), 16)
		return
	var drops: Array = resultado.get("drops", [])
	rotulo(("Vitória em %.0f s! " % (int(resultado["duracaoMs"]) / 1000.0)) + ((T.t("window.bosses.rewards") + " " + ", ".join(PackedStringArray(drops.map(func(d): return "%d× %s" % [int(d["qtd"]), String(d["nome"])])))) if not drops.is_empty() else "") if ok
		else T.t("window.bosses.lostToken", {"qty": 1, "token": "token"}), Color("9fe0a0") if ok else Color("ff9a8a"), 16)


func _montar_lista(info: Dictionary) -> void:
	var cats := {}
	for b in info["bosses"]:
		cats[String(b["categoria"])] = true
	var barra := HBoxContainer.new()
	corpo.add_child(barra)
	for c in [""] + cats.keys():
		var bt := Button.new()
		bt.text = "Todos" if c == "" else String(c)
		bt.toggle_mode = true
		bt.button_pressed = categoria == c
		var cc := String(c)
		bt.pressed.connect(func() -> void:
			categoria = cc
			atualizar())
		barra.add_child(bt)
	for b in info["bosses"]:
		if categoria != "" and String(b["categoria"]) != categoria:
			continue
		var h := HBoxContainer.new()
		h.name = "B_" + String(b["key"])
		corpo.add_child(h)
		var ent = b["entrada"]
		var txt_ent := T.t("window.bosses.auto.free", {}, "Entrada grátis") if not ent is Array else "%d× %s (%s)" % [int(ent[1]), String(ent[0]), T.t("window.bosses.auto.youHave", {"count": int(b["tem"])})]
		var l := rotulo("%s · %s · %s\n%s" % [String(b["nome"]), String(b["categoria"]), T.t("window.bosses.lvShort", {"level": int(b["nivel"])}), txt_ent],
			Color.WHITE if bool(b["liberado"]) else Color("8a7f6a"), 0, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key := String(b["key"])
		var d := Button.new()
		d.name = "Desafiar_" + key
		if not bool(b["liberado"]):
			d.text = T.t("window.bosses.requiresLevel", {"level": int(b["nivel"])})
			d.disabled = true
		elif int(b["recargaS"]) > 0:
			d.text = "⏳ %d s" % int(b["recargaS"])
			d.disabled = true
		else:
			d.text = T.t("window.bosses.challengeBoss", {}, "Desafiar Boss")
			d.pressed.connect(func() -> void: comando({"type": "boss-desafiar", "key": key}))
		h.add_child(d)
		var au := Button.new()
		au.name = "Auto_" + key
		au.text = T.t("window.bosses.auto.button", {}, "Auto Boss") + " ×%d" % lutas_auto
		au.tooltip_text = T.t("window.bosses.auto.ruleCity") + "\n" + T.t("window.bosses.auto.ruleLoss")
		au.disabled = na_hunt or not bool(b["liberado"])
		au.pressed.connect(func() -> void: comando({"type": "auto-boss", "key": key, "lutas": lutas_auto}))
		h.add_child(au)


func _montar_altar(info: Dictionary) -> void:
	rotulo("%s Shiny Card %s" % [T.t("window.bosses.altarIntroPre"), T.t("window.bosses.altarIntroPost")], Color("c8b89a"))
	if (info["cards"] as Array).is_empty():
		rotulo(T.t("window.bosses.noCards"), Color("8a7f6a"))
		return
	for c in info["cards"]:
		var h := HBoxContainer.new()
		corpo.add_child(h)
		var l := rotulo("%d× %s" % [int(c["qtd"]), String(c["nome"])], Color("ffe080"), 0, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var iid := int(c["itemId"])
		botao(T.t("window.bosses.sacrifice", {}, "Sacrificar"), func() -> void: comando({"type": "altar-desafiar", "itemId": iid}), "Altar_%d" % iid, h)


func _montar_hist(info: Dictionary) -> void:
	var hist: Array = info["historico"]
	if hist.is_empty():
		rotulo(T.t("window.bosses.auto.histEmpty"), Color("8a7f6a"))
		rotulo(T.t("window.bosses.auto.histEmptyHint"), Color("8a7f6a"))
		return
	for x in hist:
		var drops: Array = x.get("drops", [])
		rotulo("%s · %s · %s · %.0f s · %s" % [String(x["nome"]), T.t("window.bosses.auto.histWon") if bool(x["venceu"]) else T.t("window.bosses.auto.histLost"),
			T.t("window.bosses.auto.histAuto") if String(x["modo"]) == "auto" else T.t("window.bosses.auto.histManual"), int(x["ms"]) / 1000.0,
			", ".join(PackedStringArray(drops.map(func(d): return "%d× %s" % [int(d["qtd"]), String(d["nome"])]))) if not drops.is_empty() else T.t("window.bosses.auto.histNoDrops")],
			Color("9fe0a0") if bool(x["venceu"]) else Color("ff9a8a"))
