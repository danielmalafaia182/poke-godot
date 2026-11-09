extends RefCounted
## Regras puras da simulação (sem estado). Cada regra traz a origem:
## (A) observado no servidor, (B) Pokepedia, (C) extraído do cliente original, (D) testado localmente,
## (E) decisão do projeto, (F) hipótese. Hipóteses ficam em PARAMETROS para serem calibradas (fase 3).

const PARAMETROS := {
	"tick_ms": 200,                         # A: todos os logs
	"ticks_por_field": 2,                   # A: field a cada 400 ms
	"hero_step_ms": 500,                    # A: field-init.heroStepMs (duração da animação)
	"mob_step_ms": 1000,                    # A: field-init.mobStepMs
	"trainer_step_ms": 500,                 # A: field-init.trainerStepMs
	# Passos (A, ferramentas/gravador/medir_passos.py; gravações antigas + rhydon-1h): espera antes de cada passo =
	# stepMs × (2 se o passo é diagonal), arredondada para cima ao tick. Herói →reto 600 ms (113/121 e 241/247),
	# →diagonal 1000 ou 1200 (40/19 e 110/54); selvagem →reto 1000 ou 1200 (167/93 e 409/226),
	# →diagonal 2000 ou 2200 (89/4 e 138/6).
	"fator_diagonal_passo": 2,              # A (e C: o cliente anima a diagonal com o mesmo custo, dS)
	"passo_extra_prob_heroi_reto": 0.0,     # A: 500 ms não cai num tick exato; 600 em 113/121
	"passo_extra_prob_heroi_diagonal": 0.33,  # A: 73/223 esperas de 1000 ms saíram em 1200
	"passo_extra_prob_mob_reto": 0.36,      # A: 319/895 esperas de 1000 ms saíram em 1200
	"passo_extra_prob_mob_diagonal": 0.04,  # A: 10/237 esperas de 2000 ms saíram em 2200
	# Caminho (F: Dijkstra de tempo mínimo com os custos acima). Desempate entre passos igualmente ótimos, por classe
	# [reto no eixo maior, diagonal, reto no eixo menor], com pesos = frequências medidas fora do eixo (A), somando as
	# gravações antigas e a rhydon-1h (herói 475/146/26 + 1294/325/48; selvagem 385/232/143 + 1152/447/244).
	"desempate_heroi": [1769, 471, 74],
	"desempate_mob": [1537, 679, 387],
	"caminho_margem": 6,                    # F: folga da caixa de busca em volta do herói/alvo (tiles)
	"ataque_aliado_ticks": 8,               # A: 1600 ms, grade fixa (as variações de 1200/2000 vêm de field não recebido)
	"ataque_selvagem_ticks": 10,            # A: ~2000 ms por selvagem
	"ataque_selvagem_extra_prob": 0.25,     # F: às vezes +1 tick (média medida ~2050 ms no Kangaskhan)
	"primeiro_ataque_selvagem_ticks": 10,   # F: 1º golpe ~2000 ms depois de encostar (4 casos: 1600–3200 ms)
	"visao_meia_largura": 13,               # C+A: comando view {hc:27, hr:15}; selvagens só perseguem dentro dela
	"visao_meia_altura": 7,                 # C+A
	"respawn_ms": 60000,                    # A: 7 respawns medidos, todos 60 s, no ponto de spawn, mesmo indivíduo
	"cadaver_ms": 20000,                    # A aproximado: corpos somem em ~19–20 s
	"fator_selvagem": 1.8,                  # F: fórmula candidata
	"stab": 1.5,                            # B
	"aleatorio_min": 0.85,                  # A: máx/mín ≤ 1,17 por indivíduo
	"aleatorio_max": 1.0,                   # A
	"piso_aliado": 2,                       # A: Gastly × Rattata
	"piso_selvagem": 1,                     # A: 880 hits do Rattata no Geodude
	"arredondamento_dano": "round",         # F: round (Math.round) ou floor; sem evidência
	# Stats na fórmula de dano (F, forte). Selvagem sem arredondar: na rhydon-1h o Solar Beam é explicado por uma SpD
	# inteira em 2/15 indivíduos e por uma SpD contínua em 15/15. Aliado arredondado (o valor exibido no poke-delta):
	# com a SpA exibida 15/15; com a SpA recalculada sem arredondar (IVs e Q exatos) só 10/15.
	"stats_dano_selvagem": "continuo",      # "inteiro" volta ao modelo antigo
	"stats_dano_aliado": "inteiro",
	"pocao_limiar": 0.5,                    # A: HP ≤ 50% dispara no mesmo tick (91/91 cruzamentos; HP exato na cura ≤ 0,50
	                                        # em 409 curas); o Auto-Helper da gravação de 1 h mostra "Heal when HP ≤ 50%"
	"pocao_recarga_ms": 0,                  # A/F: nenhuma cura adiada observada; menor intervalo real 1988 ms
	"troca_cooldown_ms": 5000,              # E: depois da troca automática por KO, 5 s sem troca manual
	"vip_fracao": 0.5,                      # A: parcela vip = 50% da base
	"debuff_entrada_abates": 7,             # A: rhydon-1h, os 7 primeiros abates após entrar (o 8º, 22 s depois, já sem)
	                                        # F: mecanismo contado em abates (pode ser tempo, ~1 min; não dá para separar)
	"debuff_entrada_fator": 0.3,            # A: 1731 = floor(5772 × 0,3); debuff = −4041
	# Captura (A nos pontos, F na curva): {bola: [[nível do selvagem, capturas, tentativas], ...]}. Entre os pontos,
	# interpolação linear no logit; fora deles, o ponto mais próximo. Bola sem pontos → 0 (F). Espécie ignorada (F:
	# os dois pontos são de espécies diferentes, Rattata e Rhydon). hunt-config.catchChance é 0 em todas (não usado).
	"captura_pontos": {"3": [[1, 35, 59], [80, 5, 608]]},
	"hp_selvagem_por_stat": 35,             # A
	"hp_selvagem_minimo": 120,              # A
	"golpe_poder_maximo": 599,              # F: golpes de poder 600 (assinatura) nunca aparecem nas gravações
	"chance_shiny": 0.0,                    # E: sem shiny na fase 1
}

