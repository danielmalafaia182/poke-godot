extends SceneTree
## Fase 4, item 2 — sem bolas no depot (A, gravação G4: o depot do original só guarda itens). Um save antigo com bolas
## no depot (dados/testes/save_antigo_bolas_no_depot.json: o save_antigo_inventario.json com 40 Poké Balls e 5 Super
## Balls no depot) carrega com essas bolas de volta na BAG, e o próximo save já sai sem bola no depot.
## Rodar: testes/rodar.sh res://testes/test_migracao_depot_bolas.gd   (user:// isolado)

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	call_deferred("executar")


func executar() -> void:
	var ej: Node = root.get_node("EstadoJogo")
	var texto := FileAccess.get_file_as_string("res://dados/testes/save_antigo_bolas_no_depot.json")
	var f := FileAccess.open("user://progresso_v1.json", FileAccess.WRITE)
	f.store_string(texto)
	f.close()
	var conteudo: Dictionary = JSON.parse_string(JSON.parse_string(texto)["conteudo"])
	var bolas_antes: Dictionary = conteudo["bolas"]
	var sl = load("res://salvamento_local.gd").new()
	checar(sl.carregar(ej), "save antigo com bolas no depot carrega", sl.erro)
	checar(int(ej.estoque_bolas[1]) == int(bolas_antes["1"]) + 40 and int(ej.estoque_bolas[3]) == int(bolas_antes["3"]) + 5,
		"as bolas do depot voltam para a BAG", "Poké %d, Super %d" % [int(ej.estoque_bolas[1]), int(ej.estoque_bolas[3])])
	checar(not ej.itens_depot.has(1) and not ej.itens_depot.has(3) and int(ej.itens_depot.get(203, 0)) == 4 and int(ej.itens_depot.get(126, 0)) == 9,
		"o resto do depot fica como estava", str(ej.itens_depot))
	checar(ej.salvar_agora(), "save gravado")
	var lido: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json"))
	var dep: Dictionary = lido.get("dados", {}).get("depot", {})
	checar(lido.has("dados") and not dep.has("1") and not dep.has("3") and int(dep.get("203", 0)) == 4, "o save novo sai sem bola no depot", str(dep))
	ej.forcar_cidade = "cerulean"
	checar(not String(ej.mover_item_depot(1, true)).is_empty() and int(ej.estoque_bolas[1]) == int(bolas_antes["1"]) + 40,
		"guardar bola no depot: recusa (A)")
	var poc := int(ej.estoque_pocoes.get(200, 0))
	ej.estoque_pocoes[200] = poc + 3
	checar(String(ej.guardar_todos_itens_depot()) == "Itens guardados." and int(ej.estoque_bolas[1]) == int(bolas_antes["1"]) + 40 and int(ej.estoque_pocoes.get(200, 0)) == 0,
		"guardar tudo leva as poções e deixa as bolas")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
