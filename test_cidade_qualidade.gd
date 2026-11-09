extends SceneTree
var falhas: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("executar")
func checar(ok: bool, texto: String) -> void:
	checks += 1
	if not ok:
		falhas += 1
		push_error(texto)
func andar(cidade: Control, destino: Vector2i) -> void:
	var personagem: Node2D = cidade.personagem
	var origem: Vector2i = personagem.celula
	var fila: Array[Vector2i] = [origem]
	var anteriores: Dictionary = {origem: origem}
	var index: int = 0
	while index < fila.size() and not anteriores.has(destino):
		var atual: Vector2i = fila[index]
		index += 1
		for direcao in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var proximo: Vector2i = atual+direcao
			if not anteriores.has(proximo) and cidade.cenario.celula_transitavel(proximo):
				anteriores[proximo] = atual
				fila.append(proximo)
	checar(anteriores.has(destino),"destino conectado")
	if not anteriores.has(destino):
		return
	var passos: Array[Vector2i] = []
	var celula: Vector2i = destino
	while celula != origem:
		passos.push_front(celula)
		celula = anteriores[celula]
	for proximo in passos:
		var d: Vector2i = proximo-personagem.celula
		var acao: String = "mover_direita" if d.x>0 else ("mover_esquerda" if d.x<0 else ("mover_baixo" if d.y>0 else "mover_cima"))
		Input.action_press(acao)
		cidade._process(32.0/personagem.velocidade_movimento)
		Input.action_release(acao)
		checar(personagem.celula==proximo and not personagem.andando,"passo completo")

func executar() -> void:
	# Alteração: regressão do layout Full HD sem escala do HUD.
	root.size = Vector2i(1920,1080)
	var estado: Node = root.get_node("EstadoJogo")
	var cidade: Control = load("res://cidade.tscn").instantiate()
	root.add_child(cidade)
	cidade.set_process(false)
	await process_frame
	await process_frame
	var menu: Control = cidade.get_node("Interface/MenuSuperior")
	checar(root.content_scale_mode==Window.CONTENT_SCALE_MODE_DISABLED,"tela usa pixels reais sem ampliar HUD")
	checar(cidade.size==Vector2(1920,1080),"cidade ocupa toda a janela Full HD")
	checar(is_equal_approx(cidade.painel_time.size.x,208),"HUD compacto de208px")
	checar(is_equal_approx(menu.barra.size.x,1244) and is_equal_approx(menu.barra.size.y,48),"dock Full HD1244x48")
	checar(menu.linha.size.x<=menu.rolagem.size.x+1,"todos os ícones cabem em Full HD")
	checar(menu.barra.position.x>cidade.painel_time.position.x+cidade.painel_time.size.x,"dock não cobre o TEAM")
	var cartao: CartaoPokemonHud = cidade.painel_time.cartoes[estado.obter_lider()]
	checar(cartao.icone_tipo.texture!=null,"tipo original no retrato")
	var retrato: Texture2D = cartao.retrato.texture
	var usado: Rect2i = retrato.get_image().get_used_rect()
	checar(usado.size==Vector2i(retrato.get_size()),"retrato sem margem transparente deslocando o Pokémon")
	for tamanho in [Vector2i(1280,720),Vector2i(1152,648),Vector2i(1920,1080)]:
		root.size = tamanho
		await process_frame
		await process_frame
		checar(cidade.size==Vector2(tamanho),"cidade acompanha redimensionamento")
		checar(menu.barra.position.x>=0 and menu.barra.position.x+menu.barra.size.x<=tamanho.x,"dock cabe na largura disponível")
		checar(is_equal_approx(cidade.painel_time.size.x,208),"HUD mantém tamanho ao redimensionar")
	var inicio: Vector2i = cidade.personagem.celula
	checar(cidade.painel_time.cartoes.size()==estado.time_pokemon.size(),"HUD cidade")
	andar(cidade,Vector2i(-8,-13))
	checar(cidade._perto_depot(),"próximo ao depot")
	cidade.botao_depot.pressed.emit()
	checar(cidade.painel_depot.visible,"clique abre convite")
	cidade.painel_depot.abrir_depot()
	checar(cidade.painel_depot.visible,"depot abre")
	var antes: Vector2 = cidade.personagem.position
	Input.action_press("mover_baixo")
	cidade._process(0.4)
	Input.action_release("mover_baixo")
	checar(cidade.personagem.position==antes,"modal bloqueia caminhada")
	cidade.painel_depot.fechar()
	andar(cidade,inicio)
	checar(estado.celula_cidade_salva==inicio,"caminhada agenda checkpoint")
	checar(estado.salvar_agora(),"salva cidade")
	var celula_salva: Vector2i = estado.celula_cidade_salva
	cidade.queue_free()
	await process_frame
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	checar(caca.populacao_iniciada and caca.selvagens.size()==15,"cidade para caça")
	caca.queue_free()
	await process_frame
	cidade = load("res://cidade.tscn").instantiate()
	root.add_child(cidade)
	cidade.set_process(false)
	await process_frame
	checar(cidade.personagem.celula==celula_salva,"retorno restaura posição")
	checar(cidade.seguidores.size()==estado.time_pokemon.size(),"seguidores preservados")
	cidade.queue_free()
	await process_frame
	print("CIDADE: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
