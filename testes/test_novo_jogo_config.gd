extends Node
## "Novo jogo" nas Configurações (ciclo 5, item 98). Carregado por POKE_VERIFICAR em duas execuções com o mesmo APPDATA
## isolado (testes/test_novo_jogo_config.sh):
##   FASE=1: jogo com progresso (ouro 777), abre ⚙ → Novo jogo, confere a confirmação (print), confirma
##           (POKE_NOVO_JOGO_SEM_REINICIAR=1: sem reiniciar), confere o backup e que o save sumiu.
##   FASE=2: reabre: é um jogo novo (tela do inicial), sem o progresso antigo; o backup continua lá.
## Grava SAIDA/novo_jogo_fase<N>.txt (linhas "OK ..." / "FALHA ...") e SAIDA/98_confirmacao.png.

var fase := 1
var saida := ""
var q := 0
var linhas: Array = []


func _ready() -> void:
	fase = int(OS.get_environment("FASE"))
	saida = OS.get_environment("SAIDA")
	process_mode = Node.PROCESS_MODE_ALWAYS


func chk(c: bool, t: String) -> void:
	linhas.append(("OK    " if c else "FALHA ") + t)


func _process(_d: float) -> void:
	q += 1
	var ej = get_node("/root/EstadoJogo")
	var cena := get_tree().current_scene
	if cena == null or cena.scene_file_path != "res://cidade.tscn":
		return
	if fase == 1:
		if q == 20:
			var pn := cena.find_child("PainelNovoJogo", true, false)
			if pn != null:
				pn.queue_free()
			ej.novo_jogo(1, "Antigo", 1)
			ej.tutorial_passo = "fim"
			ej.ouro = 777
			chk(ej.salvamento.salvar_agora(), "save com progresso gravado")
		elif q == 30:
			var b: Button = cena.find_child("NovoJogo", true, false)
			chk(b != null, "botão Novo jogo nas Configurações")
			b.pressed.emit()
		elif q == 45:
			var d: ConfirmationDialog = cena.find_child("ConfirmarNovoJogo", true, false)
			chk(d != null and d.visible, "pede confirmação antes")
			chk(FileAccess.file_exists("user://progresso_v1.json"), "sem confirmar, nada apagado")
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png(saida + "/98_confirmacao.png")
			d.confirmed.emit()
			d.hide()
		elif q == 50:
			var bk: String = cena.ultimo_backup
			chk(bk != "" and FileAccess.file_exists(bk), "backup criado: " + bk)
			var txt := FileAccess.get_file_as_string(bk)
			chk(txt.contains("777") and txt.contains("Antigo"), "backup tem o progresso antigo")
			chk(not FileAccess.file_exists("user://progresso_v1.json"), "save atual apagado depois do backup")
			_fim()
	else:
		if q == 40:
			chk(bool(ej.salvamento.jogo_novo), "reabriu como jogo novo")
			chk(cena.find_child("PainelNovoJogo", true, false) != null, "tela de escolha do inicial aberta")
			chk(cena.find_child("PainelImportarSave", true, false) == null, "não oferece importar o save do projeto")
			chk(int(ej.ouro) != 777, "progresso antigo não voltou")
			var d := DirAccess.get_files_at("user://backups")
			chk(d.size() >= 1, "backup continua na pasta (%d arquivo(s))" % d.size())
			_fim()


func _fim() -> void:
	var f := FileAccess.open(saida + "/novo_jogo_fase%d.txt" % fase, FileAccess.WRITE)
	f.store_string("\n".join(linhas) + "\n")
	f.close()
	get_tree().quit()
