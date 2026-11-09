extends SceneTree
## Regras puras da simulação contra fatos medidos (fonte A nas gravações) e o cliente original (C).
## Rodar: testes/rodar.sh res://testes/test_sim_regras.gd

const Regras := preload("res://sim/regras.gd")
const DadosJogo := preload("res://sim/dados_jogo.gd")
const Rng := preload("res://sim/rng.gd")
const Json := preload("res://sim/json_canonico.gd")

var falhas := 0
var total := 0


func checar(ok: bool, nome: String, detalhe: String = "") -> void:
	total += 1
	if not ok:
		falhas += 1
	print(("OK    " if ok else "FALHA ") + nome + ("" if detalhe == "" else "  (" + detalhe + ")"))


func stats_tipicos(dados, id: int, nivel: int) -> Dictionary:
	# Indivíduo mediano (IV 16, Quality 1,05) para casos em que os stats reais do oponente não foram gravados.
	var iv := {"hp": 16, "atk": 16, "def": 16, "spAtk": 16, "spDef": 16, "speed": 16}
	return Regras.calcular_stats(dados.especie(id)["base"], iv, nivel, 1.05)


func _init() -> void:
	var dados = DadosJogo.carregar()
	var venu: Dictionary = dados.especie(3)

	# --- Venusaur da gravação (poke-delta, nível 109): IVs únicos, soma = ivTotal, Power e HP batem.
	var st109 := {"hp": 121, "atk": 87, "def": 86, "spAtk": 128, "spDef": 126, "speed": 125}
	var cand := Regras.estimar_ivs(venu["base"], st109, 109, 0.835)
	var ivs := {}
	var unicos := true
	var soma := 0
	for k in Regras.CHAVES_STATS:
		unicos = unicos and (cand[k] as Array).size() == 1
		ivs[k] = cand[k][0] if (cand[k] as Array).size() > 0 else 0
		soma += int(ivs[k])
	checar(unicos, "IVs do Venusaur únicos a partir dos stats exibidos", str(ivs))
	checar(soma == 98, "soma dos IVs = ivTotal 98 do servidor", str(soma))
	checar(Regras.power(Regras.calcular_stats(venu["base"], ivs, 109, 0.835), 0.835) == 562, "Power 562")
	var st108 := Regras.calcular_stats(venu["base"], ivs, 108, 0.835)
	checar(Regras.hp_combate_aliado(int(st108["hp"])) == 1440, "HP de combate nível 108 = 1440", str(st108["hp"]))
	checar(Regras.hp_combate_aliado(121) == 1452 and Regras.hp_combate_aliado(2) == 24 and Regras.hp_combate_aliado(3) == 36, "HP aliado 12×, piso 24")
	checar(Regras.hp_combate_selvagem(1) == 120 and Regras.hp_combate_selvagem(123) == 4305, "HP selvagem 35×, piso 120")

	# --- Curva de XP (A: 100/200/400/800; conta da gravação nos níveis 108/109)
	checar([2, 3, 4, 5].map(func(n): return Regras.xp_total_para_nivel(n)) == [100, 200, 400, 800], "XP acumulada níveis 2–5")
	checar(Regras.nivel_por_xp(20416399) == 108 and Regras.nivel_por_xp(20474874) == 109, "nível do poke 108 e do treinador 109 pelos XP gravados")
	checar(Regras.nivel_por_xp(102) == 2 and Regras.nivel_por_xp(210) == 3 and Regras.nivel_por_xp(714) == 4, "Geodude: 102→2, 210→3, 714→4")

	# --- Efetividade amplificada (A: valores de eff vistos nos hits)
	checar(Regras.efetividade_amplificada(Regras.efetividade_bruta("GRASS", "GROUND", "ROCK")) == 5.5, "Grama em Terra/Pedra = 5,5")
	checar(is_equal_approx(Regras.efetividade_amplificada(Regras.efetividade_bruta("NORMAL", "ROCK", "GROUND")), 1.0 / 3.0), "Normal em Pedra = 0,333")
	checar(Regras.efetividade_amplificada(Regras.efetividade_bruta("FIRE", "GRASS", "POISON")) == 2.5, "Fogo em Grama/Veneno = 2,5")
	checar(Json.numero(Regras.efetividade_amplificada(0.5)) == "0.3333333333333333", "eff 0,333 serializa como no servidor")

	# --- Seleção de golpe: os 9 pares vistos nas gravações (atacante, nível, defensor, nível, golpe observado)
	var casos := [
		[3, 108, 112, 80, "Solar Beam"], [3, 108, 115, 80, "Solar Beam"], [3, 108, 157, 80, "Double-Edge"],
		[112, 80, 3, 108, "Stone Edge"], [115, 80, 3, 108, "Mega Punch"], [157, 80, 3, 108, "Eruption"],
		[157, 80, 74, 4, "Eruption"], [19, int(dados.hunts["rattata"]["nivel"]), 74, 2, "Tackle"], [74, 2, 19, int(dados.hunts["rattata"]["nivel"]), "Tackle"],
		[112, 80, 9, 80, "Stone Edge"],
	]
	for c in casos:
		var sa: Dictionary = st108 if c[0] == 3 else stats_tipicos(dados, c[0], c[1])
		var sd: Dictionary = st108 if c[2] == 3 else stats_tipicos(dados, c[2], c[3])
		var g := Regras.escolher_golpe(dados.especie(c[0]), c[1], sa, dados.especie(c[2]), sd)
		checar(g.get("nome", "") == c[4], "golpe %s→%s = %s" % [dados.especie(c[0])["nome"], dados.especie(c[2])["nome"], c[4]], "escolhido: %s" % g.get("nome", "-"))

	# --- Dano: piso 2 aliado / 1 selvagem inclusive com eff 0
	checar(Regras.dano(1, 50, 1, 500, false, 0.0, false, 1.0) == 2 and Regras.dano(1, 50, 1, 500, false, 0.0, true, 1.0) == 1, "piso de dano com eff 0")
	checar(Regras.dano(1, 50, 1, 500, false, 1.0 / 3.0, true, 0.85) == 1, "piso 1 do selvagem resistido")

	# --- Quality e IV seguem as faixas do cliente
	var rng = Rng.new(123)
	var qmin := 9.0
	var qmax := 0.0
	var faixa_vazia := 0
	var ivok := true
	for i in 20000:
		var q := Regras.sortear_qualidade(rng)
		qmin = minf(qmin, q)
		qmax = maxf(qmax, q)
		if q > 1.6 and q < 1.7:
			faixa_vazia += 1
		var iv := Regras.sortear_ivs(rng)
		for k in iv:
			ivok = ivok and int(iv[k]) >= 1 and int(iv[k]) <= 32
	checar(qmin >= 0.8 and qmax <= 1.8 and faixa_vazia == 0, "Quality em 0,8–1,8 sem a faixa 1,6–1,7", "%.3f–%.3f" % [qmin, qmax])
	checar(ivok, "IV de 1 a 32")
	var r1 = Rng.new(42)
	var r2 = Rng.new(42)
	var iguais := true
	for i in 1000:
		iguais = iguais and r1.proximo_u32() == r2.proximo_u32()
	checar(iguais and Rng.new(43).proximo_u32() != Rng.new(42).proximo_u32(), "RNG determinístico por semente")

	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(0 if falhas == 0 else 1)