# (C) cliente original, chunk 0fllz2m_ktm3s.js: tabela de tipos `k` e typeEffectiveness().
const TABELA_TIPOS := {
	"NORMAL": {"ROCK": 0.5, "GHOST": 0.0, "STEEL": 0.5},
	"FIRE": {"FIRE": 0.5, "WATER": 0.5, "GRASS": 2.0, "ICE": 2.0, "BUG": 2.0, "ROCK": 0.5, "DRAGON": 0.5, "STEEL": 2.0},
	"WATER": {"FIRE": 2.0, "WATER": 0.5, "GRASS": 0.5, "GROUND": 2.0, "ROCK": 2.0, "DRAGON": 0.5},
	"ELECTRIC": {"WATER": 2.0, "ELECTRIC": 0.5, "GRASS": 0.5, "GROUND": 0.0, "FLYING": 2.0, "DRAGON": 0.5},
	"GRASS": {"FIRE": 0.5, "WATER": 2.0, "GRASS": 0.5, "POISON": 0.5, "GROUND": 2.0, "FLYING": 0.5, "BUG": 0.5, "ROCK": 2.0, "DRAGON": 0.5, "STEEL": 0.5},
	"ICE": {"FIRE": 0.5, "WATER": 0.5, "GRASS": 2.0, "ICE": 0.5, "GROUND": 2.0, "FLYING": 2.0, "DRAGON": 2.0, "STEEL": 0.5},
	"FIGHTING": {"NORMAL": 2.0, "ICE": 2.0, "POISON": 0.5, "FLYING": 0.5, "PSYCHIC": 0.5, "BUG": 0.5, "ROCK": 2.0, "GHOST": 0.0, "DARK": 2.0, "STEEL": 2.0, "FAIRY": 0.5},
	"POISON": {"GRASS": 2.0, "POISON": 0.5, "GROUND": 0.5, "ROCK": 0.5, "GHOST": 0.5, "STEEL": 0.0, "FAIRY": 2.0},
	"GROUND": {"FIRE": 2.0, "ELECTRIC": 2.0, "GRASS": 0.5, "POISON": 2.0, "FLYING": 0.0, "BUG": 0.5, "ROCK": 2.0, "STEEL": 2.0},
	"FLYING": {"ELECTRIC": 0.5, "GRASS": 2.0, "FIGHTING": 2.0, "BUG": 2.0, "ROCK": 0.5, "STEEL": 0.5},
	"PSYCHIC": {"FIGHTING": 2.0, "POISON": 2.0, "PSYCHIC": 0.5, "DARK": 0.0, "STEEL": 0.5},
	"BUG": {"FIRE": 0.5, "GRASS": 2.0, "FIGHTING": 0.5, "POISON": 0.5, "FLYING": 0.5, "PSYCHIC": 2.0, "GHOST": 0.5, "DARK": 2.0, "STEEL": 0.5, "FAIRY": 0.5},
	"ROCK": {"FIRE": 2.0, "ICE": 2.0, "FIGHTING": 0.5, "GROUND": 0.5, "FLYING": 2.0, "BUG": 2.0, "STEEL": 0.5},
	"GHOST": {"NORMAL": 0.0, "PSYCHIC": 2.0, "GHOST": 2.0, "DARK": 0.5},
	"DRAGON": {"DRAGON": 2.0, "STEEL": 0.5, "FAIRY": 0.0},
	"DARK": {"FIGHTING": 0.5, "PSYCHIC": 2.0, "GHOST": 2.0, "DARK": 0.5, "FAIRY": 0.5},
	"STEEL": {"FIRE": 0.5, "WATER": 0.5, "ELECTRIC": 0.5, "ICE": 2.0, "ROCK": 2.0, "STEEL": 0.5, "FAIRY": 2.0},
	"FAIRY": {"FIRE": 0.5, "FIGHTING": 2.0, "POISON": 0.5, "DRAGON": 2.0, "DARK": 2.0, "STEEL": 0.5},
}

