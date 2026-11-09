extends ProgressBar
const COR_HP: Color=Color("00c000")
# Mantém a API Range, mas desenha o HP sem preenchimento/animação nativa.
# O desenho é função exclusiva de value/max_value: nenhum relógio ou tween.
func _init() -> void:
 show_percentage=false
 indeterminate=false
 step=0.0
 min_value=0.0
 add_theme_stylebox_override("background",StyleBoxEmpty.new())
 add_theme_stylebox_override("fill",StyleBoxEmpty.new())
 mouse_filter=Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
 value_changed.connect(func(_v: float) -> void:queue_redraw())
 changed.connect(queue_redraw)
 resized.connect(queue_redraw)
func largura_preenchida() -> int:
 var interior: int=maxi(0,floori(size.x)-2)
 if value<=0 or interior==0:return 0
 return clampi(ceili(interior*clampf(ratio,0.0,1.0)),1,interior)
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color.BLACK)
 var largura: int=largura_preenchida()
 if largura>0:
  draw_rect(Rect2(Vector2(1,1),Vector2(largura,maxf(0,size.y-2))),COR_HP)
