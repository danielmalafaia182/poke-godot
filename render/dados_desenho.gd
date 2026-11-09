extends RefCounted
## Carrega do snapshot (fonte A) tudo o que o desenho do mapa precisa: manifest do atlas de map-items
## (versão em asset-packs/version.json), draworder, offsets, colisão e o mapa da hunt. Monta as RegrasDesenho.
## As páginas do atlas (webp) são lidas sob demanda por `pagina()` e ficam em cache (ImageTexture).

const Fontes := preload("res://sim/fontes.gd")
const RegrasDesenho := preload("res://render/regras_desenho.gd")

var pasta_game := ""
var versao := ""
var manifest: Dictionary = {}
var paginas_url: Array = []          # índice -> caminho do arquivo da página
var _texturas: Dictionary = {}       # índice -> ImageTexture
var regras: RefCounted


static func carregar() -> RefCounted:
	var d = load("res://render/dados_desenho.gd").new()
	d.pasta_game = Fontes.pasta_snapshot() + "/game"
	var v: Dictionary = Fontes.ler_json(d.pasta_game + "/asset-packs/version.json")
	d.versao = String(v["version"])
	d.manifest = Fontes.ler_json("%s/asset-packs/categories/map-items-%s.json" % [d.pasta_game, d.versao])
	var cat: Dictionary = (d.manifest["categories"] as Dictionary).values()[0]
	for pg in cat["pages"]:
		d.paginas_url.append(d.pasta_game + "/asset-packs/" + String(pg["image"]).trim_prefix("/assets-packs/"))
	return d


func regras_para(mapa: Dictionary) -> RefCounted:
	var r = RegrasDesenho.new()
	r.configurar(manifest["assets"], Fontes.ler_json(pasta_game + "/draworder.json"),
		Fontes.ler_json(pasta_game + "/offsets.json"), Fontes.ler_json(pasta_game + "/collision.json"),
		mapa.get("_meta", {}))
	regras = r
	return r


func pagina(i: int) -> Texture2D:
	## Página do atlas como textura (webp sem perdas no snapshot). Sem filtro: o original desenha "nearest".
	if _texturas.has(i):
		return _texturas[i]
	var bytes := FileAccess.get_file_as_bytes(paginas_url[i])
	var img := Image.new()
	if img.load_webp_from_buffer(bytes) != OK:
		push_error("página do atlas ilegível: " + String(paginas_url[i]))
		return null
	var tex := ImageTexture.create_from_image(img)
	_texturas[i] = tex
	return tex


func paginas_usadas(por_andar: Dictionary) -> Array:
	var r := {}
	for z in por_andar:
		for c in por_andar[z]:
			var a: Dictionary = regras.assets[int(c[0])]
			for f in a["frames"]:
				r[int(f["page"])] = true
	var lista := r.keys()
	lista.sort()
	return lista
