extends SceneTree
## Movimento dos selvagens na cena antiga (Caca.tscn), determinístico: todas as fontes de aleatoriedade da cena são
## semeadas (RNG global, que sorteia IV/Quality dos selvagens; rng_dano, rng_troca, rng_loot; IA de movimento) e o
## relógio de troca é fixo. A cena avança por passos explícitos de 0,1 s (_physics_process/_process chamados pelo
## teste, timers parados), sem depender de tempo real nem de quadros.
## Uso: testes/rodar.sh res://test_movimento_selvagens.gd                 (semente fixa, asserções)
##      testes/rodar.sh res://test_movimento_selvagens.gd -- --varrer 40  (sementes 1..40, uma linha por semente)

const SEMENTE := 20261105
var falhas: int = 0
var verificacoes: int = 0


func checar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error(descricao)


func _initialize() -> void:
	call_deferred("testar")


func _arg(nome: String, padrao: String) -> String:
	var a := OS.get_cmdline_user_args()
	for i in a.size() - 1:
		if a[i] == "--" + nome:
			return a[i + 1]
	return padrao


func testar() -> void:
	root.size = Vector2i(1152, 648)
	var varrer := int(_arg("varrer", "0"))
	if varrer > 0:
		for s in range(1, varrer + 1):
			var r: Dictionary = await executar(s, false)
			print("SEMENTE %d xp_ganho=%d mudaram=%d impressao=%s" % [s, int(r["xp_ganho"]), int(r["mudaram"]), r["impressao"]])
		quit(0)
		return
	await parte_unitaria(SEMENTE)
	var r1: Dictionary = await executar(SEMENTE, true)
	var r2: Dictionary = await executar(SEMENTE, false)
	checar(r1["impressao"] == r2["impressao"], "mesma semente → mesmo resultado (posições, XP, alvo)")
	print("impressão: ", r1["impressao"])
	print("MOVIMENTO SELVAGENS: ", verificacoes, " verificações; ", falhas, " falhas")
	quit(1 if falhas > 0 else 0)


func _semear(caca: Node, ai: RefCounted, semente: int) -> void:
	caca.rng_dano.seed = semente * 3 + 1
	caca.rng_troca.seed = semente * 3 + 2
	caca.rng_loot.seed = semente * 3 + 3
	ai.aleatorio.seed = semente
	caca.relogio_troca = func() -> int: return 0


