extends RefCounted
## Laço por quadro do cliente original (fonte C, efeito do requestAnimationFrame no chunk 0gx72gz9qjk5j.js), portado:
## a partir do último `field` recebido, mantém os estados de interpolação do herói (N), do treinador (S) e de cada
## selvagem (C), com as mesmas regras de quando chamar dT/dI/dM, do treinador seguindo o tile anterior do herói (BFS
## 4 direções na grade, sem pisar em selvagem vivo), do selvagem morto parado onde caiu e do efeito de respawn (1,2 s).
## `quadro(agora)` devolve a vista: posições fracionárias (col/row da grade), direção, fase de passo.

const Interp := preload("res://render/interpolacao.gd")

const QUATRO := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]   # df (C): {dr, dc}

var it = Interp.new()
var init: Dictionary = {}          # field-init: grid, rows, cols, minTx, minTy, heroStepMs, mobStepMs, trainerStepMs
var field: Dictionary = {}         # F.current
var _hunt_key := ""
var N = null                       # herói
var S = null                       # treinador
var L := {}                        # último tile do herói visto
var T := {}                        # tile que o treinador persegue
var C := {}                        # slot -> estado do selvagem
var M := {}                        # slot -> último tile visto
var morto := {}                    # slot -> estava morto ($)
var onde_caiu := {}                # slot -> tile do cadáver (I)
var fx_respawn := {}               # slot -> até quando mostrar o efeito (E)
var todos_mortos := false          # P
var dir_heroi := "south"           # R
var dir_treinador := "south"       # B
var dir_mob := {}                  # A
var _escondido := false            # q (aba escondida)


func receber_init(msg: Dictionary) -> void:
	init = msg


func receber_field(msg: Dictionary, agora: float) -> void:
	## Equivale a guardar F.current e ajustar o relógio pelo serverNow (C).
	it.ajustar_relogio(float(msg.get("serverNow", 0)), agora)
	field = msg


func _passo_heroi() -> float:
	return float(field.get("stepMs", {}).get("hero", init.get("heroStepMs", 500))) if field.get("stepMs") is Dictionary \
		else float(init.get("heroStepMs", 500))


static func _tile(d) -> Dictionary:
	return {"row": int(d["row"]), "col": int(d["col"])}


static func _igual(a: Dictionary, b: Dictionary) -> bool:
	return int(a["row"]) == int(b["row"]) and int(a["col"]) == int(b["col"])


static func dj(e: Dictionary, s: Dictionary) -> String:
	var t := int(s["row"]) - int(e["row"])
	var a := int(s["col"]) - int(e["col"])
	if t == 0 and a == 0:
		return "south"
	if absi(a) >= absi(t):
		return "east" if a >= 0 else "west"
	return "south" if t >= 0 else "north"


static func _dir(e: Dictionary, s: Dictionary, t, a: String, n: bool) -> String:
	## dP
	if n and not _igual(e, s):
		return dj(e, s)
	return String(t) if t != null and String(t) != "" else a


func _livre(grid: Array, p: Dictionary) -> bool:
	## dw
	var r := int(p["row"])
	var c := int(p["col"])
	return r >= 0 and r < grid.size() and c >= 0 and c < (grid[r] as Array).size() and bool(grid[r][c])


func reiniciar(agora: float) -> void:
	var h := _tile(field["hero"])
	N = Interp.novo(h["row"], h["col"], _passo_heroi(), agora)
	S = Interp.novo(h["row"], h["col"], float(init.get("trainerStepMs", 500)), agora)
	L = h.duplicate()
	T = h.duplicate()
	C = {}
	M = {}
	morto = {}
	onde_caiu = {}
	fx_respawn = {}
	todos_mortos = bool(field.get("allMobsDead", false))
	for m in field.get("mobs", []):
		M[int(m["slot"])] = _tile(m)
		C[int(m["slot"])] = Interp.novo(int(m["row"]), int(m["col"]), float(m.get("stepMs", init.get("mobStepMs", 1000))), agora)
		morto[int(m["slot"])] = bool(m["dead"])


