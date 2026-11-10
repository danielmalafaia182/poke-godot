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
## Atlas por mapa (2b.6, padrão): render/atlas_mapa.gd junta só os quadros usados pelo mapa numa textura única
## (cache em disco); todos os sprites do mapa usam essa textura e o GL junta os lotes. Sem ele (`usar_atlas_mapa =
## false`), vale o modo por páginas abaixo.
## Páginas do atlas (2b.6): as da tela são decodificadas em paralelo (WorkerThreadPool) e sobem na carga; as outras
## só quando um chunk da fila precisa delas (thread + upload de uma por quadro). Decodificar todas na carga foi testado
## e descartado: a sequência de uploads (~15–20 ms cada) virava uma rajada de dezenas de quadros lentos.
## `usar_array = true` (desligado) põe todas num Texture2DArray (paginas_array.gdshader): ~1000 → ~120 draw calls em
## Nightmare, mas medido a 1× o p99 empata (o gargalo era script) e a carga sobe ~1 s (espera todas as páginas e o
## upload de até 38 × 16 MB). Fica como opção.

const DadosDesenho := preload("res://render/dados_desenho.gd")
const CacheMapa := preload("res://render/cache_mapa.gd")
const AtlasMapa := preload("res://render/atlas_mapa.gd")
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
var _animados := {}         # rid -> {"a": asset, "i": quadro, "base": int, "len": int, "vence": ms, "x":, "y":, "z":}
var _relogio := {}          # z -> ms de animação do andar (só anda com o andar visível)
var _baldes := {}           # z -> {balde (vence / BALDE_MS) -> Array de RID}
var _balde_prox := {}       # z -> primeiro balde ainda não esvaziado
const BALDE_MS := 10.0
var _chao := {}             # "x,y,z" -> true (tile com chão), para o andar visível
var _ret_chunks := Rect2i()
var centro_tile := Vector2(0, 0)   # tile (fracionário) no centro da tela: o herói interpolado
var primeiro_andar_visivel := 0
var estatisticas := {"sprites_carregados": 0, "chunks": 0}
var perfil := {"drenar_us": 0, "animar_us": 0, "drenar_max_us": 0, "animar_max_us": 0, "n": 0, "animados": 0}
var orcamento_ms := 3.0            # tempo máximo por quadro montando/desmontando chunks
var _fila_carregar: Array = []
var _fila_descarregar: Array = []
var _primeira_carga := true
var _paginas: Dictionary = {}      # página -> Texture2D (pronta)
var _decodificando: Dictionary = {}  # página -> id da tarefa
var _imagens_prontas: Dictionary = {}  # página -> Image (vinda da thread)
var _mutex := Mutex.new()
var _caminhos_paginas: Array = []
static var usar_array := false
static var usar_atlas_mapa := true
var _tex_atlas: ImageTexture
var _rect_atlas := {}              # id * 4096 + quadro -> Vector2i (canto no atlas do mapa)
const LADO_CAMADA := 2048
var _camada := {}                  # página -> camada no array
var _array: Texture2DArray
var _branca: ImageTexture
var _material: ShaderMaterial


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
	for chave in _chunks_desejados(1.0):       # só o que aparece na tela; a margem chega pela fila
		for pg in _paginas_chunk.get(chave, PackedInt32Array()):
			perto[int(pg)] = true
	# 2b.6: TODAS as páginas do mapa vão para a decodificação em paralelo (WorkerThreadPool), as da tela primeiro;
	# a carga espera só as da tela e as sobe para a GPU; as outras sobem uma por quadro (_receber_paginas) logo depois
	# da carga, e durante o jogo não sobra upload (cada um custa milissegundos na thread principal). p90 = 32 páginas.
	if usar_atlas_mapa:
		var ta := Time.get_ticks_msec()
		var at: Dictionary = AtlasMapa.obter(slug, dados, c)
		_tex_atlas = ImageTexture.create_from_image(at["imagem"])
		var rs: PackedInt32Array = at["rects"]
		for i in range(0, rs.size(), 4):
			_rect_atlas[rs[i] * 4096 + rs[i + 1]] = Vector2i(rs[i + 2], rs[i + 3])
		for pg in paginas_necessarias():
			_paginas[int(pg)] = true          # nada a esperar: tudo está no atlas do mapa
		tempos_carga["atlas_ms"] = Time.get_ticks_msec() - ta
		tempos_carga["atlas_origem"] = String(at.get("origem", ""))
		tempos_carga["atlas_lado"] = [_tex_atlas.get_width(), _tex_atlas.get_height()]
		perto.clear()
	for pg in perto:
		_decodificar_em_fundo(int(pg))
	if usar_array and not usar_atlas_mapa:
		for pg in paginas_necessarias():
			_decodificar_em_fundo(int(pg))
		_montar_array()
	else:
		for pg in perto:
			_esperar_e_subir(int(pg))
	tempos_carga["paginas_iniciais"] = perto.size()
	tempos_carga["paginas_iniciais_ms"] = Time.get_ticks_msec() - t2
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
	var t0 := Time.get_ticks_usec()
	if not _fila_carregar.is_empty() or not _fila_descarregar.is_empty():
		_drenar(orcamento_ms)
	var t1 := Time.get_ticks_usec()
	if animacao_ligada:
		_animar(ms)
	var t2 := Time.get_ticks_usec()
	perfil["drenar_us"] += t1 - t0
	perfil["animar_us"] += t2 - t1
	perfil["drenar_max_us"] = maxi(int(perfil["drenar_max_us"]), t1 - t0)
	perfil["animar_max_us"] = maxi(int(perfil["animar_max_us"]), t2 - t1)
	perfil["n"] += 1
	perfil["animados"] = _animados.size()


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

