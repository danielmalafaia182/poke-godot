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
		_ when tela.begins_with("tutorial"):
			# tutorial = welcome; tutorial_<passo> = esse passo (party, depot, openMap…)
			var ej = get_root().get_node("EstadoJogo")
			ej.novo_jogo(1, "danpoke", 1)
			ej.tutorial_passo = "welcome" if tela == "tutorial" else tela.trim_prefix("tutorial_")
			change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if quadros == 5 and tela == "criar_personagem_escolhido":
		no.escolher_inicial(1)
		no.escolher_genero("male")
		no.nome.text = "danpoke"
		no._atualizar()
	if quadros == 40:
		get_root().get_texture().get_image().save_png(saida)
		print("PRINT ", saida)
		quit(0)
	return false
