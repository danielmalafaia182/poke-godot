extends Node2D
## Desenha o mapa original (stonegy-map-compact-v1) com o atlas de map-items do snapshot.
##
## Ordem e posições: render/regras_desenho.gd (porte literal do cliente, conferido contra o JS original), lidas do
## cache binário render/cache_mapa.gd (já ordenadas por andar; montado na 1ª vez e reaproveitado depois).
## Desenho em lote via RenderingServer: um canvas item por sprite, filho do canvas item do andar, sem Node por tile.
## A ordem dentro do andar é o draw_index = 2 × posto do sprite na ordenação estável por zIndex (os ímpares ficam para
## as entidades). Como no cliente (streamChunks/unloadChunk), só os chunks de 8×8 tiles perto da câmera existem.
## Andares: um por z, deslocados (z − groundZ)·32 px; o andar acima do herói some quando há chão sobre ele
## (computeFirstVisibleFloor, C), com o fade de 180 ms por unidade de alpha (tickFloorFade, C).
## Páginas do atlas: as dos chunks em volta do ponto inicial são decodificadas na carga; as outras numa thread de
## fundo (WorkerThreadPool). Um chunk cuja página ainda não chegou espera na fila (F de desempenho).

const DadosDesenho := preload("res://render/dados_desenho.gd")
const CacheMapa := preload("res://render/cache_mapa.gd")
const Fontes := preload("res://sim/fontes.gd")

const CHUNK := 8
const MARGEM_TILES := 10          # streamChunks (C): ±10 tiles além da metade da vista
const DURACAO_QUADRO_PADRAO := 150.0

var dados: RefCounted
var slug := ""
var ground_z := 7
var min_z := 0
var max_z := 0
var animacao_ligada := true
var tiles_visiveis := Vector2(25, 13)   # vista do original em zoom 1 ("25×13")
var origem_cache := ""                  # "cache" ou "montado"
var tempos_carga := {}

var _assets: Dictionary = {}       # id (String) -> asset do manifest
var _andares := {}          # z -> {"rid", "a" (arrays do cache), "alpha"}
var _chunks: Dictionary = {}       # "z|cx,cy" -> PackedInt32Array
var _paginas_chunk: Dictionary = {}
var _carregados := {}       # chave -> Array de RID
var _animados := {}         # rid -> {"a": asset, "i": quadro, "base": int, "len": int, "t": ms, "x":, "y":, "z":}
var _chao := {}             # "x,y,z" -> true (tile com chão), para o andar visível
var _ret_chunks := Rect2i()
var centro_tile := Vector2(0, 0)   # tile (fracionário) no centro da tela: o herói interpolado
var primeiro_andar_visivel := 0
var estatisticas := {"sprites_carregados": 0, "chunks": 0}
var orcamento_ms := 3.0            # tempo máximo por quadro montando/desmontando chunks
var _fila_carregar: Array = []
var _fila_descarregar: Array = []
var _primeira_carga := true
var _paginas: Dictionary = {}      # página -> Texture2D (pronta)
var _decodificando: Dictionary = {}  # página -> id da tarefa
var _imagens_prontas: Dictionary = {}  # página -> Image (vinda da thread)
var _mutex := Mutex.new()
var _caminhos_paginas: Array = []


