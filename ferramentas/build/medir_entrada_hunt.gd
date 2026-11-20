extends Node
## Mede a entrada na hunt no build exportado (ciclo 4, item 4). Carregado por POKE_VERIFICAR (o template de release não
## roda --script), com APPDATA isolado. Faz um jogo novo, vai da cidade a cada hunt da lista (pelo mesmo caminho do
## mapa-múndi: EstadoJogo.slug_caca + troca de cena) e mede, do pedido até o 1º quadro da hunt desenhado (mapa e simulação prontos). Cada hunt entra duas vezes: a 1ª com o user:// vazio (o caso do jogador na primeira visita), a 2ª
## depois de voltar à cidade. Grava MEDIR_SAIDA/entrada_hunt.txt: "slug vez ms origem_cache atlas_origem".
## Uso: APPDATA=<temp> POKE_VERIFICAR=<este arquivo> MEDIR_SAIDA=<pasta> PokeIdle.exe

const HUNTS := ["rattata", "geodude", "rhydon", "electabuzz", "nightmare_steelix"]
var saida := ""
var fila: Array = []
var atual := ""
var vez := 0
var t0 := 0
var quadros := 0
var etapa := 0
var linhas: Array = []


func _ready() -> void:
	saida = OS.get_environment("MEDIR_SAIDA")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for h in HUNTS:
		fila.append([h, 1])
		fila.append([h, 2])


func _process(_d: float) -> void:
	quadros += 1
	var ej = get_node("/root/EstadoJogo")
	var cena := get_tree().current_scene
	if cena == null:
		return
	match etapa:
		0:   # cidade aberta: jogo novo (Bulbasaur no ciclo 4; o ciclo 3 só aceitava o Geodude)
			if cena.scene_file_path == "res://cidade.tscn" and quadros > 20:
				var r: Dictionary = ej.novo_jogo(1, "Medidor", 1)
				if r.has("erro"):
					ej.novo_jogo(74, "Medidor", 1)
				ej.tutorial_passo = "fim"
				etapa = 1
				quadros = 0
		1:   # pede a próxima hunt
			if quadros < 30:
				return
			if fila.is_empty():
				_fim()
				return
			var p: Array = fila.pop_front()
			atual = String(p[0])
			vez = int(p[1])
			ej.especie_caca = null
			ej.slug_caca = atual
			t0 = Time.get_ticks_msec()
			if ResourceLoader.exists("res://tela_carregando.gd"):   # ciclo 4: o caminho do mapa-múndi (com a tela)
				load("res://tela_carregando.gd").ir_para(get_tree(), "res://caca_sim.tscn")
			else:
				get_tree().change_scene_to_file("res://caca_sim.tscn")
			etapa = 2
			quadros = 0
		2:   # espera o 1º quadro com o mapa desenhado e a sim rodando
			# 1º quadro da hunt com o mapa e a sim prontos (o quadro em que _process roda é desenhado)
			if cena.scene_file_path == "res://caca_sim.tscn" and "sim" in cena and cena.sim != null and cena.is_node_ready():
				var ms := Time.get_ticks_msec() - t0
				var oc := ""
				var ao := ""
				var vista = cena.get("vista")
				if vista != null and vista.mapa != null:
					oc = String(vista.mapa.origem_cache)
					ao = String(vista.mapa.tempos_carga.get("atlas_origem", ""))
				var det := ""
				if "tempos_carga" in cena:
					det = JSON.stringify(cena.tempos_carga)
				if vista != null and vista.mapa != null:
					det += " " + JSON.stringify(vista.mapa.tempos_carga)
				linhas.append("%s %d %d %s %s %s" % [atual, vez, ms, oc, ao, det])
				etapa = 3
				quadros = 0
			elif Time.get_ticks_msec() - t0 > 120000:
				linhas.append("%s %d TEMPO_ESGOTADO" % [atual, vez])
				_fim()
		3:   # volta à cidade
			if quadros == 20:
				get_tree().change_scene_to_file("res://cidade.tscn")
			if quadros > 20 and cena.scene_file_path == "res://cidade.tscn":
				etapa = 1
				quadros = 0


func _fim() -> void:
	if saida != "":
		var f := FileAccess.open(saida + "/entrada_hunt.txt", FileAccess.WRITE)
		f.store_string("\n".join(linhas) + "\n")
		f.close()
	get_tree().quit(0)
