extends RefCounted
## Animação da Pokébola na hunt (ciclo 5; C: spawnCatchFx/tickCatchFx e a tabela `sl` do cliente; A: vídeo do usuário).
## Para cada catch-result: a bola voa do herói até o selvagem em 320 ms (folha throw/<bola>.png: 3×3 células de 32 px,
## a célula pela direção do arremesso em 8 setores) e, ao chegar, toca a folha da captura (sucesso: <bola>_catch.png,
## 60 quadros) ou da fuga (<bola>_broke.png, 44 quadros), quadros de 64×96 empilhados na vertical, 75 ms cada, âncora
## (0,5; 0,72), por cima de tudo. No 4º quadro o cadáver daquela casa some (C: removeCorpseAtTile).
## As folhas são as do original, já no projeto (assets/efeitos/captura). Master Ball: só a folha de captura (43 quadros).

const PASTA := "res://assets/efeitos/captura/"
const BOLAS := {1: ["pokeball", 60, 44, true], 2: ["greatball", 60, 44, true], 3: ["superball", 60, 44, true], 4: ["ultraball", 60, 44, true],
	5: ["masterball", 43, 0, false], 6: ["idleball", 60, 44, true], 7: ["idleball_gold", 60, 44, true]}   # C: sl
const QUADRO_MS := 75.0
const ARREMESSO_MS := 320.0
const CELULAS := [[1, 2], [2, 2], [2, 1], [2, 0], [1, 0], [0, 0], [0, 1], [0, 2]]   # C: o[r] = [linha, coluna]

var efeitos: Array = []   # {rid, de, para, ms, fase ("throw"/"catch"), folha, n, arremesso, celula, tile, cadaver_ok}
var _cache := {}


static func _tex(caminho: String) -> Texture2D:
	return load(caminho) if ResourceLoader.exists(caminho) else null


func iniciar(pai: RID, de_px: Vector2, para_px: Vector2, tile: Vector2i, bola: int, sucesso: bool) -> void:
	var b: Array = BOLAS.get(bola, [])
	if b.is_empty():
		return
	var nome := String(b[0])
	var folha := _tex(PASTA + nome + ("_catch" if sucesso or not bool(b[3]) else "_broke") + ".png")
	if folha == null:
		return
	var n := int(b[1]) if (sucesso or not bool(b[3])) else int(b[2])
	var arremesso: Texture2D = _tex(PASTA + "throw/" + nome + ".png") if bool(b[3]) else null
	var ang := atan2(para_px.y - de_px.y, para_px.x - de_px.x)
	var r := posmod(int(round(ang / (PI / 4.0))), 8)
	var rid := RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(rid, pai)
	RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	RenderingServer.canvas_item_set_z_index(rid, 4000)   # C: zIndex 1e9 (por cima de tudo no andar)
	efeitos.append({"rid": rid, "de": de_px, "para": para_px, "ms": 0.0, "fase": "throw" if arremesso != null else "catch",
		"folha": folha, "n": n, "arremesso": arremesso, "celula": CELULAS[r], "tile": tile, "cadaver_ok": false})


func atualizar(delta_ms: float, remover_cadaver: Callable) -> void:
	for i in range(efeitos.size() - 1, -1, -1):
		var e: Dictionary = efeitos[i]
		e["ms"] = float(e["ms"]) + delta_ms
		var rid: RID = e["rid"]
		RenderingServer.canvas_item_clear(rid)
		if String(e["fase"]) == "throw":
			var t := minf(1.0, float(e["ms"]) / ARREMESSO_MS)
			var pos: Vector2 = (e["de"] as Vector2).lerp(e["para"], t)
			var tex: Texture2D = e["arremesso"]
			var cel: Array = e["celula"]
			RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(pos - Vector2(16, 32 * 0.72), Vector2(32, 32)), tex.get_rid(),
				Rect2(int(cel[1]) * 32, int(cel[0]) * 32, 32, 32))
			if t >= 1.0:
				e["fase"] = "catch"
				e["ms"] = 0.0
			continue
		var q := int(float(e["ms"]) / QUADRO_MS)
		if q >= int(e["n"]):
			RenderingServer.free_rid(rid)
			efeitos.remove_at(i)
			continue
		if q >= 4 and not bool(e["cadaver_ok"]):
			e["cadaver_ok"] = true
			if remover_cadaver.is_valid():
				remover_cadaver.call(e["tile"])
		var p: Vector2 = e["para"]
		RenderingServer.canvas_item_add_texture_rect_region(rid, Rect2(p - Vector2(32, 96 * 0.72), Vector2(64, 96)), (e["folha"] as Texture2D).get_rid(),
			Rect2(0, q * 96, 64, 96))


func limpar() -> void:
	for e in efeitos:
		RenderingServer.free_rid(e["rid"])
	efeitos.clear()