# (C) rollQuality(): [mín, máx, peso%]. Não existe faixa 1,6–1,7 no cliente.
const FAIXAS_QUALIDADE := [
	[0.8, 0.9, 5.0], [0.9, 1.0, 5.0], [1.0, 1.1, 34.03846], [1.1, 1.2, 20.0], [1.2, 1.3, 10.0],
	[1.3, 1.4, 10.0], [1.4, 1.5, 10.0], [1.5, 1.6, 5.0], [1.7, 1.8, 0.67308], [1.8, 1.8, 0.28846],
]
const CHAVES_STATS := ["hp", "atk", "def", "spAtk", "spDef", "speed"]
const EXPOENTE_STAT := {"hp": 0.95, "atk": 0.8, "def": 0.8, "spAtk": 0.8, "spDef": 0.8, "speed": 0.95}  # C


static func js_round(x: float) -> int:
	## Math.round do JavaScript (meio arredonda para cima).
	return int(floor(x + 0.5))


# ---------------------------------------------------------------- stats (C, conferido em D)

static func stat(base: int, iv: int, nivel: int, qualidade: float, chave: String) -> int:
	return js_round(float(nivel) / 100.0 * float(base + 2 * iv) * pow(qualidade, EXPOENTE_STAT[chave]))


static func stat_bruto(base: int, iv: int, nivel: int, qualidade: float, chave: String) -> float:
	return float(nivel) / 100.0 * float(base + 2 * iv) * pow(qualidade, EXPOENTE_STAT[chave])


static func calcular_stats_dano(base: Dictionary, ivs: Dictionary, nivel: int, qualidade: float, modo: String) -> Dictionary:
	## Stats usados na fórmula de dano: modo "continuo" (sem arredondar) ou "inteiro" (os exibidos). Ver PARAMETROS
	## stats_dano_*. Os stats exibidos (poke-delta) e o HP de combate continuam arredondados (A).
	if modo == "inteiro":
		return calcular_stats(base, ivs, nivel, qualidade)
	var r := {}
	for k in CHAVES_STATS:
		r[k] = stat_bruto(int(base[k]), int(ivs[k]), nivel, qualidade, k)
	return r


static func calcular_stats(base: Dictionary, ivs: Dictionary, nivel: int, qualidade: float) -> Dictionary:
	var r := {}
	for k in CHAVES_STATS:
		r[k] = stat(int(base[k]), int(ivs[k]), nivel, qualidade, k)
	return r


static func power(stats: Dictionary, qualidade: float) -> int:
	var soma := 0
	for k in CHAVES_STATS:
		soma += int(stats[k])
	return js_round(float(soma) * qualidade)


static func hp_combate_aliado(stat_hp: int) -> int:
	return maxi(24, js_round(float(stat_hp) * 12.0))  # C: combatHp(e,false); A: 120→1440, 2→24