func _montar_array() -> void:
	## Espera todas as páginas do mapa e monta o Texture2DArray (2048×2048 por camada, RGBA8).
	var imagens: Array[Image] = []
	var lista := paginas_necessarias()
	for pg in lista:
		if _decodificando.has(int(pg)):
			WorkerThreadPool.wait_for_task_completion(_decodificando[int(pg)])
			_decodificando.erase(int(pg))
	_mutex.lock()
	for pg in lista:
		var img: Image = _imagens_prontas.get(int(pg))
		if img == null:
			img = Image.create_empty(LADO_CAMADA, LADO_CAMADA, false, Image.FORMAT_RGBA8)
			push_error("página do atlas ilegível: %d" % int(pg))
		_camada[int(pg)] = imagens.size()
		imagens.append(img)
		_paginas[int(pg)] = true
	_imagens_prontas.clear()
	_mutex.unlock()
	if imagens.is_empty():
		imagens.append(Image.create_empty(LADO_CAMADA, LADO_CAMADA, false, Image.FORMAT_RGBA8))
	_array = Texture2DArray.new()
	_array.create_from_images(imagens)
	var b := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	b.fill(Color(1, 1, 1, 1))
	_branca = ImageTexture.create_from_image(b)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://render/paginas_array.gdshader")
	_material.set_shader_parameter("paginas", _array)
	for z in _andares:
		RenderingServer.canvas_item_set_material(_andares[z]["rid"], _material.get_rid())


func _esperar_e_subir(pg: int) -> void:
	## Espera a decodificação da página (thread) e cria a textura agora.
	if _paginas.has(pg) or not _decodificando.has(pg):
		return
	WorkerThreadPool.wait_for_task_completion(_decodificando[pg])
	_decodificando.erase(pg)
	_mutex.lock()
	var img = _imagens_prontas.get(pg)
	_imagens_prontas.erase(pg)
	_mutex.unlock()
	_subir(pg, img)


func _subir(pg: int, img) -> void:
	if _paginas.has(pg):
		return
	if img == null:
		push_error("página do atlas ilegível: %d" % pg)
		return
	var tex := ImageTexture.create_from_image(img)
	_paginas[pg] = tex
	if not dados._texturas.has(pg):
		dados._texturas[pg] = tex      # o mesmo cache que dados.pagina() usa (cadáveres, outros desenhos)


