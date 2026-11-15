extends SceneTree
## Sombras (render/sombras.gd) contra o código ORIGINAL do cliente rodado no Node (ferramentas/render/referencia_sombras.js
## → saida_testes/ref_sombras_<slug>.json): a luz do mapa, quais sprites do mapa ganham sombra (mesma ordem) e a geometria
## de cada uma (posição dos pés, âncora, escala, skew, alpha, tint 0), e a sombra de uma criatura.
## Rodar: testes/test_render_sombras.sh [slug ...]

const Fontes := preload("res://sim/fontes.gd")
const DadosDesenho := preload("res://render/dados_desenho.gd")
const Sombras := preload("res://render/sombras.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


static func perto(a: float, b: float, tol: float = 1e-6) -> bool:
	return absf(a - b) <= tol


func _init() -> void:
	var slugs := OS.get_cmdline_user_args()
	if slugs.is_empty():
		slugs = PackedStringArray(["rhydon"])
	var dados = DadosDesenho.carregar()
	var assets: Dictionary = dados.manifest["assets"]
	for slug in slugs:
		var ref: Dictionary = Fontes.ler_json(Fontes.raiz_projeto() + "/saida_testes/ref_sombras_%s.json" % slug)
		var l := Sombras.luz(slug)
		var rl: Dictionary = ref["luz"]
		checar(perto(l["lonRad"], rl["lonRad"]) and perto(l["tanLat"], rl["tanLat"]) and perto(l["opacity"], rl["opacity"]) and perto(l["soft"], rl["soft"]),
			"%s: luz igual à do original (sb/sj)" % slug, str(l))
		var mapa := Fontes.ler_mapa(slug)
		var por_andar: Dictionary = dados.regras_para(mapa).montar(mapa["tiles"])
		var zs := por_andar.keys()
		zs.sort()
		zs.reverse()
		var nossas: Array = []
		for z in zs:
			for c in por_andar[z]:
				var a: Dictionary = assets[str(int(c[0]))]
				if Sombras.tem_sombra(float(c[4]), int(a["height"])):
					var f: Dictionary = a["frames"][int(c[1])]
					var g := Sombras.geometria_mapa(float(c[2]), float(c[3]), float(a["width"]), float(a["height"]), float(f["w"]), float(f["h"]), l)
					nossas.append([int(c[0]), int(c[1]), int(z), int(c[2]), int(c[3]), float(c[4])] + g)
		var deles: Array = ref["registro"]
		checar(nossas.size() == deles.size(), "%s: mesmo número de sombras" % slug, "%d × %d" % [nossas.size(), deles.size()])
		var primeira := -1
		for i in mini(nossas.size(), deles.size()):
			var a: Array = nossas[i]
			var b: Array = deles[i]
			var ok: bool = a[0] == int(b[0]) and a[1] == int(b[1]) and a[2] == int(b[2]) and a[3] == int(b[3]) and a[4] == int(b[4]) and perto(a[5], float(b[5]))
			for k in 7:
				ok = ok and perto(float(a[6 + k]), float(b[6 + k]))
			ok = ok and perto(float(b[13]), 1.0) and int(b[14]) == 0
			if not ok:
				primeira = i
				break
		checar(primeira < 0, "%s: mesmos sprites com sombra, na mesma ordem, e a mesma geometria (pés, âncora, escala, skew; alpha 1, tint 0)" % slug,
			"" if primeira < 0 else "1ª diferença na sombra %d: nossa %s × original %s" % [primeira, str(nossas[primeira]), str(deles[primeira])])
		var gc := Sombras.geometria_criatura(32.0 * 10 + 16, 32.0 * 7 + 16, 64.0, l)
		var rc: Array = ref["criatura"]
		var ok_c := true
		for k in 7:
			ok_c = ok_c and perto(float(gc[k]), float(rc[k]), 1e-4)
		checar(ok_c, "%s: sombra de criatura igual (feetBaseY, âncora 0,5/1, escala, skew)" % slug, "%s × %s" % [str(gc), str(rc)])
		# a matriz M e o retângulo dentro da camada levam os pés ao lugar certo e o topo para (+sen L, −cos L) × h × tanLat
		var m := Sombras.transformacao(l)
		var pes := Vector2(100.0, 200.0)
		var r := Sombras.retangulo(m.affine_inverse(), pes, 32.0, 64.0, 0.0)
		var pe_tela := m * Vector2(r.position.x, r.position.y + r.size.y)
		var topo_tela := m * r.position
		checar(pe_tela.distance_to(pes) < 1e-3 and topo_tela.distance_to(pes + Vector2(sin(l["lonRad"]), -cos(l["lonRad"])) * 64.0 * float(l["tanLat"])) < 1e-3,
			"%s: na camada, pés no lugar e topo inclinado como o skew do Pixi" % slug, "%s %s" % [str(pe_tela), str(topo_tela)])
	var lm := Sombras.luz("mt-moon")
	checar(perto(lm["tanLat"], tan(20.0 * PI / 180.0)) and perto(lm["opacity"], 0.3), "mt-moon/rock-tunnel: latitude 20, opacidade 0,3 (C)")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