static func hp_combate_selvagem(stat_hp: int, p: Dictionary = PARAMETROS) -> int:
	return maxi(int(p.hp_selvagem_minimo), js_round(float(stat_hp) * float(p.hp_selvagem_por_stat)))  # A


static func estimar_ivs(base: Dictionary, stats: Dictionary, nivel: int, qualidade: float) -> Dictionary:
	## Para cada atributo, os IVs (1..32) que reproduzem o stat exibido. Retorna {chave: [ivs possíveis]}.
	var r := {}
	for k in CHAVES_STATS:
		var ok: Array = []
		for iv in range(1, 33):
			if stat(int(base[k]), iv, nivel, qualidade, k) == int(stats[k]):
				ok.append(iv)
		r[k] = ok
	return r


static func sortear_ivs(rng) -> Dictionary:
	var r := {}
	for k in CHAVES_STATS:
		r[k] = 1 + int(floor(32.0 * rng.randf()))  # C: rollGrowthSet
	return r


static func sortear_qualidade(rng) -> float:
	var o: float = 100.0 * rng.randf()  # C: rollQuality
	for faixa in FAIXAS_QUALIDADE:
		var lo: float = faixa[0]
		var hi: float = faixa[1]
		var w: float = faixa[2]
		if o < w:
			if lo == hi:
				return lo
			return floor((lo + rng.randf() * (hi - lo)) * 1000.0) / 1000.0
		o -= w
	return 1.0


# ---------------------------------------------------------------- XP (C: totalXpForLevel / levelProgress; A: 100/200/400/800)

static func _c(l: int) -> float:
	if l <= 1:
		return 0.0
	var e := float(l)
	return float(js_round(50.0 / 3.0 * (e * e * e - 6.0 * e * e + 17.0 * e - 12.0)))


static func xp_total_para_nivel(nivel: int) -> int:
	if nivel <= 150:
		return int(_c(nivel))
	var t := nivel - 150
	if t <= 100:
		var i := float(t)
		var extra := 0.5 * pow(i * (i + 1.0) / 2.0, 2.0) + i * (i + 1.0) * (2.0 * i + 1.0) / 6.0 * 197.5 + i * (i + 1.0) / 2.0 * 25629.0 + 1087900.0 * i
		return js_round(_c(150) + extra)
	return js_round(float(xp_total_para_nivel(250)) + 2.0 * (_c(nivel) - _c(250)))


static func nivel_por_xp(xp: int) -> int:
	if xp <= 0:
		return 1
	var o := 2
	while o < 10000000 and xp_total_para_nivel(o) <= xp:
		o *= 2
	var t := maxi(1, o / 2)
	var melhor := t
	while t <= o:
		var meio := (t + o) / 2
		if xp_total_para_nivel(meio) <= xp:
			melhor = meio
			t = meio + 1
		else:
			o = meio - 1
	return melhor


# ---------------------------------------------------------------- tipos e dano

static func efetividade_bruta(tipo_golpe: String, t1: String, t2: String) -> float:
	var linha: Dictionary = TABELA_TIPOS.get(tipo_golpe.to_upper(), {})
	var a := t1.to_upper()
	var b := t2.to_upper()
	var e: float = linha.get(a, 1.0)
	if b != "" and b != a:
		e *= float(linha.get(b, 1.0))
	return e


static func efetividade_amplificada(bruta: float) -> float:
	## (B)+(A): ×4→5,5; ×2→2,5; ×1,5→1,75; ×½→÷1,5 (0,333…, visto em `eff`); ×0 fica 0 (dano vai ao piso).
	## ×¼ → 0,25/1,5 é hipótese (F): nenhum caso observado.
	if bruta == 0.0:
		return 0.0
	if bruta >= 4.0:
		return 5.5
	if bruta >= 2.0:
		return 2.5
	if bruta >= 1.5:
		return 1.75
	if bruta >= 1.0:
		return 1.0
	return bruta / 1.5


