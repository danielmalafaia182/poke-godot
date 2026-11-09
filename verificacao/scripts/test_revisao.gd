extends SceneTree
var falhas: int = 0
var checks: int = 0
func checar(valor: bool, nome: String) -> void:
	checks += 1
	if not valor:
		falhas += 1
		push_error(nome)
func _initialize() -> void:
	call_deferred("testar")
func testar() -> void:
	var contrato: Script = load("res://dados_navegacao.gd")
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/caca/geodude_navegacao_original.json"))
	checar(contrato.validar(dados)=="","grade original aceita")
	for invalido in [null,[],{"rows":88},"texto"]:
		checar(contrato.validar(invalido)!="","objeto inválido rejeitado")
	for chave in ["rows","cols","heroStepMs","mobStepMs"]:
		var copia: Dictionary = dados.duplicate(true)
		copia[chave] = 0
		checar(contrato.validar(copia)!="","zero rejeitado")
	var copia: Dictionary = dados.duplicate(true)
	copia["grid"][0].pop_back()
	checar(contrato.validar(copia)!="","linha curta rejeitada")
	copia = dados.duplicate(true)
	copia["grid"][0][0] = 1
	checar(contrato.validar(copia)!="","número não substitui booleano")
	var estado: Node = root.get_node("EstadoJogo")
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.pokemon_inicial.vida_atual = estado.pokemon_inicial.obter_vida_maxima()
	estado.selecionar_lider(estado.pokemon_inicial)
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	await process_frame
	caca.movimento_selvagens_habilitado = false
	var indice: int = caca.indice_alvo
	var origem: Vector2i = caca.selvagens[indice].celula
	var iniciou: bool = false
	for direcao in caca.DIRECOES:
		if caca.movimento_selvagens.iniciar_passo(indice,origem+direcao):
			iniciou = true
			break
	checar(iniciou,"alvo começou deslocamento")
	caca.aproximando = false
	caca.recalcular_alvo_pendente = true
	caca.caminho.clear()
	caca._physics_process(0.0)
	checar(not caca.aproximando and caca.caminho.is_empty() and caca.recalcular_alvo_pendente,"espera sem A* repetido")
	checar(caca.parametros_navegacao_original["mobStepMs"]==1000 and caca.movimento_selvagens.duracao_passo==1.0,"tempo compartilhado")
	caca.queue_free()
	await process_frame
	print("REVISÃO: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
