extends SceneTree
var falhas: int = 0
var checks: int = 0
var eventos: Array[Dictionary] = []
const AGENDA: Script = preload("res://agenda_golpes.gd")
func checar(condicao: bool, descricao: String) -> void:
	checks += 1
	if not condicao:
		falhas += 1
		push_error(descricao)
func _initialize() -> void:
	call_deferred("testar")
func testar() -> void:
	var a: RefCounted = AGENDA.new()
	a.configurar("Larvitar",1)
	checar(a.golpes.size()==1,"nível1 libera Bite")
	checar(a.retirar_pronto()["name"]=="Bite","primeiro uso")
	checar(a.retirar_pronto().is_empty(),"cooldown impede repetição")
	a.avancar(19.999)
	checar(a.retirar_pronto().is_empty(),"não antecipa20s")
	a.avancar(0.001)
	checar(a.retirar_pronto()["name"]=="Bite","Bite libera em20s")
	var tempo: float = a.tempo
	a.avancar(NAN)
	a.avancar(-1)
	checar(a.tempo==tempo,"relógio rejeita delta inválido")
	var g: RefCounted = AGENDA.new()
	g.configurar("Geodude",9)
	checar(g.golpes.size()==1,"Rollout bloqueado antes10")
	g.retirar_pronto()
	g.configurar("Geodude",10)
	checar(g.retirar_pronto()["name"]=="Rollout","novo golpe sem reiniciar Tackle")
	checar(g.retirar_pronto().is_empty(),"cooldowns independentes reservados")
	var estado: Node = root.get_node("EstadoJogo")
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.selecionar_lider(estado.pokemon_inicial)
	estado.curar_time()
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	caca.usar_golpes_catalogados = true
	# Alteração: este teste continua validando os cooldowns originais do catálogo.
	caca.aplicar_cooldowns_catalogo = true
	caca.usar_atributos_combate=false
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	caca.timer_auto_potion.stop()
	caca.movimento_selvagens_habilitado = false
	await process_frame
	var encontro: EncontroSelvagem = caca.encontro_atual
	var vizinha: Vector2i = encontro.celula
	for direcao in caca.DIRECOES:
		if caca.passagem_permitida(encontro.celula,encontro.celula+direcao):
			vizinha = encontro.celula+direcao
			break
	caca.imagem_aliado.global_position = caca.celula_para_posicao(vizinha)
	caca.aproximando = false
	caca.batalha_encerrada = false
	caca.golpe_executado.connect(func(evento: Dictionary) -> void: eventos.append(evento))
	var hp_inimigo: int = caca.vida_selvagem
	var hp_aliado: int = caca.vida_aliado
	caca._on_timer_combate_timeout()
	caca.timer_combate.start()
	checar(eventos.size()==2,"Bite e Tackle no início")
	checar(eventos[0]["nome"]=="Bite" and eventos[1]["nome"]=="Tackle","nomes reais")
	checar(eventos[0]["tipo"]=="DARK" and eventos[1]["tipo"]=="NORMAL","tipos reais")
	checar(caca.vida_selvagem==hp_inimigo-caca.pokemon_aliado.especie.dano_base,"Power não vira dano")
	checar(caca.vida_aliado==hp_aliado-encontro.pokemon.especie.dano_base,"retaliação provisória")
	caca._on_timer_combate_timeout()
	checar(eventos.size()==2,"verificação extra não repete golpes")
	caca._physics_process(15.0)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==3 and eventos[2]["nome"]=="Tackle","Tackle aos15s")
	caca._physics_process(5.0)
	caca._on_timer_combate_timeout()
	checar(eventos.size()==4 and eventos[3]["nome"]=="Bite","Bite aos20s")
	var id: String = encontro.id
	caca.encontro_atual = null
	caca._selecionar_alvo()
	checar(caca.encontro_atual.id==id and encontro.agenda_golpes.retirar_pronto().is_empty(),"reacquirir alvo preserva cooldown")
	var indice: int = encontro.slot
	caca._liberar_selvagem_derrotado(indice)
	caca._criar_individuo(indice,caca.PONTOS_RESPAWN[indice])
	var novo: EncontroSelvagem = caca.selvagens[indice]
	novo.agenda_golpes.configurar("Geodude",1)
	checar(novo.id!=id and novo.agenda_golpes.retirar_pronto()["name"]=="Tackle","respawn recebe agenda nova")
	checar(caca.get_node("Interface/HudCaca").painel_golpes!=null,"painel de cooldown criado")
	caca.queue_free()
	await process_frame
	print("GOLPES COMBATE: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
