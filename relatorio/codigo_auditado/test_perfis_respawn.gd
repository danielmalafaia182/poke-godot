extends SceneTree
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func parar(caca: Node) -> void:
	caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
func executar() -> void:
	var estado: Node=root.get_node("EstadoJogo")
	estado.especie_caca=preload("res://especies_importadas.gd").obter_especies()["Blastoise"];estado.auto_catch=false;estado.curar_time()
	var caca: Node=load("res://Caca.tscn").instantiate();root.add_child(caca);parar(caca)
	var primeiro: EncontroSelvagem=caca.selvagens[0]
	var perfil_id: String=primeiro.perfil_combate_id
	var id_vida: String=primeiro.id
	var hp: int=primeiro.vida_maxima
	var attrs: Dictionary=primeiro.obter_pokemon_combate().obter_atributos()
	var q: float=primeiro.obter_pokemon_combate().qualidade
	check(primeiro.perfil_combate_persistente and not perfil_id.is_empty(),"perfil persistente de Blastoise ativo")
	check(primeiro.pokemon!=primeiro.obter_pokemon_combate(),"capturável e combate são Resources distintos")
	check(primeiro.pokemon.obter_atributos()==attrs,"primeiro perfil mantém os valores inicialmente sorteados")
	check(caca.perfis_combate_slots.size()==15,"um template por slot")
	var captura: DadosPokemon=primeiro.pokemon
	# Mudar o capturável não pode afetar o combate, incluindo futuros nascimentos.
	captura.nivel=3;captura.qualidade=0.8;captura.iv_hp=1;captura.iv_atk=1
	check(primeiro.obter_pokemon_combate().obter_atributos()==attrs,"capturável não reescreve combate atual")
	check(estado.registrar_captura(captura),"captura preserva fluxo de persistência existente")
	var ids: Dictionary={id_vida:true};var referencias: Array[DadosPokemon]=[captura]
	for i in range(9):
		var anterior: EncontroSelvagem=caca.selvagens[0]
		anterior.vida=0;check(anterior.reservar_recompensa(),"recompensa reservada uma vez nesta vida")
		check(not anterior.reservar_recompensa(),"não duplica recompensa")
		anterior.resolver(10)
		caca._criar_individuo(0,anterior.celula)
		var novo: EncontroSelvagem=caca.selvagens[0]
		check(novo.perfil_combate_id==perfil_id,"respawn conserva perfil do slot")
		check(not ids.has(novo.id),"respawn recebe identidade de encontro nova")
		ids[novo.id]=true
		check(novo.vida==hp and novo.vida_maxima==hp,"respawn recupera máximo estável")
		check(novo.obter_pokemon_combate().obter_atributos()==attrs and novo.obter_pokemon_combate().qualidade==q,"respawn conserva atributos/qualidade de combate")
		check(not novo.recompensado and not novo.captura_iniciada and novo.agenda_golpes.tempo==0,"estado e agenda reiniciados por vida")
		check(not referencias.has(novo.pokemon),"cada capturável é uma instância independente")
		referencias.append(novo.pokemon)
		check(novo.obter_pokemon_combate()!=anterior.obter_pokemon_combate(),"combate também recebe cópia independente por nascimento")
		check(novo.perfil_hp["perfil_combate_id"]==perfil_id and novo.perfil_hp["hp_maximo_aplicado"]==hp,"procedência acompanha o perfil estável")
	check(captura.nivel==3 and estado.pokemons_capturados.has(captura),"respawns não alteram Pokémon já capturado")
	var alvo: EncontroSelvagem=caca.selvagens[0]
	caca.encontro_atual=alvo
	var golpe: Dictionary={"name":"Tackle","power":50,"type":"NORMAL","category":"PHYSICAL","cooldownMs":15000}
	var esperado: float=caca._prever_dano_selvagem(golpe,alvo)
	alvo.pokemon.qualidade=1.8;alvo.pokemon.nivel=300
	check(caca._prever_dano_selvagem(golpe,alvo)==esperado,"previsão ofensiva usa o perfil de combate")
	var defesa: float=caca._prever_dano_aliado(golpe)
	alvo.pokemon.iv_def=32
	check(caca._prever_dano_aliado(golpe)==defesa,"previsão contra selvagem usa a defesa de combate")
	caca.registro_combate.comecar();var arquivo: String=caca.registro_combate.encerrar()
	var log: String=FileAccess.get_file_as_string(arquivo)
	check(log.contains('"pokemon_capturavel"') and log.contains('"perfil_combate_id"'),"log distingue perfis capturável/combate")
	caca.preservar_perfis_de_combate_na_hunt=false
	caca._criar_individuo(0,alvo.celula)
	var antigo: EncontroSelvagem=caca.selvagens[0]
	check(not antigo.perfil_combate_persistente and antigo.obter_pokemon_combate()==antigo.pokemon,"rollback restaura perfil único por nascimento")
	var caca2: Node=load("res://Caca.tscn").instantiate();root.add_child(caca2);parar(caca2)
	check(caca2.selvagens[0].perfil_combate_id!=perfil_id,"nova instância da hunt recebe novo perfil")
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	var caca3: Node=load("res://Caca.tscn").instantiate();root.add_child(caca3);parar(caca3)
	check(not caca3.selvagens[0].perfil_combate_persistente,"outras espécies mantêm comportamento anterior")
	var fixture: EncontroSelvagem=caca2.selvagens[0]
	var novo_p: DadosPokemon=DadosPokemon.new();fixture.pokemon=novo_p
	check(fixture.obter_pokemon_combate()==novo_p and fixture.perfil_combate_id.is_empty(),"substituição explícita não deixa procedência falsa")
	caca.queue_free();caca2.queue_free();caca3.queue_free();await process_frame
	print("PERFIS RESPAWN: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
