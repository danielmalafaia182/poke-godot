extends PanelContainer

# Evolução: painel local de consulta; não equipa golpes nem altera cooldowns.
var controlador: Node2D
var lista: VBoxContainer
var linhas: Dictionary = {}
var tempo: float = 0.0
var titulo: Label
const ESTILO: Script = preload("res://estilo_hud_original.gd")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel",ESTILO.moldura())
	var coluna: VBoxContainer = VBoxContainer.new()
	add_child(coluna)
	titulo = Label.new()
	titulo.text = "GOLPES · dano provisório"
	titulo.add_theme_font_override("font",preload("res://assets/interface/depot/barlow_semibold.ttf"))
	titulo.add_theme_font_size_override("font_size",12)
	titulo.add_theme_color_override("font_color",Color("e0c084"))
	coluna.add_child(titulo)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(scroll)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

func _process(delta: float) -> void:
	visible = controlador.usar_golpes_catalogados and controlador.populacao_iniciada
	if not visible:
		return
	tempo -= delta
	if tempo > 0:
		return
	tempo = 0.1
	# Alteração: apresenta os dois intervalos independentes.
	titulo.text = "GOLPES · cooldowns do catálogo" if controlador.aplicar_cooldowns_catalogo else "GOLPES · aliado %.2fs / selvagem %.2fs" % [controlador.intervalo_ataques_caca,controlador.intervalo_ataques_selvagem]
	var resumo: Array[Dictionary] = controlador.agenda_aliado.resumo(controlador.aplicar_cooldowns_catalogo)
	for golpe in resumo:
		var chave: String = golpe["nome"]
		if not linhas.has(chave):
			var linha: Label = Label.new()
			linha.add_theme_font_override("font",preload("res://assets/interface/depot/barlow_semibold.ttf"))
			linha.add_theme_font_size_override("font_size",12)
			lista.add_child(linha)
			linhas[chave] = linha
		var restante: float = float(golpe["restante"])
		linhas[chave].text = "%s · %s — %s" % [chave,golpe["tipo"],"Pronto" if restante<=0.000001 else "%.1fs" % restante]
		linhas[chave].modulate = Color("98e4ad") if restante<=0.000001 else Color("d7e2ee")
