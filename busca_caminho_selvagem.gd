extends RefCounted

# Política LOCAL de P03, não algoritmo comprovado do servidor original.
# Um A* com vários destinos evita repetir a busca para cada posição de ataque.
# O orçamento limita expansões, não milissegundos. Não confundir limite com sem rota.
static func buscar(controlador: Node2D, origem: Vector2i,
		destinos: Array[Vector2i], ocupadas: Dictionary, limite: int = 256) -> Dictionary:
	var metas: Dictionary = {}
	for destino in destinos:
		if controlador.celula_transitavel(destino) and not ocupadas.has(destino):
			metas[destino] = true
	var vazio: Array[Vector2i] = []
	if metas.is_empty():
		return {"caminho": vazio, "motivo": "sem_destino", "expandidos": 0}
	var abertos: Array[Vector2i] = [origem]
	var em_aberto: Dictionary = {origem: true}
	var fechados: Dictionary = {}
	var custos: Dictionary = {origem: 0.0}
	var anteriores: Dictionary = {}
	var prioridades: Dictionary = {origem: _heuristica(controlador, origem, metas)}
	var expandidos: int = 0
	var orcamento: int = clampi(limite, 1, 4096)
	while not abertos.is_empty():
		var melhor: int = 0
		for i in range(1, abertos.size()):
			if float(prioridades[abertos[i]]) < float(prioridades[abertos[melhor]]):
				melhor = i
		var atual: Vector2i = abertos[melhor]
		if metas.has(atual):
			var caminho: Array[Vector2i] = [atual]
			while anteriores.has(atual):
				atual = anteriores[atual]
				caminho.push_front(atual)
			return {"caminho": caminho, "motivo": "encontrado", "expandidos": expandidos}
		if expandidos >= orcamento:
			return {"caminho": vazio, "motivo": "limite", "expandidos": expandidos}
		abertos.remove_at(melhor)
		em_aberto.erase(atual)
		fechados[atual] = true
		expandidos += 1
		for direcao in controlador.DIRECOES:
			var proximo: Vector2i = atual + direcao
			if fechados.has(proximo) or ocupadas.has(proximo):
				continue
			if not controlador.passagem_permitida(atual, proximo):
				continue
			if direcao.x != 0 and direcao.y != 0:
				if ocupadas.has(atual + Vector2i(direcao.x, 0)) or ocupadas.has(atual + Vector2i(0, direcao.y)):
					continue
			var custo: float = float(custos[atual]) + (sqrt(2.0) if direcao.x != 0 and direcao.y != 0 else 1.0)
			if custos.has(proximo) and custo >= float(custos[proximo]):
				continue
			custos[proximo] = custo
			anteriores[proximo] = atual
			prioridades[proximo] = custo + _heuristica(controlador, proximo, metas)
			if not em_aberto.has(proximo):
				abertos.append(proximo)
				em_aberto[proximo] = true
	return {"caminho": vazio, "motivo": "sem_rota", "expandidos": expandidos}

static func _heuristica(controlador: Node2D, origem: Vector2i, metas: Dictionary) -> float:
	var menor: float = INF
	for destino in metas:
		menor = minf(menor, controlador.estimar_distancia(origem, destino))
	return menor
