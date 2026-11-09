extends RefCounted
## Interpolação de movimento do cliente original — porte literal (fonte C) de d$, dI, dE, dM, dS, dk, dy, dC, dL e dT
## (chunk 0gx72gz9qjk5j.js) e da correção de relógio pelo serverNow (dh/dc/dm). Estado de um ator = Dictionary
## {row, col, prevRow, prevCol, walkQueue, walkAnimStartMs, stepDurationMs, walking}. Tempos em ms do relógio local.
## Conferido contra o JS original em testes/test_render_interpolacao.sh.

# --- relógio (C): dc = Date.now() − serverNow suavizado; reinicia se pular mais de 2 s
var _dc := 0.0
var _dm := false


func ajustar_relogio(server_now: float, agora: float) -> void:
	if server_now <= 0.0:
		return
	var s := agora - server_now
	if not _dm or absf(s - _dc) > 2000.0:
		_dc = s
		_dm = true
		return
	_dc = 0.85 * _dc + (1.0 - 0.85) * s   # o chunk tem .15000000000000002 = 1 − 0,85 em double


func para_local(t_servidor: float, agora: float) -> float:
	## dh (C): instante do servidor no relógio local; sem valor válido → agora.
	if t_servidor <= 0.0:
		return agora
	return t_servidor + _dc if _dm else t_servidor


# --- funções puras (C)
static func novo(row: int, col: int, passo_ms: float, agora: float) -> Dictionary:
	return {"row": row, "col": col, "prevRow": row, "prevCol": col, "walkQueue": [], "walkAnimStartMs": agora,
		"stepDurationMs": passo_ms, "walking": false}


static func _igual(a: Dictionary, b: Dictionary) -> bool:
	return int(a["row"]) == int(b["row"]) and int(a["col"]) == int(b["col"])


static func _cheb(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a["row"]) - int(b["row"])), absi(int(a["col"]) - int(b["col"])))


static func fase(inicio: float, dur: float, agora: float) -> float:
	## dy
	return 1.0 if dur <= 0.0 else clampf((agora - inicio) / dur, 0.0, 1.0)


static func andando(e: Dictionary, agora: float) -> bool:
	## dk
	return (int(e["prevRow"]) != int(e["row"]) or int(e["prevCol"]) != int(e["col"])) \
		and fase(float(e["walkAnimStartMs"]), float(e["stepDurationMs"]), agora) < 1.0


static func duracao_passo(passo_ms: float, de: Dictionary, para: Dictionary) -> float:
	## dS: max(dr,dc) + min(dr,dc) passos (diagonal = 2×), mínimo 16 ms
	var a := absi(int(de["row"]) - int(para["row"]))
	var n := absi(int(de["col"]) - int(para["col"]))
	var i := maxi(a, n) + mini(a, n)
	return passo_ms if i <= 0 else maxf(16.0, float(roundi(passo_ms * i)))


static func _fila(fila: Array, de: Dictionary, para: Dictionary) -> void:
	## dC: caminho em linha (sign) de `de` até `para`
	var a := int(de["row"])
	var n := int(de["col"])
	while a != int(para["row"]) or n != int(para["col"]):
		a += signi(int(para["row"]) - a)
		n += signi(int(para["col"]) - n)
		var ult: Dictionary = fila.back() if not fila.is_empty() else {}
		if ult.is_empty() or int(ult["row"]) != a or int(ult["col"]) != n:
			fila.append({"row": a, "col": n})


static func _iniciar_passo(e: Dictionary, de: Dictionary, para: Dictionary, passo_ms: float, agora: float) -> void:
	## dL
	e["prevRow"] = int(de["row"])
	e["prevCol"] = int(de["col"])
	e["row"] = int(para["row"])
	e["col"] = int(para["col"])
	e["walkAnimStartMs"] = agora
	e["stepDurationMs"] = duracao_passo(passo_ms, de, para)
	e["walking"] = true