func carregar(slug_mapa: String, centro_inicial = null) -> void:
	slug = slug_mapa
	var t0 := Time.get_ticks_msec()
	dados = DadosDesenho.carregar()
	_assets = dados.manifest["assets"]
	_caminhos_paginas = dados.paginas_url
	tempos_carga["manifest_ms"] = Time.get_ticks_msec() - t0
	var t1 := Time.get_ticks_msec()
	var c: Dictionary = CacheMapa.obter(slug, dados)
	origem_cache = String(c.get("origem", ""))
	tempos_carga["cache_ms"] = Time.get_ticks_msec() - t1
	ground_z = int(c["ground_z"])
	min_z = int(c["min_z"])
	max_z = int(c["max_z"])
	for k in c["chao"]:
		_chao[k] = true
	_chunks = c["chunks"]
	_paginas_chunk = c["paginas_chunk"]
	var zs: Array = (c["andares"] as Dictionary).keys()
	zs.sort()
	zs.reverse()          # buildWorld (C): andares adicionados do maior z ao menor → o menor fica por cima
	for z in zs:
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, get_canvas_item())
		RenderingServer.canvas_item_set_transform(rid, Transform2D(0.0, Vector2((int(z) - ground_z) * 32, (int(z) - ground_z) * 32)))
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		_andares[int(z)] = {"rid": rid, "a": c["andares"][z], "alpha": 1.0}
	# páginas: as dos chunks em volta do início agora; o resto em segundo plano
	var t2 := Time.get_ticks_msec()
	if centro_inicial != null:
		centro_tile = centro_inicial
	var perto := {}
	for chave in _chunks_desejados():
		for pg in _paginas_chunk.get(chave, PackedInt32Array()):
			perto[int(pg)] = true
	for pg in perto:
		_pagina_sincrona(int(pg))
	tempos_carga["paginas_iniciais"] = perto.size()
	tempos_carga["paginas_iniciais_ms"] = Time.get_ticks_msec() - t2
	for pg in c["paginas"]:
		if not _paginas.has(int(pg)):
			_decodificar_em_fundo(int(pg))
	primeiro_andar_visivel = _primeiro_andar_visivel()
	for z in _andares:
		_aplicar_alpha(int(z), 1.0 if int(z) >= primeiro_andar_visivel else 0.0)
	tempos_carga["total_ms"] = Time.get_ticks_msec() - t0


func paginas_necessarias() -> Array:
	var r := {}
	for k in _paginas_chunk:
		for pg in _paginas_chunk[k]:
			r[int(pg)] = true
	var l := r.keys()
	l.sort()
	return l


func posto_entidade(z_index: float, z_andar: int = -999999) -> int:
	## draw_index de uma entidade (criatura, cadáver) no andar: logo depois do último sprite estático com zIndex menor.
	var a: Dictionary = _andares.get(ground_z if z_andar == -999999 else z_andar, {})
	if a.is_empty():
		return 0
	return 2 * (a["a"]["zi"] as PackedFloat64Array).bsearch(z_index, true) + 1


func rid_andar(z: int = -999999) -> RID:
	var a: Dictionary = _andares.get(ground_z if z == -999999 else z, {})
	return a.get("rid", RID())


func definir_centro(tile: Vector2) -> void:
	## Herói (interpolado) no centro: atualiza streaming e visibilidade de andares.
	centro_tile = tile
	_stream()
	primeiro_andar_visivel = _primeiro_andar_visivel()


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_receber_paginas()
	# tickFloorFade (C): alpha anda 1/180 por ms rumo a 0/1
	for z in _andares:
		var alvo := 1.0 if int(z) >= primeiro_andar_visivel else 0.0
		var a: float = _andares[z]["alpha"]
		if a != alvo:
			a = minf(1.0, a + ms / 180.0) if alvo > a else maxf(0.0, a - ms / 180.0)
			_aplicar_alpha(int(z), a)
	if not _fila_carregar.is_empty() or not _fila_descarregar.is_empty():
		_drenar(orcamento_ms)
	if animacao_ligada:
		_animar(ms)


func _aplicar_alpha(z: int, a: float) -> void:
	_andares[z]["alpha"] = a
	var rid: RID = _andares[z]["rid"]
	RenderingServer.canvas_item_set_modulate(rid, Color(1, 1, 1, a))
	RenderingServer.canvas_item_set_visible(rid, a > 0.001)


func _primeiro_andar_visivel() -> int:
	## computeFirstVisibleFloor (C): sobe a partir do andar do herói; o primeiro andar com chão na diagonal
	## (x+n, y+n) esconde a si e os de cima.
	var sx := roundi(centro_tile.x)
	var sy := roundi(centro_tile.y)
	for a in range(ground_z - 1, min_z - 1, -1):
		var n := ground_z - a
		if _chao.has("%d,%d,%d" % [sx + n, sy + n, a]):
			return a + 1
	return min_z


# ------------------------------------------------------------------- páginas do atlas

func _pagina_sincrona(pg: int) -> void:
	if _paginas.has(pg):
		return
	_paginas[pg] = dados.pagina(pg)


