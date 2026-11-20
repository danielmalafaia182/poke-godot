extends RefCounted
## Atlas por mapa (2b.6): só os quadros de sprite que o mapa usa (todos os quadros dos animados), copiados das páginas do
## atlas original para UMA imagem. Com isso todos os sprites do mapa usam a mesma textura e o GL Compatibility junta os
## lotes (com uma textura por página, cada troca de página na ordem de desenho custava uma draw call: ~2200 por quadro
## em electabuzz/magneton), e a carga sobe só alguns MB em vez de páginas de 2048² (mediana ~1700², máx. ~5300²).
## Os pixels são cópia exata (blit) dos quadros; 1 px transparente de folga entre quadros.
##
## Arquivo: res://cache/mapas/<slug>.atlas.bin (zstd; fora do git e do scan), válido para a mesma chave do cache do
## mapa (render/cache_mapa.gd) + VERSAO deste formato. Conteúdo (store_var):
##   versao, chave, w, h, rects (PackedInt32Array: id, quadro, x, y, …), e depois o buffer RGBA8 (store_buffer).

const CacheMapa := preload("res://render/cache_mapa.gd")
const Fontes := preload("res://sim/fontes.gd")

const VERSAO := 1
const FOLGA := 1
const LADO_MAX := 16384


static func caminho(slug: String) -> String:
	return CacheMapa.pasta_abs() + "/" + slug + ".atlas.bin"


static func _chave(slug: String, dados: RefCounted) -> String:
	return "%d|%s" % [VERSAO, CacheMapa.chave(slug, dados)]


