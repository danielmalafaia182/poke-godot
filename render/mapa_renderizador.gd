extends Node2D
## Desenha o mapa original (stonegy-map-compact-v1) com o atlas de map-items do snapshot.
##
## Ordem e posições: render/regras_desenho.gd (porte literal do cliente, conferido contra o JS original).
## Desenho em lote via RenderingServer: um canvas item por sprite, filho do canvas item do andar, sem Node por tile.
## A ordem dentro do andar é o draw_index = posto do sprite na ordenação estável por zIndex (×2; os ímpares ficam para
## as entidades). Como no cliente (streamChunks/unloadChunk), só os chunks de 8×8 tiles perto da câmera existem.
## Andares: um por z, deslocados (z − groundZ)·32 px; o andar acima do herói some quando há chão sobre ele
## (computeFirstVisibleFloor, C), com o fade de 180 ms por unidade de alpha (tickFloorFade, C).

const DadosDesenho := preload("res://render/dados_desenho.gd")
const Fontes := preload("res://sim/fontes.gd")

const CHUNK := 8
const MARGEM_TILES := 10          # streamChunks (C): ±10 tiles além da metade da vista
const DURACAO_QUADRO_PADRAO := 150.0

var dados: RefCounted
var regras: RefCounted
var slug := ""
var ground_z := 7
var min_z := 0
var max_z := 0
var animacao_ligada := true
var tiles_visiveis := Vector2(25, 13)   # vista do original em zoom 1 ("25×13")

var _andares := {}          # z -> {"rid": RID, "colocacoes": Array, "z_ord": PackedFloat64Array, "posto": PackedInt32Array, "alpha": float}
var _chunks_tiles := {}     # "z|cx,cy" -> Array de índices de colocação daquele andar
var _carregados := {}       # chave -> Array de {rid, i, z}
var _animados := {}         # rid -> {"a": asset, "i": quadro, "base": int, "len": int, "t": ms, "x":, "y":, "z":}
var _tile_index := {}       # "x,y,z" -> true (tile com chão), para o andar visível
var _ret_chunks := Rect2i()
var centro_tile := Vector2(0, 0)   # tile (fracionário) no centro da tela: o herói interpolado
var primeiro_andar_visivel := 0
var estatisticas := {"sprites_carregados": 0, "chunks": 0}


func carregar(slug_mapa: String) -> void:
	slug = slug_mapa
	dados = DadosDesenho.carregar()
	var mapa := Fontes.ler_mapa(slug)
	regras = dados.regras_para(mapa)
	var meta: Dictionary = mapa.get("_meta", {})
	ground_z = int(meta.get("groundZ", (meta.get("range", [0, 0, 0, 0, 7]) as Array)[4]))
	var por_andar: Dictionary = regras.montar(mapa["tiles"])
	min_z = 1 << 30
	max_z = -(1 << 30)
	for t in mapa["tiles"]:
		if int(t[3]) != 0:
			_tile_index["%d,%d,%d" % [int(t[0]), int(t[1]), int(t[2])]] = true
		min_z = mini(min_z, int(t[2]))
		max_z = maxi(max_z, int(t[2]))
	var zs := por_andar.keys()
	zs.sort()
	zs.reverse()          # buildWorld (C): andares adicionados do maior z ao menor → o menor fica por cima
	for z in zs:
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, get_canvas_item())
		RenderingServer.canvas_item_set_transform(rid, Transform2D(0.0, Vector2((int(z) - ground_z) * 32, (int(z) - ground_z) * 32)))
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		var col: Array = por_andar[z]
		# posto = posição na ordenação estável por zIndex (empate → ordem de inserção, como o Array.sort do JS)
		var idx := range(col.size())
		idx.sort_custom(func(a, b):
			var za: float = col[a][4]
			var zb: float = col[b][4]
			return za < zb or (za == zb and a < b))
		var posto := PackedInt32Array()
		posto.resize(col.size())
		var z_ord := PackedFloat64Array()
		z_ord.resize(col.size())
		for r in idx.size():
			posto[idx[r]] = r
			z_ord[r] = col[idx[r]][4]
		_andares[int(z)] = {"rid": rid, "colocacoes": col, "z_ord": z_ord, "posto": posto, "alpha": 1.0}
		for i in col.size():
			var c: Array = col[i]
			var chave := "%d|%d,%d" % [int(z), floori(float(c[6]) / CHUNK), floori(float(c[7]) / CHUNK)]
			if not _chunks_tiles.has(chave):
				_chunks_tiles[chave] = []
			_chunks_tiles[chave].append(i)
	primeiro_andar_visivel = _primeiro_andar_visivel()
	for z in _andares:
		_aplicar_alpha(int(z), 1.0 if int(z) >= primeiro_andar_visivel else 0.0)