static func chance_captura(bola: int, nivel: int, p: Dictionary = PARAMETROS) -> float:
	var pts: Array = p.get("captura_pontos", {}).get(str(bola), [])
	if pts.is_empty():
		return 0.0
	var ord := pts.duplicate()
	ord.sort_custom(func(x, y): return int(x[0]) < int(y[0]))
	var prob := func(pt) -> float: return float(pt[1]) / maxf(1.0, float(pt[2]))
	if nivel <= int(ord[0][0]):
		return prob.call(ord[0])
	if nivel >= int(ord[ord.size() - 1][0]):
		return prob.call(ord[ord.size() - 1])
	for i in range(ord.size() - 1):
		var a: Array = ord[i]
		var b: Array = ord[i + 1]
		if nivel <= int(b[0]):
			var t := float(nivel - int(a[0])) / float(int(b[0]) - int(a[0]))
			var la := _logit(prob.call(a))
			var lb := _logit(prob.call(b))
			return 1.0 / (1.0 + exp(-(la + t * (lb - la))))
	return 0.0


static func _logit(x: float) -> float:
	var c := clampf(x, 1e-6, 1.0 - 1e-6)
	return log(c / (1.0 - c))


static func tipos_de(especie: Dictionary) -> Array:
	var t: Array = especie.get("tipos", [])
	return [t[0] if t.size() > 0 else "", t[1] if t.size() > 1 else ""]


static func dano(nivel: int, poder: int, ataque: float, defesa: float, stab: bool, eff: float, selvagem: bool, aleatorio: float, p: Dictionary = PARAMETROS) -> int:
	## Fórmula candidata (F), coerente com os envelopes medidos (ver CLAUDE.md).
	var piso: int = int(p.piso_selvagem) if selvagem else int(p.piso_aliado)
	if eff == 0.0:
		return piso
	var v := (2.0 * float(nivel) / 5.0 + 2.0) * float(poder) * ataque / maxf(1.0, defesa) / 50.0
	if stab:
		v *= float(p.stab)
	v *= eff
	if selvagem:
		v *= float(p.fator_selvagem)
	v *= aleatorio
	var n: int = js_round(v) if String(p.arredondamento_dano) == "round" else int(floor(v))
	return maxi(piso, n)


static func escolher_golpe(especie_atk: Dictionary, nivel: int, stats_atk: Dictionary, especie_def: Dictionary, stats_def: Dictionary, p: Dictionary = PARAMETROS) -> Dictionary:
	## Hipótese (F), coerente com os 7 pares gravados: entre os golpes com nivel ≤ nível, de dano e com poder abaixo de 600,
	## o de maior dano esperado (poder × A/D × STAB × eff amplificada); empate → menor cooldown; depois o primeiro da lista.
	var tipos_atk := tipos_de(especie_atk)
	var tipos_def := tipos_de(especie_def)
	var melhor: Dictionary = {}
	var melhor_valor := -1.0
	var melhor_cd := 1 << 40
	for g in especie_atk.get("golpes", []):
		if int(g.get("nivel", 1)) > nivel:
			continue
		var cat := String(g.get("categoria", ""))
		var poder := int(g.get("poder", 0))
		if cat == "STATUS" or poder <= 0 or poder > int(p.golpe_poder_maximo):
			continue
		var especial := cat == "SPECIAL"
		var a := float(stats_atk["spAtk"] if especial else stats_atk["atk"])
		var d := float(stats_def["spDef"] if especial else stats_def["def"])
		var tipo := String(g.get("tipo", ""))
		var stab: bool = tipo == tipos_atk[0] or (tipos_atk[1] != "" and tipo == tipos_atk[1])
		var eff := efetividade_amplificada(efetividade_bruta(tipo, tipos_def[0], tipos_def[1]))
		var valor := float(poder) * a / maxf(1.0, d) * (float(p.stab) if stab else 1.0) * eff
		var cd := int(g.get("cooldownMs", 0))
		if valor > melhor_valor + 1e-9 or (absf(valor - melhor_valor) <= 1e-9 and cd < melhor_cd):
			melhor = g
			melhor_valor = valor
			melhor_cd = cd
	if melhor.is_empty():
		return {}
	var tipo_m := String(melhor.get("tipo", ""))
	return {
		"nome": melhor.get("nome", ""), "tipo": tipo_m, "categoria": melhor.get("categoria", ""),
		"poder": int(melhor.get("poder", 0)),
		"stab": tipo_m == tipos_atk[0] or (tipos_atk[1] != "" and tipo_m == tipos_atk[1]),
		"eff": efetividade_amplificada(efetividade_bruta(tipo_m, tipos_def[0], tipos_def[1])),
	}
