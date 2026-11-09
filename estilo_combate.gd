extends RefCounted
# Mesma apresentação para aliado e selvagens; HP continua pertencendo ao encontro.
# Acima dos impactos (100) e abaixo do HUD em CanvasLayer.
const CAMADA_INDICADORES: int=120
const FONTE: Script=preload("res://fonte_mundo.gd")
const UI: Script=preload("res://estilo_ui_fiel.gd")
static func nome(texto: String) -> TextureRect:
	var label: TextureRect=TextureRect.new()
	label.texture=FONTE.texto(texto,Color("00ff00"))
	label.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	label.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	label.size=label.texture.get_size()
	label.position=Vector2(-floorf(label.size.x*0.5),-53)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label
static func barra() -> ProgressBar:
	var controle: ProgressBar=preload("res://barra_vida_mundo.gd").new()
	controle.position=Vector2(-16,-35)
	controle.size=Vector2(32,4)
	return controle
static func atualizar(controle: ProgressBar, atual: int, maximo: int) -> void:
	# Evita reconfigurar o Range a cada frame. HP não vira animação indeterminada.
	var limite: int=maxi(1,maximo)
	if controle.max_value!=limite: controle.max_value=limite
	controle.indeterminate=false
	controle.set_value_no_signal(clampi(atual,0,limite))
	controle.queue_redraw()
	# Mesmo preenchimento e leitura de HP em ambos os lados.