static func _manter(e: Dictionary, passo_ms: float, agora: float) -> void:
	## dM: terminou o passo → consome a fila
	if andando(e, agora):
		return
	if bool(e["walking"]):
		e["walking"] = false
		e["prevRow"] = int(e["row"])
		e["prevCol"] = int(e["col"])
		var fila: Array = e["walkQueue"]
		while not fila.is_empty():
			var prox: Dictionary = fila[0]
			var n := _cheb({"row": e["row"], "col": e["col"]}, prox)
			if n == 0 or n != 1:
				fila.pop_front()
				continue
			fila.pop_front()
			_iniciar_passo(e, {"row": e["row"], "col": e["col"]}, prox, passo_ms, agora)
			return
		return
	e["prevRow"] = int(e["row"])
	e["prevCol"] = int(e["col"])


static func _ir(e, row: int, col: int, passo_ms: float, agora: float, teleporte: bool) -> Dictionary:
	## dI
	var alvo := {"row": row, "col": col}
	if e == null:
		return novo(row, col, passo_ms, agora)
	if teleporte:
		e["walkQueue"] = []
		e["walking"] = false
		e["row"] = row
		e["col"] = col
		e["prevRow"] = row
		e["prevCol"] = col
		return e
	_manter(e, passo_ms, agora)
	var anda := andando(e, agora)
	var o := {"row": e["prevRow"], "col": e["prevCol"]} if anda else {"row": e["row"], "col": e["col"]}
	if _igual(o, alvo):
		return e
	var d := _cheb(o, alvo)
	if anda:
		e["walkQueue"] = []
		_fila(e["walkQueue"], {"row": e["row"], "col": e["col"]}, alvo)
		return e
	if d > 1:
		e["walkQueue"] = []
		_fila(e["walkQueue"], {"row": e["row"], "col": e["col"]}, alvo)
		var s: Dictionary = (e["walkQueue"] as Array).pop_front() if not (e["walkQueue"] as Array).is_empty() else {}
		if not s.is_empty():
			_iniciar_passo(e, {"row": e["row"], "col": e["col"]}, s, passo_ms, agora)
		return e
	_iniciar_passo(e, {"row": e["row"], "col": e["col"]}, alvo, passo_ms, agora)
	return e


func receber(e, ator: Dictionary, passo_ms: float, agora: float, teleporte: bool = false) -> Dictionary:
	## dT: estado do ator vindo num field {row, col, walkFrom, stepStartAt}
	var i := {"row": int(ator["row"]), "col": int(ator["col"])}
	var wf = ator.get("walkFrom")
	if wf is Dictionary and not _igual(wf, i):
		var m: Dictionary = e if e != null else novo(i["row"], i["col"], passo_ms, agora)
		_manter(m, passo_ms, agora)
		var o := {"row": m["prevRow"], "col": m["prevCol"]} if andando(m, agora) else {"row": m["row"], "col": m["col"]}
		if _igual(o, wf):
			var dur := duracao_passo(passo_ms, wf, i)
			var d := para_local(float(ator.get("stepStartAt", 0)), agora)
			var c := minf(d, agora) if d > 0.0 else agora
			m["prevRow"] = int(wf["row"])
			m["prevCol"] = int(wf["col"])
			m["row"] = i["row"]
			m["col"] = i["col"]
			m["walkAnimStartMs"] = c
			m["stepDurationMs"] = dur
			m["walkQueue"] = []
			m["walking"] = fase(c, dur, agora) < 1.0
			if not bool(m["walking"]):
				m["prevRow"] = i["row"]
				m["prevCol"] = i["col"]
			return m
		return _ir(m, i["row"], i["col"], passo_ms, agora, teleporte)
	return _ir(e, i["row"], i["col"], passo_ms, agora, teleporte)


static func posicao(e: Dictionary, agora: float) -> Vector2:
	## dE: (col, row) fracionários no instante `agora`
	if not andando(e, agora):
		return Vector2(float(e["col"]), float(e["row"]))
	var t := fase(float(e["walkAnimStartMs"]), float(e["stepDurationMs"]), agora)
	return Vector2(float(e["prevCol"]) + (float(e["col"]) - float(e["prevCol"])) * t,
		float(e["prevRow"]) + (float(e["row"]) - float(e["prevRow"])) * t)
