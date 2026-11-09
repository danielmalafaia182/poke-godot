extends RefCounted

# Novo: mobStepMs=1000 vem do field-init. Raios, pausas e escolhas são
# regras locais configuráveis: não representam uma IA original comprovada.
var controlador: Node2D
var aleatorio: RandomNumberGenerator = RandomNumberGenerator.new()
var duracao_passo: float = 1.0
# Candidata limitada à amostra de Blastoise: não é uma regra global confirmada.
var usar_perfil_blastoise_observado: bool = true
const RAIO_BLASTOISE_OBSERVADO: int = 12

func perfil_observado_ativo() -> bool:
	return usar_perfil_blastoise_observado and controlador!=null and not controlador.selvagens.is_empty() and controlador.selvagens[0].pokemon!=null and controlador.selvagens[0].pokemon.especie.nome=="Blastoise"

func descrever_perfil() -> Dictionary:
	return {"id":"blastoise_aproximacao_candidata_v1" if perfil_observado_ativo() else "movimento_local_v1","raio":RAIO_BLASTOISE_OBSERVADO if perfil_observado_ativo() else controlador.raio_perseguicao_selvagens,"metrica":"chebyshev" if perfil_observado_ativo() else "euclidiana","passeio_fora_raio":not perfil_observado_ativo(),"fidelidade_comprovada":false,"rota_dinamica_e_distribuicao":"escolha_local"}


func iniciar(caca: Node2D) -> void:
	controlador = caca
	aleatorio.randomize()
	# Revisão: a caça fornece os tempos após validar o arquivo uma única vez.

func preparar_individuo(registro: EncontroSelvagem, celula: Vector2i) -> void:
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
	if perfil_observado_ativo():
		var distancia_grade: int=maxi(absi(origem.x-aliado.x),absi(origem.y-aliado.y))
		if distancia_grade>RAIO_BLASTOISE_OBSERVADO:return origem
		if controlador._selvagem_em_alcance(registro):return origem
		return _aproximar_por_posicao_livre(indice,aliado)
	var spawn: Vector2i = controlador.PONTOS_RESPAWN[indice]
	var distancia: float = Vector2(origem).distance_to(Vector2(aliado))
	if distancia <= float(controlador.raio_perseguicao_selvagens):
		# Ao chegar à célula vizinha, aguarda: não ocupa a célula do aliado.
		if controlador.passagem_permitida(origem,aliado):
			return origem
		var caminho: Array[Vector2i] = controlador.calcular_caminho(origem,aliado)
		if caminho.size() > 1 and passo_livre(indice,origem,caminho[1]):
			return caminho[1]
		return origem
	# Fora da perseguição, volta para a região de origem se necessário.
	if Vector2(origem).distance_to(Vector2(spawn)) > float(controlador.raio_passeio_selvagens):
		var retorno: Array[Vector2i] = controlador.calcular_caminho(origem,spawn)
		if retorno.size() > 1 and passo_livre(indice,origem,retorno[1]):
			return retorno[1]
		return origem
	if aleatorio.randf() < controlador.chance_pausa_selvagens:
		return origem
	var candidatas: Array[Vector2i] = []
	for direcao in controlador.DIRECOES:
		var destino: Vector2i = origem+direcao
		if Vector2(destino).distance_to(Vector2(spawn)) <= float(controlador.raio_passeio_selvagens) and passo_livre(indice,origem,destino):
			candidatas.append(destino)
	return origem if candidatas.is_empty() else candidatas[aleatorio.randi_range(0,candidatas.size()-1)]

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
func obter_ocupacao_selvagens() -> Dictionary:
	var ocupadas: Dictionary = {}
	for registro in controlador.selvagens:
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

# Escolha local para evitar a fila no mesmo caminho: busca uma posição de ataque
# livre, com A* considerando corpos e reservas. Não altera agendas nem o alvo.
func _aproximar_por_posicao_livre(indice: int, aliado: Vector2i) -> Vector2i:
	var origem: Vector2i=controlador.selvagens[indice].celula
	var bloqueios: Dictionary=obter_ocupacao_selvagens()
	bloqueios.erase(origem)
	for celula in controlador.obter_reservas_aliado():bloqueios[celula]=true
	var melhor: Array[Vector2i]=[]
	var comprimento: float=INF
	for direcao in controlador.DIRECOES:
		var destino: Vector2i=aliado+direcao
		if bloqueios.has(destino) or not controlador.passagem_permitida(aliado,destino):continue
		if controlador.celula_para_posicao(aliado).distance_to(controlador.celula_para_posicao(destino))>controlador.alcance_combate:continue
		var candidato: Array[Vector2i]=controlador.calcular_caminho(origem,destino,bloqueios)
		if candidato.size()<2 or not passo_livre(indice,origem,candidato[1]):continue
		var tamanho: float=controlador.obter_comprimento_caminho(candidato)
		if tamanho<comprimento:melhor=candidato;comprimento=tamanho
	return origem if melhor.is_empty() else melhor[1]
