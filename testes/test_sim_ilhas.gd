extends SceneTree
## Ilhas da grade (2b.6): ponto inicial bloqueado, ilha do herói sem spawn e alvo só entre os alcançáveis, sobre hunts
## reais (grade derivada do snapshot). Rodar: testes/rodar.sh res://testes/test_sim_ilhas.gd

const Fontes := preload("res://sim/fontes.gd")
const MapaHunt := preload("res://sim/mapa_hunt.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Cenario := preload("res://sim/cenario.gd")
const Simulacao := preload("res://sim/simulacao_hunt.gd")
const Regras := preload("res://sim/regras.gd")

var falhas := 0
var total := 0
var dados: RefCounted


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func nova_sim(slug: String, semente: int = 1) -> RefCounted:
	var cfg := Cenario.de_estado(Fontes.raiz_projeto() + "/dados/testes/estado_rhydon_venusaur_1h.json", dados, semente, slug)
	# time de teste (E): nível 3 × nível da hunt + 50, como na varredura, para o herói não morrer no caminho
	for e in cfg["equipe"]:
		e["xp"] = Regras.xp_total_para_nivel(int(cfg["nivel_selvagem"]) * 3 + 50)
		e.erase("hp")
	var mapa = MapaHunt.carregar(slug, Fontes.ler_mapa(slug), Fontes.ler_colisao())
	var sim = Simulacao.new(cfg, dados, mapa)
	sim.iniciar()
	return sim


func rodar(sim, ticks: int) -> int:
	## Devolve o maior tempo de um tick (µs).
	var pior := 0
	for i in ticks:
		var t := Time.get_ticks_usec()
		sim.passo()
		pior = maxi(pior, Time.get_ticks_usec() - t)
	return pior


func _initialize() -> void:
	dados = DadosJogo.carregar()

	# typhlosion (A): start (54,75) bloqueado; o herói real aparece em (53,74) = 1º livre do anel 1 em linha → coluna
	var s = nova_sim("typhlosion")
	checar(s.heroi["pos"] == Vector2i(74, 53), "typhlosion: start bloqueado vai para (row 53, col 74) como no original",
		str(s.heroi["pos"]) + " " + str(s.ajuste_inicio))

	# rhydon: start livre e todos os spawns alcançáveis → nada muda
	s = nova_sim("rhydon")
	checar(s.ajuste_inicio.is_empty(), "rhydon: start usado como veio", str(s.ajuste_inicio))

	# nightmare_magby (E): os 56 spawns estão em outra ilha → o herói começa na ilha que alcança mais spawns e abate
	s = nova_sim("nightmare_magby")
	checar(s.ajuste_inicio.has("ilha_sem_spawn"), "nightmare_magby: herói levado à ilha com spawns", str(s.ajuste_inicio))
	var pior := rodar(s, 300)
	checar(int(s.estatisticas["hits_aliado"]) > 0, "nightmare_magby: o aliado chega a atacar", str(s.estatisticas["hits_aliado"]))
	checar(pior < 100000, "nightmare_magby: nenhum tick acima de 100 ms", "%d µs" % pior)

	# hunts que ficavam sem abate na varredura (start bloqueado ou selvagem inalcançável como alvo). O time do teste é
	# o Venusaur real com nível 3 × o da hunt + 50; o que se cobra é o herói não ficar preso: chega a atacar em até 3 min.
	for slug in ["arbok", "arcanine", "cyndaquil", "quilava", "venomoth", "seel", "slowbro", "nightmare_elekid", "nightmare_snorunt"]:
		s = nova_sim(slug)
		pior = 0
		var n := 0
		while n < 900 and int(s.estatisticas["hits_aliado"]) == 0:
			pior = maxi(pior, rodar(s, 1))
			n += 1
		checar(int(s.estatisticas["hits_aliado"]) > 0 and pior < 100000, slug + ": o aliado chega a atacar, nenhum tick > 100 ms",
			"1º golpe no tick %d, pior tick %d µs, ajuste %s" % [n, pior, s.ajuste_inicio])

	# banette (F): alvo atrás de outros selvagens num corredor de 1 tile; o herói ataca o encostado em vez de apanhar parado
	s = nova_sim("banette")
	rodar(s, 300)
	checar(int(s.estatisticas["abates"]) > 0, "banette: com o caminho fechado, ataca o selvagem encostado e abate em 60 s",
		"abates %d" % s.estatisticas["abates"])

	# o alvo nunca é um selvagem inalcançável
	s = nova_sim("seel")
	var ok := true
	for i in 300:
		s.passo()
		var a := int(s.heroi["alvo"])
		if a >= 0 and not s._alvo_valido(s.mobs[a]):
			ok = false
	checar(ok, "seel: alvo sempre alcançável em 300 ticks")

	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
