extends SceneTree
## Metas visíveis (ciclo 2, classe 3): sim/metas.gd puro e a cidade (botão sempre à vista + painel), com save ISOLADO
## (rodar com testes/rodar.sh res://testes/test_metas.gd).

const Metas := preload("res://sim/metas.gd")
const Regras := preload("res://sim/regras.gd")
const B := preload("res://sim/balanceamento.gd")

var falhas := 0
var total := 0
var quadros := 0
var feito := false


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	_puro()
	get_root().get_node("EstadoJogo").iniciar_depot()
	change_scene_to_file("res://cidade.tscn")


func _puro() -> void:
	var dados = preload("res://ponte_cidade.gd").dados()
	var hl: Array = dados.hunts.values()
	var ivs := {"hp": 20, "atk": 20, "def": 20, "spAtk": 20, "spDef": 20, "speed": 20}
	checar(B.secao("metas").has("metas_fator_poder") and B.secao("metas").has("metas_marcos_nivel"), "balanceamento.json: seção metas (classe 3)")
	# treinador 1, Geodude 1: a recomendada é de Kanto nível 1 e a próxima meta existe
	var g1 := {"speciesId": 74, "xp": 0, "ivs": ivs, "quality": 1.1}
	var r1 := Metas.resumo(dados, hl, 0, g1, [])
	checar(String(r1["hunt"]["atual"].get("area", "")) == "kanto" and int(r1["hunt"]["atual"].get("nivel", -1)) == 1, "nível 1: recomenda uma hunt de Kanto nível 1", str(r1["hunt"]["atual"].get("slug")))
	checar(not (r1["hunt"]["proxima"] as Dictionary).is_empty() and int(r1["hunt"]["proxima"]["nivel_lider"]) > 1, "nível 1: há uma próxima meta à frente do líder")
	checar(int(r1["marco"]["proximo"]) == 10, "marco de nível: o primeiro é 10")
	# a recomendada é sempre liberada e aguentável
	var ok := true
	var det := ""
	for par in [[74, 5, 1], [75, 40, 40], [76, 100, 100], [76, 200, 170], [76, 400, 350]]:
		var l := {"speciesId": par[0], "xp": Regras.xp_total_para_nivel(par[1]), "ivs": ivs, "quality": 1.1}
		var r := Metas.recomendacao(dados, hl, par[2], l)
		var at: Dictionary = r["atual"]
		if at.is_empty() or int(dados.hunts[at["slug"]]["nivel"]) > par[2] or int(at["poder"]) > int(r["poder_lider"]):
			ok = false
			det += " %s" % str(par)
	checar(ok, "a recomendada é liberada (nível da hunt ≤ treinador, C) e o líder aguenta (Power)", det)
	# trecho 150–500: sem hunt nova, a meta é o salto na mesma hunt (golpe a menos) e os marcos 175, 200, 250…
	var g170 := {"speciesId": 76, "xp": Regras.xp_total_para_nivel(160), "ivs": ivs, "quality": 1.1}
	var r170 := Metas.resumo(dados, hl, Regras.xp_total_para_nivel(160), g170, [])
	checar(String(r170["hunt"]["atual"].get("area", "")) == "outland" and int(r170["marco"]["proximo"]) == 175, "treinador 160: recomenda Outland e o próximo marco é 175", str(r170["marco"]))
	var pr: Dictionary = r170["hunt"]["proxima"]
	checar(not pr.is_empty() and int(pr["nivel_lider"]) > 160 and int(pr["ganho_pct"]) >= 5, "treinador 160: próxima meta com nível do líder e ganho ≥ 5%", str(pr))
	checar(String(r170["hunt"]["regiao"].get("area", "")) == "orre", "treinador 160: mostra a próxima região (Orre, 500)")
	var co := Metas.colecao(dados, [74, 74, 19], hl, 10)
	checar(int(co["especies"]) == 2 and int(co["proximo"]) == 5 and int(co["liberadas_capturadas"]) <= int(co["liberadas_total"]), "coleção: espécies diferentes e o próximo marco", str(co))


func _process(_d: float) -> bool:
	quadros += 1
	if feito or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	feito = true
	var bm := current_scene.find_child("MetaAtual", true, false) as Button
	checar(bm != null and bm.visible and bm.text.begins_with("🎯"), "cidade: a próxima meta fica sempre à vista", bm.text if bm != null else "")
	var pm: Control = current_scene.get_node("Interface/PainelMetas")
	bm.pressed.emit()
	checar(pm.visible and pm.find_children("*", "Label", true, false).size() >= 6, "clique abre o painel de metas")
	checar(current_scene.find_child("Metas", true, false) != null, "botão Metas no ⚙")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