func quadro(agora: float) -> Dictionary:
	if field.is_empty():
		return {}
	if N == null:
		reiniciar(agora)
		_hunt_key = String(field.get("huntKey", init.get("huntKey", "")))
	var s := field
	var hk := String(s.get("huntKey", init.get("huntKey", "")))
	if hk != "" and hk != _hunt_key:
		_hunt_key = hk
		reiniciar(agora)
		todos_mortos = false
	var i := _tile(s["hero"])
	var l := L.is_empty() or not _igual(L, i)
	var wf = s["hero"].get("walkFrom")
	if l or (wf is Dictionary and not _igual(wf, i)):
		var t := L
		if not t.is_empty() and l and not _igual(t, i):
			T = t.duplicate()
		L = i.duplicate()
		N = it.receber(N, s["hero"], _passo_heroi(), agora, false)
	var r := bool(s.get("allMobsDead", false))
	if todos_mortos and not r:
		for m in s["mobs"]:
			var a := float(m.get("stepMs", init.get("mobStepMs", 1000)))
			C[int(m["slot"])] = Interp.novo(int(m["row"]), int(m["col"]), a, agora)
			onde_caiu.erase(int(m["slot"]))
			fx_respawn[int(m["slot"])] = agora + 1200.0
			M[int(m["slot"])] = _tile(m)
			morto[int(m["slot"])] = bool(m["dead"])
	todos_mortos = r
	for m in s["mobs"]:
		var slot := int(m["slot"])
		var a := _tile(m)
		var n = M.get(slot)
		var estava := bool(morto.get(slot, false))
		var passo := float(m.get("stepMs", init.get("mobStepMs", 1000)))
		if estava and not bool(m["dead"]):
			onde_caiu.erase(slot)
			fx_respawn[slot] = agora + 1200.0
			C[slot] = Interp.novo(a["row"], a["col"], passo, agora)
			M[slot] = a.duplicate()
			morto[slot] = false
			continue
		if bool(m["dead"]):
			if not estava:
				var e = C.get(slot)
				onde_caiu[slot] = {"row": e["row"], "col": e["col"]} if e != null else a.duplicate()
			var sp: Dictionary = onde_caiu.get(slot, a)
			C[slot] = it.receber(C.get(slot), {"row": sp["row"], "col": sp["col"], "facing": m.get("facing")}, passo, agora, true)
			M[slot] = sp.duplicate()
			morto[slot] = true
			continue
		var mudou_morte := estava != bool(m["dead"])
		var wfm = m.get("walkFrom")
		var d: bool = wfm is Dictionary and not _igual(wfm, a)
		if n == null or not _igual(n, a) or mudou_morte or d:
			M[slot] = a.duplicate()
			morto[slot] = bool(m["dead"])
			C[slot] = it.receber(C.get(slot), m, passo, agora, false)
	if N != null:
		Interp._manter(N, _passo_heroi(), agora)
	for m in s["mobs"]:
		var e = C.get(int(m["slot"]))
		if e != null:
			Interp._manter(e, float(m.get("stepMs", init.get("mobStepMs", 1000))), agora)
	var o := _tile(s["trainer"])
	if not _igual(o, i):
		T = o
	if S != null:
		_seguir(S, T, init.get("grid", []), s["mobs"], float(init.get("trainerStepMs", 500)), agora)
	# --- vista
	var hp := Interp.posicao(N, agora)
	var m_h := Interp.andando(N, agora) or not (N["walkQueue"] as Array).is_empty()
	var p := _dir({"row": N["prevRow"], "col": N["prevCol"]}, {"row": N["row"], "col": N["col"]},
		s["hero"].get("facing", s.get("heroDir")), dir_heroi, m_h)
	dir_heroi = p
	var tp := Interp.posicao(S, agora)
	var w := Interp.andando(S, agora) or not (S["walkQueue"] as Array).is_empty()
	var g := _dir({"row": S["prevRow"], "col": S["prevCol"]}, {"row": S["row"], "col": S["col"]},
		s["trainer"].get("facing"), dir_treinador, w)
	dir_treinador = g
	var alvo = null
	if s.get("targetSlot") != null:
		for m in s["mobs"]:
			if int(m["slot"]) == int(s["targetSlot"]):
				alvo = m
	var j = _tile(alvo) if alvo != null else null
	var mobs := {}
	for m in s["mobs"]:
		var slot := int(m["slot"])
		var e = C.get(slot)
		var pos: Vector2 = Interp.posicao(e, agora) if e != null else Vector2(float(m["col"]), float(m["row"]))
		var anda: bool = e != null and (Interp.andando(e, agora) or not (e["walkQueue"] as Array).is_empty()) and not bool(m["dead"])
		var dm := String(m.get("facing", dir_mob.get(slot, "south")))
		if e != null:
			dm = _dir({"row": e["prevRow"], "col": e["prevCol"]}, {"row": e["row"], "col": e["col"]},
				m.get("facing", s.get("mobDirs", {}).get(slot)), String(dir_mob.get(slot, "south")), anda)
		dir_mob[slot] = dm
		mobs[slot] = {"col": pos.x, "row": pos.y, "dir": dm, "walking": anda,
			"walkPhase": Interp.fase(float(e["walkAnimStartMs"]), float(e["stepDurationMs"]), agora) if e != null else 1.0,
			"diagonal": e != null and int(e["prevRow"]) != int(e["row"]) and int(e["prevCol"]) != int(e["col"]),
			"hp": m["hp"], "maxHp": m["maxHp"], "dead": m["dead"], "respawning": m.get("respawning", false),
			"speciesId": m["speciesId"], "shiny": m.get("shiny", false), "fxRespawn": float(fx_respawn.get(slot, 0.0)) > agora}
	var lutando := bool(s.get("fighting", false))
	return {
		"hero": {"col": hp.x, "row": hp.y, "dir": dj(i, j) if lutando and j != null else p,
			"walkPhase": Interp.fase(float(N["walkAnimStartMs"]), float(N["stepDurationMs"]), agora),
			"walking": m_h and not lutando,
			"diagonal": int(N["prevRow"]) != int(N["row"]) and int(N["prevCol"]) != int(N["col"])},
		"trainer": {"col": tp.x, "row": tp.y, "dir": g,
			"walkPhase": Interp.fase(float(S["walkAnimStartMs"]), float(S["stepDurationMs"]), agora),
			"walking": w and not lutando},
		"mobs": mobs, "heroFighting": lutando, "heroTile": i, "targetTile": j, "targetSlot": s.get("targetSlot")}


