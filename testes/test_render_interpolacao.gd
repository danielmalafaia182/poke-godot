extends SceneTree
## Interpolação portada (render/interpolacao.gd) contra as funções ORIGINAIS do cliente rodadas no Node sobre fields
## reais (ferramentas/render/referencia_interpolacao.js → saida_testes/ref_interp.json). Confere cada amostra de
## posição (herói e selvagens, a cada 50 ms). Rodar: testes/test_render_interpolacao.sh

const Fontes := preload("res://sim/fontes.gd")
const Interp := preload("res://render/interpolacao.gd")
# Vector2 do Godot é float32: em ~53 tiles o passo de representação é ~4e-6. 1e-5 tile = 0,0003 px.
const TOLERANCIA := 1e-5


func _init() -> void:
	var ref: Dictionary = Fontes.ler_json(Fontes.raiz_projeto() + "/saida_testes/ref_interp.json")
	var it = Interp.new()
	var estados := {}
	var amostras: Array = ref["amostras"]
	var j := 0
	var difs := 0
	var max_dif := 0.0
	var primeira := ""
	var entradas: Array = ref["entradas"]
	for k in entradas.size():
		var en: Dictionary = entradas[k]
		var t := float(en["t"])
		it.ajustar_relogio(float(en["serverNow"]), t)
		for a in en["atores"]:
			var ator := {"row": int(a[1]), "col": int(a[2]), "walkFrom": a[3], "stepStartAt": float(a[4])}
			estados[a[0]] = it.receber(estados.get(a[0]), ator, float(a[5]), t)
		while j < amostras.size() and int(amostras[j][0]) == k:
			var s: Array = amostras[j]
			var p: Vector2 = Interp.posicao(estados[s[1]], float(s[2]))
			var d := maxf(absf(p.y - float(s[3])), absf(p.x - float(s[4])))
			if d > TOLERANCIA:
				difs += 1
				if primeira == "":
					primeira = "field %d, %s, t=%d: nosso (%.4f, %.4f) × original (%.4f, %.4f)" % [k, s[1], int(s[2]), p.y, p.x, float(s[3]), float(s[4])]
			max_dif = maxf(max_dif, d)
			j += 1
	var ok := difs == 0 and j == amostras.size()
	print(("OK    " if ok else "FALHA ") + "interpolação igual ao original (tol. 1e-5 tile) em %d amostras de %d fields (máx. diferença %.9f)%s" % [j, entradas.size(), max_dif, "" if primeira == "" else "  1ª: " + primeira])
	print("RESULTADO: %d/1" % (1 if ok else 0))
	quit(0 if ok else 1)
