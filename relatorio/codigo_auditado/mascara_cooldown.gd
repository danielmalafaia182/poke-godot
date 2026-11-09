extends Control
# Máscara radial e número sobre o retrato, como observado no vídeo original.
const FONTE: Font=preload("res://assets/interface/fiel/barlow_bold.ttf")
var restante: float=0.0
var duracao: float=5.0
func _init() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 hide()
func atualizar(segundos: float,total: float=5.0) -> void:
 restante=maxf(0.0,segundos);duracao=maxf(0.001,total)
 visible=restante>0.0
 queue_redraw()
func _draw() -> void:
 if restante<=0:return
 var centro: Vector2=size*0.5
 var raio: float=maxf(0.0,minf(size.x,size.y)*0.5-2)
 draw_circle(centro,raio,Color("050b12b8"))
 var proporcao: float=clampf(restante/duracao,0,1)
 var pontos: PackedVector2Array=PackedVector2Array([centro])
 for i in range(49):
  var angulo: float=-PI/2.0+TAU*proporcao*i/48.0
  pontos.append(centro+Vector2(cos(angulo),sin(angulo))*raio)
 if proporcao>=0.9999:draw_circle(centro,raio,Color("000000b0"))
 else:draw_colored_polygon(pontos,Color("000000b0"))
 draw_arc(centro,raio,-PI/2.0,-PI/2.0+TAU*proporcao,48,Color("ddc681"),1.0,true)
 var texto: String=str(ceili(restante))
 var tamanho: int=16
 var largura: float=FONTE.get_string_size(texto,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho).x
 var pos: Vector2=Vector2(centro.x-largura/2.0,centro.y+(FONTE.get_ascent(tamanho)-FONTE.get_descent(tamanho))/2.0)
 draw_string_outline(FONTE,pos,texto,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho,3,Color.BLACK)
 draw_string(FONTE,pos,texto,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho,Color("f2df9a"))
