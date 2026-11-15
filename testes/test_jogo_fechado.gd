extends SceneTree
## Jogo fechado numa hunt sem soneca (B-relatado: o servidor segue caçando até a sessão morrer, 15 min depois de fechar):
## ao reabrir, a sim recupera até 15 min de caça e descarta o resto; com soneca, vale a regra da soneca. Save ISOLADO.
## Casos: fechado 5 min (recupera 300 s), 20 min (recupera 900 s), com soneca (nada aqui) e fora de hunt (nada).
## Rodar: testes/rodar.sh res://testes/test_jogo_fechado.gd

const Servico := preload("res://sim/servico_jogador.gd")

var falhas := 0
var total := 0
var quadros := 0
var feito := false


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func _process(_d: float) -> bool:
	quadros += 1
	if feito or quadros < 5:
		return false
	feito = true
	var ej = get_root().get_node("EstadoJogo")
	var agora := int(Time.get_unix_time_from_system())
	# regra pura
	var sv = Servico.new()
	checar(sv.segundos_recuperar({"hunt_ao_fechar": "geodude", "soneca": {}}, agora - 300, agora) == 300, "regra: fechado 5 min na hunt → recupera 300 s")
	checar(sv.segundos_recuperar({"hunt_ao_fechar": "geodude", "soneca": {}}, agora - 1200, agora) == 900, "regra: fechado 20 min → recupera 900 s (o resto se perde)")
	checar(sv.segundos_recuperar({"hunt_ao_fechar": "geodude", "soneca": {"inicio": agora - 1200}}, agora - 1200, agora) == 0, "regra: com soneca → vale a soneca (nada aqui)")
	checar(sv.segundos_recuperar({"hunt_ao_fechar": "", "soneca": {}}, agora - 600, agora) == 0, "regra: fechado na cidade → nada")
	# no jogo: Bulbasaur do jogo novo, fechado 5 min no Geodude
	ej.novo_jogo(1, "Teste", 11)
	var b: DadosPokemon = ej.pokemon_inicial
	var xp_t0: int = ej.experiencia_treinador_acumulada
	var xp_b0: int = b.experiencia_total
	var bolas0: int = ej.obter_quantidade_bola(1)
	ej.hunt_ao_fechar = "geodude"
	ej.fechado_em_unix = agora - 300
	var r: Dictionary = ej.recuperar_hunt_fechada(agora)
	checar(int(r.get("segundos", 0)) == 300 and int(r["kills"]) > 0, "fechado 5 min: 300 s de caça recuperados, com abates", "%d s, %d abates" % [int(r.get("segundos", 0)), int(r.get("kills", 0))])
	checar(ej.experiencia_treinador_acumulada == xp_t0 + int(r["xpTreinador"]) and int(r["xpTreinador"]) > 0 and b.experiencia_total > xp_b0,
		"XP do treinador e do Bulbasaur aplicados", "+%d" % int(r["xpTreinador"]))
	checar(ej.obter_quantidade_bola(1) == bolas0 - int(r["bolas"].get("1", 0)) and ej.hunt_ao_fechar == "", "bolas gastas descontadas; marca de hunt limpa")
	# 20 min fechado: só 15 min contam
	ej.hunt_ao_fechar = "geodude"
	ej.fechado_em_unix = agora - 1200
	var r2: Dictionary = ej.recuperar_hunt_fechada(agora)
	checar(int(r2.get("segundos", 0)) == 900 and int(r2["kills"]) > int(r["kills"]), "fechado 20 min: só 900 s recuperados (o resto se perde)", "%d s, %d abates" % [int(r2.get("segundos", 0)), int(r2.get("kills", 0))])
	# com soneca: nada aqui
	ej.hunt_ao_fechar = "geodude"
	ej.fechado_em_unix = agora - 1200
	ej.soneca = {"inicio": agora - 1200, "fim": agora - 900, "amostra": {"slug": "geodude", "kills": 1, "xpSample": 10, "pokeXpSample": 10}}
	checar(ej.recuperar_hunt_fechada(agora).is_empty(), "com soneca: a recuperação não roda (vale a soneca)")
	ej.soneca = {}
	# save: o campo vai e volta, e o fechado_em sai do salvo_em_unix
	ej.hunt_ao_fechar = "geodude"
	checar(ej.salvar_agora(), "save gravado")
	var sl = load("res://salvamento_local.gd").new()
	var d: Dictionary = sl.decodificar(FileAccess.get_file_as_string("user://progresso_v1.json")).get("dados", {})
	ej.hunt_ao_fechar = ""
	sl._restaurar(ej, d)
	checar(ej.hunt_ao_fechar == "geodude" and ej.fechado_em_unix == int(d.get("salvo_em_unix", -1)), "save: hunt ao fechar e horário do fechamento restaurados")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
	return true
