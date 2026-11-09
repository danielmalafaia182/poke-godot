extends RefCounted
## Carregador de outfits (sprites de criaturas) no formato do cliente original (fonte C, loadOutfit em 0wl3dp5-44hi8.js):
## outfits-index.json → manifest da categoria → página webp; cada asset "…/{quadro}_{_}_{_}_{dir}.png" vira
## por_dir[dir][quadro − 1] = {rect, dur}; "…_template.png" é a máscara de cores. dir: 1 norte, 2 leste, 3 sul,
## 4 oeste (dD, C). Quadro 0 = parado.
##
## Colorização (C, colorizeFrame/getOutfitColor): para outfit `colorizable`, cada pixel com máscara visível é
## multiplicado pela cor da parte — máscara amarela (R,G ≥ 200, B ≤ 80) = cabeça, vermelha = corpo, verde = pernas,
## azul = pés —, com as cores da paleta de 133 índices (HSV em 7 faixas). Feita uma vez por (looktype, cores).
##
## Procura primeiro no snapshot (A, coleta de 09/11) e depois no poke-local. Outfit sem arquivos → `substituto`
## (decisão E) e entra em `trocas` (relatório de faltantes).

const Fontes := preload("res://sim/fontes.gd")

const DIRECAO := {"north": 1, "east": 2, "south": 3, "west": 4}

var pastas: Array = []          # pastas "…/asset-packs"
var substituto := 200           # looktype usado quando o pedido não existe (E)
var _indice: Dictionary = {}    # looktype (String) -> entrada do outfits-index
var _cache: Dictionary = {}     # "looktype|cores" -> outfit carregado ou {} (ausente)
var trocas: Dictionary = {}     # looktype pedido -> looktype usado (para relatório)


static func padrao() -> RefCounted:
	var o = load("res://render/outfits.gd").new()
	var raiz := Fontes.raiz_projeto()
	o.pastas = [Fontes.pasta_snapshot() + "/game/asset-packs", raiz + "/poke-local/public/game/asset-packs"]
	for p in o.pastas:
		var idx = Fontes.ler_json(p + "/outfits-index.json") if FileAccess.file_exists(p + "/outfits-index.json") else null
		if idx is Dictionary:
			for k in idx.get("outfits", {}):
				if not o._indice.has(k):
					o._indice[k] = idx["outfits"][k]
	return o


func entrada(looktype: int) -> Dictionary:
	return _indice.get(str(looktype), {})


func existe(looktype: int) -> bool:
	return not _carregar(looktype, {}).is_empty()


func obter(looktype: int, cores: Dictionary = {}) -> Dictionary:
	## {looktype, largura, altura, por_dir {dir: [{tex, rect, dur}]}} — com substituto se preciso; {} se nem ele existe.
	var o := _carregar(looktype, cores)
	if o.is_empty() and looktype != substituto:
		trocas[looktype] = substituto
		o = _carregar(substituto, {})
	return o


func quadros(o: Dictionary, dir: int) -> int:
	## e2 (C): quantos quadros a direção tem.
	return (o.get("por_dir", {}).get(dir, []) as Array).size()


func quadro(o: Dictionary, dir: int, i: int) -> Dictionary:
	## e3 (C): (dir, i) → (dir, 0) → (sul, i) → (sul, 0).
	var pd: Dictionary = o.get("por_dir", {})
	for par in [[dir, i], [dir, 0], [3, i], [3, 0]]:
		var l: Array = pd.get(par[0], [])
		if int(par[1]) < l.size() and l[int(par[1])] != null:
			return l[int(par[1])]
	return {}


static func cor_outfit(e: int) -> Color:
	## getOutfitColor (C): índice 0..132 da paleta → cor (componentes floor(255·x)).
	if e >= 133:
		e = 0
	var t := 0.0
	var a := 0.0
	var r := 0.0
	if e % 19 != 0:
		t = float(e % 19) / 18.0
		a = 1.0
		r = 1.0
		match floori(e / 19.0):
			0: a = 0.25; r = 1.0
			1: a = 0.25; r = 0.75
			2: a = 0.5; r = 0.75
			3: a = 0.667; r = 0.75
			4: a = 1.0; r = 1.0
			5: a = 1.0; r = 0.75
			6: a = 1.0; r = 0.5
	else:
		t = 0.0
		a = 0.0
		r = 1.0 - float(e) / 19.0 / 7.0
	if r == 0.0:
		return Color8(0, 0, 0)
	if a == 0.0:
		var g := floori(255.0 * r)
		return Color8(g, g, g)
	var i := 0.0
	var n := 0.0
	var s := 0.0
	if t < 1.0 / 6.0:
		i = r; s = r * (1.0 - a); n = s + (r - s) * 6.0 * t
	elif t < 2.0 / 6.0:
		n = r; s = r * (1.0 - a); i = n - (r - s) * (6.0 * t - 1.0)
	elif t < 0.5:
		n = r; i = r * (1.0 - a); s = i + (r - i) * (6.0 * t - 2.0)
	elif t < 4.0 / 6.0:
		s = r; i = r * (1.0 - a); n = s - (r - i) * (6.0 * t - 3.0)
	elif t < 5.0 / 6.0:
		s = r; n = r * (1.0 - a); i = n + (r - n) * (6.0 * t - 4.0)
	else:
		i = r; n = r * (1.0 - a); s = i - (r - n) * (6.0 * t - 5.0)
	return Color8(floori(255.0 * i), floori(255.0 * n), floori(255.0 * s))


