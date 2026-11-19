extends SceneTree

var falhas: int = 0
var verificacoes: int = 0

func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error(descricao)

func _initialize() -> void:
	call_deferred("testar")

func novo_pokemon() -> DadosPokemon:
	var p: DadosPokemon = DadosPokemon.new()
	p.especie = load("res://dados/especies/geodude.tres")
	p.normalizar_atributos()
	return p

func testar() -> void:
	var estado: Node = root.get_node("EstadoJogo")
	root.size = Vector2i(1152,648)
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.forcar_cidade="cerulean" # fase 4: cura e depot são da cidade; o teste os usa como preparo
	estado.curar_time()
	estado.selecionar_lider(estado.pokemon_inicial)
	# Coleção: recursos distintos não podem compartilhar identidade persistente.
	var extra: DadosPokemon = novo_pokemon()
	checar(estado.registrar_captura(extra),"registra indivíduo")
	checar(not estado.registrar_captura(extra),"rejeita captura repetida por referência")
	var duplicado: DadosPokemon = extra.duplicate()
	checar(not estado.registrar_captura(duplicado),"rejeita captura repetida por identidade")
	checar(estado.mover_pokemon_depot(extra,false)=="","BOX para TEAM")
	checar(estado.selecionar_lider(extra),"líder extra")
	checar(estado.mover_pokemon_depot(extra,true)=="" and estado.obter_lider()==estado.pokemon_inicial,"depositar líder restaura inicial")
	checar(estado.mover_pokemon_depot(estado.pokemon_inicial,true)!="","inicial protegido")
	checar(estado.mover_pokemon_depot(extra,false)=="","retorna ao TEAM")
	for i in range(4):
		var outro: DadosPokemon = novo_pokemon()
		estado.registrar_captura(outro)
		checar(estado.mover_pokemon_depot(outro,false)=="","completa time")
	var excedente: DadosPokemon = novo_pokemon()
	estado.registrar_captura(excedente)
	checar(estado.time_pokemon.size()==6 and estado.mover_pokemon_depot(excedente,false)!="","limite TEAM seis")
	checar(estado.time_pokemon == estado.colecao.time_pokemon,"fachada usa coleção do módulo")
	# Inventário: ida e volta sem duplicação, consumos e restrições.
	# Fase 4 (A, G4): bolas não vão para o depot; o vaivém fica só com itens/poções.
	checar(estado.mover_item_depot(1,true)!="","bola não vai para o depot")
	for id in [200]:
		var antes: int = estado.quantidade_item_bag(id)
		checar(estado.mover_item_depot(id,true)=="","guarda item")
		checar(estado.quantidade_item_bag(id)==0 and int(estado.itens_depot[id])==antes,"estoque único transferido")
		checar(estado.mover_item_depot(id,false)=="" and estado.quantidade_item_bag(id)==antes,"retira mesmo estoque")
	estado.estoque_bolas[7] = 1
	checar(estado.consumir_bola(7) and estado.estoque_bolas[7]==1,"bola infinita")
	checar(estado.mover_item_depot(7,true)!="","bola vinculada não deposita")
	checar(not estado.selecionar_bola_auto_catch(5),"Master Ball rejeitada no automático")
	checar(not estado.definir_limite_auto_potion(51),"limite não suportado rejeitado")
	estado.definir_nomes_auto_catch(" Larvitar, GEODUDE ")
	checar(estado.nome_permitido_auto_catch("Geodude") and not estado.nome_permitido_auto_catch("Pikachu"),"filtro normalizado")
	estado.definir_nomes_auto_catch("")
	# Ciclo 3: a parte da cena antiga (cartões do time, encontro, captura) foi para testes/test_hud_time.gd (cena nova)
	# e para os testes da sim (captura, recompensa uma vez por abate).
	# Persistência usa fachada delegada, sem mudar esquema ou referências do TEAM.
	var save: RefCounted = load("res://salvamento_local.gd").new()
	var dados: Dictionary = save.construir_dados(estado)
	checar(save._validar(dados)=="","snapshot da fachada válido")
	checar(estado.salvar_agora(),"salva estado refatorado")
	var carregado: Dictionary = save.decodificar(FileAccess.get_file_as_string(save.caminho))
	checar(carregado.has("dados"),"save escrito íntegro")
	var snapshot: Dictionary = dados.duplicate(true)
	save._restaurar(estado,snapshot)
	var depois: Dictionary = save.construir_dados(estado)
	dados.erase("salvo_em_unix")
	depois.erase("salvo_em_unix")
	checar(dados==depois,"round-trip preserva atributos estoques configurações e identidade")
	print("QUALIDADE: ",verificacoes," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
