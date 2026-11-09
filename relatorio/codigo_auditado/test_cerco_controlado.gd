extends SceneTree
var falhas: int=0
var checks: int=0
var lab: Node
var caca: Node
var eventos: Array[Dictionary]=[]
var frame_atual: int=0
var primeiros: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("executar")
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func montar(manual: bool=true) -> void:
	load("res://laboratorio_validacao.gd").caso_atual="cerco3"
	lab=load("res://laboratorio_validacao.tscn").instantiate();root.add_child(lab)
	caca=lab.caca
	if manual:
		caca.set_process(false);caca.set_physics_process(false)
		caca.timer_combate.stop();caca.timer_auto_potion.stop()
	eventos.clear();frame_atual=0
	caca.golpe_executado.connect(func(e: Dictionary) -> void:
		var copia: Dictionary=e.duplicate(true)
		copia["frame_teste"]=frame_atual
		copia["alvo_no_golpe"]=caca.encontro_atual.id if caca.encontro_atual!=null else ""
		eventos.append(copia))
func avancar(frames: int) -> void:
	for i in range(frames):
		frame_atual+=1
		caca._process(1.0/60.0)
		caca._physics_process(1.0/60.0)
func golpes(id: String="") -> Array[Dictionary]:
	var saida: Array[Dictionary]=[]
	for e in eventos:
		if not e["aliado"] and (id.is_empty() or e["encontro_id"]==id):saida.append(e)
	return saida
func executar() -> void:
	montar()
	check(lab.iniciado and caca.selvagens.size()==3,"cerco abre pronto com três adversários")
	if caca.selvagens.size()!=3:quit(1);return
	var posicoes: Dictionary={};var perfis: Dictionary={}
	for e: EncontroSelvagem in caca.selvagens:
		check(caca._selvagem_em_alcance(e),"todos nascem em alcance transitável")
		check(not e.movendo and e.vida_maxima==3780,"perfis controlados sem passeio")
		posicoes[e.celula]=true;perfis[e.perfil_combate_id]=true
	check(posicoes.size()==3 and perfis.size()==3,"três posições e identidades de perfil distintas")
	avancar(72)
	check(golpes().is_empty(),"nenhum ataque antes da preparação de 2s")
	var prazos: Array=[]
	for e: EncontroSelvagem in caca.selvagens:prazos.append(e.prazo_primeiro_ataque)
	var alvo: int=caca.indice_alvo
	caca.trocar_alvo_laboratorio()
	check(caca.indice_alvo!=alvo,"botão troca o alvo")
	for i in range(3):check(caca.selvagens[i].prazo_primeiro_ataque==prazos[i],"troca não reinicia preparo de nenhum inimigo")
	avancar(72)
	var recebidos: Array[Dictionary]=golpes()
	check(recebidos.size()==3,"três ataques após o preparo")
	if recebidos.size()!=3:quit(1);return
	check(recebidos[0]["frame_teste"]==recebidos[1]["frame_teste"] and recebidos[1]["frame_teste"]==recebidos[2]["frame_teste"],"três inimigos atacam no mesmo frame")
	var sem_ser_alvo: int=0
	for e in recebidos:
		if e["encontro_id"]!=e["alvo_no_golpe"]:sem_ser_alvo+=1
		primeiros.append({"slot":e["slot"],"frame":e["frame_teste"],"tempo_atacante":e["tempo_atacante"],"dano":e["dano"],"alvo":e["encontro_id"]==e["alvo_no_golpe"]})
	check(sem_ser_alvo==2,"os dois inimigos não selecionados também atacam")
	var hp: int=caca.vida_aliado
	caca._processar_ataques_selvagens();caca._processar_ataques_selvagens()
	check(golpes().size()==3 and caca.vida_aliado==hp,"consultas duplicadas não repetem dano")
	lab.exportar_registro()
	var exportado: String=FileAccess.get_file_as_string(lab.ultimo_exportado)
	check(exportado.contains('"cerco_controlado":true'),"JSONL identifica o cerco garantido")
	lab.queue_free();await process_frame
	# Ritmos diferentes usam a extensão de intervalo por indivíduo já existente.
	montar()
	caca.agenda_aliado.proximo_ataque_rapido=9999.0
	for i in range(3):caca.selvagens[i].intervalo_ataque=float(i+1)
	avancar(198)
	for i in range(3):check(golpes(caca.selvagens[i].id).size()==(3 if i==0 else 1),"ritmo próprio de %ds" % [i+1])
	var morto: EncontroSelvagem=caca.selvagens[0]
	var outro: EncontroSelvagem=caca.selvagens[1]
	var agenda_outro: RefCounted=outro.agenda_golpes
	var prazo_outro: float=agenda_outro.proximo_ataque_rapido
	var perfil_morto: String=morto.perfil_combate_id
	caca.encontro_atual=morto;morto.vida=0
	caca.encerrar_batalha(caca.pokemon_aliado.especie.nome)
	check(morto.estado==EncontroSelvagem.Estado.RESOLVIDO,"KO passa pela resolução real de combate")
	check(outro.agenda_golpes==agenda_outro and outro.agenda_golpes.proximo_ataque_rapido==prazo_outro,"KO não altera a agenda do sobrevivente")
	var n_morto: int=golpes(morto.id).size()
	avancar(maxi(1,ceili(caca.intervalo_respawn*60.0)-6))
	check(caca.selvagens[0]==morto and golpes(morto.id).size()==n_morto,"morto não ataca e aguarda o respawn")
	avancar(12)
	var novo: EncontroSelvagem=caca.selvagens[0]
	check(novo!=morto and novo.id!=morto.id,"respawn cria nova vida e identidade")
	check(novo.agenda_golpes!=morto.agenda_golpes and novo.perfil_combate_id==perfil_morto and novo.vida==3780,"nova agenda preserva somente o perfil e HP máximo")
	check(novo.primeiro_ataque_preparado and golpes(novo.id).is_empty(),"renascido prepara primeiro ataque e não ataca imediatamente")
	check(outro.agenda_golpes==agenda_outro and golpes(outro.id).size()>=2,"sobrevivente continua atacando durante o respawn")
	avancar(132)
	check(not golpes(novo.id).is_empty(),"renascido volta a atacar após a própria preparação")
	lab.queue_free();await process_frame
	# Integração: cena roda com seu processamento normal, sem chamadas manuais de ataque.
	montar(false)
	await create_timer(2.7).timeout
	var naturais: Array[Dictionary]=golpes()
	var slots: Dictionary={}
	for e in naturais:slots[e["slot"]]=true
	check(slots.size()==3,"loop normal da cena produz golpes dos três adversários")
	lab.exportar_registro()
	var relatorio: Dictionary={"schema":1,"checks":checks,"falhas":falhas,"primeira_rodada":primeiros,"loop_normal_atacantes":slots.keys(),"formula_original_comprovada":false}
	var f: FileAccess=FileAccess.open("user://cerco_controlado_resultado.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(relatorio,"\t"));f.close()
	print("CERCO RESULTADO: "+JSON.stringify(relatorio))
	lab.queue_free();await process_frame
	print("CERCO CONTROLADO: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
