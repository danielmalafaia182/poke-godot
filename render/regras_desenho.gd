extends RefCounted
## Regras de desenho do mapa stonegy-map-compact-v1 — porte literal (fonte C) de `buildTile`, `placeSprite` e
## `frameIndexFor` do cliente original (chunk 0gx72gz9qjk5j.js), no modo HD (sem "bake" de chunks): cada sprite sai
## com a posição em pixels e o zIndex que o PixiJS usaria para ordenar o andar.
## Conferido contra o próprio código JS (ferramentas/render/referencia_desenho.js) em testes/test_render_regras.gd.
##
## Resultado de `montar()`: Dictionary andar (z) -> Array de colocações, na ordem de inserção do original:
##   [asset_id, indice_quadro, x_px, y_px, z_index, animado(bool), tile_x, tile_y]
## A ordem final de desenho do andar é a ordenação estável por z_index (a do sortableChildren do Pixi).

# Constantes do chunk (C): itens nunca desenhados e itens de "cobertura baixa".
const NUNCA := {7124: true, 1510: true, 8274: true, 46638: true, 46639: true, 46620: true, 46621: true, 1511: true, 1024: true}
const COBERTURA_BAIXA := {60411: true, 60412: true, 60413: true, 60417: true, 60418: true, 60419: true, 60420: true,
	60421: true, 60422: true, 60414: true, 60415: true, 60416: true, 100013: true, 100014: true, 100015: true,
	60380: true, 100027: true}
const BANDA_ITENS := 1.0e7

var assets: Dictionary = {}        # id (int) -> asset do manifest {width, height, isGround, frames, patternX, ...}
var topo: Dictionary = {}          # draworder.top
var fundo: Dictionary = {}         # draworder.bottom
var bordas: Dictionary = {}        # draworder.borders
var bloqueio: Dictionary = {}      # collision.blocking
var disp: Dictionary = {}          # offsets.disp: id -> [dx, dy]
var elev: Dictionary = {}          # offsets.elev: id -> elevação em px
var centro := Vector2i.ZERO        # _meta.center do mapa
var cobertura_baixa: Dictionary = {}   # "x,y" -> z (markLowCover; nenhum no Rhydon)


static func sx(x: int, y: int) -> float:
	return float((x + y) * 4096 + 4 * x)


static func _conjunto(lista) -> Dictionary:
	var r := {}
	for v in lista if lista != null else []:
		r[int(v)] = true
	return r


func configurar(manifest_assets: Dictionary, draworder: Dictionary, offsets: Dictionary, colisao: Dictionary, meta: Dictionary) -> void:
	for k in manifest_assets:
		assets[int(k)] = manifest_assets[k]
	topo = _conjunto(draworder.get("top"))
	fundo = _conjunto(draworder.get("bottom"))
	bordas = _conjunto(draworder.get("borders"))
	bloqueio = _conjunto(colisao.get("blocking"))
	for k in offsets.get("disp", {}):
		disp[int(k)] = offsets["disp"][k]
	for k in offsets.get("elev", {}):
		elev[int(k)] = int(offsets["elev"][k])
	var c: Array = meta.get("center", [0, 0])
	centro = Vector2i(int(c[0]), int(c[1]))


static func ordenar_tiles(tiles: Array) -> Array:
	## Mesma ordem do buildWorld: z decrescente, depois y, depois x.
	var r := tiles.duplicate()
	r.sort_custom(func(a, b):
		if int(a[2]) != int(b[2]):
			return int(a[2]) > int(b[2])
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		return int(a[0]) < int(b[0]))
	return r


func montar(tiles: Array) -> Dictionary:
	var por_andar := {}
	for t in ordenar_tiles(tiles):
		var z := int(t[2])
		if not por_andar.has(z):
			por_andar[z] = []
		_montar_tile(t, por_andar[z])
	return por_andar


func indice_quadro(a: Dictionary, px: int, py: int) -> int:
	## frameIndexFor (C): quadro do padrão (patternX × patternY) pela posição absoluta no mundo.
	var pxn := int(a.get("patternX", 0))
	var pyn := int(a.get("patternY", 0))
	if pxn == 0 and pyn == 0:
		return 0
	var ax := pxn if pxn != 0 else 1
	var ny := pyn if pyn != 0 else 1
	var al := int(a.get("animLen", 1)) if int(a.get("animLen", 1)) != 0 else 1
	var l := centro.x + _js_round(float(px) / 32.0)
	var r := (posmod(centro.y + _js_round(float(py) / 32.0), ny) * ax + posmod(l, ax)) * al
	return r if r < (a["frames"] as Array).size() else 0


