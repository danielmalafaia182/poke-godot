extends SceneTree
## Captura das 4 abas da janela Quests, Tasks & Dailys (fase 4, item 3) e da janela da soneca, renderizadas de verdade.
## Rodar: testes/rodar_janela.sh res://testes/captura_diarias.gd   (user:// isolado; PNGs em saida_testes/)

var quadros := 0
var aba := -1


func _initialize() -> void:
	var ej = get_root().get_node("EstadoJogo")
	ej.iniciar_depot()
	ej.definir_perfil_treinador("Teste", 169)
	ej.vip = true
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 20:
		return false
	var painel: Control = current_scene.get_node("Interface/PainelDiarias")
	if aba == -1:
		var ej = get_root().get_node("EstadoJogo")
		for i in 15:
			ej.diaria_abate(19)
		ej.diaria_captura(246)
		aba = 0
		painel.abrir(0)
		quadros = 10
		return false
	if quadros % 10 == 0:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://saida_testes/diarias_aba%d.png" % aba))
		aba += 1
		if aba >= 4:
			quit(0)
			return true
		painel.abrir(aba)
		if aba == 1:
			painel.find_child("Escolher2", true, false).pressed.emit()
	return false