static func colorir(pagina: Image, base: Rect2i, template: Rect2i, cores: Dictionary) -> void:
	## colorizeFrame (C), no lugar, sobre a região `base` da imagem da página.
	var c := {"head": cor_outfit(int(cores.get("head", 0))), "body": cor_outfit(int(cores.get("body", 0))),
		"legs": cor_outfit(int(cores.get("legs", 0))), "feet": cor_outfit(int(cores.get("feet", 0)))}
	for y in base.size.y:
		for x in base.size.x:
			var m := pagina.get_pixel(template.position.x + x, template.position.y + y)
			if m.a8 <= 0:
				continue
			var cor = null
			if m.r8 >= 200 and m.g8 >= 200 and m.b8 <= 80:
				cor = c["head"]
			elif m.r8 >= 200 and m.g8 <= 80 and m.b8 <= 80:
				cor = c["body"]
			elif m.g8 >= 200 and m.r8 <= 80 and m.b8 <= 80:
				cor = c["legs"]
			elif m.b8 >= 200 and m.r8 <= 80 and m.g8 <= 80:
				cor = c["feet"]
			if cor == null:
				continue
			var p := pagina.get_pixel(base.position.x + x, base.position.y + y)
			# u[e] = u[e] * cor / 255 (o canvas guarda bytes: o resultado é truncado)
			pagina.set_pixel(base.position.x + x, base.position.y + y, Color8(
				int(p.r8 * (cor as Color).r8 / 255.0), int(p.g8 * (cor as Color).g8 / 255.0), int(p.b8 * (cor as Color).b8 / 255.0), p.a8))


func _carregar(looktype: int, cores: Dictionary) -> Dictionary:
	var e: Dictionary = _indice.get(str(looktype), {})
	var colorir_ := bool(e.get("colorizable", false)) and not cores.is_empty()
	var chave := "%d|%s" % [looktype, str(cores) if colorir_ else ""]
	if _cache.has(chave):
		return _cache[chave]
	var r := {}
	if not e.is_empty():
		for p in pastas:
			var man_path: String = p + "/" + String(e["manifest"]).trim_prefix("/assets-packs/")
			if not FileAccess.file_exists(man_path):
				continue
			var man: Dictionary = Fontes.ler_json(man_path)
			var cat: Dictionary = (man["categories"] as Dictionary).values()[0]
			var pg_path: String = p + "/" + String(cat["pages"][0]["image"]).trim_prefix("/assets-packs/")
			if not FileAccess.file_exists(pg_path):
				continue
			var img := Image.new()
			if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(pg_path)) != OK:
				continue
			var bases := {}
			var templates := {}
			var w := 32
			var h := 32
			for k in man["assets"]:
				var nome := String(k).get_file().trim_suffix(".png")
				var eh_t := nome.ends_with("_template")
				var partes := (nome.trim_suffix("_template")).split("_")
				var qi := int(partes[0])
				var di := int(partes[3])
				var a: Dictionary = man["assets"][k]
				var f: Dictionary = a["frames"][0]
				w = int(a["width"])
				h = int(a["height"])
				var rect := Rect2i(int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"]))
				if eh_t:
					templates["%d:%d" % [di, qi]] = rect
				else:
					bases["%d:%d" % [di, qi]] = {"rect": rect, "dur": float(f.get("durationMs", 150))}
			if colorir_:
				if img.is_compressed():
					img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				for k in bases:
					if templates.has(k):
						colorir(img, bases[k]["rect"], templates[k], cores)
			var tex := ImageTexture.create_from_image(img)
			var por_dir := {}
			for k in bases:
				var dq := String(k).split(":")
				var di := int(dq[0])
				var qi := int(dq[1])
				if not por_dir.has(di):
					por_dir[di] = []
				var l: Array = por_dir[di]
				while l.size() < qi:
					l.append(null)
				l[qi - 1] = {"tex": tex, "rect": Rect2(bases[k]["rect"]), "dur": bases[k]["dur"]}
			r = {"looktype": looktype, "largura": w, "altura": h, "por_dir": por_dir, "colorido": colorir_}
			break
	_cache[chave] = r
	return r