func _decodificar_em_fundo(pg: int) -> void:
	if _decodificando.has(pg) or _paginas.has(pg):
		return
	if not usar_array and dados._texturas.has(pg):           # já decodificada por outro desenho
		_paginas[pg] = dados._texturas[pg]
		return
	var caminho: String = _caminhos_paginas[pg]
	var para_array := usar_array
	_decodificando[pg] = WorkerThreadPool.add_task(func():
		var img := Image.new()
		var ok := img.load_webp_from_buffer(FileAccess.get_file_as_bytes(caminho)) == OK
		if ok and para_array:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			img.crop(LADO_CAMADA, LADO_CAMADA)    # completa até 2048×2048 (pixels novos transparentes)
		_mutex.lock()
		_imagens_prontas[pg] = img if ok else null
		_mutex.unlock())


func _receber_paginas() -> void:
	## No máximo UMA página por quadro vai para a GPU (criar a textura de 2046×2040 custa ~15 ms na thread principal).
	if _imagens_prontas.is_empty():
		return
	_mutex.lock()
	var pg: int = _imagens_prontas.keys()[0]
	var img = _imagens_prontas[pg]
	_imagens_prontas.erase(pg)
	_mutex.unlock()
	WorkerThreadPool.wait_for_task_completion(_decodificando[pg])
	_decodificando.erase(pg)
	_subir(pg, img)


func _chunk_pronto(chave: String) -> bool:
	for pg in _paginas_chunk.get(chave, PackedInt32Array()):
		if not _paginas.has(int(pg)):
			return false
	return true


# ------------------------------------------------------------------- streaming

func _chunks_desejados(margem: float = MARGEM_TILES) -> Dictionary:
	var meia := tiles_visiveis / 2.0
	var x0 := floori((centro_tile.x - meia.x - margem) / CHUNK)
	var x1 := floori((centro_tile.x + meia.x + margem) / CHUNK)
	var y0 := floori((centro_tile.y - meia.y - margem) / CHUNK)
	var y1 := floori((centro_tile.y + meia.y + margem) / CHUNK)
	var manter := {}
	for z in _andares:
		var d := int(z) - ground_z
		for cy in range(y0 - 1, y1 + 2):
			for cx in range(x0 - 1, x1 + 2):
				var ox := float(cx * CHUNK + d)
				var oy := float(cy * CHUNK + d)
				if ox + CHUNK < centro_tile.x - meia.x - margem or ox > centro_tile.x + meia.x + margem:
					continue
				if oy + CHUNK < centro_tile.y - meia.y - margem or oy > centro_tile.y + meia.y + margem:
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
		# 1ª montagem: só os chunks dentro da vista (+1 tile) de uma vez; os da margem de 10 tiles vão pela fila
		_primeira_carga = false
		var na_vista := _chunks_desejados(1.0)
		var resto: Array = []
		for chave in _fila_carregar:
			if na_vista.has(chave) and _chunk_pronto(chave):
				_carregar_chunk(chave)
			else:
				resto.append(chave)
		_fila_carregar = resto


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
			for pg in _paginas_chunk.get(chave, PackedInt32Array()):
				if not _paginas.has(int(pg)):
					_decodificar_em_fundo(int(pg))      # sob demanda, numa thread
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
		if usar_array and not usar_atlas_mapa:
			RenderingServer.canvas_item_set_use_parent_material(rid, true)
		_desenhar_quadro(rid, asset, qs[i], xs[i], ys[i])
		if an[i] == 1:
			var com_padrao := int(asset.get("patternX", 0)) != 0 or int(asset.get("patternY", 0)) != 0
			var sa := {"a": asset, "i": qs[i], "base": qs[i] if com_padrao else 0,
				"len": int(asset.get("animLen", 1)) if com_padrao else (asset["frames"] as Array).size(),
				"x": xs[i], "y": ys[i], "z": z}
			sa["vence"] = float(_relogio.get(z, 0.0)) + _duracao(asset, qs[i])   # t = 0 agora (C)
			_animados[rid] = sa
			_agendar(rid, sa)
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
	RenderingServer.canvas_item_clear(rid)
	if usar_atlas_mapa:
		var p: Vector2i = _rect_atlas.get(int(a["id"]) * 4096 + quadro, Vector2i(-1, -1))
		if p.x >= 0:
			RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(x, y, float(a["width"]), float(a["height"])),
				_tex_atlas.get_rid(), Rect2(float(p.x), float(p.y), float(f["w"]), float(f["h"])))
		return
	if usar_array:
		var ox := float(int(_camada[int(f["page"])]) * LADO_CAMADA)
		RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(x, y, float(a["width"]), float(a["height"])),
			_branca.get_rid(), Rect2(float(f["x"]) + ox, float(f["y"]), float(f["w"]), float(f["h"])))
		return
	var tex: Texture2D = _paginas[int(f["page"])]
	RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(x, y, float(a["width"]), float(a["height"])),
		tex.get_rid(), Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"])))


