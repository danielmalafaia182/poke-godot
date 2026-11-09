extends SceneTree
var falhas: int=0
var checks: int=0
var eventos: Array[Dictionary]=[]
var caca: Node2D
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, mensagem: String) -> void:
	checks+=1
	if not ok:
		falhas+=1
		push_error(mensagem)
func quantidade(id: String) -> int:
	var n: int=0
	for e in eventos:
		if not e["aliado"] and e["encontro_id"]==id: n+=1
	return n
func avancar(delta: float) -> void: caca._physics_process(delta)
func colocar(registro: EncontroSelvagem, celula: Vector2i) -> void:
	registro.celula=celula
	registro.origem_movimento=celula
	registro.destino_movimento=celula
	registro.movendo=false
	registro.imagem.global_position=caca.celula_para_posicao(celula)
func executar() -> void:
	root.size=Vector2i(1152,648)
	var estado: Node=root.get_node("EstadoJogo")
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	estado.auto_catch=false
	estado.auto_potion=false
	var lider: DadosPokemon=estado.obter_lider()
	lider.experiencia_total=preload("res://regras_pokemon.gd").xp_total_para_nivel(100)
	lider.normalizar_atributos()
	estado.curar_time()
	caca=load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	caca.movimento_selvagens_habilitado=false
	caca.reagir_ao_cerco=false # Isola relógios inimigos durante a pausa artificial do aliado.
	caca.timer_combate.stop()
	caca.timer_auto_potion.stop()
	caca.aproximando=false
	caca.batalha_encerrada=true # Simula a pausa do aliado entre alvos; inimigos não devem parar.
	await process_frame
	var centro: Vector2i
	var vizinhos: Array[Vector2i]=[]
	for celula: Vector2i in caca.celulas_acessiveis:
		var livres: Array[Vector2i]=[]
		for direcao in caca.DIRECOES:
			if caca.passagem_permitida(celula,celula+direcao): livres.append(celula+direcao)
		if livres.size()>=4:
			centro=celula
			vizinhos=livres
			break
	checar(vizinhos.size()>=4,"fixture possui espaço real para vários inimigos")
	if vizinhos.size()<4: quit(1); return
	caca.imagem_aliado.global_position=caca.celula_para_posicao(centro)
	for i in range(3,caca.selvagens.size()):
		caca.selvagens[i].resolver(100)
		caca.selvagens[i].imagem.hide()
	var a: EncontroSelvagem=caca.selvagens[0]
	var b: EncontroSelvagem=caca.selvagens[1]
	var c: EncontroSelvagem=caca.selvagens[2]
	colocar(a,vizinhos[0]); colocar(b,vizinhos[1]); colocar(c,vizinhos[2])
	a.intervalo_ataque=1.0
	b.intervalo_ataque=2.0
	c.intervalo_ataque=0.5
	caca.encontro_atual=a
	caca.golpe_executado.connect(func(e: Dictionary) -> void:
		eventos.append(e)
		print("ATAQUE slot=%d; encontro=%s; tempo=%.3f; dano=%d; hp_removido=%d" % [e["slot"],e["encontro_id"],e["tempo_atacante"],e["dano"],e["vida_removida"]])
	)
	var hp: int=caca.vida_aliado
	avancar(0)
	checar(eventos.size()==3,"três inimigos atacam no mesmo frame sem ataque do aliado")
	var soma: int=0
	for e in eventos:
		soma+=int(e["vida_removida"])
		var registro: EncontroSelvagem=caca.selvagens[int(e["slot"])]
		checar(not e["aliado"] and e["encontro_id"]==registro.id and e["origem"]==registro.imagem.global_position,"evento identifica o atacante real")
	checar(caca.vida_aliado==hp-soma and lider.obter_vida_atual()==caca.vida_aliado,"todos os danos descontados no indivíduo persistente")
	checar(caca.encontro_atual==a,"atacar não troca o alvo do aliado")
	caca._processar_ataques_selvagens(); caca._processar_ataques_selvagens()
	checar(eventos.size()==3,"consultas repetidas no mesmo instante não duplicam ataques")
	avancar(0.49)
	checar(eventos.size()==3,"nenhum inimigo ataca cedo")
	avancar(0.01)
	checar(quantidade(c.id)==2 and quantidade(a.id)==1 and quantidade(b.id)==1,"ritmo individual de 0,5s")
	avancar(0.5)
	checar(quantidade(c.id)==3 and quantidade(a.id)==2 and quantidade(b.id)==1,"ritmo individual de 1s")
	avancar(1.0)
	checar(quantidade(a.id)==3 and quantidade(b.id)==2 and quantidade(c.id)==4,"ritmo de 2s e sem rajada acumulada no frame longo")
	var prazo: float=b.agenda_golpes.proximo_ataque_rapido
	caca.encontro_atual=b
	avancar(0)
	checar(b.agenda_golpes.proximo_ataque_rapido==prazo and eventos.size()==9,"troca de alvo não reinicia nem antecipa agenda")
	caca.encontro_atual=null
	var antes: int=eventos.size()
	avancar(0.5)
	checar(eventos.size()==antes+1 and eventos.back()["encontro_id"]==c.id,"inimigo ataca sem alvo atual")
	var total_a: int=quantidade(a.id)
	caca.celulas_bloqueadas[a.celula]=true
	avancar(0.5)
	checar(quantidade(a.id)==total_a,"não ataca através de bloqueio")
	caca.celulas_bloqueadas.erase(a.celula)
	avancar(0)
	checar(quantidade(a.id)==total_a+1,"retoma quando há passagem, sem fila de golpes")
	colocar(a,centro+Vector2i(8,0))
	total_a=quantidade(a.id)
	avancar(1.0)
	checar(quantidade(a.id)==total_a,"não ataca fora de alcance")
	colocar(a,vizinhos[0])
	caca.movimento_selvagens.duracao_passo=10.0
	a.movendo=true
	avancar(1.0)
	checar(quantidade(a.id)==total_a,"aguarda finalizar o próprio passo")
	a.movendo=false
	caca.movimento_selvagens.duracao_passo=1.0
	avancar(0)
	checar(quantidade(a.id)==total_a+1,"não depende de ser selecionado para retomar")
	var slot: int=a.slot
	var id_antigo: String=a.id
	caca._criar_individuo(slot,caca.PONTOS_RESPAWN[slot])
	var novo: EncontroSelvagem=caca.selvagens[slot]
	colocar(novo,vizinhos[0])
	avancar(0)
	checar(novo.id!=id_antigo and quantidade(novo.id)==1 and quantidade(id_antigo)==total_a+1,"respawn tem identidade e agenda novas")
	# Modo de cooldowns também limita o ator: um polling por frame não pode disparar todos os golpes de uma vez.
	var agenda: RefCounted=preload("res://agenda_golpes.gd").new()
	agenda.configurar("Geodude",50)
	checar(not agenda.retirar_pronto(true,1.5).is_empty() and agenda.retirar_pronto(true,1.5).is_empty(),"cooldowns do catálogo respeitam a cadência do indivíduo")
	agenda.avancar(1.5)
	checar(not agenda.retirar_pronto(true,1.5).is_empty(),"outro golpe pronto pode ser usado após a cadência")
	var xp: int=lider.experiencia_total
	var box: int=estado.pokemons_capturados.size()
	caca.vida_aliado=1
	for registro in caca.selvagens:
		registro.agenda_golpes.proximo_ataque_rapido=0
	antes=eventos.size()
	avancar(0)
	checar(caca.vida_aliado==0 and eventos.size()==antes+1,"golpe fatal encerra o lote e não aplica ataques após o KO")
	avancar(1); caca._processar_ataques_selvagens()
	checar(eventos.size()==antes+1 and lider.experiencia_total==xp and estado.pokemons_capturados.size()==box,"KO não duplica ataques, XP ou captura")
	caca.queue_free()
	await process_frame
	print("ATAQUES INDEPENDENTES: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
