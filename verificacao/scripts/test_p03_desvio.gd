extends SceneTree

const BUSCA = preload("res://busca_caminho_selvagem.gd")
var checks: int = 0
var falhas: int = 0
var c: Node2D
var m: RefCounted
var tempos: Array[int] = []

func _initialize() -> void:
	call_deferred("executar")

func check(ok: bool, mensagem: String) -> void:
	checks += 1
	if not ok:
		falhas += 1
		push_error(mensagem)

func preparar(aliado: Vector2i, corpos: Array[Vector2i], largura: int = 8) -> void:
	c.celulas_existentes.clear()
	c.celulas_bloqueadas.clear()
	c.limitar_area_caca = false
	for x in range(-largura, largura + 1):
		for y in range(-largura, largura + 1):
			c.celulas_existentes[Vector2i(x,y)] = true
	c.aproximando = false
	c.caminho.clear()
	c.indice_caminho = 0
	c.indice_alvo = -1
	c.imagem_aliado.global_position = c.celula_para_posicao(aliado)
	c.raio_perseguicao_selvagens = 100.0
	m.limite_expansoes_por_busca = 256
	m.diagnosticos_busca.clear()
	for i in range(c.selvagens.size()):
		var r: EncontroSelvagem = c.selvagens[i]
		r.vida = r.vida_maxima
		r.movendo = false
		r.progresso_movimento = 0.0
		r.tempo_decisao = 0.0
		r.celula = corpos[i] if i < corpos.size() else Vector2i(100+i,100)
		r.origem_movimento = r.celula
		r.destino_movimento = r.celula
		r.imagem.global_position = c.celula_para_posicao(r.celula)
		c.PONTOS_RESPAWN[i] = r.celula

func completar_passo(i: int) -> void:
	m._interpolar(i, m.duracao_passo)

func custo(caminho: Array[Vector2i]) -> float:
	var total: float = 0.0
	for i in range(1, caminho.size()):
		total += Vector2(caminho[i]-caminho[i-1]).length()
	return total

# Oráculo independente: Dijkstra sem heurística sobre a mesma grade finita.
func referencia(origem: Vector2i, destinos: Array[Vector2i], ocupadas: Dictionary) -> float:
	var fila: Array[Vector2i] = [origem]
	var dist: Dictionary = {origem: 0.0}
	var fechados: Dictionary = {}
	while not fila.is_empty():
		var melhor: int = 0
		for i in range(1, fila.size()):
			if float(dist[fila[i]]) < float(dist[fila[melhor]]): melhor = i
		var atual: Vector2i = fila[melhor]
		fila.remove_at(melhor)
		if fechados.has(atual): continue
		fechados[atual] = true
		if destinos.has(atual): return dist[atual]
		for d in c.DIRECOES:
			var vizinho: Vector2i = atual+d
			if fechados.has(vizinho) or ocupadas.has(vizinho) or not c.passagem_permitida(atual,vizinho): continue
			if d.x != 0 and d.y != 0 and (ocupadas.has(atual+Vector2i(d.x,0)) or ocupadas.has(atual+Vector2i(0,d.y))): continue
			var novo: float = float(dist[atual]) + Vector2(d).length()
			if not dist.has(vizinho) or novo < float(dist[vizinho]):
				dist[vizinho] = novo
				fila.append(vizinho)
	return INF

