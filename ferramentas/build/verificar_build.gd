extends SceneTree
## Verificação do build exportado (exe + pck), com APPDATA isolado: abre, jogo novo com Geodude pela tela de jogo novo,
## cidade, mapa-múndi → hunt recomendada (Rattata), caça 90 s a 10×, capturas de tela da cidade e da hunt.

var etapa := 0
var quadros := 0
var caca: Node
var saida := ""
var falhas := 0


func ok(c: bool, t: String) -> void:
	print(("OK    " if c else "FALHA ") + t)
	if not c:
		falhas += 1


func _initialize() -> void:
	saida = OS.get_environment("VERIF_SAIDA")
	var ej = get_root().get_node("EstadoJogo")
	print("raiz dados: ", preload("res://sim/fontes.gd").pasta_dados(), "  snapshot: ", preload("res://sim/fontes.gd").pasta_snapshot())
	print("user:// = ", ProjectSettings.globalize_path("user://"), "  jogo_novo=", ej.salvamento.jogo_novo)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	change_scene_to_file("res://cidade.tscn")


func _shot(nome: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(saida + "/" + nome + ".png")


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 10:
				var pn: Control = load("res://painel_novo_jogo.gd").new()
				pn.name = "PainelNovoJogo"
				current_scene.get_node("Interface").add_child(pn)
				etapa = 1
				quadros = 0
		1:
			if quadros == 10:
				_shot("01_jogo_novo")
				var pn = current_scene.get_node("Interface/PainelNovoJogo")
				pn.escolher(74)
				ok(ej.obter_lider() != null and String(ej.obter_lider().especie.nome) == "Geodude" and ej.obter_lider().nivel == 1, "jogo novo: Geodude nível 1 no time")
				ok(int(ej.estoque_pocoes.get(200, 0)) == 100 and int(ej.estoque_bolas.get(1, 0)) == 100, "kit: 100 Small Potions e 100 Poké Balls")
			if quadros == 20:
				var b := current_scene.find_child("Comecar", true, false) as Button
				if b != null:
					b.pressed.emit()
			if quadros == 60:
				ok(String(ej.obter_lider().especie.nome) == "Geodude" and current_scene.find_child("*", true, false) != null, "cidade recarregada com o Geodude")
				_shot("02_cidade_tutorial")
				ok(current_scene.get_node("Interface/PainelTutorial").visible, "tutorial do Professor Carvalho aparece")
				var mapa: Node = load("res://mapa_mundi.tscn").instantiate()
				current_scene.add_child(mapa)
				etapa = 2
				quadros = 0
		2:
			if quadros == 5:
				var mapa: Node = current_scene.get_child(current_scene.get_child_count() - 1)
				for r in mapa.catalogo:
					if String(r["name"]) == "Rattata":
						mapa._selecionar_registro(r)
				etapa = 3
				quadros = 0
		3:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn":
				caca = current_scene
				caca.velocidade = 10.0
				ok(caca.sim != null and String(caca.sim.slug) == "rattata", "entrou na hunt Rattata (mapa real do snapshot)")
				etapa = 4
				quadros = 0
			elif quadros > 600:
				ok(false, "hunt abriu")
				return _fim()
		4:
			if quadros == 120:
				_shot("03_hunt")
			if quadros >= 900 or int(caca.registro["abates"]) >= 15:
				_shot("04_hunt_fim")
				ok(int(caca.registro["abates"]) > 0, "caça: %d abates, %d XP do treinador, líder nível %d" % [int(caca.registro["abates"]), int(caca.registro["xp_treinador"]), ej.obter_lider().nivel])
				ok(ej.salvar_agora(), "save gravado em " + ProjectSettings.globalize_path("user://progresso_v1.json"))
				return _fim()
	return false


func _fim() -> bool:
	print("RESULTADO: %s" % ("OK" if falhas == 0 else "%d falhas" % falhas))
	quit(1 if falhas else 0)
	return true
