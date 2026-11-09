extends SceneTree
var checks: int=0
var falhas: int=0
var caca: Node
var lab: Node
var eventos: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("executar")
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func colocar(e: EncontroSelvagem,celula: Vector2i) -> void:
	e.celula=celula;e.origem_movimento=celula;e.destino_movimento=celula;e.movendo=false;e.tempo_decisao=0
	e.imagem.global_position=caca.celula_para_posicao(celula)
func executar() -> void:
	load("res://laboratorio_validacao.gd").caso_atual="cerco"
	lab=load("res://laboratorio_validacao.tscn").instantiate();root.add_child(lab);caca=lab.caca
	caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
	caca.reagir_ao_cerco=false;caca.aproximando=false;caca.batalha_encerrada=true
	var ai: RefCounted=caca.movimento_selvagens
	check(ai.perfil_observado_ativo(),"perfil candidato aplicado a Blastoise")
	check(ai.descrever_perfil()["raio"]==12 and ai.descrever_perfil()["metrica"]=="chebyshev","raio em grade de 12 células")
	for i in range(1,caca.selvagens.size()):caca.selvagens[i].resolver(999);caca.selvagens[i].imagem.hide()
	var centro: Vector2i=caca.CELULA_INICIAL
	var distante: Vector2i
	var fora: Vector2i
	var encontrou: bool=false
	var encontrou_fora: bool=false
	for celula: Vector2i in caca.celulas_acessiveis:
		var d: Vector2i=celula-centro
		if maxi(absi(d.x),absi(d.y))==12 and not caca.calcular_caminho(celula,centro).is_empty():distante=celula;encontrou=true
		if maxi(absi(d.x),absi(d.y))==13:fora=celula;encontrou_fora=true
	check(encontrou and encontrou_fora,"fixture real tem posições nos limites 12 e 13")
	if not encontrou or not encontrou_fora:quit(1);return
	var e: EncontroSelvagem=caca.selvagens[0]
	colocar(e,distante)
	var proxima: Vector2i=ai._escolher_destino(0)
	check(proxima!=distante and ai.passo_livre(0,distante,proxima),"não selecionado começa a aproximar a 12 células")
	colocar(e,fora);caca.chance_pausa_selvagens=0
	for _i in range(10):check(ai._escolher_destino(0)==fora,"não passeia fora do raio candidato")
	ai.usar_perfil_blastoise_observado=false
	check(not ai.perfil_observado_ativo() and ai.descrever_perfil()["raio"]==8,"regra anterior pode ser restaurada")
	ai.usar_perfil_blastoise_observado=true
	var dados_especie: Resource=e.pokemon.especie
	e.pokemon=e.pokemon.duplicate(false);e.pokemon.especie=load("res://dados/especies/geodude.tres")
	check(not ai.perfil_observado_ativo(),"Geodude mantém política anterior")
	e.pokemon.especie=dados_especie
	# Três selvagens precisam aproximar por rotas livres, sem teleporte e sem o aliado atacar.
	var vizinhos: Array[Vector2i]=[]
	for celula: Vector2i in caca.celulas_acessiveis:
		var contagem: int=0
		for d: Vector2i in caca.DIRECOES:
			if caca.passagem_permitida(celula,celula+d):contagem+=1
		if contagem>=6:centro=celula;break
	caca.imagem_aliado.global_position=caca.celula_para_posicao(centro)
	var inicios: Array[Vector2i]=[]
	for celula: Vector2i in caca.celulas_acessiveis:
		var d: Vector2i=celula-centro
		if maxi(absi(d.x),absi(d.y))<3 or maxi(absi(d.x),absi(d.y))>4:continue
		var caminho: Array[Vector2i]=caca.calcular_caminho(celula,centro)
		if caminho.size()>1 and caminho.size()<8:inicios.append(celula)
		if inicios.size()==3:break
	check(inicios.size()==3,"três origens fora de alcance e próximas da área livre")
	if inicios.size()!=3:quit(1);return
	for i in range(3):caca._criar_individuo(i,inicios[i]);colocar(caca.selvagens[i],inicios[i])
	caca.encontro_atual=caca.selvagens[0]
	caca.golpe_executado.connect(func(x: Dictionary) -> void:
		var copia: Dictionary=x.duplicate(true)
		copia["alvo_no_golpe"]=caca.encontro_atual.id if caca.encontro_atual!=null else ""
		eventos.append(copia))
	var sem_sobreposicao: bool=true
	for _frame in range(1200):
		caca._physics_process(1.0/60.0)
		for a in range(3):
			if caca.selvagens[a].imagem.global_position.distance_to(caca.imagem_aliado.global_position)<0.01:sem_sobreposicao=false
			for b in range(a+1,3):
				if caca.selvagens[a].imagem.global_position.distance_to(caca.selvagens[b].imagem.global_position)<0.01:sem_sobreposicao=false
	var atacantes: Dictionary={};var nao_alvos: int=0
	for x in eventos:
		if not x["aliado"]:
			atacantes[x["slot"]]=true
			if x["encontro_id"]!=x["alvo_no_golpe"]:nao_alvos+=1
	check(atacantes.size()==3 and nao_alvos>0,"três aproximam e atacam; não selecionados também causam dano")
	check(sem_sobreposicao,"rotas e posições não sobrepõem os corpos")
	for i in range(3):check(caca._selvagem_em_alcance(caca.selvagens[i]),"selvagem mantém posição de ataque")
	lab.exportar_registro()
	check(FileAccess.get_file_as_string(lab.ultimo_exportado).contains('blastoise_aproximacao_candidata_v1'),"registro identifica política de aproximação")
	print("APROXIMACAO RESULTADO: "+JSON.stringify({"checks":checks,"falhas":falhas,"slots_atacantes":atacantes.keys(),"ataques_nao_alvo":nao_alvos,"sobreposicao":not sem_sobreposicao,"simulacao_segundos":20}))
	lab.queue_free();await process_frame
	print("APROXIMACAO BLASTOISE: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
