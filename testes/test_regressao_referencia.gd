extends SceneTree
## Gabarito capturado ANTES da revisão estrutural. Atualizar apenas com mudança de regra justificada.


func _init() -> void:
	var referencia: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://testes/referencia_sim.json"))
	var cenarios := preload("res://testes/regras_referencia.gd").cenarios(preload("res://sim/dados_jogo.gd").carregar())
	var falhas := 0
	for nome in referencia.cenarios:
		var atual: String = String(cenarios[nome]).md5_text()
		var ok: bool = atual == referencia.cenarios[nome]
		if not ok:
			falhas += 1
		print(("OK    " if ok else "FALHA ") + nome + " byte a byte: " + atual)
	print("RESULTADO: %d/%d" % [cenarios.size() - falhas, cenarios.size()])
	quit(1 if falhas else 0)
