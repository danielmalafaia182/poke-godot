extends SceneTree
## Tutorial do Professor Carvalho (ciclo 2; C: passos e textos do cliente). Save ISOLADO (testes/rodar.sh):
## jogo novo → welcome; continuar avança; o passo da Nurse fecha ao abrir a Nurse Joy; Depot e Mark idem; Pular tutorial
## grava "fim"; ⚙ → 🎓 Tutorial refaz; save antigo sem o campo não mostra tutorial.

var falhas := 0
var total := 0
var quadros := 0
var etapa := 0
var tut: Control


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	var ej = get_root().get_node("EstadoJogo")
	checar(String(ej.tutorial_passo) != "welcome", "sem jogo novo, o tutorial não começa sozinho", String(ej.tutorial_passo))
	var r: Dictionary = ej.novo_jogo(74, "Teste", 7)
	checar(not r.has("erro") and String(ej.tutorial_passo) == "welcome", "jogo novo começa o tutorial no welcome")
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	if current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	match etapa:
		0:
			tut = current_scene.get_node("Interface/PainelTutorial")
			checar(tut.visible and tut.titulo.text.find("Bem-vindo") >= 0 and tut.texto.text.find("[b]") >= 0, "cartão do welcome com o texto do original (negrito em BBCode)", tut.titulo.text)
			for i in 4:
				(tut.find_child("Continuar", true, false) as Button).pressed.emit()
			checar(String(ej.tutorial_passo) == "nurse" and tut.objetivo.text.find("Nurse Joy") >= 0 and not tut.continuar.visible, "passos de clique avançam; o da Nurse pede o clique nela", String(ej.tutorial_passo))
			current_scene.painel_nurse.show()
			etapa = 1
		1:
			checar(String(ej.tutorial_passo) == "depot", "abrir a Nurse Joy fecha o passo", String(ej.tutorial_passo))
			current_scene.painel_nurse.hide()
			(tut.find_child("PularPasso", true, false) as Button).pressed.emit()
			checar(String(ej.tutorial_passo) == "shop", "Pular este passo avança", String(ej.tutorial_passo))
			(tut.find_child("PularTutorial", true, false) as Button).pressed.emit()
			checar(String(ej.tutorial_passo) == "fim" and not tut.visible, "Pular tutorial encerra")
			(current_scene.find_child("Tutorial", true, false) as Button).pressed.emit()
			checar(String(ej.tutorial_passo) == "welcome" and tut.visible, "⚙ → 🎓 Tutorial refaz do começo")
			checar(ej.salvar_agora(), "save gravado")
			var sl = load("res://salvamento_local.gd").new()
			var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
			checar(String(d.get("tutorial", "")) == "welcome", "o passo vai no save")
			print("RESULTADO: %d/%d" % [total - falhas, total])
			quit(1 if falhas else 0)
			return true
	return false
