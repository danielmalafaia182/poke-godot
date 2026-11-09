extends SceneTree
const A=preload("res://auditoria_ofensiva_selvagens.gd")
const CAT=preload("res://catalogo_hunts.gd")
var checks: int=0
var falhas: int=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok:falhas+=1;push_error(msg)
func _initialize() -> void:call_deferred("executar")
func executar() -> void:
	var amostra: Dictionary=A.carregar()
	var r: Dictionary=A.analisar(80,amostra)
	check(r["eventos"]==44 and r["excluidos_transicao"]==3,"44 eventos válidos,3 de transição excluídos")
	check(r["fora_limites"]==16,"16 eventos refutam limites do gerador80")
	for g in r["grupos"]:
		if g["aliado"]=="Gyarados":
			check(g["limites_dano"][1]==41 and g["fora_limites"].size()==11 and g["observados"].size()==34,"Skull Bash: teto41 e11/34 acima")
		else:
			check(g["limites_dano"][1]==29 and g["fora_limites"].size()==5 and g["observados"].size()==10,"Bite: teto29 e5/10 acima")
	var busca: Dictionary=A.varrer(amostra)
	check(not busca["niveis_nao_refutados_pelos_envelopes"].is_empty(),"existem níveis não refutados pelos envelopes")
	print("BUSCA OFENSIVA: ",JSON.stringify(busca))
	check(not busca["nivel_original_identificado"],"busca não declara nível original")
	check(busca["niveis_nao_refutados_pelos_envelopes"].front()==94 and busca["niveis_nao_refutados_pelos_envelopes"].back()==130,"limites de dano condicionais94–130")
	check(busca["niveis_nao_refutados_dano_e_hp_minimo"]==[94,95,96,97,98,99],"interseção com HP mínimo: condição necessária94–99")
	# Duplicatas simultâneas continuam sendo evidência; não deduplicar.
	var duplicada: Dictionary=amostra.duplicate(true)
	var exemplo: Dictionary={}
	for h in duplicada["recebidos"]:
		if not h["pacote_de_transicao"]:exemplo=h;break
	duplicada["recebidos"].append(exemplo.duplicate())
	check(A.analisar(80,duplicada)["eventos"]==45,"golpe repetido não é descartado")
	check(A.analisar(0,amostra).has("erro"),"nível inválido rejeitado")
	var base: Dictionary=CAT.obter("Blastoise")
	check(base["nivel"]==80 and base["nivel_combate"]==80,"fallback preserva configuração instalada")
	check(base["regra_nivel_combate"]=="proxy_nivel_acesso_nao_confirmado","fallback explicitamente provisório")
	for valor in [0,-1,2.5,INF,NAN,"94",100001]:
		var invalida: Dictionary=base.duplicate();invalida["nivel_combate"]=valor
		check(not CAT.validar(invalida).is_empty(),"configuração inválida rejeitada: "+str(valor))
	var original: String=FileAccess.get_file_as_string("res://dados/caca/hunts.json")
	var configuracoes: Dictionary=JSON.parse_string(original)
	configuracoes["Blastoise"]["nivel_combate"]=94
	var f: FileAccess=FileAccess.open("res://dados/caca/hunts.json",FileAccess.WRITE);f.store_string(JSON.stringify(configuracoes));f.close();CAT.recarregar()
	check(CAT.obter("Blastoise")["nivel"]==80 and CAT.obter("Blastoise")["nivel_combate"]==94,"níveis de acesso e combate independentes")
	var estado: Node=root.get_node("EstadoJogo");estado.especie_caca=preload("res://especies_importadas.gd").obter_especies()["Blastoise"];estado.curar_time()
	var caca: Node2D=load("res://Caca.tscn").instantiate();root.add_child(caca)
	caca.set_process(false);caca.set_physics_process(false);caca.timer_combate.stop();caca.timer_auto_potion.stop()
	for encontro in caca.selvagens:
		check(encontro.pokemon.nivel==94,"geração usa nível de combate configurado")
		check(encontro.perfil_hp["nivel_acesso_hunt"]==80 and encontro.perfil_hp["nivel_combate_local"]==94,"diagnóstico distingue níveis")
	f=FileAccess.open("res://dados/caca/hunts.json",FileAccess.WRITE);f.store_string(original);f.close();CAT.recarregar()
	caca.queue_free();await process_frame
	var lider: DadosPokemon=estado.obter_lider()
	var ui: Control=load("res://laboratorio_ofensiva_selvagens.tscn").instantiate();root.add_child(ui)
	check(ui.resultado["fora_limites"]==16,"painel abre resultado pronto")
	ui.nivel.value=94
	check(ui.resultado["nivel_combate_local_testado"]==94,"controle atualiza análise")
	ui.exportar_resultado()
	check(ui.status.text.begins_with("Exportado:"),"exporta relatório")
	check(estado.obter_lider()==lider and CAT.obter("Blastoise")["nivel_combate"]==80,"painel não altera líder nem configuração")
	ui.queue_free();await process_frame
	print("OFENSIVA SELVAGENS: %d verificações; %d falhas" % [checks,falhas]);quit(1 if falhas else 0)
