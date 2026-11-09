extends SceneTree
const BUSCA=preload("res://busca_caminho_selvagem.gd")
var checks: int=0
var falhas: int=0
func _initialize() -> void: call_deferred("executar")
func check(ok: bool, msg: String) -> void:
	checks+=1
	if not ok: falhas+=1;push_error(msg)
func executar() -> void:
	var estado: Node=root.get_node("EstadoJogo")
	for i in range(5): await process_frame
	estado.especie_caca=load("res://dados/especies/geodude.tres")
	estado.curar_time();estado.auto_potion=false;estado.auto_catch=false
	var c: Node2D=load("res://Caca.tscn").instantiate()
	root.add_child(c);c.set_process(false);c.set_physics_process(false)
	c.timer_combate.stop();c.timer_auto_potion.stop()
	var buscas: int=0
	var limites: int=0
	var max_expandidos: int=0
	var tempos: Array[int]=[]
	var centros: Array[Vector2i]=c.PONTOS_RESPAWN.duplicate()
	centros.append(c.posicao_para_celula(c.imagem_aliado.global_position))
	for centro in centros:
		var ocupadas: Dictionary={centro:true}
		for corpo in c.PONTOS_RESPAWN: ocupadas[corpo]=true
		var metas: Array[Vector2i]=[]
		for d in c.DIRECOES:
			var cel: Vector2i=centro+d
			if c.passagem_permitida(centro,cel) and not ocupadas.has(cel): metas.append(cel)
		# Dijkstra reverso: distância de toda célula a alguma meta livre.
		var fila: Array[Vector2i]=metas.duplicate()
		var dist: Dictionary={}
		var fechados: Dictionary={}
		for meta in metas: dist[meta]=0.0
		while not fila.is_empty():
			var melhor: int=0
			for i in range(1,fila.size()):
				if float(dist[fila[i]])<float(dist[fila[melhor]]): melhor=i
			var atual: Vector2i=fila[melhor];fila.remove_at(melhor)
			if fechados.has(atual): continue
			fechados[atual]=true
			for d in c.DIRECOES:
				var viz: Vector2i=atual+d
				if fechados.has(viz) or ocupadas.has(viz) or not c.passagem_permitida(atual,viz): continue
				if d.x!=0 and d.y!=0 and (ocupadas.has(atual+Vector2i(d.x,0)) or ocupadas.has(atual+Vector2i(0,d.y))): continue
				var novo: float=float(dist[atual])+Vector2(d).length()
				if not dist.has(viz) or novo<float(dist[viz]): dist[viz]=novo;fila.append(viz)
		for origem in c.celulas_acessiveis:
			if ocupadas.has(origem) or Vector2(origem-centro).length()>c.raio_perseguicao_selvagens: continue
			var inicio: int=Time.get_ticks_usec()
			var r: Dictionary=BUSCA.buscar(c,origem,metas,ocupadas,256)
			tempos.append(Time.get_ticks_usec()-inicio)
			buscas+=1;max_expandidos=maxi(max_expandidos,r["expandidos"])
			check(r["expandidos"]<=256,"grade original respeita orçamento")
			if r["motivo"]=="limite":
				limites+=1
				continue
			var caminho: Array[Vector2i]=r["caminho"]
			check(not caminho.is_empty()==dist.has(origem),"grade original: alcançabilidade coincide com Dijkstra")
			if not caminho.is_empty():
				var custo: float=0.0
				for i in range(1,caminho.size()): custo+=Vector2(caminho[i]-caminho[i-1]).length()
				check(is_equal_approx(custo,dist[origem]),"grade original: custo mínimo")
	check(limites==0,"nenhuma busca examinada na grade Geodude esgotou orçamento")
	tempos.sort()
	print("P03 GRADE GEODUDE: buscas=%d; limites=%d; max_expandidos=%d; mediana_us=%d; max_us=%d" % [buscas,limites,max_expandidos,tempos[int(tempos.size()/2.0)],tempos[-1]])
	print("P03 GRADE ORIGINAL: %d verificações; %d falhas" % [checks,falhas])
	c.free();quit(1 if falhas else 0)
