extends "res://janela_base.gd"
## Personalizar Outfit (C: Perfil "👕 Personalizar Outfit"): o mesmo seletor da criação (seletor_visual.gd). Salvar grava
## em EstadoJogo.visual e troca o sprite da cidade na hora; na hunt, vale na próxima entrada.

signal salvo(visual: Dictionary)
var seletor: VBoxContainer


func _ready() -> void:
	tamanho = Vector2(460, 360)
	super._ready()


func montar() -> void:
	var ej: Node = get_node("/root/EstadoJogo")
	titulo.text = T.t("window.profile.customizeOutfit", {}, "Personalizar Outfit")
	seletor = load("res://seletor_visual.gd").new()
	seletor.name = "Seletor"
	seletor.vip = bool(ej.vip)
	seletor.campeao = bool(ej.ginasios_info(int(Time.get_unix_time_from_system())).get("campeao", false))
	if not (ej.visual as Dictionary).is_empty():
		seletor.visual = (ej.visual as Dictionary).duplicate(true)
	corpo.add_child(seletor)
	botao("Salvar", func() -> void:
		ej.visual = seletor.visual.duplicate(true)
		ej.solicitar_salvamento()
		salvo.emit(ej.visual)
		hide(), "SalvarVisual")
