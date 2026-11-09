extends Node2D
# Somente apresentação: recebe snapshots; não espera efeitos para resolver combate.
const EFEITO_IMPACTO: Script=preload("res://efeito_impacto.gd")
const EFEITO_CAPTURA: Script=preload("res://efeito_captura.gd")
const UI: Script=preload("res://estilo_ui_fiel.gd")
var usar_eventos_de_golpe: bool=true
static func cor_efetividade(fator: float) -> Color:
	if fator>1.0: return Color("ffe65a")
	if fator<1.0: return Color("ff6666")
	return Color.WHITE
func apresentar_dano(posicao_global: Vector2, dano: int, tipo: String) -> void:
	if usar_eventos_de_golpe: return # O evento completo já apresentou este golpe.
	_impacto(tipo,posicao_global)
	_numeros("",dano,posicao_global,Color.WHITE)
func apresentar_golpe(evento: Dictionary) -> void:
	_impacto(str(evento["tipo"]),evento["destino"])
	_numeros(str(evento["nome"]),int(evento["dano"]),evento["destino"],cor_efetividade(float(evento.get("efetividade",1.0))))
func _impacto(tipo: String, posicao_global: Vector2) -> void:
	var textura: Texture2D
	var tamanho: Vector2i
	var quantidade: int
	var intervalo: float
	var escala: float
	match tipo:
		"NORMAL":
			textura=preload("res://assets/efeitos/golpes/normal.png")
			tamanho=Vector2i(64,54)
			quantidade=10
			intervalo=0.080
			escala=1.4
		"DARK":
			textura=preload("res://assets/efeitos/golpes/dark.png")
			tamanho=Vector2i(149,64)
			quantidade=9
			intervalo=0.089
			escala=1.0
		_: return # Sem reutilizar uma animação incorreta para um tipo ainda sem asset.
	var efeito: Node2D=EFEITO_IMPACTO.new()
	add_child(efeito)
	efeito.global_position=posicao_global
	efeito.configurar(textura,tamanho,quantidade,intervalo,escala,0,Color.WHITE)
	efeito.texto_dano.hide() # Dano e nome são exibidos juntos, uma única vez.
func _numeros(nome: String, dano: int, destino: Vector2, cor: Color) -> void:
	var grupo: Node2D=Node2D.new()
	grupo.name="TextoGolpe"
	grupo.z_index=115
	add_child(grupo)
	grupo.global_position=destino+Vector2(0,-96)
	if not nome.is_empty():
		var titulo: Label=UI.texto(nome,10,cor,true)
		titulo.position=Vector2(-110,0)
		titulo.size.x=220
		titulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		titulo.add_theme_color_override("font_outline_color",Color("211c0e"))
		titulo.add_theme_constant_override("outline_size",2)
		grupo.add_child(titulo)
	var numero: Label=UI.texto(str(dano),18,cor,true)
	numero.name="Dano"
	numero.position=Vector2(-110,16)
	numero.size.x=220
	numero.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	numero.add_theme_color_override("font_outline_color",Color("211c0e"))
	numero.add_theme_constant_override("outline_size",3)
	grupo.add_child(numero)
	var tween: Tween=grupo.create_tween().set_parallel(true)
	tween.tween_property(grupo,"position:y",grupo.position.y-28,0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(grupo,"modulate:a",0.0,0.25).set_delay(0.70)
	tween.chain().tween_callback(grupo.queue_free)
func apresentar_captura(evento: Dictionary) -> void:
	var efeito: Node2D=EFEITO_CAPTURA.new()
	add_child(efeito)
	efeito.configurar(evento["origem"],evento["destino"],evento["sucesso"],evento["nome"],int(evento["bola_id"]))

# Efeito apenas visual: não consome bola, não captura e não muda HP/relógios.
func apresentar_troca(_pokemon: DadosPokemon) -> void:
	var efeito: Node2D=preload("res://efeito_troca.gd").new()
	get_parent().imagem_aliado.add_child(efeito)
