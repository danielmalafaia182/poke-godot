extends RefCounted
## Carregador de outfits (sprites de criaturas) no formato do cliente original (fonte C, loadOutfit em 0wl3dp5-44hi8.js):
## outfits-index.json → manifest da categoria → página webp; cada asset "…/{quadro}_{_}_{_}_{dir}.png" vira
## por_dir[dir][quadro − 1] = {rect, dur}. dir: 1 norte, 2 leste, 3 sul, 4 oeste (dD, C). Quadro 0 = parado.
##
## Procura nas pastas de asset-packs na ordem dada (poke-local primeiro: é o que tem as páginas baixadas). Outfit que
## não existe localmente → `substituto` (decisão E do CLAUDE.md: um sprite só no offline). Quando os outfits forem
## baixados, basta colocá-los numa dessas pastas (ou acrescentar a pasta em `pastas`).
## Colorização (templates de head/body/legs/feet do treinador) ainda não portada: usa o quadro base.

const Fontes := preload("res://sim/fontes.gd")

const DIRECAO := {"north": 1, "east": 2, "south": 3, "west": 4}

var pastas: Array = []          # pastas "…/asset-packs"
var substituto := 200           # looktype usado quando o pedido não existe (E)
var _indice: Dictionary = {}    # looktype (String) -> entrada do outfits-index
var _cache: Dictionary = {}     # looktype -> outfit carregado ou {} (ausente)
var trocas: Dictionary = {}     # looktype pedido -> looktype usado (para relatório)


static func padrao() -> RefCounted:
	var o = load("res://render/outfits.gd").new()
	var raiz := Fontes.raiz_projeto()
	o.pastas = [raiz + "/poke-local/public/game/asset-packs", Fontes.pasta_snapshot() + "/game/asset-packs"]
	for p in o.pastas:
		var idx = Fontes.ler_json(p + "/outfits-index.json") if FileAccess.file_exists(p + "/outfits-index.json") else null
		if idx is Dictionary:
			for k in idx.get("outfits", {}):
				if not o._indice.has(k):
					o._indice[k] = idx["outfits"][k]
	return o


func obter(looktype: int) -> Dictionary:
	## {looktype, largura, altura, por_dir {dir: [{tex, rect, dur}]}} — com substituto se preciso; {} se nem ele existe.
	var o := _carregar(looktype)
	if o.is_empty() and looktype != substituto:
		trocas[looktype] = substituto
		o = _carregar(substituto)
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


func _carregar(looktype: int) -> Dictionary:
	if _cache.has(looktype):
		return _cache[looktype]
	var r := {}
	var e: Dictionary = _indice.get(str(looktype), {})
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
			var tex := ImageTexture.create_from_image(img)
			var por_dir := {}
			var w := 32
			var h := 32
			for chave in man["assets"]:
				var nome := String(chave).get_file().trim_suffix(".png")
				if nome.ends_with("_template"):
					continue
				var partes := nome.split("_")
				var qi := int(partes[0])
				var di := int(partes[3])
				var a: Dictionary = man["assets"][chave]
				var f: Dictionary = a["frames"][0]
				w = int(a["width"])
				h = int(a["height"])
				if not por_dir.has(di):
					por_dir[di] = []
				var l: Array = por_dir[di]
				while l.size() < qi:
					l.append(null)
				l[qi - 1] = {"tex": tex, "rect": Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"])),
					"dur": float(f.get("durationMs", 150))}
			r = {"looktype": looktype, "largura": w, "altura": h, "por_dir": por_dir}
			break
	_cache[looktype] = r
	return r
