extends SceneTree
## Regras de desenho portadas (render/regras_desenho.gd) contra o código ORIGINAL do cliente rodado no Node
## (ferramentas/render/referencia_desenho.js → saida_testes/ref_desenho_<slug>.json). Confere, sprite a sprite e na
## mesma ordem: asset, quadro, andar, x, y e zIndex. Rodar: testes/test_render_regras.sh [slug ...]

const Fontes := preload("res://sim/fontes.gd")
const DadosDesenho := preload("res://render/dados_desenho.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var slugs := OS.get_cmdline_user_args()
	if slugs.is_empty():
		slugs = PackedStringArray(["rhydon"])
	var dados = DadosDesenho.carregar()
	for slug in slugs:
		var ref: Dictionary = Fontes.ler_json(Fontes.raiz_projeto() + "/saida_testes/ref_desenho_%s.json" % slug)
		var mapa := Fontes.ler_mapa(slug)
		var regras = dados.regras_para(mapa)
		var t0 := Time.get_ticks_msec()
		var por_andar: Dictionary = regras.montar(mapa["tiles"])
		var ms := Time.get_ticks_msec() - t0
		var zs := por_andar.keys()
		zs.sort()
		zs.reverse()      # o original percorre os tiles do maior z para o menor
		var nossos: Array = []
		for z in zs:
			for c in por_andar[z]:
				nossos.append([int(c[0]), int(c[1]), int(z), int(c[2]), int(c[3]), float(c[4])])
		var deles: Array = ref["registro"]
		checar(nossos.size() == deles.size(), "%s: mesmo número de sprites" % slug, "%d × %d (%d ms)" % [nossos.size(), deles.size(), ms])
		var primeira := -1
		for i in mini(nossos.size(), deles.size()):
			var a: Array = nossos[i]
			var b: Array = deles[i]
			if a[0] != int(b[0]) or a[1] != int(b[1]) or a[2] != int(b[2]) or a[3] != int(b[3]) or a[4] != int(b[4]) \
					or absf(a[5] - float(b[5])) > 1e-6:
				primeira = i
				break
		checar(primeira < 0, "%s: asset, quadro, andar, x, y e zIndex idênticos, na mesma ordem" % slug,
			"" if primeira < 0 else "1ª diferença no sprite %d: nosso %s × original %s" % [primeira, str(nossos[primeira]), str(deles[primeira])])
		checar(regras.cobertura_baixa.size() == (ref["lowCoverZ"] as Array).size(), "%s: cobertura baixa igual" % slug)
		print("páginas do atlas usadas: ", dados.paginas_usadas(por_andar))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
