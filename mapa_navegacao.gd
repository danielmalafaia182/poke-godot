extends Control
signal visao_alterada
@onready var imagem_mapa: TextureRect=get_node("ImagemMapa")
var zoom: float=1.25
var arrastando: bool=false
var _tamanho_anterior: Vector2=Vector2.ZERO
const PASSO_ZOOM: float=1.2
func _ready() -> void:
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_DRAG
	gui_input.connect(_on_gui_input)
	resized.connect(_redimensionar)
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			arrastando=event.pressed
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_aplicar_zoom(zoom*(PASSO_ZOOM if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/PASSO_ZOOM),event.position)
			accept_event()
	elif event is InputEventMouseMotion and arrastando:
		imagem_mapa.position+=event.relative
		_limitar_posicao()
		visao_alterada.emit()
		accept_event()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: arrastando=false
func _redimensionar() -> void:
	if not is_instance_valid(imagem_mapa) or size.x<=0 or size.y<=0: return
	var centro: Vector2=(_tamanho_anterior*0.5-imagem_mapa.position)/zoom
	_tamanho_anterior=size
	zoom=maxf(zoom,_zoom_minimo())
	imagem_mapa.scale=Vector2.ONE*zoom
	imagem_mapa.position=size*0.5-centro*zoom
	_limitar_posicao()
	visao_alterada.emit()
func _zoom_minimo() -> float:
	return maxf(size.x/imagem_mapa.size.x,size.y/imagem_mapa.size.y)
func _aplicar_zoom(novo: float, ponto: Vector2) -> void:
	novo=clampf(novo,_zoom_minimo(),maxf(2.5,_zoom_minimo()*5.0))
	var mundo: Vector2=(ponto-imagem_mapa.position)/zoom
	zoom=novo
	imagem_mapa.scale=Vector2.ONE*zoom
	imagem_mapa.position=ponto-mundo*zoom
	_limitar_posicao()
	visao_alterada.emit()
func zoom_centro(fator: float) -> void: _aplicar_zoom(zoom*fator,size*0.5)
func centralizar(pixel: Vector2, proporcao: Vector2=Vector2(0.37,0.46)) -> void:
	_tamanho_anterior=size
	zoom=clampf(1.25,_zoom_minimo(),maxf(2.5,_zoom_minimo()*5.0))
	imagem_mapa.scale=Vector2.ONE*zoom
	imagem_mapa.position=size*proporcao-pixel*zoom
	_limitar_posicao()
	visao_alterada.emit()
func _limitar_posicao() -> void:
	if not is_instance_valid(imagem_mapa): return
	var mapa: Vector2=imagem_mapa.size*zoom
	imagem_mapa.position=Vector2(clampf(imagem_mapa.position.x,minf(0,size.x-mapa.x),0),clampf(imagem_mapa.position.y,minf(0,size.y-mapa.y),0))