static func _js_round(v: float) -> int:
	return int(floor(v + 0.5))


func eh_animado(a: Dictionary) -> bool:
	## placeSprite (C): com padrão → anima se animLen > 1; sem padrão → se tem mais de um quadro e frameCount > 1.
	if int(a.get("patternX", 0)) != 0 or int(a.get("patternY", 0)) != 0:
		return int(a.get("animLen", 1)) > 1
	return (a["frames"] as Array).size() > 1 and int(a.get("frameCount", 1)) > 1


func _montar_tile(t: Array, saida: Array) -> void:
	var tx := int(t[0])
	var ty := int(t[1])
	var px := 32 * tx
	var py := 32 * ty
	var l := sx(tx, ty)
	var estado := {"r": 0, "o": l - 1.0}
	var itens: Array = t[4]
	var invertidos: Array = itens.duplicate()
	if itens.size() > 1:
		invertidos.reverse()
	var e_topo := func(id: int) -> bool: return topo.has(id)
	var e_chao := func(id: int) -> bool: return assets.has(id) and assets[id].get("isGround", false) == true
	var e_fundo := func(id: int) -> bool: return fundo.has(id) and not topo.has(id)
	var e_borda := func(id: int) -> bool: return bordas.has(id) and not topo.has(id) and not e_chao.call(id)
	var e_fundo_simples := func(id: int) -> bool: return e_fundo.call(id) and not e_borda.call(id) and not e_chao.call(id)
	var e_normal := func(id: int) -> bool: return not topo.has(id) and not fundo.has(id)
	var e_alto := func(id: int) -> bool: return bloqueio.has(id) or int(elev.get(id, 0)) > 0
	if int(t[3]) != 0:
		_colocar(int(t[3]), tx, ty, px, py, l, estado, saida)
	for it in itens:
		if e_fundo.call(int(it[0])) and e_chao.call(int(it[0])):
			_colocar(int(it[0]), tx, ty, px, py, l, estado, saida)
	for it in invertidos:
		if e_borda.call(int(it[0])):
			_colocar(int(it[0]), tx, ty, px, py, l, estado, saida)
	for it in itens:
		if e_fundo_simples.call(int(it[0])):
			_colocar(int(it[0]), tx, ty, px, py, l, estado, saida)
	for it in itens:
		if e_normal.call(int(it[0])) and e_alto.call(int(it[0])):
			_colocar(int(it[0]), tx, ty, px, py, l, estado, saida)
	for it in itens:
		if e_normal.call(int(it[0])) and not e_alto.call(int(it[0])):
			_colocar(int(it[0]), tx, ty, px, py, l, estado, saida)
	for it in invertidos:
		if e_topo.call(int(it[0])):
			_colocar(int(it[0]), tx, ty, px, py, l, estado, saida)


func _colocar(id: int, tx: int, ty: int, px: int, py: int, l: float, estado: Dictionary, saida: Array) -> void:
	## Função c(...) de buildTile + placeSprite (C).
	if NUNCA.has(id):
		return
	var a: Dictionary = assets.get(id, {})
	var tem := not a.is_empty()
	var chao: bool = tem and a.get("isGround", false) == true
	var banda_g := chao or (bordas.has(id) and not topo.has(id))
	var u: float = -1.0 if chao else (0.6 if topo.has(id) else (0.0 if fundo.has(id) else 0.3))
	var baixa := COBERTURA_BAIXA.has(id)
	var base_z := l
	if baixa and tem:
		var dd: Array = disp.get(id, [0, 0])
		var w := _sw(tx, ty, int(dd[0]), int(dd[1]), int(estado["r"]))
		base_z = sx(w.x, w.y)
	var f := base_z + u + (0.0 if banda_g else BANDA_ITENS)
	if not baixa:
		f = maxf(f, float(estado["o"]) + 0.001)
		estado["o"] = f
	# (markLowCover só afeta o zIndex de criaturas; registrado em cobertura_baixa — não ocorre no Rhydon)
	if not tem:
		return
	var w_px := int(a["width"])
	var h_px := int(a["height"])
	var d: Array = disp.get(id, [0, 0])
	var x := px - (w_px - 32) - int(d[0])
	var y := py - (h_px - 32) - int(d[1]) - int(estado["r"])
	saida.append([id, indice_quadro(a, px, py), x, y, f, eh_animado(a), tx, ty])
	estado["r"] = mini(32, int(estado["r"]) + int(elev.get(id, 0)))


static func _sw(x: int, y: int, t: int, a: int, n: int) -> Vector2i:
	return Vector2i(x - _js_round(float(t) / 32.0), y - _js_round(float(a + n) / 32.0))
