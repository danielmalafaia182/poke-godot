extends SceneTree
const FICHA: Script = preload("res://ficha_pokemon_depot.gd")
var falhas: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("executar")
func checar(ok: bool, mensagem: String) -> void:
	checks += 1
	if not ok:
		falhas += 1
		push_error(mensagem)
func quadros() -> void:
	for i in range(5): await process_frame
func clicar(p: Vector2) -> void:
	var movimento: InputEventMouseMotion = InputEventMouseMotion.new()
	movimento.position=p
	movimento.global_position=p
	root.push_input(movimento,true)
	for pressionado in [true,false]:
		var evento: InputEventMouseButton = InputEventMouseButton.new()
		evento.position=p
		evento.global_position=p
		evento.button_index=MOUSE_BUTTON_LEFT
		evento.pressed=pressionado
		root.push_input(evento,true)
	await quadros()
func executar() -> void:
	root.size=Vector2i(1920,1080)
	var estado: Node = root.get_node("EstadoJogo")
	var inicial: DadosPokemon = estado.pokemon_inicial
	var extra: DadosPokemon = DadosPokemon.new()
	extra.especie=load("res://dados/especies/geodude.tres")
	extra.nivel=17
	extra.qualidade=1.4
	extra.iv_hp=32
	extra.iv_atk=19
	extra.iv_def=11
	extra.iv_sp_atk=7
	extra.iv_sp_def=21
	extra.iv_spd=25
	estado.registrar_captura(extra)
	var ivs: int = extra.obter_total_ivs()
	var power: int = extra.obter_power()
	var quantidade: int = estado.time_pokemon.size()+estado.pokemons_capturados.size()
	var bolas: Dictionary = estado.estoque_bolas.duplicate()
	var pocoes: Dictionary = estado.estoque_pocoes.duplicate()
	var cidade: Control = load("res://cidade.tscn").instantiate()
	root.add_child(cidade)
	await quadros()
	cidade.set_process(false)
	cidade.personagem.position=Vector2(900,900)
	cidade.personagem.destino=cidade.personagem.position
	cidade.personagem.andando=false
	cidade._process(0)
	checar(cidade._perto_nurse() and cidade._perto_depot(),"alcance padrão ilimitado na cidade")
	checar(cidade.placa_nurse.visible and cidade.placa_depot.visible,"placas visíveis mesmo longe")
	checar(cidade.botao_nurse.text=="Talk" and cidade.botao_depot.text=="Open Depot","ações separadas dos nomes")
	var nurse: Sprite2D = cidade.cenario.find_child("ImagemNurseJoy",true,false)
	checar(nurse.offset==Vector2(0,-20.48),"âncora da Nurse igual ao cliente original")
	cidade.alcance_interacao_cidade=96
	checar(not cidade._perto_nurse() and not cidade._perto_depot(),"alcance limitado configurável")
	cidade.alcance_interacao_cidade=0
	cidade._clicar_nurse()
	checar(cidade.painel_nurse.visible,"clique abre Nurse à distância")
	cidade.painel_nurse.hide()
	cidade._clicar_depot()
	var painel: Control = cidade.painel_depot
	checar(painel.visible,"clique abre Depot à distância")
	painel.abrir_depot()
	painel._mudar_aba(1)
	await quadros()
	checar(painel.familia.disabled and painel.filtros_pendentes.size()==3,"filtros sem metadados não inventam resultados")
	for i in range(painel.categoria.item_count):
		if str(painel.categoria.get_item_metadata(i))=="GROUND": painel.categoria.select(i)
	checar(painel.corresponde_pokemon(extra),"tipo secundário GROUND também filtra")
	for i in range(painel.categoria.item_count):
		if str(painel.categoria.get_item_metadata(i))=="WATER": painel.categoria.select(i)
	checar(not painel.corresponde_pokemon(extra),"tipo WATER exclui Geodude")
	painel.categoria.select(0)
	painel.faixas[2].text=str(ivs+1)
	checar(not painel.corresponde_pokemon(extra),"mínimo de IV usa soma verdadeira")
	painel.faixas[2].text=""
	painel.atualizar_listas()
	await quadros()
	var card: CartaoPokemonDepot = painel.colunas[1].get_child(0)
	var ficha: Control = card._make_custom_tooltip("")
	root.add_child(ficha)
	checar(ficha.find_child("Power",true,false).text=="💪 Power "+str(power),"Power do indivíduo na ficha")
	checar(ficha.find_child("Atributo0",true,false).get_parsed_text()=="HP "+str(extra.obter_atributos()["hp"]),"atributo calculado não é IV")
	checar(FICHA.dados(extra)["familia"]==null and ficha.find_child("Pendencias",true,false).text.contains("—"),"dados ausentes mantêm placeholder")
	ficha.queue_free()
	await quadros()
	var desconhecido: DadosPokemon = DadosPokemon.new()
	desconhecido.especie=DadosEspecie.new()
	desconhecido.especie.nome="Especie sem base"
	checar(FICHA.dados(desconhecido)["power"]==null,"Power desconhecido não vira zero fictício")
	await clicar(card.get_global_rect().get_center())
	checar(estado.time_pokemon.has(extra) and not estado.pokemons_capturados.has(extra),"clique transfere BOX para TEAM")
	painel.atualizar_listas()
	var devolucao: CartaoPokemonDepot
	for candidato in painel.colunas[0].get_children():
		if candidato is CartaoPokemonDepot and candidato.pokemon==extra: devolucao=candidato
	await quadros()
	if devolucao!=null: await clicar(devolucao.get_global_rect().get_center())
	else: checar(false,"cartão devolução disponível")
	checar(not estado.time_pokemon.has(extra) and estado.pokemons_capturados.has(extra),"clique transfere TEAM para BOX")
	checar(estado.time_pokemon.has(inicial),"inicial preservado")
	checar(estado.time_pokemon.size()+estado.pokemons_capturados.size()==quantidade,"transferência conserva indivíduos")
	checar(extra.obter_total_ivs()==ivs and extra.obter_power()==power,"interface preserva IVs e atributos")
	checar(estado.estoque_bolas==bolas and estado.estoque_pocoes==pocoes,"interface não consome estoque")
	for resolucao in [Vector2i(1920,1080),Vector2i(1152,648),Vector2i(800,450)]:
		root.size=resolucao
		await quadros()
		var rect: Rect2 = painel.janela.get_global_rect()
		checar(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=resolucao.x and rect.end.y<=resolucao.y,"Depot cabe em "+str(resolucao))
	checar(estado.salvar_agora(),"estado salvável após transferências")
	cidade.queue_free()
	await process_frame
	print("DEPOT CIDADE FIEL: ",checks," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