func _animar(ms: float) -> void:
	## tick (C): só sprites de andares visíveis; ao vencer durationMs (padrão 150) zera o tempo e avança
	## i = base + (i − base + 1) % len.
	## 2b.6 (desempenho, mesma regra): em vez de somar `ms` em cada sprite, cada andar tem um relógio que só anda
	## quando ele está visível; o sprite guarda quando vence (relógio no t = 0 + duração) e fica num balde de 10 ms.
	## A cada quadro só os baldes vencidos são visitados (antes: os ~2000 sprites animados de um mapa Nightmare).
	for z in _andares:
		if float(_andares[z]["alpha"]) <= 0.001:
			continue
		var c: float = float(_relogio.get(z, 0.0)) + ms
		_relogio[z] = c
		var baldes: Dictionary = _baldes.get(z, {})
		if baldes.is_empty():
			continue
		var kmax := floori(c / BALDE_MS)
		var k: int = int(_balde_prox.get(z, 0))
		while k <= kmax:
			if baldes.has(k):
				var lista: Array = baldes[k]
				baldes.erase(k)
				var resto: Array = []
				for rid in lista:
					var sp = _animados.get(rid)
					if sp == null or floori(float(sp["vence"]) / BALDE_MS) != k:
						continue                      # descarregado (ou reagendado): entrada velha
					if float(sp["vence"]) > c:
						resto.append(rid)             # mesmo balde, ainda não venceu
						continue
					var base := int(sp["base"])
					sp["i"] = base + (int(sp["i"]) - base + 1) % int(sp["len"])
					sp["vence"] = c + _duracao(sp["a"], int(sp["i"]))
					_desenhar_quadro(rid, sp["a"], int(sp["i"]), int(sp["x"]), int(sp["y"]))
					_agendar(rid, sp)
				if not resto.is_empty():
					var ja: Array = baldes.get(k, [])
					ja.append_array(resto)
					baldes[k] = ja
			k += 1
		_balde_prox[z] = kmax


func _duracao(asset: Dictionary, quadro: int) -> float:
	var dur := float((asset["frames"] as Array)[quadro].get("durationMs", 0))
	return dur if dur > 0.0 else DURACAO_QUADRO_PADRAO


func _agendar(rid: RID, sp: Dictionary) -> void:
	var z: int = sp["z"]
	if not _baldes.has(z):
		_baldes[z] = {}
	var b: Dictionary = _baldes[z]
	var k := floori(float(sp["vence"]) / BALDE_MS)
	if not b.has(k):
		b[k] = []
	b[k].append(rid)


func _exit_tree() -> void:
	for pg in _decodificando:
		WorkerThreadPool.wait_for_task_completion(_decodificando[pg])
	_decodificando.clear()
	for chave in _carregados.keys():
		_descarregar(chave)
	for z in _andares:
		RenderingServer.free_rid(_andares[z]["rid"])
	_andares.clear()
