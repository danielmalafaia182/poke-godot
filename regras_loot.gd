extends RefCounted
# Catálogo de itens do inventário (materiais). Desde a fase 2b a base é o catálogo GERADO do snapshot
# (dados/gerados/itens.json, 670 itens, fonte A); o catálogo antigo (dados/referencias/loot_hunts.json, 183 itens do
# P04) entra por cima só para manter o que o save e a UI já usavam: ícones em res:// e as tabelas por espécie de
# `sortear` (cena antiga). Nada do catálogo antigo se perde: todo id dele continua existindo com o mesmo nome.
#
# Ids internos (convenção do P04, mantida para os saves antigos): o inventário separa material/poção/bola pelo id —
# material = está neste catálogo; senão ≥ 200 é poção e < 200 é bola. Por isso:
#   - ids originais 1..7 colidem com as bolas e viram 1.000.000 + id (Ancient Stone 2 → 1000002, como no P04);
#   - as poções do jogo (200..204, CATALOGO_POCOES) ficam fora deste catálogo (continuam sendo poções);
#   - o resto mantém o id original (o mesmo que o servidor manda no loot do field-kill).
# Probabilidades de `sortear`: política do protótipo offline; não afirmam reproduzir o RNG do servidor.

const GERADO := "res://dados/gerados/itens.json"
const ANTIGO := "res://dados/referencias/loot_hunts.json"
const DESLOCAMENTO := 1000000
const MAIOR_ID_BOLA := 7
const POCOES_DO_JOGO := [200, 201, 202, 203, 204]
const SNAPSHOT_RELATIVO := "poke har/extraido/snapshot_2026-11-09"

static var _dados: Dictionary = {}
static var _indice: Dictionary = {}
static var _lista: Array[Dictionary] = []
static var _texturas: Dictionary = {}


static func id_interno(original: int) -> int:
	return DESLOCAMENTO + original if original >= 1 and original <= MAIOR_ID_BOLA else original


static func id_original(interno: int) -> int:
	return interno - DESLOCAMENTO if interno > DESLOCAMENTO and interno <= DESLOCAMENTO + MAIOR_ID_BOLA else interno


static func _categoria(gerada: String) -> String:
	# E: "loot" e "stone" eram "Materials" no catálogo antigo; as demais categorias do gerado aparecem com o próprio nome
	return "Materials" if gerada in ["loot", "stone"] else gerada.capitalize()


static func _icone_snapshot(icone: String) -> String:
	var raiz := ProjectSettings.globalize_path("res://").trim_suffix("/") + "/" + SNAPSHOT_RELATIVO
	return raiz + (icone if icone.begins_with("/") else "/assets/items/" + icone)


static func _carregar() -> void:
	if not _dados.is_empty():
		return
	_dados = JSON.parse_string(FileAccess.get_file_as_string(ANTIGO))
	var antigos: Dictionary = {}
	for item in _dados["itens"]:
		antigos[int(item["id"])] = item
	var gerados: Array = JSON.parse_string(FileAccess.get_file_as_string(GERADO))
	for g in gerados:
		var orig := int(g["id"])
		if orig in POCOES_DO_JOGO:
			continue
		var id := id_interno(orig)
		var antigo: Dictionary = antigos.get(id, {})
		var item := {"id": id, "id_original": orig, "nome": String(g["nome"]),
			"categoria": String(antigo.get("categoria", _categoria(String(g.get("categoria", "loot"))))),
			"icone": String(antigo.get("icone", _icone_snapshot(String(g.get("icone", ""))))),
			"vinculado": bool(antigo.get("vinculado", false)), "raro": bool(g.get("raro", antigo.get("raro", false))),
			"chance_catalogo": antigo.get("chance_catalogo", 0), "minimo": antigo.get("minimo", 1), "maximo": antigo.get("maximo", 1),
			"preco_npc": int(g.get("precoNpc", 0))}
		_indice[id] = item
		_lista.append(item)
	# itens do catálogo antigo que não estejam no gerado (hoje nenhum): preservados como estavam
	for id in antigos:
		if not _indice.has(id):
			var item: Dictionary = antigos[id].duplicate(true)
			_indice[id] = item
			_lista.append(item)


static func catalogo() -> Array[Dictionary]:
	_carregar()
	var itens: Array[Dictionary] = []
	for item in _lista:
		itens.append(item.duplicate(true))
	return itens


static func ids() -> Array[int]:
	_carregar()
	var resultado: Array[int] = []
	for item in _lista:
		resultado.append(int(item["id"]))
	return resultado


static func obter(id: int) -> Dictionary:
	_carregar()
	return _indice.get(id, {}).duplicate(true)


static func textura(caminho: String) -> Texture2D:
	## Ícone de item: res:// (importado) ou arquivo do snapshot (png/webp lidos em tempo de execução).
	## GIF não é lido pelo Godot: esses (24 do catálogo) ficam sem ícone.
	if caminho == "":
		return null
	if _texturas.has(caminho):
		return _texturas[caminho]
	var tex: Texture2D = null
	if caminho.begins_with("res://"):
		if ResourceLoader.exists(caminho):
			tex = load(caminho) as Texture2D
	elif FileAccess.file_exists(caminho) and not caminho.ends_with(".gif"):
		var img := Image.new()
		var bytes := FileAccess.get_file_as_bytes(caminho)
		var ok := img.load_png_from_buffer(bytes) if caminho.ends_with(".png") else img.load_webp_from_buffer(bytes)
		if ok == OK:
			tex = ImageTexture.create_from_image(img)
	_texturas[caminho] = tex
	return tex


static func sortear(especie: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	_carregar()
	for item in _dados["especies"].get(especie, []):
		var chance: float = clampf(float(item["chance_catalogo"]) / 100000.0, 0, 1)
		if chance <= 0 or (chance < 1 and rng.randf() >= chance):
			continue
		resultado.append({"itemId": int(item["id"]), "name": str(item["nome"]), "qty": rng.randi_range(int(item["minimo"]), int(item["maximo"])), "icon": item["icone"], "rare": item["raro"]})
	return resultado
