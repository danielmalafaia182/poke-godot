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

const VERSAO := 1
const FOLGA := 1
const LADO_MAX := 16384


static func caminho(slug: String) -> String:
	return CacheMapa.pasta_abs() + "/" + slug + ".atlas.bin"


static func _chave(slug: String, dados: RefCounted) -> String:
	return "%d|%s" % [VERSAO, CacheMapa.chave(slug, dados)]


static func valido(slug: String, dados: RefCounted) -> bool:
	## Só o cabeçalho (versão e chave), sem ler a imagem: para a fila de pré-aquecimento (EstadoJogo.pre_aquecer_atlas).
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
	var assets: Dictionary = dados.manifest["assets"]
	var quadros := quadros_usados(cache, assets)
	# páginas necessárias, decodificadas em paralelo
	var pags := {}
	for e in quadros:
		pags[int(assets[str(e[0])]["frames"][e[1]]["page"])] = true
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
	# prateleiras: mais altos primeiro
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
	var altura := mini(LADO_MAX, y + alt_prat)
	var img := Image.create_empty(largura, maxi(1, altura), false, Image.FORMAT_RGBA8)
	var rects := PackedInt32Array()
	for i in quadros.size():
		var fr: Dictionary = assets[str(quadros[i][0])]["frames"][quadros[i][1]]
		var p: Vector2i = pos[i]
		var origem: Image = imagens.get(int(fr["page"]))
		if origem != null:
			img.blit_rect(origem, Rect2i(int(fr["x"]), int(fr["y"]), int(fr["w"]), int(fr["h"])), p)
		rects.append_array([int(quadros[i][0]), int(quadros[i][1]), p.x, p.y])
	var d := {"versao": VERSAO, "chave": _chave(slug, dados), "w": img.get_width(), "h": img.get_height(), "rects": rects}
	DirAccess.make_dir_recursive_absolute(CacheMapa.pasta_abs())
	var f := FileAccess.open_compressed(caminho(slug), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f != null:
		f.store_var(d)
		f.store_buffer(img.get_data())
		f.close()
	d["imagem"] = img
	return d


static func obter(slug: String, dados: RefCounted, cache: Dictionary) -> Dictionary:
	var d := ler(slug, dados)
	if not d.is_empty():
		d["origem"] = "cache"
		return d
	d = montar(slug, dados, cache)
	d["origem"] = "montado"
	return d
