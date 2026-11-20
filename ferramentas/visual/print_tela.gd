extends SceneTree
## Print de uma tela do nosso jogo (ciclo 4), em janela 1880×954 (a área útil do navegador nos vídeos do original), com
## APPDATA isolado (rodar com APPDATA de teste). Uso: godot --path . --script res://ferramentas/visual/print_tela.gd --
## <tela> <saida.png>. Telas: criar_personagem, criar_personagem_escolhido, tutorial, tutorial_<passo>.
var tela := ""
var saida := ""
var quadros := 0
var no: Node


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	tela = a[0]
	saida = a[1]
	DisplayServer.window_set_size(Vector2i(1880, 954))
	get_root().size = Vector2i(1880, 954)
	match tela:
		"criar_personagem", "criar_personagem_escolhido":
			no = load("res://painel_novo_jogo.gd").new()
			get_root().add_child(no)
		"nurse", "depot", "mochila", "my_pokes", "perfil", "dock_clas", "mapa_outland", "mapa_orre", "mapa_nightmare":
			var ej = get_root().get_node("EstadoJogo")
			ej.novo_jogo(1, "danpoke", 1)
			ej.zoom_camera = 0.5   # A: o zoom do vídeo do original
			ej.tutorial_passo = "fim"
			change_scene_to_file("res://cidade.tscn")
		"hunt":
			# a hunt do Geodude com o Bulbasaur nível 8, ~12 s de luta (dano com o nome do golpe, loot)
			var ej = get_root().get_node("EstadoJogo")
			ej.novo_jogo(1, "danpoke", 1)
			ej.zoom_camera = 0.5   # A: o zoom do vídeo do original
			ej.tutorial_passo = "fim"
			ej.especie_caca = null
			ej.slug_caca = "geodude"
			change_scene_to_file("res://caca_sim.tscn")
		"cidade_colisao":
			# a cidade com zoom 2, o treinador na frente do Pokémon Center e as casas bloqueadas em vermelho
			var ej = get_root().get_node("EstadoJogo")
			ej.novo_jogo(1, "danpoke", 1)
			ej.zoom_camera = 0.5   # A: o zoom do vídeo do original
			ej.tutorial_passo = "fim"
			change_scene_to_file("res://cidade.tscn")
		_ when tela.begins_with("tutorial"):
			# tutorial = welcome; tutorial_<passo> = esse passo (party, depot, openMap…)
			var ej = get_root().get_node("EstadoJogo")
			ej.novo_jogo(1, "danpoke", 1)
			ej.zoom_camera = 0.5   # A: o zoom do vídeo do original
			ej.tutorial_passo = "welcome" if tela == "tutorial" else tela.trim_prefix("tutorial_")
			change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if quadros == 5 and tela == "criar_personagem_escolhido":
		no.escolher_inicial(1)
		no.escolher_genero("male")
		no.nome.text = "danpoke"
		no._atualizar()
	if quadros == 8 and tela == "cidade_colisao":
		var c = current_scene
		c.zoom_cidade = 1.6
		c.personagem.celula = Vector2i(-3, -6)
		c.personagem.position = Vector2(c.personagem.celula) * 32.0 + Vector2(16, 16)
		var grade := Node2D.new()
		grade.z_index = 100
		grade.draw.connect(func() -> void:
			for y in range(-16, 6):
				for x in range(-20, 14):
					var cel := Vector2i(x, y)
					if not c.cenario.celula_transitavel(cel):
						grade.draw_rect(Rect2(Vector2(cel) * 32.0, Vector2(32, 32)), Color(1, 0, 0, 0.28))
					grade.draw_rect(Rect2(Vector2(cel) * 32.0, Vector2(32, 32)), Color(1, 1, 1, 0.12), false, 1.0)
					if x % 2 == 0 and y % 2 == 0:
						grade.draw_string(ThemeDB.fallback_font, Vector2(cel) * 32.0 + Vector2(2, 11), "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE))
		c.cenario.add_child(grade)
	if quadros == 10 and tela == "nurse":
		current_scene.painel_nurse.abrir()
	if quadros == 10 and tela == "mochila":
		var ej = get_root().get_node("EstadoJogo")
		ej.receber_loot([{"itemId": 5303, "quantidade": 12}, {"itemId": 2, "quantidade": 3}]) if ej.has_method("receber_loot") else null
		current_scene.janelas_dock["inventario"].abrir()
	if quadros == 10 and tela == "my_pokes":
		current_scene._abrir_my_pokes()
	if quadros == 10 and tela.begins_with("mapa_"):
		current_scene._on_botao_cacar_pressed()
	if quadros == 14 and tela.begins_with("mapa_"):
		var mm = current_scene.find_child("MapaMundi", true, false)
		if mm != null:
			mm.selecionar_regiao(tela.trim_prefix("mapa_"))
	if quadros == 10 and tela == "dock_clas":
		current_scene.get_node("Interface/MenuSuperior").botoes["clans"].pressed.emit()
	if quadros == 10 and tela == "perfil":
		current_scene.janelas_dock["perfil"].abrir()
	if quadros == 10 and tela == "depot":
		current_scene.painel_depot.abrir_depot()
	if tela == "hunt" and quadros == 30 and current_scene != null and "velocidade" in current_scene:
		current_scene.velocidade = 4.0   # acelera até o 1º abate (o cartão fica na tela)
	if tela == "hunt" and quadros > 30 and current_scene != null and "registro" in current_scene and int(current_scene.registro.get("abates", 0)) > 0 and current_scene.velocidade > 1.0:
		current_scene.velocidade = 1.0
		quadros = 2400 - 50
	if tela == "hunt" and quadros < 2400:
		return false
	if quadros == 40 or (tela == "hunt" and quadros == 2400):
		get_root().get_texture().get_image().save_png(saida)
		print("PRINT ", saida)
		quit(0)
	return false