static func valido(slug: String, dados: RefCounted) -> bool:
	## Só o cabeçalho (versão e chave), sem ler a imagem: para a fila de pré-aquecimento (EstadoJogo.pre_aquecer_atlas).
	_mutex_mem.lock()
	var na_memoria := _em_memoria.has(slug)
	_mutex_mem.unlock()
	if na_memoria:
		return true
	var c := caminho(slug)
	if not FileAccess.file_exists(c):
		return false
	var f := FileAccess.open_compressed(c, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var d = f.get_var()
	return d is Dictionary and int(d.get("versao", -1)) == VERSAO and String(d.get("chave", "")) == _chave(slug, dados)


static func ler(slug: String, dados: RefCounted) -> Dictionary:
	var c := caminho(slug)
	if not FileAccess.file_exists(c):
		return {}
	var f := FileAccess.open_compressed(c, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	var d = f.get_var()
	if not d is Dictionary or int(d.get("versao", -1)) != VERSAO or String(d.get("chave", "")) != _chave(slug, dados):
		return {}
	var w := int(d["w"])
	var h := int(d["h"])
	var px := f.get_buffer(w * h * 4)
	if px.size() != w * h * 4:
		return {}
	d["imagem"] = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)
	return d


static func caminho_quadros_pronto(slug: String) -> String:
	## Ciclo 4: o build leva a disposição do atlas de cada mapa pronta (lista de quadros, página e retângulo de origem e
	## posição no atlas): em tempo de jogo só sobra decodificar as páginas e copiar.
	return Fontes.pasta_snapshot() + "/cache/mapas/" + slug + ".quadros.bin"


static func _disposicao(quadros: Array, assets: Dictionary) -> Dictionary:
	## {largura, altura, q (id, quadro), o (página, x, y, w, h), p (x, y)} — as mesmas prateleiras do montar original.
	var ordem := range(quadros.size())
	ordem.sort_custom(func(a, b):
		var fa: Dictionary = assets[str(quadros[a][0])]["frames"][quadros[a][1]]
		var fb: Dictionary = assets[str(quadros[b][0])]["frames"][quadros[b][1]]
		return int(fa["h"]) > int(fb["h"]) or (int(fa["h"]) == int(fb["h"]) and a < b))
	var area := 0
	for e in quadros:
		var fr: Dictionary = assets[str(e[0])]["frames"][e[1]]
		area += (int(fr["w"]) + FOLGA) * (int(fr["h"]) + FOLGA)
	var largura := clampi(int(ceil(sqrt(float(area)) * 1.08 / 64.0)) * 64, 256, LADO_MAX)
	var pos := {}
	var x := 0
	var y := 0
	var alt_prat := 0
	for i in ordem:
		var fr: Dictionary = assets[str(quadros[i][0])]["frames"][quadros[i][1]]
		var w := int(fr["w"])
		var h := int(fr["h"])
		if x + w > largura:
			x = 0
			y += alt_prat + FOLGA
			alt_prat = 0
		pos[i] = Vector2i(x, y)
		x += w + FOLGA
		alt_prat = maxi(alt_prat, h)
	var q := PackedInt32Array()
	var o := PackedInt32Array()
	var pp := PackedInt32Array()
	for i in quadros.size():
		var fr: Dictionary = assets[str(quadros[i][0])]["frames"][quadros[i][1]]
		q.append_array([int(quadros[i][0]), int(quadros[i][1])])
		o.append_array([int(fr["page"]), int(fr["x"]), int(fr["y"]), int(fr["w"]), int(fr["h"])])
		pp.append_array([pos[i].x, pos[i].y])
	return {"largura": largura, "altura": mini(LADO_MAX, y + alt_prat), "q": q, "o": o, "p": pp}


static func disposicao_de(slug: String, dados: RefCounted, cache: Dictionary) -> Dictionary:
	var c := caminho_quadros_pronto(slug)
	if FileAccess.file_exists(c):
		var f := FileAccess.open_compressed(c, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if f != null:
			var d = f.get_var()
			if d is Dictionary and String(d.get("chave", "")) == _chave(slug, dados) and d.has("o"):
				return d
	var assets: Dictionary = dados.manifest["assets"]
	return _disposicao(quadros_usados(cache, assets), assets)


static func gravar_quadros(slug: String, dados: RefCounted, cache: Dictionary, destino: String) -> void:
	var assets: Dictionary = dados.manifest["assets"]
	var d := _disposicao(quadros_usados(cache, assets), assets)
	d["chave"] = _chave(slug, dados)
	var f := FileAccess.open_compressed(destino, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f != null:
		f.store_var(d)
		f.close()


static func quadros_usados(cache: Dictionary, assets: Dictionary) -> Array:
	## [[id, quadro], …] únicos, em ordem estável.
	var vistos := {}
	var lista: Array = []
	for z in cache["andares"]:
		var a: Dictionary = cache["andares"][z]
		var ids: PackedInt32Array = a["id"]
		var qs: PackedInt32Array = a["quadro"]
		var an: PackedByteArray = a["anim"]
		for i in ids.size():
			var id := ids[i]
			var n := (assets[str(id)]["frames"] as Array).size()
			var de := 0 if an[i] == 1 else qs[i]
			var ate := n if an[i] == 1 else qs[i] + 1
			for q in range(de, ate):
				var k := id * 4096 + q
				if not vistos.has(k):
					vistos[k] = true
					lista.append([id, q])
	return lista


static func montar(slug: String, dados: RefCounted, cache: Dictionary) -> Dictionary:
	## Lento (decodifica as páginas usadas, em paralelo): uma vez por mapa; grava o arquivo.
	var t := [Time.get_ticks_usec()]
	var disp := disposicao_de(slug, dados, cache)
	t.append(Time.get_ticks_usec())
	var o: PackedInt32Array = disp["o"]
	var pags := {}
	for k in range(0, o.size(), 5):
		pags[o[k]] = true
	var lista_pags: Array = pags.keys()
	var imagens := {}
	var mutex := Mutex.new()
	var urls: Array = dados.paginas_url
	var tarefa := WorkerThreadPool.add_group_task(func(i: int):
		var pg: int = lista_pags[i]
		var img := Image.new()
		if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(urls[pg])) == OK:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			mutex.lock()
			imagens[pg] = img
			mutex.unlock(), lista_pags.size())
	WorkerThreadPool.wait_for_group_task_completion(tarefa)
	t.append(Time.get_ticks_usec())
	var img := Image.create_empty(int(disp["largura"]), maxi(1, int(disp["altura"])), false, Image.FORMAT_RGBA8)
	var q: PackedInt32Array = disp["q"]
	var pp: PackedInt32Array = disp["p"]
	var rects := PackedInt32Array()
	rects.resize(q.size() * 2)
	for i in q.size() / 2:
		var origem: Image = imagens.get(o[i * 5])
		if origem != null:
			img.blit_rect(origem, Rect2i(o[i * 5 + 1], o[i * 5 + 2], o[i * 5 + 3], o[i * 5 + 4]), Vector2i(pp[i * 2], pp[i * 2 + 1]))
		rects[i * 4] = q[i * 2]
		rects[i * 4 + 1] = q[i * 2 + 1]
		rects[i * 4 + 2] = pp[i * 2]
		rects[i * 4 + 3] = pp[i * 2 + 1]
	t.append(Time.get_ticks_usec())
	var d := {"versao": VERSAO, "chave": _chave(slug, dados), "w": img.get_width(), "h": img.get_height(), "rects": rects}
	# Ciclo 4: a gravação (zstd de ~40 MB, ~170 ms) vai para segundo plano; o atlas fica em memória para esta sessão.
	DirAccess.make_dir_recursive_absolute(CacheMapa.pasta_abs())
	var cabecalho: Dictionary = d.duplicate()
	var dados_px := img.get_data()
	var destino := caminho(slug)
	var tid := WorkerThreadPool.add_task(func():
		var tmp := destino + ".tmp"
		var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if f != null:
			f.store_var(cabecalho)
			f.store_buffer(dados_px)
			f.close()
			DirAccess.rename_absolute(tmp, destino))
	_mutex_mem.lock()
	_gravacoes.append(tid)
	_mutex_mem.unlock()
	t.append(Time.get_ticks_usec())
	d["tempos_ms"] = {"quadros": (t[1] - t[0]) / 1000, "paginas": (t[2] - t[1]) / 1000, "blit": (t[3] - t[2]) / 1000, "gravar": (t[4] - t[3]) / 1000}
	d["imagem"] = img
	_mutex_mem.lock()
	_em_memoria[slug] = d
	_ordem_mem.erase(slug)
	_ordem_mem.append(slug)
	while _ordem_mem.size() > 2:   # só os 2 últimos (~40 MB cada): o resto já está (ou vai estar) no disco
		_em_memoria.erase(_ordem_mem.pop_front())
	_mutex_mem.unlock()
	return d


static var _em_memoria: Dictionary = {}   # slug -> o atlas montado nesta sessão (a gravação em disco é assíncrona)
static var _mutex_mem := Mutex.new()
static var _ordem_mem: Array = []
static var _gravacoes: Array = []   # tarefas de gravação em andamento (esperar_gravacoes ao fechar o jogo)


static func esperar_gravacoes() -> void:
	_mutex_mem.lock()
	var l := _gravacoes.duplicate()
	_gravacoes.clear()
	_mutex_mem.unlock()
	for tid in l:
		WorkerThreadPool.wait_for_task_completion(tid)


static func obter(slug: String, dados: RefCounted, cache: Dictionary) -> Dictionary:
	_mutex_mem.lock()
	var m: Dictionary = _em_memoria.get(slug, {})
	_mutex_mem.unlock()
	if not m.is_empty() and String(m.get("chave", "")) == _chave(slug, dados):
		var r := m.duplicate()
		r["origem"] = "memória"
		return r
	var d := ler(slug, dados)
	if not d.is_empty():
		d["origem"] = "cache"
		return d
	d = montar(slug, dados, cache)
	d["origem"] = "montado"
	return d
