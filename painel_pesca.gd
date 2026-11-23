extends "res://janela_base.gd"
## Pescador (ciclo 8; sim/servico_pesca.gd). Pelo cliente (C, window.fishing.*): selo da skill, progresso
## "{{inLevel}}/{{forNext}} peixes para o próximo nível", faixas com os peixes, trancadas acima da skill (🔒 Nv N), a da sua
## skill com progresso cheio e as menores com 50%, botão "🎣 Pescar" que vira "⏳ Aguarde Ns" na recarga.

var faixa := -1
var aviso := ""
var _botao: Button


func _ready() -> void:
	tamanho = Vector2(760, 600)
	super._ready()


func _ej() -> Node:
	return get_node("/root/EstadoJogo")


func montar() -> void:
	titulo.text = T.t("window.fishing.title", {}, "🎣 Pescador")
	var r: Dictionary = _ej().pesca_cmd({"type": "pesca-get"})
	if faixa < 0:
		for f in r["tiers"]:
			if bool(f["natural"]):
				faixa = int(f["id"])
	rotulo(T.t("window.fishing.skillBadge", {"skill": int(r["skill"])}), Color("f0c040"), 16)
	rotulo(T.t("window.fishing.progressMax") if bool(r["max"]) else T.t("window.fishing.progressTitle", {"inLevel": str(r["inLevel"]).trim_suffix(".0"), "forNext": int(r["forNext"])}), Color("c8b89a"))
	rotulo(T.t("window.fishing.hint"), Color("8a9bb0"))
	for f in r["tiers"]:
		var b := Button.new()
		b.name = "Faixa_%d" % int(f["id"])
		b.toggle_mode = true
		b.button_pressed = int(f["id"]) == faixa
		b.disabled = bool(f["locked"])
		var lv: Array = f["mobLevel"]
		var nomes := ", ".join((f["fish"] as Array).map(func(x): return String(x["name"])))
		b.text = ("🔒 Nv %d · " % int(f["minSkill"]) if bool(f["locked"]) else "") + T.t("window.fishing.levelRange", {"min": int(lv[0]), "max": int(lv[1])}) + " · " + nomes + ("  (" + T.t("window.fishing.tierTagCurrent") + ")" if bool(f["natural"]) else "")
		b.tooltip_text = T.t("window.fishing.tierLockedTitle", {"minSkill": int(f["minSkill"])}) if bool(f["locked"]) else (T.t("window.fishing.tierNaturalTitle") if bool(f["natural"]) else T.t("window.fishing.tierReducedTitle"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void:
			faixa = int(f["id"])
			atualizar())
		corpo.add_child(b)
	_botao = Button.new()
	_botao.name = "Pescar"
	_botao.custom_minimum_size = Vector2(0, 40)
	corpo.add_child(_botao)
	_botao.pressed.connect(func() -> void:
		var x: Dictionary = _ej().pescar(faixa)
		if x.has("erro"):
			aviso = String(x["erro"])
		else:
			aviso = "🐟 %s Nv %d · +%d XP%s%s" % [String(x["peixe"]["name"]), int(x["nivel"]), int(x["xp"]),
				(" · " + ", ".join((x["loot"] as Array).map(func(l): return "%d× %s" % [int(l["qty"]), String(l["name"])]))) if not (x["loot"] as Array).is_empty() else "",
				("\n" + T.t("hud.world.notice.fishingLevelUp", {"level": int(x["skill"])})) if bool(x["subiu"]) else ""]
		atualizar())
	if aviso != "":
		rotulo(aviso, Color("f0e6d2"))
	_atualizar_botao()


func _atualizar_botao() -> void:
	if _botao == null or not is_instance_valid(_botao):
		return
	var cd := int(_ej().pesca_cmd({"type": "pesca-get"})["cooldownS"])
	_botao.disabled = cd > 0
	_botao.text = T.t("window.fishing.cooldownBtn", {"seconds": cd}) if cd > 0 else T.t("window.fishing.startBtn")


func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 15 == 0:
		_atualizar_botao()
