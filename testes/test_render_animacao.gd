extends SceneTree
## 2b.6: a animação dos itens do mapa por agenda (baldes por vencimento, render/mapa_renderizador.gd `_animar`) dá
## o MESMO quadro, a cada quadro de tela, que a regra do cliente (tick, C) feita do jeito antigo: t += ms em cada
## sprite visível; t ≥ durationMs (padrão 150) → t = 0 e i = base + (i − base + 1) % len.
## Sprites entram em momentos diferentes, os quadros de tela têm duração aleatória e o andar some e volta.
## Rodar: testes/rodar.sh res://testes/test_render_animacao.gd

const Renderizador := preload("res://render/mapa_renderizador.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var r = Renderizador.new()
	var b := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	r._tex_atlas = ImageTexture.create_from_image(b)      # modo padrão: atlas por mapa (o desenho em si não importa aqui)
	r._andares = {7: {"alpha": 1.0, "rid": RID()}, 6: {"alpha": 1.0, "rid": RID()}}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# assets: durações variadas (inclui 0 = padrão 150, curtas < 10 ms e longas)
	var assets: Array = []
	for n in 6:
		var frames: Array = []
		for q in rng.randi_range(2, 6):
			var d: int = [0, 5, 80, 150, 200, 333, 1000][rng.randi_range(0, 6)]
			frames.append({"page": 0, "x": 0, "y": 0, "w": 32, "h": 32, "durationMs": d})
		assets.append({"id": 9000 + n, "frames": frames, "width": 32, "height": 32})
		for q in frames.size():
			r._rect_atlas[(9000 + n) * 4096 + q] = Vector2i(0, 0)
	var antigos := {}     # rid -> {"a", "i", "base", "len", "t", "z"} (regra antiga)
	var rids: Array = []
	var divergencias := 0
	var trocas := 0
	for quadro in 6000:
		# entra um sprite novo de vez em quando (como um chunk carregando), antes do _animar do quadro (como em _process)
		if quadro % 37 == 0 and rids.size() < 120:
			var rid := RenderingServer.canvas_item_create()
			var a: Dictionary = assets[rng.randi_range(0, assets.size() - 1)]
			var z: int = 7 if rng.randf() < 0.7 else 6
			var ini := rng.randi_range(0, (a["frames"] as Array).size() - 1)
			var com_padrao := rng.randf() < 0.3
			var base := ini if com_padrao else 0
			var ln := maxi(1, (a["frames"] as Array).size() - base) if com_padrao else (a["frames"] as Array).size()
			var sa := {"a": a, "i": ini, "base": base, "len": ln, "x": 0, "y": 0, "z": z}
			sa["vence"] = float(r._relogio.get(z, 0.0)) + r._duracao(a, ini)
			r._animados[rid] = sa
			r._agendar(rid, sa)
			antigos[rid] = {"a": a, "i": ini, "base": base, "len": ln, "t": 0.0, "z": z}
			rids.append(rid)
		# às vezes um sprite é descarregado (chunk saiu da margem)
		if quadro % 211 == 0 and rids.size() > 10:
			var sai: RID = rids.pop_at(rng.randi_range(0, rids.size() - 1))
			r._animados.erase(sai)
			antigos.erase(sai)
			RenderingServer.free_rid(sai)
		# o andar 6 some e volta (computeFirstVisibleFloor)
		if quadro % 500 == 0:
			r._andares[6]["alpha"] = 0.0 if float(r._andares[6]["alpha"]) > 0.5 else 1.0
		var ms := rng.randf_range(4.0, 40.0)
		r._animar(ms)
		# regra antiga
		for rid in antigos:
			var s: Dictionary = antigos[rid]
			if float(r._andares[s["z"]]["alpha"]) <= 0.001:
				continue
			s["t"] = float(s["t"]) + ms
			var dur := float(s["a"]["frames"][int(s["i"])].get("durationMs", 0))
			if dur <= 0.0:
				dur = 150.0
			if float(s["t"]) >= dur:
				s["t"] = 0.0
				s["i"] = int(s["base"]) + (int(s["i"]) - int(s["base"]) + 1) % int(s["len"])
				trocas += 1
		for rid in antigos:
			if int(antigos[rid]["i"]) != int(r._animados[rid]["i"]):
				divergencias += 1
	checar(trocas > 1000, "o teste exercita trocas de quadro", str(trocas))
	checar(divergencias == 0, "6000 quadros de tela: mesmo quadro de animação que a regra antiga em todos os sprites",
		"%d divergências" % divergencias)
	for rid in rids:
		RenderingServer.free_rid(rid)
	r.free()
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
