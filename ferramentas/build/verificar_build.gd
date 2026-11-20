extends Node
## Verificação do build exportado (ciclo 3). O jogo carrega este script quando POKE_VERIFICAR aponta para ele (o template
## de release não roda --script); ele dirige o jogo de verdade (a tela de jogo novo e a de importar são as reais) e grava
## o resultado em VERIF_SAIDA/resultado_fase<N>.txt. APPDATA isolado (o save real nunca é tocado). VERIF_FASE:
##   1  sem save: tela de jogo novo → Bulbasaur, gênero e nome → Começar → tutorial → mapa → hunt Geodude → caça → salva
##      → fecha (ciclo 4: o começo do original; o Geodude saiu como inicial)
##   2  reabre: o save (na pasta própria, %APPDATA%/PokeIdle) carrega e continua; caça de novo, XP sobe, salva, fecha
##   3  outra APPDATA com só um save "do projeto" (Godot/app_userdata/PokeIdle): a tela de importar aparece; importar
##      carrega e o original fica intacto

var fase := 1
var saida := ""
var etapa := 0
var quadros := 0
var linhas: Array = []
var falhas := 0
var info := {}
var caca: Node


func ok(c: bool, t: String) -> void:
	linhas.append(("OK    " if c else "FALHA ") + "[fase %d] %s" % [fase, t])
	if not c:
		falhas += 1


func _ready() -> void:
	fase = int(OS.get_environment("VERIF_FASE")) if OS.get_environment("VERIF_FASE") != "" else 1
	saida = OS.get_environment("VERIF_SAIDA")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _shot(nome: String) -> void:
	if saida != "":
		get_viewport().get_texture().get_image().save_png(saida + "/fase%d_%s.png" % [fase, nome])


func _process(_d: float) -> void:
	quadros += 1
	var ej = get_node("/root/EstadoJogo")
	var cena := get_tree().current_scene
	if cena == null:
		return
	match etapa:
		0:
			if cena.scene_file_path == "res://cidade.tscn" and quadros > 20:
				var u := ProjectSettings.globalize_path("user://").replace("\\", "/")
				ok(u.to_lower().ends_with("/pokeidle/") and not u.contains("app_userdata"), "save na pasta própria do jogo: " + u)
				if fase == 1:
					var pn := cena.find_child("PainelNovoJogo", true, false)
					ok(pn != null, "sem save, abre a tela de jogo novo (a real)")
					_shot("01_jogo_novo")
					if pn != null:
						pn.escolher_inicial(1)
						pn.escolher_genero("male")
						pn.nome.text = "Verificador"
						pn._atualizar()
					etapa = 1
				elif fase == 2:
					ok(cena.find_child("PainelNovoJogo", true, false) == null and not bool(ej.salvamento.jogo_novo), "reabriu: o save carregou (sem tela de jogo novo)")
					ok(ej.obter_lider() != null and String(ej.obter_lider().especie.nome) == "Bulbasaur", "continua com o Bulbasaur no time")
					info["xp"] = int(ej.experiencia_treinador_acumulada)
					ok(int(info["xp"]) > 0, "XP do treinador do save: %d" % int(info["xp"]))
					_shot("cidade_reaberta")
					_viajar("Geodude")
					etapa = 10
				else:
					var pi := cena.find_child("PainelImportarSave", true, false)
					info["md5"] = FileAccess.get_md5(ej.salvamento.caminho_save_projeto())
					ok(pi != null, "1ª execução com save do projeto: a tela de importar aparece (a real)")
					_shot("importar")
					if pi != null:
						(pi.find_child("Importar", true, false) as Button).pressed.emit()
					etapa = 20
				quadros = 0
		1:
			if quadros == 10:
				var b := cena.find_child("Comecar", true, false) as Button
				ok(b != null and not b.disabled, "Bulbasaur, gênero e nome escolhidos: Começar liberado")
				if b != null:
					info["cena_antes"] = cena.get_instance_id()
					b.pressed.emit()
			# Começar recarrega a cidade depois de 0,4 s: espera a cidade nova (antes, o mapa era aberto na cena que ia sair)
			if quadros <= 10 or cena.get_instance_id() == int(info.get("cena_antes", 0)):
				if quadros > 900:
					ok(false, "a cidade recarregou depois de Começar")
					_fim()
				return
			if not info.has("nova_q"):
				info["nova_q"] = quadros
			if quadros - int(info["nova_q"]) == 50:
				ok(ej.obter_lider() != null and String(ej.obter_lider().especie.nome) == "Bulbasaur" and ej.obter_lider().nivel == 1, "começou com o Bulbasaur nível 1")
				var tut := get_tree().current_scene.find_child("PainelTutorial", true, false) as Control
				ok(tut != null and tut.visible, "o tutorial do Professor Carvalho aparece")
				_shot("02_tutorial")
				_viajar("Geodude")
				etapa = 2
				quadros = 0
		2, 10:
			if cena.scene_file_path == "res://caca_sim.tscn":
				caca = cena
				caca.velocidade = 10.0
				ok(caca.sim != null and String(caca.sim.slug) == "geodude", "entrou na hunt Geodude (mapa do pacote jogo/)")
				etapa = 3 if etapa == 2 else 11
				quadros = 0
			elif quadros > 900:
				ok(false, "a hunt abriu")
				_fim()
		3, 11:
			if quadros == 150:
				_shot("hunt")
			if quadros >= 2400 or int(caca.registro["abates"]) >= 6:
				ok(int(caca.registro["abates"]) > 0, "caçou: %d abates, %d XP" % [int(caca.registro["abates"]), int(caca.registro["xp_treinador"])])
				if etapa == 11:
					ok(int(ej.experiencia_treinador_acumulada) > int(info["xp"]), "continua: XP %d → %d" % [int(info["xp"]), int(ej.experiencia_treinador_acumulada)])
				ok(ej.salvar_agora(), "salvou")
				_fim()
		20:
			if quadros == 20:
				ok(not bool(ej.salvamento.jogo_novo) and ej.obter_lider() != null and String(ej.obter_lider().especie.nome) == "Bulbasaur", "importou: o progresso do projeto carregou")
				ok(FileAccess.get_md5(ej.salvamento.caminho_save_projeto()) == String(info["md5"]), "o save do projeto ficou intacto (cópia, não move)")
				ej.salvar_agora()   # espera a gravação em thread em andamento (na troca .tmp → principal o arquivo some por um instante)
				ok(FileAccess.file_exists("user://progresso_v1.json"), "a cópia está na pasta do jogo")
				_fim()


func _viajar(nome: String) -> void:
	var mapa: Node = load("res://mapa_mundi.tscn").instantiate()
	get_tree().current_scene.add_child(mapa)
	await get_tree().process_frame
	await get_tree().process_frame
	for r in mapa.catalogo:
		if String(r["name"]) == nome:
			mapa._selecionar_registro(r)
			return


func _fim() -> void:
	linhas.append("RESULTADO [fase %d]: %s" % [fase, "OK" if falhas == 0 else "%d falhas" % falhas])
	var f := FileAccess.open(saida + "/resultado_fase%d.txt" % fase, FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(linhas)) + "\n")
	f.close()
	set_process(false)
	get_tree().quit(0)