func executar(semente: int, asserir: bool) -> Dictionary:
	var estado: Node = root.get_node("EstadoJogo")
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.selecionar_lider(estado.pokemon_inicial)
	estado.pokemon_inicial.experiencia_total = preload("res://regras_pokemon.gd").xp_total_para_nivel(1)
	estado.pokemon_inicial.normalizar_atributos()
	estado.pokemon_inicial.vida_atual = estado.pokemon_inicial.obter_vida_maxima()
	estado.auto_catch = false
	seed(semente)   # RNG global: IV/Quality dos selvagens criados no _ready da cena
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	# Histórico: este teste valida o combate fixo; catálogo tem teste próprio.
	caca.usar_golpes_catalogados = false
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	caca.timer_auto_potion.stop()
	caca.timer_combate.stop()
	var ai: RefCounted = caca.movimento_selvagens
	_semear(caca, ai, semente)
	await process_frame
	caca.timer_combate.stop()
	_semear(caca, ai, semente)
	caca.movimento_selvagens_habilitado = false
	# Simulação integrada: atualização de alvos, perseguição, combate e respawn, por passos fixos de 0,1 s.
	seed(semente)
	for i in range(15):
		caca._liberar_selvagem_derrotado(i)
	for i in range(15):
		caca._criar_individuo(i, caca.PONTOS_RESPAWN[i])
	_semear(caca, ai, semente)
	caca.indice_alvo = -1
	caca.encontro_atual = null
	caca.imagem_aliado.global_position = caca.celula_para_posicao(caca.CELULA_INICIAL)
	caca.caminho.assign([])
	caca.indice_caminho = 0
	caca.aproximando = false
	caca.vida_aliado = caca.pokemon_aliado.obter_vida_maxima()
	caca.movimento_selvagens_habilitado = true
	caca._selecionar_alvo()
	var xp: int = caca.pokemon_aliado.experiencia_total
	var mudaram: Dictionary = {}
	for passo in range(600):
		caca.vida_aliado = caca.pokemon_aliado.obter_vida_maxima()
		caca._physics_process(0.1)
		caca._process(0.1)
		# combate pelo relógio do teste: um golpe a cada 1 s simulado enquanto há luta (o Timer real fica parado)
		if passo % 10 == 0 and caca.encontro_atual != null and caca.vida_selvagem > 0:
			caca._on_timer_combate_timeout()
		caca.timer_combate.stop()
		if asserir:
			checar(caca.celula_transitavel(caca.posicao_para_celula(caca.imagem_aliado.global_position)), "aliado no chão livre")
		var ocupadas: Dictionary = {}
		for i in range(15):
			var registro: EncontroSelvagem = caca.selvagens[i]
			if not bool(registro.ativo):
				continue
			var celula: Vector2i = registro.celula
			if asserir:
				# Alteração: verifica posição interpolada real, não apenas destinos reservados.
				checar(registro.imagem.global_position.distance_to(caca.imagem_aliado.global_position) > 0.01, "corpos do aliado e selvagem não se sobrepõem")
				checar(caca.celula_transitavel(celula), "selvagem no chão livre")
				checar(not ocupadas.has(celula), "destinos sem sobreposição")
			ocupadas[celula] = true
			if celula != caca.PONTOS_RESPAWN[i]:
				mudaram[i] = true
	var ganho: int = caca.pokemon_aliado.experiencia_total - xp
	if asserir:
		checar(mudaram.size() > 3, "população se movimenta")
		checar(ganho > 0, "caça conclui encontros com alvos móveis")
		# Congelamento no combate: não inicia outro passo enquanto o timer está ativo.
		if caca.indice_alvo >= 0:
			var registro: EncontroSelvagem = caca.selvagens[caca.indice_alvo]
			registro.movendo = false
			registro.tempo_decisao = 0.0
			var antes: Vector2i = registro.celula
			caca.timer_combate.start()
			ai.atualizar(0.1)
			caca.timer_combate.stop()
			checar(registro.celula == antes, "alvo não foge no meio da troca de golpes")
	var celulas: Array = []
	for i in range(15):
		celulas.append(str(caca.selvagens[i].celula) if caca.selvagens[i].ativo else "-")
	var impressao := "xp+%d|alvo %d|%s" % [ganho, caca.indice_alvo, ",".join(celulas)]
	caca.queue_free()
	await process_frame
	return {"xp_ganho": ganho, "mudaram": mudaram.size(), "impressao": impressao.sha256_text().substr(0, 12)}


func _nova_cena(semente: int) -> Node2D:
	var estado: Node = root.get_node("EstadoJogo")
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.selecionar_lider(estado.pokemon_inicial)
	estado.pokemon_inicial.vida_atual = estado.pokemon_inicial.obter_vida_maxima()
	estado.auto_catch = false
	seed(semente)
	var caca: Node2D = load("res://Caca.tscn").instantiate()
	caca.usar_golpes_catalogados = false
	root.add_child(caca)
	caca.set_process(false)
	caca.set_physics_process(false)
	caca.timer_auto_potion.stop()
	caca.timer_combate.stop()
	return caca


func parte_unitaria(semente: int) -> void:
	var caca := _nova_cena(semente)
	await process_frame
	caca.timer_combate.stop()
	var ai: RefCounted = caca.movimento_selvagens
	_semear(caca, ai, semente)
	caca.movimento_selvagens_habilitado = false
	_parte_unitaria(caca, ai)
	caca.queue_free()
	await process_frame


