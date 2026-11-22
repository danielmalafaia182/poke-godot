extends SceneTree
## Fase 4, lote 3 — itens de uso na cena da cidade, com save ISOLADO (rodar com testes/rodar.sh):
##   janela "Usar itens" → Rare Candy no líder (+1 nível) → berry de Pedra (30 min) → save → recarga → a hunt recebe as
##   berries ativas (cfg.berries).

const LOOT: Script = preload("res://regras_loot.gd")

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
	var ej = get_root().get_node("EstadoJogo")
	ej.iniciar_depot()
	ej.inventario.estoque_materiais[LOOT.id_interno(90124)] = 3
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if feito or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	feito = true
	var ej = get_root().get_node("EstadoJogo")
	var sv = ej.servico_itens()
	var rocha := -1
	for id in preload("res://ponte_cidade.gd").dados().itens:
		var ef: Dictionary = sv.efeito_berry(int(id))
		if not ef.is_empty() and String(ef["efeito"]) == "ROCK":
			rocha = int(id)
			break
	ej.inventario.estoque_materiais[LOOT.id_interno(rocha)] = 1
	var painel: Control = current_scene.get_node("Interface/PainelItensUso")
	checar(painel != null and current_scene.find_child("ItensUso", true, false) != null, "botão e janela Usar itens na cidade (⚙)")
	painel.abrir()
	var lider: DadosPokemon = ej.obter_lider()
	var nivel0: int = lider.nivel
	(painel.find_child("Item_90124", true, false) as Button).pressed.emit()
	var bp := painel.find_child("Poke_" + lider.id_persistente, true, false) as Button
	checar(bp != null, "Rare Candy escolhido: lista o time")
	bp.pressed.emit()
	checar(lider.nivel == nivel0 + 1 and int(ej.inventario.estoque_materiais.get(LOOT.id_interno(90124), 0)) == 2
		and int(ej.itens_uso["candy"].get(lider.id_persistente, 0)) == 1, "candy: líder +1 nível, 2 candies na BAG, 1/10 usado", "%d → %d" % [nivel0, lider.nivel])
	(painel.find_child("Item_%d" % rocha, true, false) as Button).pressed.emit()
	(painel.find_child("Poke_" + lider.id_persistente, true, false) as Button).pressed.emit()
	var at: Dictionary = ej.berries_ativas(int(Time.get_unix_time_from_system()))
	checar(at.has(lider.id_persistente) and String(at[lider.id_persistente][0]["efeito"]) == "ROCK", "berry de Pedra ativa no líder")
	# ciclo 6 (lote 3): TM Researcher, TM no líder, Held Machine e held equipado, pela janela
	ej.inventario.estoque_materiais[LOOT.id_interno(59194)] = 12
	ej.inventario.estoque_materiais[LOOT.id_interno(13115)] = 20
	painel.atualizar()
	(painel.find_child("TM_GRASS", true, false) as Button).pressed.emit()
	checar(int(ej.inventario.estoque_materiais.get(LOOT.id_interno(59203), 0)) == 1 and int(ej.inventario.estoque_materiais.get(LOOT.id_interno(59194), 0)) == 2,
		"TM Researcher na janela: 10 peças → Grass-Type TM Disk")
	(painel.find_child("Item_59203", true, false) as Button).pressed.emit()
	(painel.find_child("Poke_" + lider.id_persistente, true, false) as Button).pressed.emit()
	checar(painel.aviso.contains("estágio final") or painel.aviso.contains("tipo") or painel.aviso.contains("aprendeu"), "ensinar o TM: a regra do cliente responde", painel.aviso)
	(painel.find_child("Held_basic", true, false) as Button).pressed.emit()
	var held := -1
	for id in preload("res://ponte_cidade.gd").dados().lote3["helds"]:
		if int(ej.inventario.estoque_materiais.get(LOOT.id_interno(int(id)), 0)) > 0:
			held = int(id)
	checar(held > 0 and int(ej.inventario.estoque_materiais.get(LOOT.id_interno(13115), 0)) == 0, "Held Machine básica: 20 tokens → 1 held", str(held))
	(painel.find_child("Item_%d" % held, true, false) as Button).pressed.emit()
	(painel.find_child("Poke_" + lider.id_persistente, true, false) as Button).pressed.emit()
	checar(int(ej.itens_uso.get("held", {}).get(lider.id_persistente, 0)) == held, "held equipado no líder")
	var jogo: Dictionary = ej.extrair_jogo_hunt("Rhydon")["jogo"]
	checar(int(jogo["helds"].get(lider.id_persistente, 0)) == held, "a hunt recebe o held do líder (cfg.helds)")
	checar(ej.salvar_agora(), "save gravado")
	var sl = load("res://salvamento_local.gd").new()
	var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
	ej.itens_uso = {}
	sl._restaurar(ej, d)
	checar(ej.berries_ativas(int(Time.get_unix_time_from_system())).has(lider.id_persistente) and int(ej.itens_uso["candy"].get(lider.id_persistente, 0)) == 1,
		"recarga: candies usados e berry ativa preservados")
	checar(int(ej.itens_uso.get("held", {}).get(lider.id_persistente, 0)) > 0, "recarga: held equipado preservado")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
