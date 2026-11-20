extends SceneTree
## Tutorial do Professor Carvalho (ciclo 4: os 17 passos do cliente, C). Save ISOLADO (testes/rodar.sh):
## jogo novo → welcome com "1 / 17", Oak e destaques em azul; continuar avança; o passo da Nurse desenha o caminho de
## pontos e fecha ao abrir a Nurse Joy; Pular este passo; o Mercado só avança no clique; abrir o mapa fecha openMap;
## abrir a mochila fecha openInv; usar a Small Potion fecha usePotion; Pular tutorial grava "fim"; ⚙ → 🎓 Tutorial
## refaz; o passo vai no save. Os passos da hunt (hunting, throwBall) vão por evento (ao_evento).

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
	var r: Dictionary = ej.novo_jogo(1, "Teste", 7)
	checar(not r.has("erro") and String(ej.tutorial_passo) == "welcome", "jogo novo começa o tutorial no welcome")
	change_scene_to_file("res://cidade.tscn")


func _botao(n: String) -> Button:
	return tut.find_child(n, true, false) as Button


func _process(_d: float) -> bool:
	quadros += 1
	var ej = get_root().get_node("EstadoJogo")
	if current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	match etapa:
		0:
			tut = current_scene.get_node("Interface/PainelTutorial")
			checar(tut.PASSOS.size() == 17, "17 passos, como o cliente (C)", str(tut.PASSOS.size()))
			checar(tut.visible and tut.titulo.text.find("Bem-vindo") >= 0 and tut.contador.text == "1 / 17", "cartão do welcome com \"1 / 17\"", tut.contador.text)
			checar(tut.texto.text.find("[color=#0b5cad][b]") >= 0 and tut.oak.visible and tut.veu[0].visible, "destaques em azul (#0b5cad, C), Oak e o véu (C: .tutg-*)")
			_botao("Continuar").pressed.emit()
			checar(String(ej.tutorial_passo) == "party", "continuar avança para a equipe")
			etapa = 1
		1:
			checar(tut.destaque.visible, "o passo da equipe destaca o painel do time")
			for i in 3:
				_botao("Continuar").pressed.emit()
			checar(String(ej.tutorial_passo) == "nurse" and tut.objetivo_txt.text.find("Nurse Joy") >= 0 and not tut.continuar.visible and tut.pular_passo.visible,
				"o da Nurse pede ir até ela e clicar", String(ej.tutorial_passo))
			var tr = tut.trilha
			checar(tr != null and is_instance_valid(tr) and (tr.get_meta("pontos") as Array).size() >= 2, "caminho de pontos até a Nurse Joy",
				str((tr.get_meta("pontos") as Array).size()) if tr != null else "sem trilha")
			current_scene.painel_nurse.show()
			etapa = 2
		2:
			checar(String(ej.tutorial_passo) == "depot", "abrir a Nurse Joy fecha o passo", String(ej.tutorial_passo))
			current_scene.painel_nurse.hide()
			_botao("PularPasso").pressed.emit()
			_botao("PularPasso").pressed.emit()
			checar(String(ej.tutorial_passo) == "market" and tut.continuar.visible, "Pular este passo avança; o Mercado só no clique", String(ej.tutorial_passo))
			_botao("Continuar").pressed.emit()
			checar(String(ej.tutorial_passo) == "openMap", "depois do Mercado, abrir o mapa")
			etapa = 3
		3:
			checar(tut.destaque.visible, "o botão do mapa fica destacado")
			ej.tutorial_passo = "openInv"
			etapa = 4
		4:
			checar(tut.visible and tut.contador.text == "13 / 17", "openInv também aparece na cidade", tut.contador.text)
			current_scene.janelas_dock["inventario"].abrir()
			etapa = 5
		5:
			checar(String(ej.tutorial_passo) == "usePotion", "abrir a mochila fecha openInv", String(ej.tutorial_passo))
			var inv = current_scene.janelas_dock["inventario"]
			inv.aba = "all"
			inv.atualizar()
			etapa = 6
		6:
			var lider = ej.obter_lider()
			lider.vida_atual = 1
			var antes: int = ej.obter_quantidade_pocao(200)
			var motivo: String = current_scene.janelas_dock["inventario"].usar_pocao(200)
			checar(motivo == "" and ej.obter_quantidade_pocao(200) == antes - 1 and lider.obter_vida_atual() > 1, "a Small Potion cura o líder", motivo)
			checar(String(ej.tutorial_passo) == "captureMgmt", "usar a poção fecha usePotion", String(ej.tutorial_passo))
			current_scene.janelas_dock["inventario"].hide()
			tut.ao_evento("ball-thrown")
			checar(String(ej.tutorial_passo) == "captureMgmt", "evento de outro passo não avança")
			_botao("PularTutorial").pressed.emit()
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
