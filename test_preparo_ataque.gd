extends SceneTree
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
	var estado: Node=root.get_node("EstadoJogo");estado.especie_caca=preload("res://especies_importadas.gd").obter_especies()["Blastoise"];estado.curar_time();estado.auto_catch=false
	var caca: Node=load("res://Caca.tscn").instantiate();root.add_child(caca)
	caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
	caca.movimento_selvagens_habilitado=false;caca.reagir_ao_cerco=false
	# Aliado saudável de referência; não altera o time persistente da fixture.
	var gya: DadosPokemon=DadosPokemon.new();gya.especie=preload("res://especies_importadas.gd").obter_especies()["Gyarados"];gya.nivel=214;gya.qualidade=1.8
	gya.iv_hp=23;gya.iv_atk=32;gya.iv_def=23;gya.iv_sp_atk=24;gya.iv_sp_def=23;gya.iv_spd=29
	caca.pokemon_aliado=gya;gya.vida_atual=gya.obter_vida_maxima()
	var origem: Vector2i;var vizinhos: Array[Vector2i]=[]
	for celula in caca.celulas_acessiveis:
		var livres: Array[Vector2i]=[]
		for dir: Vector2i in caca.DIRECOES:
			if caca.passagem_permitida(celula,celula+dir) and caca.celula_para_posicao(celula).distance_to(caca.celula_para_posicao(celula+dir))<=caca.alcance_combate:livres.append(celula+dir)
		if livres.size()>=2:origem=celula;vizinhos=livres;break
	check(vizinhos.size()>=2,"área com dois vizinhos válidos")
	if vizinhos.size()<2:quit(1);return
	for r in caca.selvagens:r.resolver(100)
	caca.imagem_aliado.global_position=caca.celula_para_posicao(origem)
	for i in range(2):
		caca._criar_individuo(i,vizinhos[i]);caca.selvagens[i].movendo=false
	var a: EncontroSelvagem=caca.selvagens[0];var b: EncontroSelvagem=caca.selvagens[1]
	var eventos: Array[Dictionary]=[];caca.golpe_executado.connect(func(e: Dictionary) -> void:eventos.append(e))
	caca.registro_combate.comecar()
	caca.imagem_aliado.global_position=caca.celula_para_posicao(origem)+Vector2(5000,5000)
	caca._executar_ataque_selvagem(a)
	check(not a.primeiro_ataque_preparado,"fora de alcance não inicia preparo")
	caca.imagem_aliado.global_position=caca.celula_para_posicao(origem)
	caca._executar_ataque_selvagem(a)
	check(eventos.is_empty() and a.primeiro_ataque_preparado and a.prazo_primeiro_ataque==2.0,"primeiro contato prepara sem causar dano")
	a.agenda_golpes.avancar_calibrado(1.0);b.agenda_golpes.avancar_calibrado(1.0)
	caca._executar_ataque_selvagem(b)
	check(b.prazo_primeiro_ataque==3.0,"segundo inimigo inicia seu próprio prazo")
	# Troca de alvo do aliado não reinicia a preparação nem autoriza os ataques.
	caca.encontro_atual=b
	caca._executar_ataque_selvagem(a)
	check(a.prazo_primeiro_ataque==2.0 and eventos.is_empty(),"chamadas repetidas e troca de alvo não adiam o prazo")
	a.agenda_golpes.avancar_calibrado(0.8);b.agenda_golpes.avancar_calibrado(0.8)
	caca._processar_ataques_selvagens();check(eventos.is_empty(),"não ataca antes dos2s")
	a.agenda_golpes.avancar_calibrado(0.2);b.agenda_golpes.avancar_calibrado(0.2)
	caca._processar_ataques_selvagens()
	check(eventos.size()==1 and eventos[0]["encontro_id"]==a.id,"primeiro ataca sem ser o alvo do aliado")
	caca._processar_ataques_selvagens();check(eventos.size()==1,"sem duplicação no mesmo instante")
	a.agenda_golpes.avancar_calibrado(1.0);b.agenda_golpes.avancar_calibrado(1.0)
	caca._processar_ataques_selvagens()
	check(eventos.size()==2 and eventos[1]["encontro_id"]==b.id,"segundo ataca independentemente aos3s")
	# Após o primeiro golpe, usa a reserva normal de sua própria agenda.
	a.agenda_golpes.avancar_calibrado(1.0);b.agenda_golpes.avancar_calibrado(1.0)
	caca._processar_ataques_selvagens();check(eventos.size()==3 and eventos.back()["encontro_id"]==a.id,"cadência seguinte permanece2s")
	check(eventos[0]["inicio_preparo_primeiro_ataque"]==0.0 and eventos[0]["prazo_primeiro_ataque"]==2.0,"evento preserva início e prazo")
	var arquivo: String=caca.registro_combate.encerrar();var texto: String=FileAccess.get_file_as_string(arquivo)
	check(texto.contains('"inicio_preparo_primeiro_ataque"'),"log contém evidência do preparo")
	var id_perfil: String=a.perfil_combate_id
	caca._criar_individuo(0,vizinhos[0]);a=caca.selvagens[0];a.movendo=false
	check(a.perfil_combate_id==id_perfil and not a.primeiro_ataque_preparado and a.prazo_primeiro_ataque==-1.0,"respawn mantém perfil e reinicia preparo")
	caca._criar_individuo(1,vizinhos[1]);b=caca.selvagens[1];b.movendo=false
	# Dois que entram juntos podem golpear no mesmo tick: não há fila global.
	caca._processar_ataques_selvagens();var antes: int=eventos.size()
	a.agenda_golpes.avancar_calibrado(2.0);b.agenda_golpes.avancar_calibrado(2.0)
	caca._processar_ataques_selvagens();check(eventos.size()==antes+2,"ataques simultâneos continuam possíveis")
	# Tempo fora de alcance não rearma a preparação.
	caca._criar_individuo(0,vizinhos[0]);a=caca.selvagens[0];a.movendo=false;b.resolver(100)
	caca._executar_ataque_selvagem(a);var prazo: float=a.prazo_primeiro_ataque
	caca.imagem_aliado.global_position=caca.celula_para_posicao(origem)+Vector2(5000,5000)
	a.agenda_golpes.avancar_calibrado(2.2);antes=eventos.size();caca._executar_ataque_selvagem(a)
	check(eventos.size()==antes and a.prazo_primeiro_ataque==prazo,"fora de alcance não golpeia nem reinicia prazo")
	caca.imagem_aliado.global_position=caca.celula_para_posicao(origem)
	caca._executar_ataque_selvagem(a);check(eventos.size()==antes+1,"reentrada usa prazo já transcorrido")
	# Override individual mantém precisão e não herda o intervalo de outro inimigo.
	caca._criar_individuo(0,vizinhos[0]);a=caca.selvagens[0];a.movendo=false;a.intervalo_ataque=0.35
	caca._executar_ataque_selvagem(a);check(is_equal_approx(a.prazo_primeiro_ataque,0.35),"intervalo individual determina preparação")
	a.agenda_golpes.avancar(0.34);antes=eventos.size();caca._executar_ataque_selvagem(a);check(eventos.size()==antes,"override não antecipa golpe")
	a.agenda_golpes.avancar(0.01);caca._executar_ataque_selvagem(a);check(eventos.size()==antes+1,"override libera aos350ms")
	# Agenda envelhecida enquanto o selvagem andava não torna o primeiro golpe imediato.
	caca._criar_individuo(0,vizinhos[0]);a=caca.selvagens[0];a.movendo=false
	a.agenda_golpes.avancar_calibrado(10.0);antes=eventos.size();caca._executar_ataque_selvagem(a)
	check(eventos.size()==antes and a.prazo_primeiro_ataque==12.0,"tempo fora do combate não elimina preparo inicial")
	a.agenda_golpes.avancar_calibrado(2.0);caca._executar_ataque_selvagem(a)
	check(eventos.size()==antes+1,"primeiro golpe usa prazo relativo ao contato, não ao nascimento")
	caca.preparar_primeiro_ataque_selvagem=false
	caca._criar_individuo(0,vizinhos[0]);a=caca.selvagens[0];a.movendo=false;antes=eventos.size()
	caca._executar_ataque_selvagem(a);check(eventos.size()==antes+1 and not a.primeiro_ataque_preparado,"rollback em novo nascimento restaura primeiro uso imediato")
	caca.queue_free();await process_frame
	print("PREPARO ATAQUE: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