func _seguir(e: Dictionary, alvo: Dictionary, grid: Array, mobs: Array, passo: float, agora: float) -> void:
	## Treinador segue o tile anterior do herói (C): BFS 4 direções na grade evitando selvagens vivos; sem grade,
	## passo reto pelo eixo maior.
	if alvo.is_empty():
		return
	Interp._manter(e, passo, agora)
	if Interp.andando(e, agora):
		return
	var l := {"row": int(e["row"]), "col": int(e["col"])}
	if _igual(l, alvo):
		return
	var ocupado := {}
	for m in mobs:
		if not bool(m["dead"]) and not bool(m.get("respawning", false)):
			ocupado["%d,%d" % [int(m["row"]), int(m["col"])]] = true
	var o := {}
	if not grid.is_empty():
		var cam := _bfs(grid, l, alvo, ocupado)
		if cam.size() >= 2:
			o = cam[1]
	if o.is_empty():
		var dr := int(alvo["row"]) - int(l["row"])
		var dc := int(alvo["col"]) - int(l["col"])
		if absi(dr) + absi(dc) == 1:
			o = alvo.duplicate()
		elif absi(dr) >= absi(dc) and dr != 0:
			o = {"row": int(l["row"]) + signi(dr), "col": int(l["col"])}
		elif dc != 0:
			o = {"row": int(l["row"]), "col": int(l["col"]) + signi(dc)}
	if o.is_empty() or _igual(o, l):
		return
	if not grid.is_empty() and not _livre(grid, o):
		return
	if ocupado.has("%d,%d" % [int(o["row"]), int(o["col"])]):
		return
	Interp._iniciar_passo(e, l, o, passo, agora)


func _bfs(grid: Array, de: Dictionary, para: Dictionary, ocupado: Dictionary) -> Array:
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
