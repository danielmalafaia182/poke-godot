extends Node
## Reabrir depois de muito tempo fechado (ciclo 5, item 99). Carregado por POKE_VERIFICAR, em duas execuções com o mesmo
## APPDATA isolado (testes/test_reabrir.sh):
##   FASE=1: jogo novo, hunt Geodude, ~40 s de caça a 4×, fecha o jogo (get_tree().quit, como fechar a janela).
##   FASE=2: (o .sh recua o "salvo_em_unix" do save em 3 h) abre a cidade e registra a mensagem da recuperação.
## Grava SAIDA/reabrir_fase<N>.txt.

var fase := 1
var saida := ""
var q := 0
var linhas: Array = []


func _ready() -> void:
	fase = int(OS.get_environment("FASE"))
	saida = OS.get_environment("SAIDA")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_d: float) -> void:
	q += 1
	var ej = get_node("/root/EstadoJogo")
	var cena := get_tree().current_scene
	if cena == null:
		return
	if fase == 1:
		if q == 20 and cena.scene_file_path == "res://cidade.tscn":
			ej.novo_jogo(1, "Teste", 1)
			ej.tutorial_passo = "fim"
			ej.especie_caca = null
			ej.slug_caca = "geodude"
			get_tree().change_scene_to_file("res://caca_sim.tscn")
		if cena.scene_file_path == "res://caca_sim.tscn" and "velocidade" in cena:
			cena.velocidade = 4.0
			if q > 20 + 60 * 12:
				if OS.get_environment("SONECA") != "":
					linhas.append("soneca: " + str(cena.soneca()))
				linhas.append("hunt_ao_fechar=%s xp=%d abates=%d soneca=%s" % [ej.hunt_ao_fechar, ej.experiencia_treinador_acumulada, int(cena.registro["abates"]), str(not ej.soneca.is_empty())])
				ej.salvar_agora()
				_fim()
	else:
		if q == 40:
			var sp := cena.find_child("PainelSoneca", true, false)
			var txt := ""
			if sp != null:
				for l in sp.find_children("*", "Label", true, false):
					if (l as Label).is_visible_in_tree():
						txt += (l as Label).text + " | "
				for l in sp.find_children("*", "RichTextLabel", true, false):
					if (l as Control).is_visible_in_tree():
						txt += (l as RichTextLabel).get_parsed_text() + " | "
			linhas.append("hunt_ao_fechar=%s xp=%d" % [ej.hunt_ao_fechar, ej.experiencia_treinador_acumulada])
			linhas.append("MENSAGEM: " + txt)
			_fim()


func _fim() -> void:
	var f := FileAccess.open(saida + "/reabrir_fase%d.txt" % fase, FileAccess.WRITE)
	f.store_string("\n".join(linhas) + "\n")
	f.close()
	get_tree().quit()
