extends SceneTree
## Falhas não podem converter um save em novo jogo. Ambiente obrigatoriamente isolado.
var total := 0
var falhas := 0


func checar(ok: bool, nome: String) -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome)


func _initialize() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var ej := root.get_node("EstadoJogo")
	ej.novo_jogo(1, "Teste seguro", 1)
	ej.ouro = 777
	checar(ej.salvar_agora(), "prepara save descartável")
	var s = ej.salvamento
	var caminho: String = s._persistencia.caminho
	var antes := FileAccess.get_file_as_bytes(caminho)
	s._persistencia.bloqueado = true
	var resultado: Dictionary = s.pedir_jogo_novo(false)
	checar(resultado.has("erro") and FileAccess.get_file_as_bytes(caminho) == antes, "save bloqueado não é apagado")
	s._persistencia.bloqueado = false
	ej.ouro = -1  # inválido para o formato; a última versão válida continua no disco.
	resultado = s.pedir_jogo_novo(false)
	checar(resultado.has("erro") and FileAccess.get_file_as_bytes(caminho) == antes, "falha ao salvar cancela novo jogo")
	ej.ouro = 888
	# Não há permissão de escrita no destino porque ele é um diretório, não um arquivo.
	DirAccess.make_dir_recursive_absolute(s.MARCA_JOGO_NOVO)
	resultado = s.pedir_jogo_novo(false)
	checar(resultado.has("erro") and FileAccess.file_exists(caminho) and not s._persistencia.bloqueado, "falha ao preparar reinício mantém progresso e jogo utilizável")
	DirAccess.remove_absolute(s.MARCA_JOGO_NOVO)
	resultado = s.pedir_jogo_novo(false)
	checar(not resultado.has("erro") and FileAccess.file_exists(resultado.get("backup", "")) and not FileAccess.file_exists(caminho), "novo jogo só remove save após backup verificado")
	var backup: Dictionary = s._persistencia.decodificar(FileAccess.get_file_as_string(resultado.get("backup", "")))
	checar(backup.has("dados") and int(backup.dados.ouro) == 888, "backup preserva o estado mais recente")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
