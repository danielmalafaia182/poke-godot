extends SceneTree
## Mochila (ciclo 4, item 3; C: .inv-bag e window.inventory do cliente; A: vídeo). Save ISOLADO (testes/rodar.sh).
## Confere: 4 abas (Tudo/Pokémon/Pokébolas/Itens) filtram pelo tipo; a equipe vem primeiro; mínimo 30 casas em 6
## colunas; status "N/6 Pokémon" e "M itens"; busca e categoria filtram; a poção cura o líder e mostra a mensagem;
## duplo clique num Pokémon da equipe (com reserva) o manda para o Box.

var falhas := 0
var total := 0
var quadros := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	get_root().get_node("EstadoJogo").novo_jogo(1, "Teste", 3)
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	var ej = get_root().get_node("EstadoJogo")
	ej.tutorial_passo = "fim"
	var inv = current_scene.janelas_dock["inventario"]
	inv.abrir()
	var cel: Array = inv.celulas()
	checar(cel.size() == 3 and String(cel[0]["kind"]) == "poke" and String(cel[1]["kind"]) == "ball", "Tudo: equipe primeiro, depois bolas e itens", str(cel.map(func(e): return e["kind"])))
	checar(inv.grade.columns == 6 and inv.grade.get_child_count() == 30, "grade de 6 colunas com 30 casas no mínimo", str(inv.grade.get_child_count()))
	checar(inv.status_poke.text.begins_with("1/6") and inv.status_itens.text.begins_with("200"), "status N/6 Pokémon e M itens", inv.status_poke.text + " | " + inv.status_itens.text)
	for par in [["poke", "poke"], ["ball", "ball"], ["item", "item"]]:
		(inv.find_child("Aba_" + par[0], true, false) as Button).pressed.emit()
		checar(inv.celulas().all(func(e): return String(e["kind"]) == par[1]) and not inv.celulas().is_empty(), "aba %s filtra" % par[0])
	(inv.find_child("Aba_all", true, false) as Button).pressed.emit()
	inv.busca.text = "potion"
	inv.atualizar()
	checar(inv.celulas().size() == 1 and String(inv.celulas()[0]["nome"]) == "Small Potion", "busca por nome")
	inv.busca.text = ""
	inv.cat_botao.select(1)
	inv.cat_botao.item_selected.emit(1)
	checar(inv.celulas().size() == 1 and String(inv.celulas()[0]["kind"]) == "ball", "categoria Pokébola")
	inv.cat_botao.select(0)
	inv.cat_botao.item_selected.emit(0)
	var lider = ej.obter_lider()
	lider.vida_atual = 1
	checar(inv.usar_pocao(200) == "" and lider.obter_vida_atual() > 1 and inv.flash.visible, "Small Potion cura o líder e mostra a mensagem")
	var r: Dictionary = ej.novo_jogo(4, "Teste2", 3)
	var segundo = load("res://dados_pokemon.gd").new()
	segundo.especie = ej.obter_lider().especie
	ej.time_pokemon.append(segundo)
	inv.atualizar()
	var antes: int = ej.time_pokemon.size()
	var casa: Control = inv.find_child("P_1", true, false)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	casa.gui_input.emit(ev)
	checar(ej.time_pokemon.size() == antes - 1, "duplo clique manda o Pokémon da equipe para o Box", "%d → %d" % [antes, ej.time_pokemon.size()])
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
