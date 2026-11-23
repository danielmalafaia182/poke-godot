extends SceneTree
## Painel do Game Master no jogo (F12), com save ISOLADO (rodar com testes/rodar.sh; build de desenvolvimento = ligado).

const Regras := preload("res://sim/regras.gd")
const LOOT: Script = preload("res://regras_loot.gd")

var falhas := 0
var total := 0
var quadros := 0
var feito := false


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _initialize() -> void:
	get_root().get_node("EstadoJogo").iniciar_depot()
	change_scene_to_file("res://cidade.tscn")


func _process(_d: float) -> bool:
	quadros += 1
	if feito or current_scene == null or current_scene.scene_file_path != "res://cidade.tscn" or quadros < 6:
		return false
	feito = true
	var ej = get_root().get_node("EstadoJogo")
	var gm = ej.get_node_or_null("PainelGM")
	checar(gm != null, "painel instalado em build de desenvolvimento")
	var ev := InputEventKey.new()
	ev.keycode = KEY_F12
	ev.pressed = true
	gm._input(ev)
	checar(gm.painel.visible, "F12 abre o painel")
	(gm.painel.find_child("VIP", true, false) as CheckButton).button_pressed = true
	checar(bool(ej.vip), "VIP ligado pelo painel")
	(gm.painel.find_child("NivelTreinador", true, false) as SpinBox).value = 120
	(gm.painel.find_child("NivelTreinadorAplicar", true, false) as Button).pressed.emit()
	checar(int(ej.nivel_treinador) == 120 and int(ej.experiencia_treinador_acumulada) == Regras.xp_total_para_nivel(120), "nível do treinador 120")
	(gm.painel.find_child("NivelLider", true, false) as SpinBox).value = 50
	(gm.painel.find_child("NivelLiderAplicar", true, false) as Button).pressed.emit()
	checar(int(ej.obter_lider().nivel) == 50, "nível do líder 50")
	var o0: int = ej.ouro
	(gm.painel.find_child("Ouro", true, false) as SpinBox).value = 5000
	(gm.painel.find_child("OuroAplicar", true, false) as Button).pressed.emit()
	checar(int(ej.ouro) == o0 + 5000, "dar 5000 de ouro")
	checar(gm.dar_item("rare candy", 3).begins_with("+3") and int(ej.inventario.estoque_materiais.get(LOOT.id_interno(90124), 0)) >= 3, "dar item por nome (Rare Candy ×3)")
	ej.pesca = {"prox_ms": 999999999999}
	gm.pular_esperas()
	checar(int(ej.pesca["prox_ms"]) == 0, "pular esperas (pesca)")
	checar(gm.recarregar_regras().contains("original"), "recarregar regras (perfil original)")
	(gm.painel.find_child("ForcarShiny", true, false) as CheckButton).button_pressed = true
	checar(bool(ej.get_meta("gm_forcar_shiny", false)), "forçar shiny vale para a próxima hunt")
	checar(current_scene.find_child("PainelGMOpcao", true, false) != null, "opção do painel nas Configurações")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
