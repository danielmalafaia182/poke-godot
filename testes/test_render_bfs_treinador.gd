extends SceneTree
## 2b.6: a BFS do treinador com índices inteiros (render/estado_vista.gd `_bfs`) devolve exatamente o mesmo caminho
## que a versão anterior com chaves de texto (porte do cliente, C), em grades reais (field-init gravados) com
## selvagens aleatórios ocupando tiles, inclusive quando não há caminho. Rodar: testes/rodar.sh res://testes/test_render_bfs_treinador.gd

const EstadoVista := preload("res://render/estado_vista.gd")
const Fontes := preload("res://sim/fontes.gd")
const QUATRO := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _livre(grid: Array, p: Dictionary) -> bool:
	var r := int(p["row"])
	var c := int(p["col"])
	return r >= 0 and r < grid.size() and c >= 0 and c < (grid[r] as Array).size() and bool(grid[r][c])


func _igual(a: Dictionary, b: Dictionary) -> bool:
	return int(a["row"]) == int(b["row"]) and int(a["col"]) == int(b["col"])


func bfs_antiga(grid: Array, de: Dictionary, para: Dictionary, ocupado: Dictionary) -> Array:
	if not _livre(grid, de) or not _livre(grid, para):
		return []
	if _igual(de, para):
		return [de]
	var fila: Array = [de]
	var pai := {}
	var visto := {"%d,%d" % [int(de["row"]), int(de["col"])]: true}
	while not fila.is_empty():
		var s: Dictionary = fila.pop_front()
		for d in QUATRO:
			var o := {"row": int(s["row"]) + d.x, "col": int(s["col"]) + d.y}
			var k := "%d,%d" % [o["row"], o["col"]]
			if visto.has(k) or not _livre(grid, o):
				continue
			if ocupado.has(k) and not _igual(o, para):
				continue
			visto[k] = true
			pai[k] = s
			if _igual(o, para):
				var cam: Array = [o]
				var t = s
				while t != null:
					cam.push_front(t)
					t = pai.get("%d,%d" % [int(t["row"]), int(t["col"])])
				return cam
			fila.append(o)
	return []


func _iguais(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not _igual(a[i], b[i]):
			return false
	return true


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for slug in ["rhydon", "geodude", "blastoise"]:
		var fi: Dictionary = Fontes.ler_json(Fontes.raiz_projeto() + "/dados/testes/field_init_%s.json" % slug)
		var grid: Array = fi["grid"]
		var livres: Array = []
		for r in grid.size():
			for c in (grid[r] as Array).size():
				if bool(grid[r][c]):
					livres.append({"row": r, "col": c})
		var v = EstadoVista.new()
		var diferentes := 0
		var sem_caminho := 0
		for n in 400:
			var de: Dictionary = livres[rng.randi_range(0, livres.size() - 1)]
			var para: Dictionary = livres[rng.randi_range(0, livres.size() - 1)]
			if n % 3 == 0:            # destino perto (o caso comum do treinador)
				para = {"row": int(de["row"]) + rng.randi_range(-3, 3), "col": int(de["col"]) + rng.randi_range(-3, 3)}
			var ocupado := {}
			for k in rng.randi_range(0, 60):
				var m: Dictionary = livres[rng.randi_range(0, livres.size() - 1)]
				ocupado["%d,%d" % [int(m["row"]), int(m["col"])]] = true
			if n % 5 == 0:            # cerca o destino para forçar "sem caminho"
				for d in QUATRO:
					ocupado["%d,%d" % [int(para["row"]) + d.x, int(para["col"]) + d.y]] = true
			var a := bfs_antiga(grid, de, para, ocupado)
			var b: Array = v._bfs(grid, de, para, ocupado)
			var b2: Array = v._bfs(grid, de, para, ocupado)     # 2ª chamada no mesmo estado (cache de falha)
			if a.is_empty():
				sem_caminho += 1
			if not _iguais(a, b) or not _iguais(a, b2):
				diferentes += 1
		checar(diferentes == 0 and sem_caminho > 0, "%s: 400 buscas com o mesmo caminho da versão antiga" % slug,
			"%d diferentes, %d sem caminho" % [diferentes, sem_caminho])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
