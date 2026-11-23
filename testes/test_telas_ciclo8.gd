extends SceneTree
## Telas completas do ciclo 8 na cidade, com save ISOLADO (rodar com testes/rodar.sh): Profissões (escolher, crafting),
## Breeding (escolher os pais, criar ovo), Poke Slot Machine (rolar, sortear, trocar bônus).

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
	get_root().get_node("EstadoJogo").iniciar_depot()
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if feito or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	feito = true
	var ej = get_root().get_node("EstadoJogo")
	var j: Dictionary = current_scene.janelas_dock
	ej.ouro = 10000000
	# Profissões
	var pf: Control = j["profissoes"]
	pf.abrir()
	(pf.find_child("Escolher", true, false) as Button).pressed.emit()
	checar(String(ej.profissao.get("atual", "")) == "botanist", "Profissões: escolheu Botânico pela janela")
	ej.profissao["ervas"] = 40
	pf.atualizar()
	var craft: Button = null
	for c in pf.find_children("Craft_*", "Button", true, false):
		craft = c
		break
	checar(craft != null and not craft.disabled, "árvore do Botânico com berries para craftar")
	craft.pressed.emit()
	checar(not (ej.profissao.get("fila", []) as Array).is_empty() and pf.find_child("Coletar", true, false) != null, "craftar pôs a ordem na fila; botão Coletar")
	pf.hide()
	# Breeding
	var esp = preload("res://especies_importadas.gd").obter_todas().get("Golem")
	var ids: Array = []
	for q in [1.3, 1.1]:
		var pk := DadosPokemon.new()
		pk.especie = esp
		pk.nivel = 50
		pk.sortear_ivs()
		pk.qualidade = q
		pk.id_persistente = Crypto.new().generate_random_bytes(16).hex_encode()
		pk.normalizar_atributos()
		ej.pokemons_capturados.append(pk)
		ids.append(pk.id_persistente)
	ej.inventario.estoque_materiais[LOOT.id_interno(109)] = 10
	var br: Control = j["breeding"]
	br.abrir()
	for id in ids:
		(br.find_child("Pai_" + id, true, false) as Button).pressed.emit()
	(br.find_child("Caminho_livre", true, false) as CheckBox).button_pressed = true
	(br.find_child("CriarOvo", true, false) as Button).pressed.emit()
	checar((ej.breeding.get("ovos", []) as Array).size() == 1 and ej._pokemon_por_id(String(ids[0])) == null, "Breeding: pais escolhidos na box viram ovo (consumidos)", br.aviso)
	br.hide()
	# Poke Slot Machine
	var gs: Control = j["estrelas"]
	gs.abrir()
	(gs.find_child("Roll", true, false) as Button).pressed.emit()
	checar(gs.find_child("Cand_0", true, false) != null, "Slot Machine: rolou, 9 candidatos")
	var o0: int = ej.ouro
	(gs.find_child("Cand_0", true, false) as Button).pressed.emit()
	var st: Dictionary = ej.estrelas["slots"][0]
	checar(not st.is_empty() and ej.ouro == o0 - 50000, "escolha direta: estrela no slot 1 (50.000 de ouro)", str(st))
	var b0 := String(st["bonusType"])
	(gs.find_child("Reroll_0", true, false) as Button).pressed.emit()
	checar(ej.ouro == o0 - 100000, "trocar bônus: cobrado (50.000)", "%s → %s" % [b0, String(ej.estrelas["slots"][0]["bonusType"])])
	checar(ej.salvar_agora(), "save gravado")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
