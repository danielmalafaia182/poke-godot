extends Node2D

# Novo: apresentação consulta o encontro vivo, sem copiar HP nem guardar o slot como identidade.
# Aliado e selvagens compartilham fonte bitmap, cor, barra e ancoragem.
const ESTILO: Script=preload("res://estilo_combate.gd")
var controlador: Node2D
var encontro: EncontroSelvagem
var nome: TextureRect
var barra: ProgressBar
func configurar(caca: Node2D, registro: EncontroSelvagem) -> void:
	if encontro!=null and encontro.vida_alterada.is_connected(atualizar):
		encontro.vida_alterada.disconnect(atualizar)
	controlador=caca
	encontro=registro
	encontro.vida_alterada.connect(atualizar)
	if barra==null:
		top_level=true
		z_index=ESTILO.CAMADA_INDICADORES
		z_as_relative=false
		nome=ESTILO.nome(registro.pokemon.especie.nome)
		add_child(nome)
		barra=ESTILO.barra()
		add_child(barra)
	else:
		nome.texture=preload("res://fonte_mundo.gd").texto(registro.pokemon.especie.nome,Color("00ff00"))
		nome.size=nome.texture.get_size()
		nome.position.x=-floorf(nome.size.x*0.5)
	atualizar()

func _process(_delta: float) -> void:
	atualizar()

func atualizar() -> void:
	if not is_instance_valid(controlador) or encontro == null or not is_instance_valid(encontro.imagem):
		hide()
		return
	var alvo: bool = controlador.encontro_atual == encontro
	visible = encontro.estado == EncontroSelvagem.Estado.VIVO and encontro.imagem.is_visible_in_tree() and (controlador.mostrar_indicadores_todos_selvagens or alvo or encontro.vida < encontro.vida_maxima)
	# Também atualiza em HP zero: o controle oculto não retém valor antigo.
	ESTILO.atualizar(barra,encontro.vida,encontro.vida_maxima)
	if not visible:
		return
	# Alteração: usa posição interpolada em coordenadas globais; não herda escala do sprite.
	global_position = encontro.imagem.global_position
