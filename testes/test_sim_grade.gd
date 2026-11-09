extends SceneTree
## Aceitação da derivação de colisão: a grade derivada do snapshot tem de ser idêntica à grade que o servidor
## original mandou no `field-init` (dados/testes/field_init_<slug>.json) — rows, cols, minTx, minTy e cada tile.
## Rodar: testes/rodar.sh res://testes/test_sim_grade.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const HUNTS := ["geodude", "rhyhorn", "rhydon", "kangaskhan", "typhlosion", "blastoise", "rattata"]


func _init() -> void:
	var falhas := 0
	if Fontes.pasta_snapshot() == "":
		print("FALHA: snapshot não encontrado (defina POKE_SNAPSHOT)")
		quit(1)
		return
	var colisao: Dictionary = Fontes.ler_colisao()
	for slug in HUNTS:
		var ref: Dictionary = Fontes.ler_json(Fontes.pasta_dados() + "/testes/field_init_%s.json" % slug)
		var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), colisao)
		var erros: Array = []
		for campo in [["rows", mapa.rows], ["cols", mapa.cols], ["minTx", mapa.min_tx], ["minTy", mapa.min_ty]]:
			if int(ref[campo[0]]) != int(campo[1]):
				erros.append("%s: real %d, derivado %d" % [campo[0], int(ref[campo[0]]), int(campo[1])])
		var difs := 0
		var reais := 0
		var exemplo := ""
		if erros.is_empty():
			var g: Array = ref["grid"]
			for r in mapa.rows:
				for c in mapa.cols:
					var real: bool = g[r][c]
					if real:
						reais += 1
					if real != mapa.grade[r][c]:
						difs += 1
						if exemplo == "":
							exemplo = " primeiro em row %d col %d (real %s)" % [r, c, real]
			if difs > 0:
				erros.append("%d tiles diferentes%s" % [difs, exemplo])
		if erros.is_empty():
			print("OK    %-11s %dx%d minTx %d minTy %d, %d tiles transitáveis iguais" % [slug, mapa.rows, mapa.cols, mapa.min_tx, mapa.min_ty, reais])
		else:
			falhas += 1
			print("FALHA %-11s %s" % [slug, "; ".join(erros)])
	print("RESULTADO: %d/%d hunts idênticas" % [HUNTS.size() - falhas, HUNTS.size()])
	quit(0 if falhas == 0 else 1)
