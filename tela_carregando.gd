extends RefCounted
## Tela de carregamento entre a cidade e a hunt (ciclo 4, item 4). A: no vídeo do original (quadro v1_00104) a cena
## escurece e "LOADING WORLD..." aparece no meio, em letras espaçadas; C: texto play.loadingWorld do pacote.
## Fica numa CanvasLayer na raiz (atravessa a troca de cena); a hunt a tira no 1º quadro desenhado.

const NOME := "TelaCarregando"


static func mostrar(arvore: SceneTree) -> void:
	if arvore == null or arvore.root.get_node_or_null(NOME) != null:
		return
	var camada := CanvasLayer.new()
	camada.name = NOME
	camada.layer = 120
	var veu := ColorRect.new()
	veu.color = Color(0.0, 0.02, 0.05, 0.55)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	camada.add_child(veu)
	var l := Label.new()
	l.name = "Texto"
	l.text = preload("res://textos.gd").t("play.loadingWorld", {}, "Carregando mundo…").to_upper()
	var fv := FontVariation.new()
	fv.base_font = preload("res://assets/interface/fiel/cinzel_bold.ttf")
	fv.spacing_glyph = 2
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color("e8d7bd"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada.add_child(l)
	arvore.root.add_child(camada)


static func esconder(arvore: SceneTree) -> void:
	var n := arvore.root.get_node_or_null(NOME)
	if n != null:
		n.queue_free()


static func ir_para(arvore: SceneTree, cena: String) -> void:
	## Mostra a tela, deixa desenhar um quadro com ela e só então troca de cena.
	if arvore == null:
		return
	mostrar(arvore)
	await arvore.process_frame
	await arvore.process_frame
	arvore.change_scene_to_file(cena)
