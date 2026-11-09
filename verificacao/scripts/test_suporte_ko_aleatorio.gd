extends "res://caca.gd"
var saidas_por_ko: int = 0
func _on_botao_voltar_cidade_pressed() -> void:
	saidas_por_ko += 1
	_saida_solicitada = true
	aproximando = false
	batalha_encerrada = true
	timer_combate.stop()
	timer_respawn.stop()
	if is_instance_valid(timer_auto_potion):timer_auto_potion.stop()