func _parte_unitaria(caca: Node, ai: RefCounted) -> void:
	checar(is_equal_approx(ai.duracao_passo, 1.0), "mobStepMs1000")
	var indice: int = caca.indice_alvo
	var origem: Vector2i = caca.selvagens[indice].celula
	var destino: Vector2i = origem
	for direcao in caca.DIRECOES:
		if ai.passo_livre(indice, origem, origem + direcao):
			destino = origem + direcao
			break
	checar(destino != origem, "destino para interpolação")
	var pokemon: DadosPokemon = caca.pokemon_selvagem
	caca.vida_selvagem = 9
	checar(ai.iniciar_passo(indice, destino), "início de passo")
	checar(caca.recalcular_alvo_pendente, "alvo móvel agenda novo caminho")
	checar(ai.ocupada(origem), "origem reservada")
	checar(ai.ocupada(destino), "destino reservado")
	ai.atualizar(0.5)
	var imagem: Sprite2D = caca.selvagens[indice].imagem
	checar(imagem.global_position.is_equal_approx(caca.celula_para_posicao(origem).lerp(caca.celula_para_posicao(destino), 0.5)), "meio do trajeto em500ms")
	caca._recalcular_percurso_alvo()
	checar(caca.vida_selvagem == 9 and caca.pokemon_selvagem == pokemon, "recalcular preserva HP e identidade")
	var hp: int = caca.vida_selvagem
	caca._on_timer_combate_timeout()
	checar(caca.vida_selvagem == hp, "não ataca alvo em trânsito/distante")
	ai.atualizar(0.5)
	checar(not bool(caca.selvagens[indice].movendo), "passo termina em1000ms")
	checar(imagem.global_position.is_equal_approx(caca.celula_para_posicao(destino)), "sem erro acumulado de posição")
	checar(not ai.iniciar_passo(indice, destino + Vector2i(20, 0)), "não salta células")
	# Outra vaga não pode reservar a célula ocupada pelo primeiro selvagem.
	checar(ai.ocupada(destino, (indice + 1) % 15), "reserva respeita outras vagas")
	caca._liberar_selvagem_derrotado(indice)
	checar(not caca.selvagens[indice].ativo and not caca.selvagens[indice].movendo, "derrota cancela deslocamento")
	caca._criar_individuo(indice, caca.PONTOS_RESPAWN[indice])
	checar(imagem.visible and imagem.global_position.is_equal_approx(caca.celula_para_posicao(caca.PONTOS_RESPAWN[indice])), "respawn recomeça no spawn")
	checar(not caca.selvagens[indice].movendo, "respawn sem interpolação antiga")
	# Alteração: regressões da sobreposição entre aliado e selvagens.
	for i in range(15):
		caca._liberar_selvagem_derrotado(i)
	var centro: Vector2i = caca.CELULA_INICIAL
	for candidata in caca.celulas_acessiveis:
		var livre: bool = true
		for x in range(-1, 4):
			for y in range(-2, 3):
				if not caca.celula_transitavel(candidata + Vector2i(x, y)):
					livre = false
		if livre:
			centro = candidata
			break
	caca._criar_individuo(0, centro + Vector2i(2, 0))
	caca.imagem_aliado.global_position = caca.celula_para_posicao(centro)
	caca.caminho.assign([centro, centro + Vector2i(1, 0)])
	caca.indice_caminho = 1
	caca.aproximando = true
	checar(not ai.iniciar_passo(0, centro + Vector2i(1, 0)), "selvagem não invade próximo passo do aliado")
	caca.imagem_aliado.global_position += Vector2(15, 0)
	checar(ai.ocupada(centro) and ai.ocupada(centro + Vector2i(1, 0)), "origem e destino do aliado reservados durante interpolação")
	caca.imagem_aliado.global_position = caca.celula_para_posicao(centro)
	caca.caminho.assign([centro, centro + Vector2i(1, 1)])
	checar(not ai.iniciar_passo(0, centro + Vector2i(1, 0)), "selvagem não cruza lateral da diagonal do aliado")
	caca.caminho.assign([centro, centro + Vector2i(1, 0), centro + Vector2i(2, 0)])
	caca._criar_individuo(1, centro + Vector2i(1, 0))
	checar(not caca._passo_aliado_livre(centro, centro + Vector2i(1, 0)), "aliado não atravessa selvagem que ocupa sua rota")
	var desvio: Array[Vector2i] = caca._calcular_caminho_aliado(centro, centro + Vector2i(2, 0))
	checar(not desvio.is_empty() and not desvio.has(centro + Vector2i(1, 0)), "A* encontra desvio sem atravessar o bloqueio dinâmico")
