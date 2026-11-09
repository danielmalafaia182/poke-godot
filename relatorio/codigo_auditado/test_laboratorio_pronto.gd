extends SceneTree
var LAB: Script
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
	LAB=load("res://laboratorio_validacao.gd")
	var estado: Node=root.get_node("EstadoJogo")
	check(not LAB.caminho_seguro("C:/Users/Teste/PokeIdle"),"perfil real recusado")
	check(not LAB.caminho_seguro("/tmp/PokeIdle_Lab_Combate_20261108_copia"),"sufixo não contorna isolamento")
	check(LAB.caminho_seguro("C:/Users/Teste/"+LAB.PERFIL),"perfil dedicado aceito")
	check(LAB.caminho_seguro(OS.get_user_data_dir()),"runner usa perfil isolado aceito")
	var cena: Node
	for caso in ["referencia3780","referencia3815","cerco"]:
		LAB.caso_atual=caso
		cena=load("res://laboratorio_validacao.tscn").instantiate();root.add_child(cena)
		check(cena.iniciado,"inicialização pronta sem pré-requisito do jogador")
		if not cena.iniciado:quit(1);return
		var caca: Node=cena.caca
		caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
		var time: Array=estado.time_pokemon
		check(time.size()==3 and time[0].especie.nome=="Gyarados" and time[0].nivel==214 and time[1].especie.nome=="Exeggutor" and time[1].nivel==406,"time pronto nas três cenas")
		check(time[0].obter_atributos()["atk"]==647 and time[0].obter_atributos()["def"]==428 and time[0].obter_vida_maxima()==6324,"Gyarados reproduz referência")
		check(time[1].obter_atributos()=={"hp":1057,"atk":994,"def":812,"spAtk":1202,"spDef":812,"speed":419},"Exeggutor reproduz referência")
		check(caca.registro_combate.ativo,"registro começa automaticamente")
		check(caca._candidata_ativa() and caca.preparar_primeiro_ataque_selvagem and caca.preservar_perfis_de_combate_na_hunt,"usa todas as candidatas atuais")
		check(caca.selvagens.size()==(15 if caso=="cerco" else 1),"quantidade correta no cenário")
		if caca.selvagens.is_empty():quit(1);return
		if caso!="cerco":
			var e: EncontroSelvagem=caca.selvagens[0]
			var hp: int=3780 if caso=="referencia3780" else 3815
			check(e.vida_maxima==hp and e.vida==hp,"HP de referência configurado")
			check(caca._selvagem_em_alcance(e),"duelo começa em contato válido")
			var eventos: Array[Dictionary]=[];caca.golpe_executado.connect(func(x: Dictionary) -> void:eventos.append(x))
			caca._executar_ataque_selvagem(e)
			check(eventos.is_empty() and e.primeiro_ataque_preparado,"preparo real atua no cenário visual")
			e.agenda_golpes.avancar_calibrado(2.0);caca._executar_ataque_selvagem(e)
			check(eventos.size()==1 and eventos[0]["nome"]=="Skull Bash","cena realmente executa ataque")
			if eventos.size()!=1:quit(1);return
			var dano: int=eventos[0]["dano"]
			check(dano>=(47 if caso=="referencia3780" else 25) and dano<=(55 if caso=="referencia3780" else 30),"dano dentro da faixa esperada")
			var id: String=e.perfil_combate_id
			caca._criar_individuo(0,e.celula)
			check(caca.selvagens[0].vida_maxima==hp and caca.selvagens[0].perfil_combate_id==id,"respawn de referência estável")
		check(estado.salvar_agora(),"dados da fixture são válidos no perfil separado")
		cena.exportar_registro()
		var texto: String=FileAccess.get_file_as_string(LAB.ultimo_exportado)
		check(texto.contains('"laboratorio"') and texto.contains('"perfil_dados_separado"'),"exportação identifica fixture")
		cena.queue_free();await process_frame
	print("LABORATORIO PRONTO: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