func _decodificar_em_fundo(pg: int) -> void:
	if _decodificando.has(pg):
		return
	var caminho: String = _caminhos_paginas[pg]
	_decodificando[pg] = WorkerThreadPool.add_task(func():
		var img := Image.new()
		var ok := img.load_webp_from_buffer(FileAccess.get_file_as_bytes(caminho)) == OK
		_mutex.lock()
		_imagens_prontas[pg] = img if ok else null
		_mutex.unlock())


func _receber_paginas() -> void:
	if _imagens_prontas.is_empty():
		return
	_mutex.lock()
	var prontas := _imagens_prontas.duplicate()
	_imagens_prontas.clear()
	_mutex.unlock()
	for pg in prontas:
		WorkerThreadPool.wait_for_task_completion(_decodificando[pg])
		_decodificando.erase(pg)
		if not _paginas.has(pg) and prontas[pg] != null:
			_paginas[pg] = ImageTexture.create_from_image(prontas[pg])


func _chunk_pronto(chave: String) -> bool:
	for pg in _paginas_chunk.get(chave, PackedInt32Array()):
		if not _paginas.has(int(pg)):
			return false
	return true


# ------------------------------------------------------------------- streaming

func _chunks_desejados() -> Dictionary:
	var meia := tiles_visiveis / 2.0
	var x0 := floori((centro_tile.x - meia.x - MARGEM_TILES) / CHUNK)
	var x1 := floori((centro_tile.x + meia.x + MARGEM_TILES) / CHUNK)
	var y0 := floori((centro_tile.y - meia.y - MARGEM_TILES) / CHUNK)
	var y1 := floori((centro_tile.y + meia.y + MARGEM_TILES) / CHUNK)
	var manter := {}
	for z in _andares:
		var d := int(z) - ground_z
		for cy in range(y0 - 1, y1 + 2):
			for cx in range(x0 - 1, x1 + 2):
				var ox := float(cx * CHUNK + d)
				var oy := float(cy * CHUNK + d)
				if ox + CHUNK < centro_tile.x - meia.x - MARGEM_TILES or ox > centro_tile.x + meia.x + MARGEM_TILES:
					continue
				if oy + CHUNK < centro_tile.y - meia.y - MARGEM_TILES or oy > centro_tile.y + meia.y + MARGEM_TILES:
					continue
				var chave := "%d|%d,%d" % [int(z), cx, cy]
				if _chunks.has(chave):
					manter[chave] = true
	return manter


func _stream() -> void:
	var meia := tiles_visiveis / 2.0
	var ret := Rect2i(floori((centro_tile.x - meia.x - MARGEM_TILES) / CHUNK), floori((centro_tile.y - meia.y - MARGEM_TILES) / CHUNK),
		floori((centro_tile.x + meia.x + MARGEM_TILES) / CHUNK), floori((centro_tile.y + meia.y + MARGEM_TILES) / CHUNK))
	if ret == _ret_chunks:
		return
	_ret_chunks = ret
	var manter := _chunks_desejados()
	# F (desempenho): o original monta os chunks novos de uma vez; aqui eles entram numa fila, os mais perto do
	# herói primeiro, e cada quadro gasta no máximo `orcamento_ms` montando/desmontando (a margem de 10 tiles dá tempo).
	_fila_descarregar = []
	for chave in _carregados.keys():
		if not manter.has(chave):
			_fila_descarregar.append(chave)
	var faltam: Array = []
	for chave in manter:
		if not _carregados.has(chave):
			faltam.append(chave)
	var c := centro_tile
	faltam.sort_custom(func(a, b): return _dist_chunk(a, c) < _dist_chunk(b, c))
	_fila_carregar = faltam
	if _primeira_carga:
		_primeira_carga = false
		_drenar(1.0e9)


func _dist_chunk(chave: String, c: Vector2) -> float:
	var partes := chave.split("|")
	var d := int(partes[0]) - ground_z
	var xy := partes[1].split(",")
	var centro := Vector2(int(xy[0]) * CHUNK + d + CHUNK / 2.0, int(xy[1]) * CHUNK + d + CHUNK / 2.0)
	return centro.distance_squared_to(c)