func executar() -> void:
	var estado: Node = root.get_node("EstadoJogo")
	for i in range(5): await process_frame
	estado.especie_caca = load("res://dados/especies/geodude.tres")
	estado.auto_potion = false
	estado.auto_catch = false
	estado.curar_time()
	c = load("res://Caca.tscn").instantiate()
	root.add_child(c)
	c.set_process(false)
	c.set_physics_process(false)
	c.timer_combate.stop()
	c.timer_auto_potion.stop()
	m = c.movimento_selvagens
	preparar(Vector2i(3,0), [Vector2i(0,0),Vector2i(1,0)])
	var individuo: EncontroSelvagem = c.selvagens[0]
	var identidade: String = individuo.id
	var hp: int = individuo.vida
	var agenda: float = individuo.agenda_golpes.tempo
	var antigo: Array[Vector2i] = c.calcular_caminho(Vector2i.ZERO, Vector2i(3,0))
	check(antigo.size()>1 and antigo[1]==Vector2i(1,0), "controle anterior escolhe primeiro passo ocupado")
	check(not m.passo_livre(0,Vector2i.ZERO,antigo[1]), "controle anterior rejeita passo e ficaria parado")
	var destino: Vector2i = m._escolher_destino(0)
	check(destino != Vector2i.ZERO and destino != Vector2i(1,0), "P03 reproduzido: inicia desvio, não fila")
	check(m.passo_livre(0,Vector2i.ZERO,destino), "primeiro passo do desvio é livre")
	var chegou: bool = false
	for i in range(12):
		destino = m._escolher_destino(0)
		if destino == individuo.celula:
			chegou = c._selvagem_em_alcance(individuo)
			break
		check(m.iniciar_passo(0,destino), "desvio inteiro aceita passo %d" % i)
		completar_passo(0)
	check(chegou, "chega a uma posição de ataque com bloqueador imóvel")
	check(individuo.id==identidade and individuo.vida==hp and individuo.agenda_golpes.tempo==agenda, "navegar preserva identidade, HP e agenda")
	check(m._escolher_destino(0)==individuo.celula, "em alcance permanece sem ocupar aliado")
	m.preparar_individuo(individuo, individuo.celula)
	check(not m.diagnosticos_busca.has(individuo.slot), "preparação limpa diagnóstico da vida anterior")
	# Corredor sem desvio: espera; a saída do bloqueador libera a decisão seguinte.
	preparar(Vector2i(4,0), [Vector2i(0,0),Vector2i(1,0)])
	c.celulas_existentes.clear()
	for x in range(5): c.celulas_existentes[Vector2i(x,0)] = true
	check(m._escolher_destino(0)==Vector2i.ZERO, "corredor fechado espera sem atravessar")
	check(m.diagnosticos_busca[0]["motivo"]=="sem_rota", "corredor sem rota é distinguido do limite")
	c.selvagens[1].celula = Vector2i(99,99)
	check(m._escolher_destino(0)==Vector2i(1,0), "bloqueio transitório: retoma quando sai o corpo")
	# Reservas incluem origem/destino/laterais de quem já está andando.
	preparar(Vector2i(5,0), [Vector2i(0,0),Vector2i(2,0)])
	c.selvagens[1].movendo=true
	c.selvagens[1].origem_movimento=Vector2i(1,-1)
	c.selvagens[1].destino_movimento=Vector2i(2,0)
	var ocupadas: Dictionary=m._ocupacao_para_busca(0)
	for cel in [Vector2i(1,-1),Vector2i(2,0),Vector2i(2,-1),Vector2i(1,0)]:
		check(ocupadas.has(cel), "snapshot reserva corpo em trânsito "+str(cel))
	destino=m._escolher_destino(0)
	check(destino!=Vector2i.ZERO and not ocupadas.has(destino), "desvia de reserva em trânsito")
	check(not m.passo_livre(0,Vector2i(1,0),Vector2i(2,-1)), "proíbe cruzar diagonal de outro corpo")
	# Não passa diagonalmente por quina estática nem por corpo lateral.
	preparar(Vector2i(3,3), [Vector2i(0,0),Vector2i(1,0)])
	check(not m.passo_livre(0,Vector2i.ZERO,Vector2i(1,1)), "corpo lateral bloqueia corte de diagonal")
	c.celulas_bloqueadas[Vector2i(0,1)]=true
	destino=m._escolher_destino(0)
	check(destino!=Vector2i(1,1), "busca respeita quina estática e dinâmica")
	# Retorno ao spawn também precisa contornar corpos.
	preparar(Vector2i(8,8), [Vector2i(0,0),Vector2i(1,0)])
	c.raio_perseguicao_selvagens=1.0
	c.raio_passeio_selvagens=1.0
	c.PONTOS_RESPAWN[0]=Vector2i(4,0)
	check(m._escolher_destino(0)!=Vector2i.ZERO, "retorno ao spawn procura desvio")
	# Destinos de ataque todos ocupados: não invade nem empurra.
	var anel: Array[Vector2i]=[Vector2i(-3,0)]
	for d in c.DIRECOES: anel.append(d)
	preparar(Vector2i.ZERO, anel)
	check(m._escolher_destino(0)==Vector2i(-3,0), "anel cheio aguarda")
	check(m.diagnosticos_busca[0]["motivo"]=="sem_destino", "anel cheio possui diagnóstico próprio")
	# Dois pretendentes não reservam a mesma célula; eventualmente ambos chegam.
	preparar(Vector2i(4,0), [Vector2i(0,0),Vector2i(0,1)])
	for rodada in range(12):
		for i in range(2):
			destino=m._escolher_destino(i)
			if destino!=c.selvagens[i].celula:
				check(m.iniciar_passo(i,destino), "pretendentes: reserva válida")
		check(c.selvagens[0].celula!=c.selvagens[1].celula, "reservas dos pretendentes são distintas")
		for i in range(2):
			if c.selvagens[i].movendo: completar_passo(i)
	check(c._selvagem_em_alcance(c.selvagens[0]) and c._selvagem_em_alcance(c.selvagens[1]), "ambos chegam, sem esperar virar alvo")
	# Integração da atualização normal: 15 perseguidores, oito posições de ataque.
	var grupo: Array[Vector2i]=[]
	for y in range(-3,0):
		for x in range(-4,1): grupo.append(Vector2i(x,y))
	preparar(Vector2i(4,0), grupo, 10)
	for rodada in range(60):
		m.atualizar(1.0)
		var reservadas: Dictionary={}
		for r in c.selvagens:
			check(not reservadas.has(r.celula), "15 perseguidores: destinos exclusivos")
			reservadas[r.celula]=true
	var em_alcance: int=0
	for r in c.selvagens:
		if c._selvagem_em_alcance(r): em_alcance+=1
	check(em_alcance==8, "15 perseguidores ocupam oito posições sem depender do alvo")
	print("P03 CERCO ABERTO: %d de 15 em posição de ataque" % em_alcance)
	# Custo limitado: não apresenta orçamento esgotado como ausência de rota.
	preparar(Vector2i(7,0), [Vector2i(0,0)])
	m.limite_expansoes_por_busca=1
	check(m._escolher_destino(0)==Vector2i.ZERO, "orçamento esgotado não teleporta")
	check(m.diagnosticos_busca[0]["motivo"]=="limite" and m.diagnosticos_busca[0]["expandidos"]==1, "limite de expansão respeitado")
	m.limite_expansoes_por_busca=256
	check(m._escolher_destino(0)!=Vector2i.ZERO, "com orçamento suficiente encontra rota")
	# A reserva do aliado inclui seu passo inteiro, inclusive laterais diagonais.
	c.aproximando=true
	c.caminho.assign([Vector2i(6,-1),Vector2i(7,0)])
	c.indice_caminho=1
	ocupadas=m._ocupacao_para_busca(0)
	for cel in [Vector2i(6,-1),Vector2i(7,0),Vector2i(7,-1),Vector2i(6,0)]:
		check(ocupadas.has(cel), "reserva do passo do aliado "+str(cel))
	# 80 grades aleatórias: compara custo ótimo com Dijkstra independente.
	var rng: RandomNumberGenerator=RandomNumberGenerator.new()
	rng.seed=903
	for caso in range(80):
		preparar(Vector2i(4,0), [Vector2i(-4,0)], 5)
		ocupadas={Vector2i(4,0):true}
		for x in range(-5,6):
			for y in range(-5,6):
				var cel: Vector2i=Vector2i(x,y)
				if cel!=Vector2i(-4,0) and rng.randf()<0.21: ocupadas[cel]=true
		var metas: Array[Vector2i]=[]
		for d in c.DIRECOES:
			var cel: Vector2i=Vector2i(4,0)+d
			if not ocupadas.has(cel): metas.append(cel)
		var inicio: int=Time.get_ticks_usec()
		var resultado: Dictionary=BUSCA.buscar(c,Vector2i(-4,0),metas,ocupadas,256)
		tempos.append(Time.get_ticks_usec()-inicio)
		var esperado: float=referencia(Vector2i(-4,0),metas,ocupadas)
		var percurso: Array[Vector2i]=resultado["caminho"]
		check(percurso.is_empty()==is_inf(esperado), "Dijkstra alcançabilidade caso %d" % caso)
		if not percurso.is_empty():
			check(is_equal_approx(custo(percurso),esperado), "Dijkstra custo mínimo caso %d" % caso)
			for i in range(1,percurso.size()):
				check(c.passagem_permitida(percurso[i-1],percurso[i]) and not ocupadas.has(percurso[i]), "rota segura caso %d" % caso)
		check(resultado["expandidos"]<=256, "expansões limitadas caso %d" % caso)
		var repetido: Dictionary=BUSCA.buscar(c,Vector2i(-4,0),metas,ocupadas,256)
		check(repetido["caminho"]==percurso, "mesmo snapshot gera mesma rota %d" % caso)
	tempos.sort()
	print("P03 BUSCA: 80 grades; mediana_us=%d; max_us=%d" % [tempos[40],tempos[-1]])
	print("P03 DESVIO: %d verificações; %d falhas" % [checks,falhas])
	c.free()
	quit(1 if falhas else 0)
