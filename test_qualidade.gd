extends SceneTree

var falhas: int = 0
var verificacoes: int = 0
var eventos_captura: Array[Dictionary] = []
var eventos_derrota: Array[Dictionary] = []

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
	for id in [1,200]:
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
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	# Histórico: este teste valida o combate fixo; catálogo tem teste próprio.
	caca.usar_golpes_catalogados = false
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	caca.timer_combate.stop()
	caca.timer_auto_potion.stop()
	caca.movimento_selvagens_habilitado = false
	caca.captura_resolvida.connect(func(e: Dictionary) -> void: eventos_captura.append(e))
	caca.derrota_recompensada.connect(func(e: Dictionary) -> void: eventos_derrota.append(e))
	await process_frame
	var hud: Control = caca.get_node("Interface/HudCaca")
	var painel: Control = hud.painel_time
	var lider: DadosPokemon = caca.pokemon_aliado
	var cartao: CartaoPokemonHud = painel.cartoes[lider]
	var cartao_extra: CartaoPokemonHud = painel.cartoes[extra]
	var ids_antes: Array[int] = []
	for filho in painel.lista.get_children():
		ids_antes.append(filho.get_instance_id())
	var hp_id: int = cartao.barra_hp.get_instance_id()
	var xp_id: int = cartao.barra_xp.get_instance_id()
	var extra_hp: float = cartao_extra.barra_hp.value
	for i in range(100):
		estado.registrar_vida_pokemon(lider,1+(i%10))
		estado.conceder_experiencia(lider,1)
	var ids_depois: Array[int] = []
	for filho in painel.lista.get_children():
		ids_depois.append(filho.get_instance_id())
	checar(ids_antes==ids_depois,"100 alterações HP/XP mantêm todos os cartões")
	checar(cartao.barra_hp.get_instance_id()==hp_id and cartao.barra_xp.get_instance_id()==xp_id,"mantém as próprias barras")
	checar(cartao_extra.barra_hp.value==extra_hp,"não altera outro Pokémon")
	checar(cartao.barra_hp.value==lider.obter_vida_atual() and hud.vida_aliado.value==lider.obter_vida_atual(),"HUD e mundo atualizados por sinal")
	checar(cartao.nivel.text=="Lv.%d" % lider.nivel and is_equal_approx(cartao.barra_xp.value,lider.experiencia_percentual),"XP e nível atualizados")
	checar(caca.vida_aliado==lider.obter_vida_atual(),"HP combate e recurso têm fonte única")
	estado.registrar_vida_pokemon(lider,1)
	estado.definir_auto_potion(true)
	estado.selecionar_pocao_auto_potion(200)
	var pocoes: int = estado.estoque_pocoes[200]
	caca._on_timer_auto_potion_timeout()
	checar(estado.estoque_pocoes[200]==pocoes-1 and caca.vida_aliado==mini(61,lider.obter_vida_maxima()),"cura e consumo integrados")
	checar(cartao.barra_hp.value==caca.vida_aliado,"poção atualiza HUD sem reconstruir")
	caca.vida_aliado = 0
	caca._on_timer_auto_potion_timeout()
	checar(estado.estoque_pocoes[200]==pocoes-1,"derrotado não consome")
	estado.curar_time()
	checar(caca.vida_aliado==lider.obter_vida_maxima() and cartao.barra_hp.value==caca.vida_aliado,"Nurse Joy compartilha HP")
	# Composição: remove só o cartão que saiu, cria só o que entrou.
	estado.mover_pokemon_depot(extra,true)
	checar(not painel.cartoes.has(extra) and painel.cartoes[lider]==cartao,"remoção preserva restantes")
	estado.mover_pokemon_depot(extra,false)
	checar(painel.cartoes[extra]!=cartao_extra and painel.cartoes[lider]==cartao,"adição não recria restantes")
	# Perda de caminho / retomada do mesmo encontro não cura o selvagem.
	var indice: int = caca.indice_alvo
	var encontro: EncontroSelvagem = caca.encontro_atual
	checar(encontro==caca.selvagens[indice],"alvo aponta ao encontro na população")
	caca.vida_selvagem = 3
	var origem: Vector2i = caca.posicao_para_celula(caca.imagem_aliado.global_position)
	caca.celulas_bloqueadas[origem] = true
	caca._recalcular_percurso_alvo()
	checar(caca.indice_alvo == -1 and caca.encontro_atual == null,"caminho perdido libera apenas seleção")
	caca.celulas_bloqueadas.erase(origem)
	caca.imagem_aliado.global_position = caca.celula_para_posicao(encontro.celula)
	caca._selecionar_alvo()
	checar(caca.encontro_atual==encontro and caca.vida_selvagem==3,"reseleção preserva identidade e HP")
	# KO recompensa uma vez; a captura não depende da duração do efeito.
	caca.vida_selvagem = 0
	caca.batalha_encerrada = true
	var xp: int = lider.experiencia_total
	caca._recompensar_derrota()
	caca._recompensar_derrota()
	checar(lider.experiencia_total==xp+8 and eventos_derrota.size()==1,"recompensa exatamente uma vez")
	checar(eventos_derrota[0]["encontro_id"]==encontro.id,"recompensa identifica encontro")
	estado.definir_auto_catch(true)
	estado.selecionar_bola_auto_catch(1)
	caca.chance_captura = 1.0
	var bolas: int = estado.estoque_bolas[1]
	var box: int = estado.pokemons_capturados.size()
	caca.capturar()
	caca.capturar()
	checar(estado.estoque_bolas[1]==bolas-1 and estado.pokemons_capturados.size()==box+1,"captura repetida não duplica nem consome de novo")
	checar(eventos_captura.size()==1 and eventos_captura[0].is_read_only(),"evento de captura único e imutável")
	checar(encontro.estado==EncontroSelvagem.Estado.RESOLVIDO and not encontro.movendo,"encontro resolvido")
	var evento: Dictionary = eventos_captura[0].duplicate(true)
	caca._criar_individuo(indice,caca.PONTOS_RESPAWN[indice])
	var novo: EncontroSelvagem = caca.selvagens[indice]
	checar(novo != encontro and novo.id != encontro.id and novo.pokemon != encontro.pokemon,"respawn cria identidade e indivíduo novos")
	checar(novo.imagem==encontro.imagem and novo.vida==novo.vida_maxima and not novo.recompensado and not novo.captura_iniciada,"sprite reutilizado sem estado anterior")
	checar(eventos_captura[0]==evento and evento["encontro_id"]==encontro.id,"respawn não altera evento anterior")
	checar(not encontro.reservar_recompensa() and not encontro.iniciar_captura(),"referência antiga não reabre encontro")
	# Configuração sem estoque e falha conservam a recompensa, não duplicam a BOX.
	caca.imagem_aliado.global_position = caca.celula_para_posicao(novo.celula)
	caca._selecionar_alvo()
	caca.vida_selvagem = 0
	caca.chance_captura = 0.0
	caca.encerrar_batalha(lider.especie.nome)
	checar(estado.pokemons_capturados.size()==box+1 and estado.estoque_bolas[1]==bolas-2,"falha consome uma bola sem adicionar indivíduo")
	checar(eventos_captura.size()==2 and not eventos_captura[1]["sucesso"],"falha emitida")
	caca._selecionar_alvo()
	estado.estoque_bolas[1] = 0
	caca.vida_selvagem = 0
	caca.encerrar_batalha(lider.especie.nome)
	checar(eventos_captura.size()==2 and caca.indice_alvo==-1,"sem estoque encerra encontro sem tentativa")
	caca.queue_free()
	await process_frame
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
