extends SceneTree
var checks: int=0
var falhas: int=0
var estado: Node
var inicial: DadosPokemon
var reserva: DadosPokemon
func _initialize() -> void:call_deferred("executar")
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func preparar(hp_inicial: int,hp_reserva: int) -> void:
	estado.prazo_troca_hunt_ms=0
	estado.pokemon_lider=inicial
	inicial.vida_atual=hp_inicial
	reserva.vida_atual=hp_reserva
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	estado.auto_potion=true
	estado.auto_catch=false
func abrir() -> Node2D:
	var c: Node2D=load("res://Caca.tscn").instantiate()
	root.add_child(c)
	c.set_process(false);c.set_physics_process(false)
	return c
func liberar(c: Node) -> void:
	root.remove_child(c);c.free()
func executar() -> void:
	estado=root.get_node("EstadoJogo")
	for i in range(5):await process_frame
	inicial=estado.pokemon_inicial
	reserva=DadosPokemon.new();reserva.especie=load("res://dados/especies/geodude.tres");reserva.normalizar_atributos()
	estado.time_pokemon.append(reserva)
	preparar(0,12)
	var c: Node2D=abrir()
	check(c._navegacao_preparada and not c._atividade_iniciada,"navegação preparada, atividade aguardando")
	check(not c.populacao_iniciada and c.selvagens.is_empty(),"líder KO não cria população")
	check(is_instance_valid(c.timer_auto_potion) and c.timer_auto_potion.is_stopped(),"timer de cura preparado e parado")
	check(estado.lider_alterado.is_connected(c._sincronizar_lider_caca),"troca conectada antes da recuperação")
	check(estado.validador_troca_lider.get_object()==c,"validador pertence à hunt aguardando")
	check(c.titulo.visible and c.get_node_or_null("TreinadorCaca")==null,"aviso visível, sem treinador prematuro")
	var estoque: int=estado.obter_quantidade_pocao(200)
	for i in range(10):
		c._physics_process(1.0);c._process(1.0);c._on_timer_auto_potion_timeout()
	check(estado.obter_quantidade_pocao(200)==estoque and inicial.vida_atual==0,"espera não consome nem ressuscita")
	check(not estado.selecionar_lider(null),"reserva nula rejeitada")
	var invalido: DadosPokemon=DadosPokemon.new();estado.time_pokemon.append(invalido)
	check(not estado.selecionar_lider(invalido),"reserva sem espécie rejeitada sem erro")
	invalido.especie=DadosEspecie.new();invalido.especie.nome="Desconhecido"
	check(not estado.selecionar_lider(invalido),"reserva com espécie sem base/textura rejeitada")
	estado.time_pokemon.erase(invalido)
	var fora: DadosPokemon=reserva.duplicate()
	check(not estado.selecionar_lider(fora),"indivíduo fora do time rejeitado")
	var hud: Control=c.get_node("Interface/HudCaca")
	hud.painel_time.cartoes[reserva].lider_solicitado.emit(reserva)
	check(c.pokemon_aliado==reserva and estado.obter_lider()==reserva,"clique no HUD sincroniza reserva")
	check(c._atividade_iniciada and c.populacao_iniciada and c.selvagens.size()==15,"recuperação inicia exatamente população esperada")
	check(not c.timer_auto_potion.is_stopped(),"recuperação liga cura")
	check(not c.titulo.visible and c.get_node_or_null("TreinadorCaca")!=null,"recuperação atualiza aviso e cria treinador")
	check(reserva.vida_atual==12 and inicial.vida_atual==0,"troca não cura nem transfere HP")
	check(hud.placa_aliado!=null and hud.vida_aliado.value==12,"HUD lê HP da nova reserva")
	check(c.obter_troca_restante()>4.0 and c.obter_troca_restante()<=5.0,"troca recuperada mantém cooldown de cinco segundos")
	var ids: Array=[]
	for en in c.selvagens:ids.append(en.id)
	var timer: Timer=c.timer_auto_potion
	var treinador: Node=c.get_node("TreinadorCaca")
	for i in range(5):
		check(estado.selecionar_lider(reserva),"clique repetido no líder é idempotente")
		c._sincronizar_lider_caca();c._tentar_iniciar_atividade()
	check(c.selvagens.size()==15 and c.timer_auto_potion==timer and c.get_node("TreinadorCaca")==treinador,"sem população, timer ou treinador duplicado")
	for i in range(15):check(c.selvagens[i].id==ids[i],"cliques não recriam encontro "+str(i))
	check(c.cura_aplicada.get_connections().filter(func(x: Dictionary)->bool:return x.callable==c._apresentar_cura).size()==1,"efeito cura conectado uma única vez")
	liberar(c)
	check(not estado.validador_troca_lider.is_valid(),"saída limpa validador")
	# Todo time KO: nada é criado e ninguém é curado. Após obter reserva saudável, serviço retoma.
	preparar(0,0);c=abrir()
	check(not estado.selecionar_lider(reserva),"reserva KO rejeitada")
	check(not c.populacao_iniciada and c.timer_auto_potion.is_stopped(),"todos KO aguardam sem combate")
	reserva.vida_atual=10
	check(estado.selecionar_lider(reserva) and c.populacao_iniciada,"reserva que se torna saudável recupera a hunt")
	liberar(c)
	# Sair antes da recuperação: manter nó vivo fora da árvore para verificar desconexão real.
	preparar(0,12);c=abrir();root.remove_child(c)
	check(not estado.lider_alterado.is_connected(c._sincronizar_lider_caca),"saída antes de recuperação desconecta troca")
	check(not estado.validador_troca_lider.is_valid() and c.timer_auto_potion.is_stopped(),"saída antes de recuperação limpa serviços")
	check(estado.selecionar_lider(reserva),"liderança pode mudar fora da hunt")
	c._tentar_iniciar_atividade();c._sincronizar_lider_caca()
	check(not c.populacao_iniciada and c.selvagens.is_empty(),"hunt removida não recupera via callback tardio")
	c.free()
	# Entrada normal continua imediata, com uma única inicialização.
	preparar(inicial.obter_vida_maxima(),12);c=abrir()
	check(c.populacao_iniciada and c._atividade_iniciada and c.selvagens.size()==15,"entrada saudável continua imediata")
	check(c.get_node_or_null("TreinadorCaca")!=null and not c.timer_auto_potion.is_stopped(),"entrada saudável inicia apresentação e cura")
	liberar(c);await process_frame
	print("P01 ENTRADA LIDER KO: %d verificações; %d falhas" % [checks,falhas])
	quit(1 if falhas else 0)
