extends SceneTree
## Outfits: paleta de colorização igual à do cliente original (saida_testes/ref_cores.json, gerado pelo Node com o
## código original), treinador colorível com máscaras, e a lista de outfits que faltam no snapshot para as espécies
## das 451 hunts. Rodar: testes/test_outfits.sh  (grava saida_testes/outfits_faltando.json)

const Fontes := preload("res://sim/fontes.gd")
const Outfits := preload("res://render/outfits.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _init() -> void:
	var ref: Array = Fontes.ler_json(Fontes.raiz_projeto() + "/saida_testes/ref_cores.json")
	var dif := []
	for e in ref.size():
		var c := Outfits.cor_outfit(e)
		if c.r8 != int(ref[e][0]) or c.g8 != int(ref[e][1]) or c.b8 != int(ref[e][2]):
			dif.append(e)
	checar(dif.is_empty(), "paleta de cores (getOutfitColor) igual à do original nos índices 0..140", str(dif.slice(0, 5)))

	var o = Outfits.padrao()
	var tr: Dictionary = o.entrada(5759)
	var colorido: Dictionary = o.obter(5759, {"head": 94, "body": 95, "legs": 0, "feet": 0})
	var cru: Dictionary = o.obter(5759, {})
	checar(bool(tr.get("colorizable", false)) and bool(colorido.get("colorido", false)), "treinador 5759 é colorível e foi colorido")
	var q1: Dictionary = o.quadro(colorido, 3, 0)
	var q0: Dictionary = o.quadro(cru, 3, 0)
	var img1: Image = (q1["tex"] as Texture2D).get_image()
	var img0: Image = (q0["tex"] as Texture2D).get_image()
	var r: Rect2i = Rect2i(q1["rect"])
	var mudou := 0
	for y in r.size.y:
		for x in r.size.x:
			if img1.get_pixel(r.position.x + x, r.position.y + y) != img0.get_pixel(r.position.x + x, r.position.y + y):
				mudou += 1
	checar(mudou > 0, "colorização altera os pixels mascarados do quadro", "%d px" % mudou)

	# espécies das hunts (selvagens) e do time de teste
	var dados = DadosJogo.carregar()
	var faltando := {}
	var vistos := {}
	for slug in dados.hunts:
		var hc := Fontes.ler_hunt_config(String(slug))
		for s in hc.get("spawns", []):
			var sid := int(s["pokeId"])
			if vistos.has(sid):
				continue
			vistos[sid] = true
			var esp: Dictionary = dados.especies.get(sid, {})
			var lt := int(esp.get("looktype", 0))
			if lt <= 0 or not o.existe(lt):
				faltando[sid] = {"nome": esp.get("nome", "?"), "looktype": lt, "no_indice": not o.entrada(lt).is_empty()}
	for sid in [3, 74, 112]:
		var lt := int(dados.especies[sid]["looktype"])
		checar(o.existe(lt), "outfit real de %s (%d)" % [dados.especies[sid]["nome"], lt])
	print("espécies nas hunts: %d; sem outfit: %d" % [vistos.size(), faltando.size()])
	var f := FileAccess.open(Fontes.raiz_projeto() + "/saida_testes/outfits_faltando.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(faltando, " "))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
