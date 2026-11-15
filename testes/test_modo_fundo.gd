extends SceneTree
## Segundo plano (E, 15/11; jogo idle): sem foco, o desenho cai para ~10 quadros/s e a simulação continua no ritmo do
## relógio (5 ticks/s); uma trava de 12 s (PC ocupado, janela minimizada) não perde ticks — antes, o laço descartava o
## atraso acima de 10 s. Save isolado (testes/rodar.sh), velocidade 1 (tempo real).
## Rodar: testes/rodar.sh res://testes/test_modo_fundo.gd

var falhas := 0
var total := 0
var etapa := 0
var quadros := 0
var caca: Node
var t_ini := 0
var tick_ini := 0
var quadros_ini := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	if etapa >= 3 and not is_instance_valid(caca):
		checar(false, "a hunt continuou aberta durante o teste")
		print("RESULTADO: %d/%d" % [total - falhas, total])
		quit(1)
		return true
	match etapa:
		0:
			if current_scene != null and current_scene.scene_file_path == "res://cidade.tscn" and quadros > 5:
				ej.novo_jogo(1, "Teste", 3)   # Bulbasaur na hunt do Geodude: sobrevive e a hunt não acaba no meio
				current_scene.add_child(load("res://mapa_mundi.tscn").instantiate())
				etapa = 1
				quadros = 0
		1:
			if quadros == 3:
				var mapa: Node = current_scene.get_child(current_scene.get_child_count() - 1)
				for r in mapa.catalogo:
					if String(r["name"]) == "Geodude":
						mapa._selecionar_registro(r)
				etapa = 2
				quadros = 0
		2:
			if current_scene != null and current_scene.scene_file_path == "res://caca_sim.tscn" and quadros > 30:
				caca = current_scene
				caca.velocidade = 1.0
				ej.definir_modo_fundo(true)
				checar(ej.em_fundo and Engine.max_fps == ej.FPS_FUNDO, "sem foco: desenho limitado a %d quadros/s" % ej.FPS_FUNDO)
				t_ini = Time.get_ticks_msec()
				tick_ini = int(caca.sim.tick)
				quadros_ini = quadros
				etapa = 3
		3:
			if Time.get_ticks_msec() - t_ini >= 20000:
				var seg := (Time.get_ticks_msec() - t_ini) / 1000.0
				var ticks := int(caca.sim.tick) - tick_ini
				var fps := (quadros - quadros_ini) / seg
				checar(fps <= ej.FPS_FUNDO * 1.3, "~%d quadros/s em segundo plano" % ej.FPS_FUNDO, "%.1f quadros/s" % fps)
				checar(absf(ticks - seg * 5.0) <= 3.0, "a simulação segue o relógio (5 ticks/s)", "%d ticks em %.1f s" % [ticks, seg])
				# trava de 12 s no meio de um quadro (PC ocupado / janela minimizada)
				t_ini = Time.get_ticks_msec()
				tick_ini = int(caca.sim.tick)
				OS.delay_msec(12000)
				etapa = 4
		4:
			if Time.get_ticks_msec() - t_ini >= 16000:
				var seg2 := (Time.get_ticks_msec() - t_ini) / 1000.0
				var ticks2 := int(caca.sim.tick) - tick_ini
				checar(absf(ticks2 - seg2 * 5.0) <= 3.0, "depois de uma trava de 12 s, os ticks atrasados são recuperados (nenhum perdido)",
					"%d ticks em %.1f s" % [ticks2, seg2])
				ej.definir_modo_fundo(false)
				checar(not ej.em_fundo and Engine.max_fps == 0, "com foco de novo: sem limite de quadros")
				print("RESULTADO: %d/%d" % [total - falhas, total])
				quit(1 if falhas else 0)
				return true
	return false
