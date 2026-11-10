extends SceneTree
## Diagnóstico (2b.6): em cada hunt, a que ilha (componente 8-conexa da grade transitável) pertencem o ponto inicial
## do herói e cada spawn do hunt-config. Uso: testes/rodar.sh res://testes/diag_ilhas.gd --slugs a,b  (sem --slugs: todas)
## Saída: uma linha DIAG_ILHAS {json} por hunt.

const MapaHunt := preload("res://sim/mapa_hunt.gd")
const Fontes := preload("res://sim/fontes.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var slugs: Array = []
	var i := a.find("--slugs")
	if i >= 0 and i + 1 < a.size():
		slugs = Array(a[i + 1].split(",", false))
	else:
		slugs = DadosJogo.carregar().hunts.keys()
		slugs.sort()
	var colisao := Fontes.ler_colisao()
	for s in slugs:
		var mapa = MapaHunt.carregar(s, Fontes.ler_mapa(s), colisao)
		var hc := Fontes.ler_hunt_config(s)
		var rot := _rotular(mapa)
		var ini: Dictionary = hc.get("start", {"x": 0, "y": 0})
		var ci: Vector2i = mapa.celula_de_tile(int(ini["x"]), int(ini["y"]))
		var ilha_heroi := _ilha(mapa, rot, ci)
		var mesma := 0
		var outras := 0
		var fora := 0
		for sp in hc.get("spawns", []):
			var c: Vector2i = mapa.celula_de_tile(int(sp["x"]), int(sp["y"]))
			var il := _ilha(mapa, rot, c)
			if il < 0:
				fora += 1
			elif il == ilha_heroi:
				mesma += 1
			else:
				outras += 1
		print("DIAG_ILHAS " + JSON.stringify({"slug": s, "ilha_heroi": ilha_heroi, "heroi_livre": ilha_heroi >= 0,
			"spawns_mesma_ilha": mesma, "spawns_outra_ilha": outras, "spawns_em_tile_bloqueado": fora}))
	quit(0)


func _ilha(mapa, rot: PackedInt32Array, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= mapa.cols or c.y >= mapa.rows:
		return -1
	return rot[c.y * mapa.cols + c.x]


func _rotular(mapa) -> PackedInt32Array:
	var rot := PackedInt32Array()
	rot.resize(mapa.rows * mapa.cols)
	rot.fill(-1)
	var n := 0
	for r in mapa.rows:
		for c in mapa.cols:
			if rot[r * mapa.cols + c] >= 0 or not mapa.passavel(r, c):
				continue
			var pilha: Array[Vector2i] = [Vector2i(c, r)]
			rot[r * mapa.cols + c] = n
			while not pilha.is_empty():
				var p: Vector2i = pilha.pop_back()
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var q := Vector2i(p.x + dx, p.y + dy)
						if q.x < 0 or q.y < 0 or q.x >= mapa.cols or q.y >= mapa.rows:
							continue
						var k: int = q.y * mapa.cols + q.x
						if rot[k] < 0 and mapa.passavel(q.y, q.x):
							rot[k] = n
							pilha.append(q)
			n += 1
	return rot
