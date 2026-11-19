extends Control
## Primeira execução do jogo exportado (ciclo 3): existe um save do projeto (pasta de desenvolvimento) e o jogo ainda não
## tem save na pasta dele. Oferece importar uma CÓPIA — o arquivo do projeto fica onde está — ou começar um jogo novo.

signal decidido(importou: bool)
const ESTILO: Script = preload("res://estilo_hud_original.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.75)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var janela := PanelContainer.new()
	janela.add_theme_stylebox_override("panel", ESTILO.moldura())
	add_child(janela)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	janela.add_child(col)
	var t := Label.new()
	t.text = "Progresso encontrado"
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color("f0c040"))
	col.add_child(t)
	var l := Label.new()
	l.text = "Há um progresso salvo da versão de desenvolvimento em\n%s\n\nImportar uma cópia para este jogo? O arquivo original não é movido nem alterado." % EstadoJogo.salvamento.caminho_save_projeto()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	col.add_child(l)
	var erro := Label.new()
	erro.add_theme_color_override("font_color", Color("ff9a8a"))
	col.add_child(erro)
	var h := HBoxContainer.new()
	col.add_child(h)
	var imp := Button.new()
	imp.name = "Importar"
	imp.text = "Importar cópia"
	imp.pressed.connect(func() -> void:
		var r: String = EstadoJogo.salvamento.importar_save_do_projeto()
		if r != "":
			erro.text = r
			return
		decidido.emit(true)
		queue_free())
	h.add_child(imp)
	var novo := Button.new()
	novo.name = "JogoNovo"
	novo.text = "Começar jogo novo"
	novo.pressed.connect(func() -> void:
		decidido.emit(false)
		queue_free())
	h.add_child(novo)
	await get_tree().process_frame
	janela.reset_size()
	janela.position = (size - janela.size) * 0.5