func paginas_necessarias() -> Array:
	var r := {}
	for z in _andares:
		for c in _andares[z]["colocacoes"]:
			for f in regras.assets[int(c[0])]["frames"]:
				r[int(f["page"])] = true
	var l := r.keys()
	l.sort()
	return l


func posto_entidade(z_index: float, z_andar: int = -999999) -> int:
	## draw_index de uma entidade (criatura, cadáver) no andar: 2 × (quantos sprites têm zIndex menor) − 1 + 2,
	## isto é, logo depois do último sprite estático com zIndex < z_index.
	var a: Dictionary = _andares.get(ground_z if z_andar == -999999 else z_andar, {})
	if a.is_empty():
		return 0
	return 2 * (a["z_ord"] as PackedFloat64Array).bsearch(z_index, true) + 1


func rid_andar(z: int = -999999) -> RID:
	var a: Dictionary = _andares.get(ground_z if z == -999999 else z, {})
	return a.get("rid", RID())


func definir_centro(tile: Vector2) -> void:
	## Herói (interpolado) no centro: atualiza streaming, cull e visibilidade de andares.
	centro_tile = tile
	_stream()
	var novo := _primeiro_andar_visivel()
	if novo != primeiro_andar_visivel:
		primeiro_andar_visivel = novo


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	# tickFloorFade (C): alpha anda 1/180 por ms rumo a 0/1
	for z in _andares:
		var alvo := 1.0 if int(z) >= primeiro_andar_visivel else 0.0
		var a: float = _andares[z]["alpha"]
		if a != alvo:
			a = minf(1.0, a + ms / 180.0) if alvo > a else maxf(0.0, a - ms / 180.0)
			_aplicar_alpha(int(z), a)
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
		if _tile_index.has("%d,%d,%d" % [sx + n, sy + n, a]):
			return a + 1
	return min_z


func _stream() -> void:
	var meia := tiles_visiveis / 2.0
	var x0 := floori((centro_tile.x - meia.x - MARGEM_TILES) / CHUNK)
	var x1 := floori((centro_tile.x + meia.x + MARGEM_TILES) / CHUNK)
	var y0 := floori((centro_tile.y - meia.y - MARGEM_TILES) / CHUNK)
	var y1 := floori((centro_tile.y + meia.y + MARGEM_TILES) / CHUNK)
	var ret := Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	if ret == _ret_chunks:
		return
	_ret_chunks = ret
	# os andares deslocados ((z − groundZ) tiles) também precisam dos chunks deslocados
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
				if _chunks_tiles.has(chave):
					manter[chave] = true
	for chave in _carregados.keys():
		if not manter.has(chave):
			_descarregar(chave)
	for chave in manter:
		if not _carregados.has(chave):
			_carregar_chunk(chave)
	estatisticas["chunks"] = _carregados.size()


func _carregar_chunk(chave: String) -> void:
	var z := int(chave.split("|")[0])
	var andar: Dictionary = _andares[z]
	var col: Array = andar["colocacoes"]
	var posto: PackedInt32Array = andar["posto"]
	var lista: Array = []
	for i in _chunks_tiles[chave]:
		var c: Array = col[i]
		var a: Dictionary = regras.assets[int(c[0])]
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, andar["rid"])
		RenderingServer.canvas_item_set_draw_index(rid, 2 * posto[i])
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		_desenhar_quadro(rid, a, int(c[1]), int(c[2]), int(c[3]))
		if bool(c[5]):
			var com_padrao := int(a.get("patternX", 0)) != 0 or int(a.get("patternY", 0)) != 0
			_animados[rid] = {"a": a, "i": int(c[1]), "base": int(c[1]) if com_padrao else 0,
				"len": int(a.get("animLen", 1)) if com_padrao else (a["frames"] as Array).size(),
				"t": 0.0, "x": int(c[2]), "y": int(c[3]), "z": z}
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
	var tex: Texture2D = dados.pagina(int(f["page"]))
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
	for chave in _carregados.keys():
		_descarregar(chave)
	for z in _andares:
		RenderingServer.free_rid(_andares[z]["rid"])
	_andares.clear()
