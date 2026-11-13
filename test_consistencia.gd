extends SceneTree
var falhas: int = 0
var checks: int = 0
func checar(valor: bool, texto: String) -> void:
	checks += 1
	if not valor:
		falhas += 1
		push_error(texto)
func _initialize() -> void:
	call_deferred("testar")
func novo() -> DadosPokemon:
	var p: DadosPokemon = DadosPokemon.new()
	p.especie = load("res://dados/especies/geodude.tres")
	return p
func testar() -> void:
	var colecao: ColecaoPokemon = ColecaoPokemon.new()
	var invalidos: Array[DadosPokemon] = []
	var p: DadosPokemon = novo()
	p.qualidade = NAN
	invalidos.append(p)
	p = novo(); p.iv_atk = 33; invalidos.append(p)
	p = novo(); p.nivel = 0; invalidos.append(p)
	p = novo(); p.id_persistente = "ID-invalido"; invalidos.append(p)
	p = novo(); p.experiencia_total = -2; invalidos.append(p)
	p = novo(); p.vida_atual = -2; invalidos.append(p)
	p = novo(); p.especie = null; invalidos.append(p)
	for invalido in invalidos:
		var id: String = invalido.id_persistente
		checar(not colecao.registrar_captura(invalido),"rejeita captura inválida")
		checar(colecao.pokemons_capturados.is_empty(),"rejeição não altera BOX")
		checar(invalido.id_persistente==id,"rejeição não atribui identidade")
	p = novo()
	checar(colecao.registrar_captura(p),"captura válida aceita")
	checar(p.id_persistente.length()==32,"ID criado")
	var duplicado: DadosPokemon = p.duplicate()
	checar(not colecao.registrar_captura(duplicado),"mesmo ID rejeitado")
	var inventario: InventarioJogo = InventarioJogo.new()
	var bola: Dictionary = inventario.obter_dados_bola(1)
	bola["infinita"] = true
	checar(not inventario.obter_dados_bola(1)["infinita"],"catálogo não muda por consulta")
	var pocao: Dictionary = inventario.obter_dados_pocao(200)
	pocao["cura"] = 99999
	checar(inventario.obter_dados_pocao(200)["cura"]==60,"poção não muda por consulta")
	# Estoque excedente rejeita o lote inteiro, mesmo com outra pilha válida.
	inventario.itens_depot[200] = 2147483647
	var bag: Dictionary = inventario.estoque_bolas.duplicate()
	var pocoes: Dictionary = inventario.estoque_pocoes.duplicate()
	var depot: Dictionary = inventario.itens_depot.duplicate()
	checar(inventario.guardar_todos_itens_depot()!="Itens guardados.","overflow recusa lote")
	checar(inventario.estoque_bolas==bag and inventario.estoque_pocoes==pocoes and inventario.itens_depot==depot,"lote rejeitado não move pilhas anteriores")
	inventario.itens_depot.clear()
	for i in range(199):
		inventario.itens_depot[10000+i] = 1
	depot = inventario.itens_depot.duplicate()
	checar(inventario.guardar_todos_itens_depot().begins_with("Depot cheio"),"pré-valida capacidade do lote")
	checar(inventario.estoque_bolas==bag and inventario.itens_depot==depot,"capacidade insuficiente não move nada")
	inventario.itens_depot.clear()
	var eventos: Dictionary = {"bolas":0,"pocoes":0,"depot":0,"completo":true}
	inventario.estoque_bolas_alterado.connect(func() -> void:
		eventos["bolas"] += 1
		eventos["completo"] = eventos["completo"] and inventario.estoque_pocoes[200]==0
	)
	inventario.estoque_pocoes_alterado.connect(func() -> void: eventos["pocoes"] += 1)
	inventario.depot_alterado.connect(func() -> void: eventos["depot"] += 1)
	checar(inventario.guardar_todos_itens_depot()=="Itens guardados.","lote completo aceito")
	# Fase 4 (A, G4): as bolas não vão para o depot; só itens e poções.
	checar(eventos["bolas"]==0 and eventos["pocoes"]==1 and eventos["depot"]==1,"sinais agrupados")
	checar(eventos["completo"],"observadores recebem estado concluído")
	checar(not inventario.itens_depot.has(1) and inventario.itens_depot[200]==20 and inventario.estoque_bolas[1]==100,"quantidades conservadas; bolas na BAG")
	checar(inventario.mover_item_depot(1,true)!="" and inventario.estoque_bolas[1]==100,"bola não vai para o depot")
	# Limpa callbacks que capturam o inventário neste teste isolado.
	for sinal in [inventario.estoque_bolas_alterado,inventario.estoque_pocoes_alterado,inventario.depot_alterado]:
		for conexao in sinal.get_connections():
			sinal.disconnect(conexao["callable"])
	var estado: Node = root.get_node("EstadoJogo")
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.curar_time()
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	caca.set_physics_process(false)
	caca.set_process(false)
	caca.timer_auto_potion.stop()
	await process_frame
	var estoque_antes: Dictionary = estado.estoque_bolas.duplicate()
	caca.encontro_atual.pokemon.qualidade = NAN
	caca.vida_selvagem = 0
	caca.batalha_encerrada = true
	caca.capturar()
	checar(estado.estoque_bolas==estoque_antes,"captura inválida não consome bola")
	checar(caca.indice_alvo==-1,"captura inválida libera o encontro")
	caca.queue_free()
	await process_frame
	print("CONSISTÊNCIA: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
