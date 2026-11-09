extends SceneTree
var falhas: int = 0
var verificacoes: int = 0
func _initialize() -> void:
	call_deferred("executar")
func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error(descricao)
func quadros() -> void:
	for i in range(5):
		await process_frame
func clicar(posicao: Vector2) -> void:
	var mover: InputEventMouseMotion = InputEventMouseMotion.new()
	mover.position = posicao
	mover.global_position = posicao
	root.push_input(mover,true)
	for pressionado in [true,false]:
		var evento: InputEventMouseButton = InputEventMouseButton.new()
		evento.position = posicao
		evento.global_position = posicao
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pressionado
		root.push_input(evento,true)
	await quadros()
func executar() -> void:
	root.size = Vector2i(1920,1080)
	var estado: Node = root.get_node("EstadoJogo")
	for id: int in [1,2,3,4,6,7]:
		estado.estoque_bolas[id] = 9999
	var cidade: Control = load("res://cidade.tscn").instantiate()
	root.add_child(cidade)
	await quadros()
	cidade.set_process(false)
	var helper: Control = cidade.painel_auto_helper
	var menu: Control = cidade.get_node("Interface/MenuSuperior")
	var painel: PanelContainer = cidade.painel_time
	var p: DadosPokemon = estado.pokemon_inicial
	var cartao: CartaoPokemonHud = painel.cartoes[p]
	var identidade: int = cartao.get_instance_id()
	checar(painel.size.x==208,"painel compacto 208px")
	checar(cartao.retrato.size==Vector2(24,26),"retrato centralizado em área própria")
	checar(cartao.icone_tipo.texture!=null and cartao.icone_tipo.modulate.a==1,"tipo como insígnia visível")
	checar(cartao.evoluir.disabled,"evolução não simula função inexistente")
	for hp: int in [1,3,7,p.obter_vida_maxima()]:
		estado.registrar_vida_pokemon(p,hp)
		estado.conceder_experiencia(p,1)
	checar(painel.cartoes[p].get_instance_id()==identidade,"HP/XP conservam o cartão")
	checar(cartao.barra_hp.value==p.obter_vida_atual(),"barra conserva valor real")
	checar(not helper.janela.visible and not helper._sombra.visible,"overlay inicialmente oculto")
	await clicar(menu.abrir.get_global_rect().get_center())
	checar(helper.janela.visible and helper._sombra.visible,"clique do menu abre modal e sombra")
	checar(helper._camada.layer>cidade.get_node("Interface").layer,"modal acima do HUD")
	checar(helper.janela.size.x==236,"largura do original 236px")
	checar(helper.janela.get_global_rect().get_center().distance_to(Vector2(root.size)*0.5)<2,"modal centralizado")
	checar(helper.seletor_pocao.size.x==130,"seletor compacto da poção")
	checar(helper.botoes_bolas[1].icon!=null and helper.botoes_bolas[7].icon!=null,"ícones de bolas, inclusive Golden")
	checar(helper.botoes_bolas[7].icon.get_image().get_used_rect().has_area(),"quadro dourado contém pixels visíveis")
	checar(helper.botoes_bolas[1].text=="9.999" and helper.botoes_bolas[7].text=="∞","estoque com separador e infinito")
	checar(helper.botoes_bolas[1].size.x>60,"chip reserva espaço para ícone e texto")
	var altura: float = helper.janela.size.y
	await clicar(helper.ativar_pocao.get_global_rect().get_center())
	checar(not estado.auto_potion and not helper._pocoes.visible,"checkbox desliga poção e recolhe seção")
	checar(helper.janela.size.y<altura,"modal encolhe com seção recolhida")
	await clicar(helper.ativar_pocao.get_global_rect().get_center())
	checar(estado.auto_potion and helper._pocoes.visible,"poção reativada pelo clique")
	await clicar(helper.botoes_bolas[3].get_global_rect().get_center())
	checar(estado.auto_catch_ball_id==3 and helper.botoes_bolas[3].button_pressed,"chip escolhe bola persistente")
	var antes: int = estado.obter_quantidade_bola(3)
	checar(antes==9999,"configurar não consome bola")
	estado.estoque_bolas[3] = 0
	estado.estoque_bolas_alterado.emit()
	await quadros()
	checar(not helper.botoes_bolas[3].visible and helper.resumo.visible,"estoque esgotado mostra aviso sem trocar seleção")
	checar(estado.auto_catch_ball_id==3,"esgotamento não substitui seleção silenciosamente")
	helper.nomes.text = "Larvitar, Geodude"
	helper.nomes.text_changed.emit(helper.nomes.text)
	checar(estado.auto_catch_names=="Larvitar, Geodude","filtro continua ligado ao estado")
	var indice: int = helper.seletor_limite.get_item_index(75)
	helper.seletor_limite.item_selected.emit(indice)
	checar(estado.auto_potion_threshold==75,"limite segue funcional")
	checar(helper.ativar_shiny.disabled,"Shiny identificado como indisponível")
	# Clique exterior sobre o cabeçalho do perfil fecha apenas o modal.
	await clicar(Vector2(40,30))
	checar(not helper.janela.visible and not helper._sombra.visible,"clique exterior fecha e remove sombra")
	checar(not painel.perfil.visible,"overlay impede clique atravessando para perfil")
	await clicar(menu.abrir.get_global_rect().get_center())
	var tecla: InputEventKey = InputEventKey.new()
	tecla.keycode = KEY_ESCAPE
	tecla.pressed = true
	root.push_input(tecla,true)
	await quadros()
	checar(not helper.janela.visible and not helper._sombra.visible,"Esc fecha janela e sombra")
	helper._alternar_painel()
	await quadros()
	# Código externo existente usa janela.hide(); a sombra deve acompanhar.
	helper.janela.hide()
	checar(not helper._sombra.visible,"janela.hide sincroniza overlay")
	helper._alternar_painel()
	await quadros()
	var cabecalho: Control = helper.janela.get_child(0).get_child(0)
	var posicao_anterior: Vector2 = helper.janela.position
	var inicio: Vector2 = cabecalho.get_global_rect().get_center()
	var pressionar: InputEventMouseButton = InputEventMouseButton.new()
	pressionar.position = inicio
	pressionar.global_position = inicio
	pressionar.button_index = MOUSE_BUTTON_LEFT
	pressionar.pressed = true
	root.push_input(pressionar,true)
	var mover: InputEventMouseMotion = InputEventMouseMotion.new()
	mover.position = inicio+Vector2(80,25)
	mover.global_position = mover.position
	root.push_input(mover,true)
	pressionar.pressed = false
	pressionar.position = mover.position
	pressionar.global_position = mover.position
	root.push_input(pressionar,true)
	checar(helper.janela.position.distance_to(posicao_anterior+Vector2(80,25))<1,"arraste funciona no cabeçalho")
	for resolucao: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1152,648),Vector2i(800,450)]:
		root.size = resolucao
		helper._centralizar = true
		await quadros()
		var retangulo: Rect2 = helper.janela.get_global_rect()
		checar(retangulo.position.x>=0 and retangulo.position.y>=0 and retangulo.end.x<=resolucao.x and retangulo.end.y<=resolucao.y,"modal cabe em "+str(resolucao))
		checar(painel.cartoes[p].get_instance_id()==identidade,"redimensionar conserva cartão")
	checar(helper._rolagem.get_v_scroll_bar().visible,"janela baixa usa rolagem")
	helper.janela.hide()
	checar(estado.salvar_agora(),"configurações continuam serializáveis")
	cidade.queue_free()
	await process_frame
	print("UI FIEL: ",verificacoes," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
