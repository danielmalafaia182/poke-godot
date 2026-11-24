extends RefCounted
## Escrita local: prepara e confere o temporário antes de substituir o destino.
## O chamador serializa as gravações. Nunca remove o arquivo válido para abrir espaço.


static func texto(caminho: String, conteudo: String) -> Error:
	if DirAccess.dir_exists_absolute(caminho):
		return ERR_FILE_CANT_WRITE
	var erro := DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	if erro != OK:
		return erro
	var temporario := caminho + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return FileAccess.get_open_error()
	arquivo.store_string(conteudo)
	arquivo.flush()
	erro = arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return erro
	if FileAccess.get_file_as_bytes(temporario) != conteudo.to_utf8_buffer():
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(temporario, caminho)


static func recurso(caminho: String, valor: Resource) -> Error:
	var erro := DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	if erro != OK:
		return erro
	# ResourceSaver escolhe o formato pela extensão final.
	var temporario := caminho + ".tmp.tres"
	if DirAccess.dir_exists_absolute(temporario):
		return ERR_FILE_CANT_WRITE
	erro = ResourceSaver.save(valor, temporario)
	if erro != OK:
		return erro
	if FileAccess.get_file_as_bytes(temporario).is_empty():
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(temporario, caminho)
