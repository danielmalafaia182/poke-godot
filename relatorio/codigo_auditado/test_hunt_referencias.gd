extends SceneTree
var falhas: int = 0
var verificacoes: int = 0
func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error(descricao)
func _initialize() -> void:
	call_deferred("testar")
func testar() -> void:
	seed(749) # Fixture determinística: o percurso do treinador não depende do RNG ambiente.
	root.size = Vector2i(1152,648)
	var estado: Node = root.get_node("EstadoJogo")
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.selecionar_lider(estado.pokemon_inicial)
	estado.pokemon_inicial.vida_atual = estado.pokemon_inicial.obter_vida_maxima()
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	caca.timer_combate.stop()
	caca.movimento_selvagens_habilitado=false
	caca.timer_auto_potion.stop()
	await process_frame
	await process_frame
	checar(caca.populacao_iniciada,"população iniciou")
	checar(caca.selvagens.size()==15,"15 slots")
	checar(caca.celulas_existentes.size()-caca.celulas_bloqueadas.size()==757,"757 células livres originais")
	checar(caca.velocidade_movimento==64.0,"passo500ms")
	for ponto in caca.PONTOS_RESPAWN:
		checar(caca.celula_transitavel(ponto),"spawn validado")
	var hud: Control = caca.get_node("Interface/HudCaca")
	checar(hud.painel_time.visible,"HUD permanente")
	checar(not hud.my_pokes.visible,"TEAM modal fechado")
	hud.menu.time_solicitado.emit()
	checar(hud.my_pokes.visible,"pokebola abre MyPokes")
	checar(hud.painel_time.visible,"HUD não fecha")
	hud.my_pokes.hide()
	hud.menu.pokepedia_solicitada.emit()
	checar(hud.pokepedia.visible,"Pokepedia abre")
	hud.pokepedia.hide()
	checar(hud.recompensas.pilha.get_child_count()==0,"sem recompensa antes do KO")
	var treinador_visual: Node2D = caca.get_node("TreinadorCaca")
	treinador_visual.set_physics_process(false)
	# O teste de apresentação usa trechos válidos, sem depender de um mob
	# desocupar aleatoriamente o primeiro passo da aproximação automática.
	var trajeto: Array[Vector2i]=caca.calcular_caminho(caca.posicao_para_celula(caca.imagem_aliado.global_position),Vector2i(5,-14))
	checar(trajeto.size()>=4,"fixture tem percurso válido para o treinador")
	for indice in range(mini(4,trajeto.size())):
		var origem: Vector2=caca.imagem_aliado.global_position
		var destino: Vector2=caca.celula_para_posicao(trajeto[indice])
		caca.imagem_aliado.global_position=destino
		caca.trecho_percorrido.emit(origem,destino)
		treinador_visual._physics_process(0.5)
		checar(caca.celula_transitavel(caca.posicao_para_celula(treinador_visual.global_position)),"treinador segue chão livre")
	checar(treinador_visual.visible,"treinador aparece após abrir espaço")
	checar(hud.size==Vector2(1152,648),"HUD usa viewport")
	checar(hud.captura.position.x+hud.captura.size.x<=1152,"captura cabe horizontalmente")
	var xp: int = caca.pokemon_aliado.experiencia_total
	var treinador: int = estado.experiencia_treinador_acumulada
	var bolas: Dictionary = estado.estoque_bolas.duplicate()
	estado.auto_catch = false
	caca.vida_selvagem = 0
	caca.encerrar_batalha(caca.pokemon_aliado.especie.nome)
	checar(caca.pokemon_aliado.experiencia_total==xp+8,"base8 ao líder")
	checar(estado.experiencia_treinador_acumulada==treinador+8,"contador treinador8")
	checar(estado.estoque_bolas==bolas,"KO sem autocatch não consome bola")
	checar(hud.recompensas.cartoes.size()==1,"cartão de derrota")
	caca._recompensar_derrota()
	checar(caca.pokemon_aliado.experiencia_total==xp+8,"sem XP duplicado")
	caca._selecionar_alvo()
	caca.bonus_vip_recompensa = true
	caca.vida_selvagem = 0
	caca.encerrar_batalha(caca.pokemon_aliado.especie.nome)
	checar(caca.pokemon_aliado.experiencia_total==xp+20,"VIP8+4")
	checar(hud.recompensas.cartoes.size()==1,"agrupamento700ms")
	checar(int(hud.recompensas.cartoes[0]["evento"]["xpGained"])==8,"cartão em exibição permanece intacto")
	caca._selecionar_alvo()
	caca.chance_captura = 0.0
	estado.auto_catch = true
	estado.auto_catch_names = ""
	estado.auto_catch_ball_id = 1
	estado.estoque_bolas[1] = 1
	var quantidade_box: int = estado.pokemons_capturados.size()
	caca.vida_selvagem = 0
	caca.encerrar_batalha(caca.pokemon_aliado.especie.nome)
	checar(caca.pokemon_aliado.experiencia_total==xp+32,"falha na captura conserva recompensa")
	checar(estado.estoque_bolas[1]==0,"uma bola consumida na falha")
	checar(estado.pokemons_capturados.size()==quantidade_box,"falha não acrescenta BOX")
	checar(not hud.resumo_captura.visible and hud.capturados_hunt==0,"falha não exibe mensagem nem aumenta capturados")
	var persistencia: RefCounted = load("res://salvamento_local.gd").new()
	var dados: Dictionary = persistencia.construir_dados(estado)
	checar(persistencia._validar(dados)=="","save validado")
	checar(int(dados["experiencia_treinador_acumulada"])==treinador+32,"contador serializado")
	dados.erase("experiencia_treinador_acumulada")
	checar(persistencia._validar(dados)=="","save anterior aceito")
	var eventos: Array = JSON.parse_string(FileAccess.get_file_as_string("res://dados/referencias/encontros_geodude.json"))
	var kills: int = 0
	for evento in eventos:
		if evento["type"] == "field-kill":
			kills += 1
			checar(evento["xpGained"]==12 and evento["pokeXp"]["xpGained"]==12,"recompensas capturadas")
	checar(kills==3,"três encontros arquivados")
	caca.queue_free()
	await process_frame
	print("HUNT REFERÊNCIAS: ",verificacoes," verificações; ",falhas," falhas")
	quit(1 if falhas>0 else 0)
