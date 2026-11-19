extends "res://janela_base.gd"
## Log de Capturas (C: window.captureLog, "últimas 100"; textos do pacote original). Desenha EstadoJogo.log_capturas
## (gravado a cada captura: espécie, shiny, nível, IV total, bola, hora, 1ª captura da espécie/variante).

var confirmar := false


func _ready() -> void:
	tamanho = Vector2(560, 560)
	aba = "todos"
	super._ready()


func montar() -> void:
	var ej: Node = get_node("/root/EstadoJogo")
	titulo.text = T.t("window.captureLog.title", {}, "Log de Capturas") + " " + T.t("window.captureLog.subtitle")
	botao_aba("todos", T.t("window.captureLog.tabAll"))
	botao_aba("normal", T.t("window.captureLog.tabNormal"))
	botao_aba("shiny", T.t("window.captureLog.tabShiny"))
	var log: Array = ej.log_capturas
	var n_sh := 0
	for e in log:
		n_sh += 1 if bool(e.get("shiny", false)) else 0
	rotulo("%s %d   %s %d   %s %d" % [T.t("window.captureLog.total"), log.size(), T.t("window.captureLog.normal"), log.size() - n_sh,
		T.t("window.captureLog.shiny"), n_sh], Color("c8b89a"))
	var algum := false
	for e in log:
		var sh := bool(e.get("shiny", false))
		if (aba == "normal" and sh) or (aba == "shiny" and not sh):
			continue
		algum = true
		var h := HBoxContainer.new()
		corpo.add_child(h)
		var nome := rotulo(("✨ " if sh else "") + String(e.get("especie", "")), Color("ffe080") if sh else Color.WHITE, 0, h)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(e.get("primeira", false)):
			var b := rotulo(T.t("window.captureLog.firstCatchBadge"), Color("9fe0a0"), 0, h)
			b.tooltip_text = T.t("window.captureLog.firstCatchTitle")
			b.mouse_filter = Control.MOUSE_FILTER_STOP
		rotulo(T.t("window.captureLog.level", {"level": int(e.get("nivel", 1))}), Color("c8b89a"), 0, h)
		rotulo(T.t("window.captureLog.iv", {"iv": int(e.get("iv", 0))}), Color("c8b89a"), 0, h)
		rotulo(String(e.get("bola", "")), Color("c8b89a"), 0, h)
		var t := int(e.get("t", 0))
		rotulo(Time.get_datetime_string_from_unix_time(t + _fuso(), true).substr(5, 11).replace("T", " ") if t > 0 else "", Color("8a7f6a"), 0, h)
	if not algum:
		rotulo(T.t("window.captureLog.emptyShiny") if aba == "shiny" else (T.t("window.captureLog.emptyNormal") if aba == "normal" else T.t("window.captureLog.emptyAll")), Color("c8b89a"))
	rotulo(T.t("window.captureLog.note"), Color("8a7f6a"))
	botao(T.t("window.captureLog.clearConfirm") if confirmar else T.t("window.captureLog.clearBtn"), func() -> void:
		if confirmar:
			ej.log_capturas.clear()
			ej.solicitar_salvamento()
		confirmar = not confirmar
		atualizar(), "Limpar")


static func _fuso() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
