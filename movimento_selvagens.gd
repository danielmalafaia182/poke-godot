extends RefCounted

# Novo: mobStepMs=1000 vem do field-init. Raios, pausas e escolhas são
# regras locais configuráveis: não representam uma IA original comprovada.
var controlador: Node2D
var aleatorio: RandomNumberGenerator = RandomNumberGenerator.new()
var duracao_passo: float = 1.0
var limite_expansoes_por_busca: int = 256
# Última decisão por slot; tamanho limitado à população, sem histórico crescente.
var diagnosticos_busca: Dictionary = {}
const BUSCA = preload("res://busca_caminho_selvagem.gd")

func iniciar(caca: Node2D) -> void:
	controlador = caca
	aleatorio.randomize()
	# Revisão: a caça fornece os tempos após validar o arquivo uma única vez.

func preparar_individuo(registro: EncontroSelvagem, celula: Vector2i) -> void:
	diagnosticos_busca.erase(registro.slot)
	# Alteração: respawn cancela todo deslocamento do indivíduo anterior.
	registro.movendo = false
	registro.origem_movimento = celula
	registro.destino_movimento = celula
	registro.progresso_movimento = 0.0
	registro.tempo_decisao = aleatorio.randf_range(0.0,duracao_passo)

func atualizar(delta: float) -> void:
	if controlador == null or not controlador.populacao_iniciada or controlador.vida_aliado <= 0:
		return
	for indice in range(controlador.selvagens.size()):
		var registro: EncontroSelvagem = controlador.selvagens[indice]
		if registro.estado != EncontroSelvagem.Estado.VIVO:
			continue
		if bool(registro.movendo):
			_interpolar(indice,delta)
			continue
		if not controlador.movimento_selvagens_habilitado:
			continue
		# O alvo permanece parado durante a troca de golpes já iniciada.
		if indice == controlador.indice_alvo and not controlador.timer_combate.is_stopped():
			continue
		registro.tempo_decisao = float(registro.tempo_decisao)-delta
		if float(registro.tempo_decisao) > 0.0:
			continue
		registro.tempo_decisao = duracao_passo
		var origem: Vector2i = registro.celula
		var destino: Vector2i = _escolher_destino(indice)
		if destino != origem:
			iniciar_passo(indice,destino)

func ocupada(celula: Vector2i, ignorar: int = -1) -> bool:
	# Alteração: não invade o destino do passo do aliado nem cruza sua diagonal.
	if controlador.obter_reservas_aliado().has(celula):
		return true
	for indice in range(controlador.selvagens.size()):
		if indice == ignorar:
			continue
		var outro: EncontroSelvagem = controlador.selvagens[indice]
		if not bool(outro.ativo):
			continue
		if outro.celula == celula:
			return true
		if bool(outro.movendo) and outro.origem_movimento == celula:
			return true
	return false

func passo_livre(indice: int, origem: Vector2i, destino: Vector2i) -> bool:
	if not controlador.passagem_permitida(origem,destino) or ocupada(destino,indice):
		return false
	var diferenca: Vector2i = destino-origem
	# Reserva também as laterais da diagonal: dois selvagens não trocam
	# de célula nem cruzam diagonais simultaneamente.
	if diferenca.x != 0 and diferenca.y != 0:
		if ocupada(origem+Vector2i(diferenca.x,0),indice) or ocupada(origem+Vector2i(0,diferenca.y),indice):
			return false
	for outro_indice in range(controlador.selvagens.size()):
		if outro_indice == indice:
			continue
		var outro: EncontroSelvagem = controlador.selvagens[outro_indice]
		if not bool(outro.ativo) or not bool(outro.movendo):
			continue
		var a: Vector2i = outro.origem_movimento
		var b: Vector2i = outro.destino_movimento
		if origem+destino == a+b:
			return false
	return true

