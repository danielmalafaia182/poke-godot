extends SceneTree
## Decisões do usuário (E, CLAUDE.md) que vivem na simulação: troca aleatória após KO entre membros vivos do time,
## sem curar; 5 s de cooldown para troca manual depois dela; volta à cidade sem reserva viva; cartão de derrota um por
## vez e até 30 por instância; contador Capture zerado por instância. Rodar: testes/rodar.sh res://testes/test_sim_regras_usuario.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Apresentacao := preload("res://sim/regras_apresentacao.gd")

var falhas := 0
var total := 0
var dados: RefCounted
var mapa: RefCounted


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func nova_sim(semente: int, hp_reservas: Array) -> RefCounted:
	var cfg := Cenario.de_estado(Fontes.raiz_projeto() + "/dados/testes/estado_rhydon_venusaur_1h.json", dados, semente)
	cfg["auto_potion"] = false
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	sim.equipe[0]["hp"] = 1           # o ativo cai no primeiro golpe
	for i in hp_reservas.size():
		sim.equipe[i + 1]["hp"] = hp_reservas[i]
		sim.equipe[i + 1]["max_hp"] = maxi(int(sim.equipe[i + 1]["max_hp"]), hp_reservas[i])
	return sim


func ate_ko(sim) -> Array:
	## Avança até a primeira troca por KO (ou fim); devolve as mensagens emitidas até lá.
	var msgs: Array = []
	for i in 3000:
		var ativo_antes: int = sim.ativo
		for m in sim.passo():
			msgs.append(m["msg"])
		if sim.ativo != ativo_antes or sim.encerrada:
			return msgs
	return msgs


func _init() -> void:
	dados = DadosJogo.carregar()
	mapa = MapaHunt.carregar("rhydon", Fontes.ler_mapa("rhydon"), Fontes.ler_colisao())

	# --- troca aleatória entre vivos, sem curar
	var escolhidos := {}
	var curou := false
	var morto_escolhido := false
	for semente in range(1, 21):
		var sim = nova_sim(semente, [20, 30])
		ate_ko(sim)
		escolhidos[sim.ativo] = true
		if sim.ativo == 0:
			morto_escolhido = true
		var hp_esperado := 20 if sim.ativo == 1 else 30
		if int(sim.equipe[sim.ativo]["hp"]) > hp_esperado:
			curou = true
	checar(not morto_escolhido and escolhidos.has(1) and escolhidos.has(2),
		"KO → troca aleatória entre os membros vivos do time (20 sementes)", str(escolhidos.keys()))
	checar(not curou, "a troca não cura o substituto")
	var sim2 = nova_sim(5, [0, 30])
	ate_ko(sim2)
	checar(sim2.ativo == 2, "membro desmaiado nunca é escolhido", "ativo %d" % sim2.ativo)

	# --- 5 s de cooldown para troca manual após a troca automática
	var sim3 = nova_sim(7, [99999999, 99999999])   # reservas que aguentam os 5 s (Geodude 1 toma ~18 mil por golpe)
	ate_ko(sim3)
	var outro: int = 1 if sim3.ativo == 2 else 2
	var tick_ko: int = sim3.tick
	var recusas := 0
	var aceita_em := -1
	for k in 40:
		var antes: int = sim3.ativo
		var t_pedido: int = sim3.tick      # a intenção é tratada no começo do passo, antes do tick avançar
		for m in sim3.passo([{"type": "switch", "teamIndex": outro}] if sim3.ativo != outro else []):
			if m["msg"]["type"] == "error":
				recusas += 1
		if sim3.ativo == outro and antes != outro:
			aceita_em = t_pedido - tick_ko
			break
	checar(recusas == 25 and aceita_em == 25, "troca manual recusada nos 5 s (25 ticks) depois do KO e aceita aos 5 s",
		"recusas %d, aceita %d ticks depois do KO" % [recusas, aceita_em])
	var sim4 = nova_sim(8, [20, 30])
	for k in 3:
		sim4.passo()
	sim4.equipe[0]["hp"] = 999
	var antes4: int = sim4.ativo
	sim4.passo([{"type": "switch", "teamIndex": 1}])
	checar(sim4.ativo == 1 and antes4 == 0, "sem KO recente, a troca manual é aceita na hora")

	# --- sem reserva viva: volta à cidade
	var sim5 = nova_sim(9, [0, 0])
	var msgs := ate_ko(sim5)
	var none := msgs.filter(func(m): return m["type"] == "field-none")
	checar(sim5.encerrada and none.size() == 1 and String(none[0].get("motivo", "")) == "sem-reserva",
		"KO sem reserva viva → field-none (motivo sem-reserva) e a instância acaba")
	checar(sim5.passo().is_empty(), "depois disso a simulação não emite mais nada")

	# --- cartão de derrota: um por vez, sem fila, até 30 por instância
	var ap = Apresentacao.new()
	ap.nova_instancia("rhydon:1")
	checar(ap.mostrar_cartao({}, 0), "1º abate abre cartão")
	checar(not ap.mostrar_cartao({}, 1000), "abate com cartão na tela não abre outro (nem entra em fila)")
	checar(not ap.cartao_visivel(4720) and ap.mostrar_cartao({}, 4720), "abre de novo só depois de 4500 + 220 ms")
	var t := 10000
	var abertos := 2
	for i in 100:
		if ap.mostrar_cartao({}, t):
			abertos += 1
		t += 5000
	checar(abertos == 30, "no máximo 30 cartões por instância", "%d" % abertos)
	ap.nova_instancia("rhydon:1")
	checar(not ap.mostrar_cartao({}, t + 10000), "retomada (mesma huntKey) mantém o limite")
	ap.nova_instancia("rhydon:2")
	checar(ap.mostrar_cartao({}, t + 20000), "instância nova zera o limite")
	var ap2 = Apresentacao.new()
	ap2.nova_instancia("x")
	ap2.mostrar_cartao({"shiny": true}, 0)
	checar(not ap2.mostrar_cartao({}, 5000) and ap2.mostrar_cartao({}, 7220), "shiny fica 7000 ms (+220)")

	# --- contador Capture por instância
	var ap3 = Apresentacao.new()
	ap3.nova_instancia("a")
	ap3.ao_resultado_captura({"success": false})
	ap3.ao_resultado_captura({"success": true})
	var c := ap3.ao_resultado_captura({"success": true})
	checar(c == 2, "contador Capture conta só sucessos", str(c))
	ap3.nova_instancia("a")
	checar(ap3.capturas == 2, "retomada mantém o contador")
	ap3.nova_instancia("b")
	checar(ap3.capturas == 0, "instância nova zera o contador")

	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
