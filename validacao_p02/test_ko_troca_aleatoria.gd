extends SceneTree
var checks: int=0
var falhas: int=0
var instante: int=100000
var estado: Node
var inicial: DadosPokemon
var time: Array[DadosPokemon]=[]
func _initialize() -> void:call_deferred("executar")
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func abrir(interceptar: bool=true) -> Node:
	estado.prazo_troca_hunt_ms=0
	estado.pokemon_lider=inicial
	for p in time:p.vida_atual=p.obter_vida_maxima()
	var c: Node=load("res://Caca.tscn").instantiate()
	if interceptar:c.set_script(load("res://validacao_p02/test_suporte_ko_aleatorio.gd"))
	root.add_child(c);c.set_process(false);c.set_physics_process(false)
	c.timer_combate.stop();c.timer_auto_potion.stop()
	c.relogio_troca=func()->int:return instante
	c.rng_troca.seed=12345
	return c
func fechar(c: Node) -> void:root.remove_child(c);c.free()
func executar() -> void:
	estado=root.get_node("EstadoJogo")
	for i in range(5):await process_frame
	estado.auto_catch=false;estado.auto_potion=false
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	inicial=estado.pokemon_inicial;time.append(inicial)
	for i in range(5):
		var p: DadosPokemon=DadosPokemon.new();p.especie=estado.especie_caca;p.normalizar_atributos();p.vida_atual=24;time.append(p);estado.time_pokemon.append(p)
	var c: Node=abrir()
	var en: EncontroSelvagem=c.encontro_atual
	en.vida=37
	var id: String=en.id;var quantidade: int=c.selvagens.size()
	var hp: Dictionary={}
	for p in time:hp[p]=p.obter_vida_atual()
	var sinais: Array=[]
	c.aliado_alterado.connect(func(p: DadosPokemon)->void:sinais.append(p))
	# Inimigos e percurso não são reiniciados pela troca automática.
	c.aproximando=true;c.batalha_encerrada=false
	c.imagem_aliado.global_position+=Vector2(0,8)
	var posicao: Vector2=c.imagem_aliado.global_position
	var caminho: Array=c.caminho.duplicate();var indice: int=c.indice_caminho
	c.agenda_aliado.tempo=3.0;c.agenda_aliado.residuo_tick=0.1;c.agenda_aliado.proximo_ataque_rapido=4.7
	var timer_cura: Timer=c.timer_auto_potion
	var xp: int=inicial.experiencia_total
	var capturas: int=estado.pokemons_capturados.size()
	var estado_rng_dano: int=c.rng_dano.state;var estado_rng_loot: int=c.rng_loot.state
	# Cooldown manual em andamento não pode bloquear a resposta ao KO.
	estado.prazo_troca_hunt_ms=instante+2000
	c.vida_aliado=0;c.encerrar_batalha("Geodude")
	var substituto: DadosPokemon=c.pokemon_aliado
	check(substituto!=inicial and time.has(substituto),"entra reserva do time")
	check(c.saidas_por_ko==0 and not c._saida_solicitada,"não sai havendo reserva")
	check(inicial.vida_atual==0 and substituto.obter_vida_atual()==hp[substituto],"troca sem cura")
	check(estado.obter_lider()==substituto and sinais.size()==1,"estado, controlador e sinal concordam")
	check(c.obter_troca_restante()==5.0,"cada troca automática começa cinco segundos")
	check(c.encontro_atual==en and en.id==id and en.vida==37 and c.selvagens.size()==quantidade,"mantém encontro, HP inimigo e população")
	check(c.aproximando and not c.batalha_encerrada and c.caminho==caminho and c.indice_caminho==indice and c.imagem_aliado.global_position==posicao,"KO em deslocamento preserva passo e rota")
	check(c.agenda_aliado.tempo==3.0 and is_equal_approx(c.agenda_aliado.residuo_tick,0.1) and c.agenda_aliado.proximo_ataque_rapido>=4.7,"nova reserva não ganha ataque fora da agenda")
	check(c.timer_auto_potion==timer_cura and c.get_node_or_null("TreinadorCaca")!=null,"serviços e treinador mantidos")
	check(c.rng_dano.state==estado_rng_dano and c.rng_loot.state==estado_rng_loot,"sorteio não consome RNG de dano/loot")
	check(inicial.experiencia_total==xp and estado.pokemons_capturados.size()==capturas,"KO do aliado não concede XP nem captura")
	var manual: DadosPokemon
	for p in time:
		if p!=inicial and p!=substituto:manual=p;break
	check(not estado.selecionar_lider(manual),"manual bloqueada após troca automática")
	instante+=4999
	check(not estado.selecionar_lider(manual),"manual bloqueada até 4,999 s")
	instante+=1
	var hud: Control=c.get_node("Interface/HudCaca")
	hud.painel_time.cartoes[manual].lider_solicitado.emit(manual)
	check(c.pokemon_aliado==manual and estado.obter_lider()==manual,"clique manual escolhe outro vivo aos cinco segundos")
	check(c.obter_troca_restante()==5.0,"troca manual mantém regra de cooldown")
	check(not estado.selecionar_lider(inicial),"derrotado não pode ser escolhido manualmente")
	check(estado.selecionar_lider(manual) and c.obter_troca_restante()==5.0,"clicar no ativo não prolonga prazo")
	# KO durante o novo cooldown sempre substitui, inclusive sem relógio avançar.
	c.vida_aliado=0;c.encerrar_batalha("Geodude")
	check(c.pokemon_aliado!=manual and c.vida_aliado>0 and c.obter_troca_restante()==5.0,"novo KO ignora bloqueio manual")
	check(manual.vida_atual==0 and inicial.vida_atual==0,"derrotados ficam fora dos sorteios seguintes")
	fechar(c)
	# Seis KOs sem tempo entre eles: cada membro entra uma vez, cidade só no último.
	c=abrir();var vistos: Array=[]
	for i in range(6):
		var caiu: DadosPokemon=c.pokemon_aliado
		check(not vistos.has(caiu),"não ressorteia derrotado "+str(i))
		vistos.append(caiu);c.vida_aliado=0;c.encerrar_batalha("Geodude")
		check(caiu.vida_atual==0,"preserva KO "+str(i))
		if i<5:check(c.saidas_por_ko==0 and c.vida_aliado>0 and c.obter_troca_restante()==5.0,"continua até a última reserva "+str(i))
		else:check(c.saidas_por_ko==1 and c.vida_aliado==0,"retorna somente no sexto KO")
	check(vistos.size()==6,"usou os seis membros")
	c.encerrar_batalha("duplicado")
	check(c.saidas_por_ko==1,"notificação duplicada após saída não retorna duas vezes")
	fechar(c)
	# Somente a última reserva válida pode entrar. BOX e membros inválidos não participam.
	c=abrir()
	for p in time:p.vida_atual=0
	time[5].vida_atual=7
	var invalido: DadosPokemon=DadosPokemon.new();estado.time_pokemon.append(invalido);estado.time_pokemon.append(null)
	var box: DadosPokemon=time[1].duplicate();box.vida_atual=24;estado.pokemons_capturados.append(box)
	c.encerrar_batalha("Geodude")
	check(c.pokemon_aliado==time[5] and c.vida_aliado==7,"entra só última reserva válida, sem curar")
	check(c.saidas_por_ko==0,"BOX não interfere na escolha válida")
	# Remover fixtures inválidas antes de permitir salvamento deferred.
	estado.time_pokemon.erase(invalido);estado.time_pokemon.erase(null)
	c.vida_aliado=0;c.encerrar_batalha("Geodude")
	check(c.saidas_por_ko==1,"BOX viva não impede KO total do time")
	estado.pokemons_capturados.erase(box)
	fechar(c)
	# Sorteio não é sempre a primeira posição: mesma fixture, diferentes seeds.
	c=abrir();var escolhidos: Dictionary={}
	for s in range(40):
		for p in time:p.vida_atual=24
		estado.pokemon_lider=inicial;c.pokemon_aliado=inicial;c._saida_solicitada=false
		c.rng_troca.seed=s;c.vida_aliado=0;c.encerrar_batalha("Geodude")
		check(c.pokemon_aliado!=inicial and c.vida_aliado>0,"sorteio só entre elegíveis seed "+str(s))
		escolhidos[c.pokemon_aliado]=true
	check(escolhidos.size()==5,"seeds exercitam todas as cinco reservas; não é ordem fixa")
	fechar(c)
	# Vários atacantes prontos no mesmo frame, cada um capaz de causar KO.
	c=abrir()
	for p in time:p.vida_atual=1
	var centro: Vector2i
	for cel in c.celulas_acessiveis:
		var n: int=0
		for dir in c.DIRECOES:
			if c.passagem_permitida(cel,cel+dir):n+=1
		if n>=6:centro=cel;break
	c.imagem_aliado.global_position=c.celula_para_posicao(centro)
	var vizinhos: Array[Vector2i]=[]
	for dir in c.DIRECOES:
		if c.passagem_permitida(centro,centro+dir):vizinhos.append(centro+dir)
	check(vizinhos.size()>=6,"fixture possui seis posições de ataque")
	for i in range(c.selvagens.size()):
		var mob: EncontroSelvagem=c.selvagens[i]
		if i>=6:mob.resolver(10);continue
		mob.movendo=false;mob.celula=vizinhos[i];mob.imagem.global_position=c.celula_para_posicao(mob.celula)
		mob.intervalo_ataque=0.1;mob.agenda_golpes.avancar(100)
	c._processar_ataques_selvagens()
	check(c.saidas_por_ko==1,"seis hits no mesmo frame encerram só depois de todo time KO")
	for p in time:check(p.vida_atual==0,"cada membro recebeu seu hit fatal no mesmo frame")
	fechar(c)
	# A saída real usa a cidade; sem interceptação neste caso final.
	c=abrir(false);current_scene=c
	for p in time:p.vida_atual=0
	c.encerrar_batalha("Geodude")
	for i in range(3):await process_frame
	check(current_scene!=null and current_scene.scene_file_path=="res://cidade.tscn","KO total troca efetivamente para cidade")
	for p in time:check(p.vida_atual==0,"cidade não cura automaticamente o time")
	check(not estado.validador_troca_lider.is_valid(),"saída real limpa validador da hunt")
	print("P02 KO E TROCA ALEATORIA: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
