extends SceneTree
# Executado somente pelo runner, em cópia e nome de aplicação exclusivos de QA.
func _initialize() -> void:
	call_deferred("preparar")
func preparar() -> void:
	var estado: Node = root.get_node("EstadoJogo")
	estado.salvamento._salvamento_pendente = false
	var texto: String = FileAccess.get_file_as_string("res://validacao_qualidade/save_anterior_fixture.json")
	for nome in ["progresso_v1.json", "fixture_anterior.json"]:
		var arquivo: FileAccess = FileAccess.open("user://"+nome,FileAccess.WRITE)
		arquivo.store_string(texto)
		arquivo.close()
	print("FIXTURE ANTERIOR PREPARADA")
	quit()
