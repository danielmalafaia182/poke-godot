extends RefCounted
## Grade transitável de uma hunt, derivada do mapa `stonegy-map-compact-v1` e de `collision.json`.
##
## Regra (C = extraída do cliente original, D = conferida contra as grades reais do servidor):
## - Retângulo da grade = caixa dos tiles **somente no andar `_meta.groundZ`** (D: bate rows/cols/minTx/minTy nas 7 hunts;
##   a caixa de todos os andares falha em rhydon, typhlosion e blastoise).
## - Tile transitável = existe tile em `groundZ` (C: `existing`), o chão e nenhum item estão em `blocking` (C: `blocked`),
##   e está dentro de `_meta.walk` = [minX, minY, maxX, maxY] (C: `walkable()`/`setWalkLimit`).
## - Sem filtro de alcançabilidade: o servidor manda também ilhas desconexas (D: rhyhorn tem 499 tiles fora do
##   componente do ponto inicial e o typhlosion começa num tile fora da grade).
## `col = x - min_tx`, `row = y - min_ty`.

var slug: String = ""
var ground_z: int = 7
var min_tx: int = 0
var min_ty: int = 0
var rows: int = 0
var cols: int = 0
var walk: Array = []          # [minX, minY, maxX, maxY] em coordenadas de tile
var centro: Array = []        # _meta.center (coordenadas absolutas do mundo original)
var grade: Array = []         # grade[row][col] -> bool
var transitaveis: int = 0


static func carregar(slug_hunt: String, mapa: Dictionary, colisao: Dictionary) -> RefCounted:
	var m: RefCounted = load("res://sim/mapa_hunt.gd").new()
	m._derivar(slug_hunt, mapa, colisao)
	return m


func _derivar(slug_hunt: String, mapa: Dictionary, colisao: Dictionary) -> void:
	slug = slug_hunt
	var meta: Dictionary = mapa.get("_meta", {})
	ground_z = int(meta.get("groundZ", (meta.get("range", [0, 0, 0, 0, 7]) as Array)[4]))
	centro = meta.get("center", [])
	var w: Array = meta.get("walk", [])
	walk = []
	for v in w:
		walk.append(int(v))
	var bloqueia := {}
	for id in colisao.get("blocking", []):
		bloqueia[int(id)] = true

	var tiles: Array = mapa.get("tiles", [])
	var ax := 1 << 30
	var ay := 1 << 30
	var bx := -(1 << 30)
	var by := -(1 << 30)
	var livres: Array = []   # [x, y] dos tiles transitáveis
	for t in tiles:
		if int(t[2]) != ground_z:
			continue
		var x := int(t[0])
		var y := int(t[1])
		ax = mini(ax, x); bx = maxi(bx, x)
		ay = mini(ay, y); by = maxi(by, y)
		if walk.size() == 4 and (x < walk[0] or x > walk[2] or y < walk[1] or y > walk[3]):
			continue
		if bloqueia.has(int(t[3])):
			continue
		var livre := true
		for item in t[4]:
			if bloqueia.has(int(item[0])):
				livre = false
				break
		if livre:
			livres.append([x, y])
	if bx < ax:
		rows = 0; cols = 0; grade = []
		return
	min_tx = ax
	min_ty = ay
	cols = bx - ax + 1
	rows = by - ay + 1
	grade = []
	for r in rows:
		var linha: Array = []
		linha.resize(cols)
		linha.fill(false)
		grade.append(linha)
	transitaveis = 0
	for p in livres:
		var linha: Array = grade[p[1] - min_ty]
		if not linha[p[0] - min_tx]:
			linha[p[0] - min_tx] = true
			transitaveis += 1


func passavel(row: int, col: int) -> bool:
	if row < 0 or col < 0 or row >= rows or col >= cols:
		return false
	return grade[row][col]


func celula_de_tile(x: int, y: int) -> Vector2i:
	## Vector2i(col, row)
	return Vector2i(x - min_tx, y - min_ty)
