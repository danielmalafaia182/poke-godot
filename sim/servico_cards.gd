extends RefCounted
## Álbum de Pokécards (ciclo 3). Puro e determinístico (semente no comando).
## Com fonte: as 430 cartas em 3 sets, com número, nome e raridade (A, snapshot game/pokecards.json, lido aqui do
## pacote em dados/gerados/pokecards.json); o item Poke Card Pack (A, itens.json 6352); o cliente (C): "Abre 1 Poke Card
## Pack da mochila: a carta sorteada vai direto pro álbum", posse ×N, "Descoberta em", filtros por set e raridade.
## Desenhado (classe 3, balanceamento.json "cards"): o peso de cada raridade no sorteio do pacote e a chance de o pacote
## cair num abate (a sim, `pack_chance_abate` em combate).
##
## Estado: album: {"<cardId>": {qtd, primeiro}}, itens {"6352": qtd} (BAG, ids do servidor)
## Comandos: album-get, pack-abrir {qtd, agora, semente}

const Rng := preload("res://sim/rng.gd")
const Balanceamento := preload("res://sim/balanceamento.gd")
const Fontes := preload("res://sim/fontes.gd")
const PACK_ID := 6352

const PARAMETROS := {"pesos_raridade": {"common": 60.0}}
var p: Dictionary = PARAMETROS.duplicate(true)
var sets: Array = []
var cartas: Array = []
var _por_raridade := {}


func _init(parametros: Dictionary = {}) -> void:
	Balanceamento.aplicar(p, "cards")
	for k in parametros:
		p[k] = parametros[k]
	var d = Fontes.ler_json(Fontes.pasta_dados() + "/gerados/pokecards.json")
	if d is Dictionary:
		sets = d.get("sets", [])
		cartas = d.get("cards", [])
	for c in cartas:
		var r := String(c["rarity"])
		if not _por_raridade.has(r):
			_por_raridade[r] = []
		_por_raridade[r].append(c)


func tratar(estado: Dictionary, cmd: Dictionary) -> Array:
	if not estado.has("album"):
		estado["album"] = {}
	if not estado.has("itens"):
		estado["itens"] = {}
	match String(cmd.get("type", "")):
		"album-get":
			return [msg_album(estado)]
		"pack-abrir":
			return _abrir(estado, int(cmd.get("qtd", 1)), int(cmd.get("agora", 0)), int(cmd.get("semente", 0)))
	return [{"type": "error", "message": "comando desconhecido"}]


func msg_album(estado: Dictionary) -> Dictionary:
	var al: Dictionary = estado["album"]
	return {"type": "album", "sets": sets, "total": cartas.size(), "obtidas": al.size(), "album": al.duplicate(true),
		"packs": int(estado["itens"].get(str(PACK_ID), 0))}


func sortear(rng) -> Dictionary:
	var pesos: Dictionary = p.pesos_raridade
	var soma := 0.0
	for r in _por_raridade:
		soma += float(pesos.get(r, 0.0))
	var x: float = rng.randf() * soma
	for r in _por_raridade.keys():
		x -= float(pesos.get(r, 0.0))
		if x <= 0.0:
			var l: Array = _por_raridade[r]
			return l[int(rng.randf() * l.size())]
	return cartas[0]


func _abrir(estado: Dictionary, qtd: int, agora: int, semente: int) -> Array:
	var tem := int(estado["itens"].get(str(PACK_ID), 0))
	if tem <= 0:
		return [{"type": "error", "message": "Sem pacotes."}]
	qtd = clampi(qtd, 1, tem)
	var rng = Rng.new(semente if semente != 0 else agora)
	var saiu: Array = []
	for i in qtd:
		var c := sortear(rng)
		var k := str(int(c["id"]))
		var e: Dictionary = estado["album"].get(k, {"qtd": 0, "primeiro": agora})
		var nova: bool = int(e["qtd"]) == 0
		e["qtd"] = int(e["qtd"]) + 1
		estado["album"][k] = e
		saiu.append({"id": int(c["id"]), "name": String(c["name"]), "rarity": String(c["rarity"]), "set": String(c["set"]), "num": int(c["num"]), "nova": nova})
	estado["itens"][str(PACK_ID)] = tem - qtd
	return [{"type": "pack-aberto", "cartas": saiu}, msg_album(estado)]