func _drenar(orcamento: float) -> void:
	var t0 := Time.get_ticks_usec()
	var adiados: Array = []
	while not _fila_carregar.is_empty() and (Time.get_ticks_usec() - t0) / 1000.0 < orcamento:
		var chave: String = _fila_carregar.pop_front()
		if _carregados.has(chave):
			continue
		if not _chunk_pronto(chave):
			adiados.append(chave)       # página ainda decodificando: volta para a fila
			continue
		_carregar_chunk(chave)
	_fila_carregar.append_array(adiados)
	while not _fila_descarregar.is_empty() and (Time.get_ticks_usec() - t0) / 1000.0 < orcamento:
		var chave: String = _fila_descarregar.pop_front()
		if _carregados.has(chave):
			_descarregar(chave)
	estatisticas["chunks"] = _carregados.size()


func _carregar_chunk(chave: String) -> void:
	var z := int(chave.split("|")[0])
	var andar: Dictionary = _andares[z]
	var a: Dictionary = andar["a"]
	var ids: PackedInt32Array = a["id"]
	var qs: PackedInt32Array = a["quadro"]
	var xs: PackedInt32Array = a["x"]
	var ys: PackedInt32Array = a["y"]
	var an: PackedByteArray = a["anim"]
	var lista: Array = []
	for i in _chunks[chave]:
		var asset: Dictionary = _assets[str(ids[i])]
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, andar["rid"])
		RenderingServer.canvas_item_set_draw_index(rid, 2 * i)
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		_desenhar_quadro(rid, asset, qs[i], xs[i], ys[i])
		if an[i] == 1:
			var com_padrao := int(asset.get("patternX", 0)) != 0 or int(asset.get("patternY", 0)) != 0
			_animados[rid] = {"a": asset, "i": qs[i], "base": qs[i] if com_padrao else 0,
				"len": int(asset.get("animLen", 1)) if com_padrao else (asset["frames"] as Array).size(),
				"t": 0.0, "x": xs[i], "y": ys[i], "z": z}
		lista.append(rid)
	_carregados[chave] = lista
	estatisticas["sprites_carregados"] = int(estatisticas["sprites_carregados"]) + lista.size()


func _descarregar(chave: String) -> void:
	for rid in _carregados[chave]:
		_animados.erase(rid)
		RenderingServer.free_rid(rid)
	estatisticas["sprites_carregados"] = int(estatisticas["sprites_carregados"]) - (_carregados[chave] as Array).size()
	_carregados.erase(chave)


func _desenhar_quadro(rid: RID, a: Dictionary, quadro: int, x: int, y: int) -> void:
	var f: Dictionary = a["frames"][quadro]
	var tex: Texture2D = _paginas[int(f["page"])]
	RenderingServer.canvas_item_clear(rid)
	RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(x, y, float(a["width"]), float(a["height"])),
		tex.get_rid(), Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"])))


func _animar(ms: float) -> void:
	## tick (C): só sprites de andares visíveis; ao vencer durationMs (padrão 150) zera o tempo e avança
	## i = base + (i − base + 1) % len.
	for rid in _animados:
		var s: Dictionary = _animados[rid]
		if float(_andares[s["z"]]["alpha"]) <= 0.001:
			continue
		s["t"] = float(s["t"]) + ms
		var frames: Array = s["a"]["frames"]
		var dur := float(frames[int(s["i"])].get("durationMs", 0))
		if dur <= 0.0:
			dur = DURACAO_QUADRO_PADRAO
		if float(s["t"]) >= dur:
			s["t"] = 0.0
			var base := int(s["base"])
			s["i"] = base + (int(s["i"]) - base + 1) % int(s["len"])
			_desenhar_quadro(rid, s["a"], int(s["i"]), int(s["x"]), int(s["y"]))


func _exit_tree() -> void:
	for pg in _decodificando:
		WorkerThreadPool.wait_for_task_completion(_decodificando[pg])
	_decodificando.clear()
	for chave in _carregados.keys():
		_descarregar(chave)
	for z in _andares:
		RenderingServer.free_rid(_andares[z]["rid"])
	_andares.clear()
