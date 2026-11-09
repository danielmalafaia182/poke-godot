extends SceneTree
# Alteração: verifica o padrão de 1.5 s e o bloqueio de ataques antecipados.
var falhas: int = 0
var checks: int = 0
var eventos: Array[Dictionary] = []
func checar(valor: bool, descricao: String) -> void:
	checks += 1
	if not valor:
		falhas += 1
		push_error(descricao)
func _initialize() -> void:
	call_deferred("testar")
func testar() -> void:
	var agenda: RefCounted = load("res://agenda_golpes.gd").new()
	agenda.configurar("Geodude",10)
	checar(agenda.retirar_pronto(false)["name"]=="Tackle","rotação começa em Tackle")
	checar(agenda.retirar_pronto(false)["name"]=="Rollout","rotação usa segundo golpe")
	checar(agenda.retirar_pronto(false)["name"]=="Tackle","rotação reinicia")
	checar(agenda.golpes[0]["cooldownMs"]==15000,"catálogo preservado")
	var estado: Node = root.get_node("EstadoJogo")
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.selecionar_lider(estado.pokemon_inicial)
	estado.curar_time()
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	caca.usar_atributos_combate=false
	root.add_child(caca)
	caca.set_physics_process(false)
	caca.set_process(false)
	caca.timer_auto_potion.stop()
	caca.movimento_selvagens_habilitado = false
	await process_frame
	var encontro: EncontroSelvagem = caca.encontro_atual
	# Alteração: alvo resistente permite medir vários ciclos sem encerrar o combate.
	encontro.vida_maxima = 10000
	encontro.vida = 10000
	# Alteração: o indicador usa HP do encontro, inclusive quando difere do Pokémon capturado.
	var indicador: Node2D = encontro.imagem.get_node("IndicadorSelvagem")
	indicador.atualizar()
	checar(indicador.visible and indicador.barra.max_value==10000,"indicador do alvo usa HP máximo do encontro")
	checar(indicador.is_set_as_top_level(),"indicador não herda escala do sprite")
	for direcao in caca.DIRECOES:
		if caca.passagem_permitida(encontro.celula,encontro.celula+direcao):
			caca.imagem_aliado.global_position = caca.celula_para_posicao(encontro.celula+direcao)
			break
	caca.aproximando = false
	checar(not caca.aplicar_cooldowns_catalogo,"caça rápida por padrão")
	checar(is_equal_approx(caca.timer_combate.wait_time,1.5),"timer1500ms")
	caca.golpe_executado.connect(func(evento: Dictionary) -> void: eventos.append(evento))
	caca._on_timer_combate_timeout()
	caca.timer_combate.start()
	checar(eventos.size()==2,"primeira troca imediata")
	caca._on_timer_combate_timeout()
	checar(eventos.size()==2,"duplicação no mesmo instante bloqueada")
	caca._physics_process(1.499)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==2,"intervalo mínimo respeitado")
	caca._physics_process(0.001)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==4,"repete aos1500ms sem esperar15ou20s")
	checar(eventos[0]["cooldown_ms"]==20000,"metadados do original preservados")
	# Alteração: cadências diferentes comprovam que não há mais uma troca obrigatória.
	caca.intervalo_ataques_selvagem = 2.0
	caca._physics_process(1.5)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==6,"ambos atacam aos3s e reservam próximos prazos")
	caca._physics_process(1.5)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==7 and eventos[6]["aliado"],"somente aliado aos4.5s")
	checar(is_equal_approx(caca.timer_combate.wait_time,1.5),"timer do aliado não aguarda o selvagem; agendas são independentes")
	caca._physics_process(0.5)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==8 and not eventos[7]["aliado"],"somente selvagem aos5s")
	var prazo: float = encontro.agenda_golpes.proximo_ataque_rapido
	caca.encontro_atual = null
	caca._selecionar_alvo()
	checar(caca.encontro_atual==encontro and encontro.agenda_golpes.proximo_ataque_rapido==prazo,"reseleção preserva prazo do selvagem")
	caca.aproximando = false
	caca._physics_process(5.0)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==10,"atraso longo não dispara rajada acumulada")
	caca._on_timer_combate_timeout()
	checar(eventos.size()==10,"cada agenda bloqueia duplicação")
	caca.vida_selvagem = 1
	indicador.atualizar()
	checar(indicador.barra.value==1,"barra acompanha HP sem recriar controles")
	caca._physics_process(2.0)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==11 and eventos[10]["aliado"],"golpe fatal impede retaliação do alvo derrotado")
	checar(eventos[10]["dano"]==caca.pokemon_aliado.especie.dano_base and eventos[10]["vida_removida"]==1,"golpe fatal preserva dano completo e registra HP efetivamente removido")
	indicador.atualizar()
	checar(not indicador.visible,"indicador some após derrota")
	var slot: int = encontro.slot
	caca._criar_individuo(slot,caca.PONTOS_RESPAWN[slot])
	var novo: EncontroSelvagem = caca.selvagens[slot]
	checar(novo.imagem.get_node("IndicadorSelvagem")==indicador and indicador.encontro==novo,"respawn reutiliza indicador com nova identidade")
	indicador.atualizar()
	checar(indicador.visible,"indicadores de todos os vivos por padrão")
	caca.mostrar_indicadores_todos_selvagens=false
	indicador.atualizar()
	checar(not indicador.visible,"modo compacto oculta saudável fora do alvo")
	caca.encontro_atual = novo
	indicador.atualizar()
	checar(indicador.visible and indicador.barra.value==novo.vida,"novo alvo exibe HP do novo encontro")
	caca.queue_free()
	await process_frame
	print("COMBATE RÁPIDO: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