func _escolher_destino(indice: int) -> Vector2i:
	var registro: EncontroSelvagem = controlador.selvagens[indice]
	var origem: Vector2i = registro.celula
	var aliado: Vector2i = controlador.posicao_para_celula(controlador.imagem_aliado.global_position)
	var spawn: Vector2i = controlador.PONTOS_RESPAWN[indice]
	var distancia: float = Vector2(origem).distance_to(Vector2(aliado))
	if distancia <= float(controlador.raio_perseguicao_selvagens):
		if controlador._selvagem_em_alcance(registro):
			diagnosticos_busca[indice] = {"motivo": "em_alcance", "expandidos": 0}
			return origem
		var ocupadas: Dictionary = _ocupacao_para_busca(indice)
		var destinos: Array[Vector2i] = []
		# Procura posição de ataque livre, nunca a célula ocupada pelo aliado.
		for direcao in controlador.DIRECOES:
			var destino: Vector2i = aliado + direcao
			if ocupadas.has(destino) or not controlador.passagem_permitida(destino, aliado):
				continue
			if controlador.celula_para_posicao(destino).distance_to(controlador.imagem_aliado.global_position) <= controlador.alcance_combate + 0.1:
				destinos.append(destino)
		return _primeiro_passo(indice, origem, destinos, ocupadas)
	# Fora da perseguição, volta para a região de origem se necessário.
	if Vector2(origem).distance_to(Vector2(spawn)) > float(controlador.raio_passeio_selvagens):
		var destinos_retorno: Array[Vector2i] = [spawn]
		return _primeiro_passo(indice, origem, destinos_retorno, _ocupacao_para_busca(indice))
	if aleatorio.randf() < controlador.chance_pausa_selvagens:
		return origem
	var candidatas: Array[Vector2i] = []
	for direcao in controlador.DIRECOES:
		var destino: Vector2i = origem+direcao
		if Vector2(destino).distance_to(Vector2(spawn)) <= float(controlador.raio_passeio_selvagens) and passo_livre(indice,origem,destino):
			candidatas.append(destino)
	return origem if candidatas.is_empty() else candidatas[aleatorio.randi_range(0,candidatas.size()-1)]

func _ocupacao_para_busca(indice: int) -> Dictionary:
	var ocupadas: Dictionary = obter_ocupacao_selvagens(indice)
	for celula in controlador.obter_reservas_aliado():
		ocupadas[celula] = true
	return ocupadas

func _primeiro_passo(indice: int, origem: Vector2i, destinos: Array[Vector2i], ocupadas: Dictionary) -> Vector2i:
	var resultado: Dictionary = BUSCA.buscar(controlador, origem, destinos, ocupadas, limite_expansoes_por_busca)
	diagnosticos_busca[indice] = {"motivo": resultado["motivo"], "expandidos": resultado["expandidos"]}
	var caminho: Array[Vector2i] = resultado["caminho"]
	# Revalida a reserva imediatamente antes de aceitar o primeiro passo.
	if caminho.size() > 1 and passo_livre(indice, origem, caminho[1]):
		return caminho[1]
	return origem

func iniciar_passo(indice: int, destino: Vector2i) -> bool:
	var registro: EncontroSelvagem = controlador.selvagens[indice]
	var origem: Vector2i = registro.celula
	if registro.estado != EncontroSelvagem.Estado.VIVO or bool(registro.movendo) or not passo_livre(indice,origem,destino):
		return false
	registro.origem_movimento = origem
	registro.destino_movimento = destino
	registro.progresso_movimento = 0.0
	registro.movendo = true
	# Celula representa o destino reservado; a imagem é interpolada até ele.
	registro.celula = destino
	var imagem: Sprite2D = registro.imagem
	imagem.call("_olhar_para",controlador.celula_para_posicao(destino))
	if indice == controlador.indice_alvo:
		controlador.recalcular_alvo_pendente = true
	return true

func _interpolar(indice: int, delta: float) -> void:
	var registro: EncontroSelvagem = controlador.selvagens[indice]
	var progresso: float = minf(1.0,float(registro.progresso_movimento)+maxf(0.0,delta)/duracao_passo)
	registro.progresso_movimento = progresso
	var imagem: Sprite2D = registro.imagem
	imagem.global_position = controlador.celula_para_posicao(registro.origem_movimento).lerp(
		controlador.celula_para_posicao(registro.destino_movimento),progresso)
	if progresso >= 1.0:
		registro.movendo = false
		registro.tempo_decisao = 0.0
		if indice == controlador.indice_alvo:
			controlador.recalcular_alvo_pendente = true

# Alteração: snapshot de ocupação para o A* e a validação de trechos do aliado.
func obter_ocupacao_selvagens(ignorar: int = -1) -> Dictionary:
	var ocupadas: Dictionary = {}
	for indice in range(controlador.selvagens.size()):
		if indice == ignorar:
			continue
		var registro: EncontroSelvagem = controlador.selvagens[indice]
		if not registro.ativo:
			continue
		ocupadas[registro.celula] = true
		if registro.movendo:
			ocupadas[registro.origem_movimento] = true
			var diferenca: Vector2i = registro.destino_movimento-registro.origem_movimento
			if diferenca.x != 0 and diferenca.y != 0:
				ocupadas[registro.origem_movimento+Vector2i(diferenca.x,0)] = true
				ocupadas[registro.origem_movimento+Vector2i(0,diferenca.y)] = true
	return ocupadas
