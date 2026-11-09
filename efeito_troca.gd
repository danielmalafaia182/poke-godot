extends Node2D
# Trecho de abertura da Pokébola já presente nos assets, como no vídeo de troca.
const TEXTURA: Texture2D=preload("res://assets/efeitos/captura/pokeball_broke.png")
const QUADROS: Array[int]=[3,4,5,6,7,8,9,10]
const INTERVALO: float=0.075
var tempo: float=0.0
var imagem: Sprite2D
var recorte: AtlasTexture
func _ready() -> void:
 name="EfeitoTroca"
 z_index=110;z_as_relative=false
 imagem=Sprite2D.new();imagem.centered=false
 imagem.position=Vector2(-32,-96)
 imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 recorte=AtlasTexture.new();recorte.atlas=TEXTURA;imagem.texture=recorte
 add_child(imagem);_aplicar(0)
func _aplicar(indice: int) -> void:
 recorte.region=Rect2(0,QUADROS[indice]*96,64,96)
func _process(delta: float) -> void:
 tempo+=maxf(0.0,delta)
 var indice: int=floori((tempo+0.000001)/INTERVALO)
 if indice>=QUADROS.size():queue_free();return
 _aplicar(indice)
