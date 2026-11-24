extends SceneTree
## Entradas inválidas, isolamento dos perfis e persistência. Sempre com user:// isolado.

const RJ := preload("res://sim/regras_jogo.gd")
const Arquivo := preload("res://infra/arquivo_atomico.gd")
var total := 0
var falhas := 0


func checar(ok: bool, nome: String) -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome)


func _init() -> void:
	RJ.definir_perfil("original")
	for nome in ["../escape", "..\\escape", "C:\\fora", "x:y", "original.", "CON", "scripts", "", "a/b"]:
		checar(RJ.criar_perfil(nome) != "" and RJ.definir_perfil(nome) != "" and RJ.perfil() == "original", "recusa caminho/nome: " + nome)
	checar(RJ.criar_perfil("seguranca") == "", "cria perfil válido")
	checar(RJ.definir_perfil("seguranca") == "", "ativa perfil válido")
	checar(RJ.criar_perfil("seguranca") != "", "não sobrescreve perfil existente")
	checar(RJ.gravar_valor("../outro", "stab", 2) != "", "Resource fora do catálogo recusado")
	checar(RJ.gravar_valor("RegrasCombate", "script", null) != "", "script não é um parâmetro")
	for valor in ["2", -1, NAN, INF, {}]:
		checar(RJ.gravar_valor("RegrasCombate", "stab", valor) != "", "recusa valor inválido: " + str(valor))
	checar(RJ.gravar_valor("RegrasCombate", "tick_ms", 0) != "", "tick zero recusado antes da simulação")
	checar(RJ.gravar_valor("RegrasCombate", "arredondamento_dano", "inventado") != "", "opção desconhecida recusada")
	checar(RJ.gravar_valor("RegrasCaptura", "shiny_chance", 2) != "", "chance fora da faixa recusada")
	checar(RJ.gravar_valor("RegrasCombate", "stab", 2.0) == "", "edição válida gravada")
	var c := "user://regras/seguranca/RegrasCombate.tres"
	var antes := FileAccess.get_file_as_bytes(c)
	RJ.gravar_valor("RegrasCombate", "stab", -2)
	checar(FileAccess.get_file_as_bytes(c) == antes, "recusa preserva arquivo byte a byte")
	var valores := RJ.valores("RegrasCombate")
	valores.stab = 99
	checar(RJ.valores("RegrasCombate").stab == 2.0, "leitor não consegue corromper cache compartilhado")
	checar(RJ.restaurar("RegrasCombate") == "" and RJ.valores("RegrasCombate").stab == 1.5, "restauração grava os defaults")
	checar(RJ.gravar_alteracao("script", {"id": 1, "campo": "x"}, 1) != "", "tabela desconhecida recusada")
	checar(RJ.gravar_alteracao("especies", {"id": 1, "campo": "loot"}, {}) != "", "campo estrutural recusado")
	checar(RJ.gravar_alteracao("loot", {"especie": 1, "itemId": 1, "campo": "chanceBruta"}, 100001) != "", "chance de loot inválida recusada")
	checar(RJ.gravar_alteracao("hunts", {"id": "rattata", "campo": "nivel"}, 0) != "", "hunt com nível zero recusada")
	checar(RJ.gravar_alteracao("especies", {"id": 999999, "campo": "xpAbate"}, 10) != "", "registro inexistente não gera falso sucesso")
	checar(RJ.gravar_alteracao("especies", {"id": 1, "campo": "xpAbate"}, 900) == "", "tabela válida gravada")
	checar(RJ.alteracoes().especies[0].valor == 900, "array tipado do Resource é lido como dados")
	checar(RJ.restaurar_alteracao("especies", {"id": 1, "campo": "xpAbate"}) == "" and RJ.alteracoes().especies.is_empty(), "restaura alteração de tabela")
	# Camada res:// simulada em um pacote temporário; não escreve na pasta do projeto.
	var modelo := load("res://dados/regras/original/RegrasCombate.tres").duplicate()
	modelo.stab = 7.0
	ResourceSaver.save(modelo, "user://base_camadas.tres")
	var pacote := PCKPacker.new()
	pacote.pck_start("user://base_camadas.pck")
	pacote.add_file("res://dados/regras/camadas/RegrasCombate.tres", "user://base_camadas.tres")
	ResourceSaver.save(modelo, "user://base_compilada.res")
	Arquivo.texto("user://base_compilada.remap", '[remap]\npath="res://dados/regras/compilado/base.res"\n')
	pacote.add_file("res://dados/regras/compilado/base.res", "user://base_compilada.res")
	pacote.add_file("res://dados/regras/compilado/RegrasCombate.tres.remap", "user://base_compilada.remap")
	pacote.flush()
	ProjectSettings.load_resource_pack("user://base_camadas.pck")
	checar(RJ.recurso("RegrasCombate", "compilado").stab == 7.0, "perfil binário remapeado do exportador preserva o valor")
	checar(RJ.recurso("RegrasCombate", "camadas").stab == 7.0, "perfil base em res:// tem override")
	checar(RJ.restaurar("RegrasCombate", "stab", "camadas") == "" and RJ.recurso("RegrasCombate", "camadas").stab == 1.5, "restaurar campo herdado funciona sem arquivo prévio em user://")
	RJ.gravar_valor("RegrasCombate", "stab", 3.0, "camadas")
	checar(RJ.restaurar("RegrasCombate", "", "camadas") == "" and RJ.recurso("RegrasCombate", "camadas").stab == 1.5, "restaurar grupo não reexpõe valor alterado de res://")
	# Um .tres pode apontar para código arbitrário. Nosso leitor ignora essa associação.
	Arquivo.texto("user://nao_executar.gd", "@tool\nextends Resource\nfunc _init():\n\tFileAccess.open('user://executou', FileAccess.WRITE).store_string('erro')\n")
	var cabecalho := '[gd_resource type="Resource" format=3]\n\n[ext_resource type="Script" path="user://nao_executar.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n'
	Arquivo.texto(c, cabecalho + "stab = 2.5\n")
	RJ.recarregar()
	checar(RJ.valores("RegrasCombate").stab == 2.5 and not FileAccess.file_exists("user://executou"), "script do override não é carregado nem executado")
	Arquivo.texto(c, cabecalho + 'stab = Object(Resource,"script":null)\n')
	RJ.recarregar()
	checar(RJ.valores("RegrasCombate").stab == 1.5 and not RJ.avisos().is_empty(), "construtor de objeto recusado antes de desserializar")
	Arquivo.texto(c, cabecalho + "stab = -10\n")
	RJ.recarregar()
	checar(RJ.valores("RegrasCombate").stab == 1.5 and not RJ.avisos().is_empty(), "arquivo inválido usa defaults e informa o motivo")
	RJ.restaurar("RegrasCombate")
	# Falha real de I/O: diretório no lugar do temporário, sem tornar o arquivo principal inválido.
	DirAccess.make_dir_recursive_absolute(c + ".tmp.tres")
	antes = FileAccess.get_file_as_bytes(c)
	checar(RJ.gravar_valor("RegrasCombate", "stab", 3.0) != "" and FileAccess.get_file_as_bytes(c) == antes, "falha de gravação preserva perfil anterior")
	DirAccess.remove_absolute(c + ".tmp.tres")
	RJ.definir_perfil("original")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
