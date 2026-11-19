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
	# Ilhas da grade (2b.6). 103 hunts têm spawns em tile bloqueado e 9 têm o `start` bloqueado (hunt-config × grade).
	# typhlosion (A, 1 caso): start (54,75) bloqueado; o herói real aparece em (53,74), o 1º tile livre do anel 1 em
	# ordem linha → coluna. F: o herói vai para o tile livre mais próximo (anel de Chebyshev, ordem linha → coluna).
	"inicio_bloqueado_anel": true,
	# E (jogabilidade): se a ilha do herói não alcança nenhum spawn (ex.: nightmare_magby, todos os 56 spawns em outra
	# ilha), ele começa no tile livre mais próximo da ilha que alcança mais spawns. O original não foi observado nesses casos.
	"inicio_ilha_com_spawns": true,
	# F: o alvo é o selvagem vivo mais próximo entre os alcançáveis (algum tile livre a Chebyshev ≤ 1 dele na ilha do
	# herói). Sem isso, o herói fica preso num selvagem de outra ilha e a busca no mapa inteiro roda a cada passo.
	"alvo_so_alcancavel": true,
	# A (18/11, medir_alvo.py: 2295/2400 trocas × 2067 com Chebyshev): alvo = menor tempo de caminho até encostar.
	# "chebyshev" volta à regra anterior (linha reta). Em labirinto (nightmare_elekid) a linha reta mandava o herói a um
	# selvagem a > 60 s de caminho e ele não abatia nada em 60 s (13/20 sementes).
	"alvo_criterio": "caminho",
	# F: sem caminho até o alvo (corredor fechado por outros selvagens; banette) e com selvagem encostado, o herói passa a
	# atacar o encostado mais próximo. Sem isso, apanha parado até morrer. O original não foi observado nesse caso.
	"alvo_troca_se_bloqueado": true,
	# E: espécie sem cadáver conhecido (dados/corpos_por_especie.json) deixa corpse 0 = genérico (a vista desenha o sprite
	# da própria espécie escurecido). Todos os cadáveres do atlas são Pokémon reconhecíveis: não há um neutro para usar.
	"cadaver_generico": true,
	"ataque_aliado_ticks": 8,               # A: 1600 ms, grade fixa (as variações de 1200/2000 vêm de field não recebido)
	"ataque_selvagem_ticks": 10,            # A: ~2000 ms por selvagem
	"ataque_selvagem_extra_prob": 0.25,     # F: às vezes +1 tick (média medida ~2050 ms no Kangaskhan)
	"primeiro_ataque_selvagem_ticks": 10,   # F: 1º golpe ~2000 ms depois de encostar (4 casos: 1600–3200 ms)
	"mob_espera_apos_heroi_ticks": 0,      # F (experimento M3): selvagem só dá passo N ticks depois do último passo do herói; 0 = desligado
	"visao_meia_largura": 13,               # A: perseguição até |dx| 13, nunca 14+ (rhydon-1h, M1, M2)
	# Revertido no ciclo 2: o alvo NÃO vem de fora da borda real (A: 0 de 9.120 intervalos fora de 13×13). Fica só para
	# experimento. O que vale (A) é o alvo perseguir dentro da borda real: `visao_meia_altura_alvo` 13.
	"alvo_vem_ao_encontro": false,
	"visao_meia_altura_alvo": 13,           # A: o alvo persegue até |dy| 13 (os outros, `visao_meia_altura`)
	"visao_meia_altura": 7,                 # F (sim). A borda real medida em 10/11/2026 é 13 nos dois eixos: selvagens se
	                                        # aproximam com |dy| até 13 (0,16–0,43 por intervalo em |dy| 8–13, centenas de
	                                        # intervalos na rhydon-1h; M1/M2 iguais) e nunca com 14+. Com 13 na sim, o
	                                        # Kangaskhan (M1, M2) passa a bater e o Rhydon piora (0,58 adjacentes × 0,40;
	                                        # curas/min fora da faixa no diferencial): falta o que limita o acúmulo em luta
	                                        # curta (F). Fica 7 até isso fechar (M3). A sim ainda persegue com |dx| = 14
	                                        # (0,26–0,41), o real nunca: a checagem real usa a posição de antes do passo (F).
	                                        # C: view = {hc: ceil(25/zoom/2)+2, hr: ceil(13/zoom/2)+2} — só o zoom muda o view
	"respawn_ms": 60000,                    # A: 7 respawns medidos, todos 60 s, no ponto de spawn, mesmo indivíduo
	"cadaver_ms": 20000,                    # A aproximado: corpos somem em ~19–20 s
	"fator_selvagem": 1.8,                  # F: fórmula candidata
	"stab": 1.5,                            # B
	"aleatorio_min": 0.85,                  # A: máx/mín ≤ 1,17 por indivíduo
	"aleatorio_max": 1.0,                   # A
	"piso_aliado": 2,                       # A: Gastly × Rattata
	"piso_selvagem": 1,                     # A: 880 hits do Rattata no Geodude
	"arredondamento_dano": "round",         # F: round (Math.round) ou floor; sem evidência
	# Fase 4, item 1 (F, `ferramentas/fase4/ajustar_dano.py`, tabela em dados/relatorios/ajuste_dano.md): variante da
	# fórmula. "atual" = a de sempre, com o divisor ≥ 1; "sem_piso_divisor" = igual, sem o max(1, D) (stats contínuos do
	# selvagem no nível 1–4 ficam em 0,3–1,0); "classica" = (K + 2) × mods; "mais2_fim" = K × mods + 2.
	# Padrão desde 15/11 (E, decisão do usuário sobre a tabela F): "sem_piso_divisor", igual ou melhor que "atual" em
	# todas as gravações (aliado 1–4: 90,5% × 32,6% dos golpes explicados; o resto igual).
	"formula_dano": "sem_piso_divisor",
	# Fase 4, item 2 (F, 15/11): piso do stat de ataque (Atk/SpA) do ALIADO no cálculo do dano. O Geodude Lv.1 das
	# gravações geodude-10min/geodeude-2 mostra Atk 1 e tira 6–8 no Rattata (153 golpes): com Atk 1 a fórmula dá 2–3;
	# com 3, 6–8. No ajuste com todas as gravações (ajustar_dano.py, variante "e+A3"): aliado nível 1–4 98,1% dos golpes
	# explicados (90,5% sem o piso), nenhuma outra faixa nem gravação muda; no selvagem o piso piora (100% → 85,1% no
	# nível 1–4), por isso só no aliado. Um atacante só (o Geodude): "piso 3" e "stats do nível 2" não se separam (G11).
	# 0 = desligado. Só pesa em stat de ataque < 3 (níveis 1–3, em geral).
	"piso_ataque_aliado": 3.0,
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
	# Penalidade de entrada = boost "shinylock" (C: texto do boost, "Por 1 minuto: nenhum Pokémon Shiny aparece e você
	# recebe 70% menos EXP e drops"; o servidor manda {type: boosts, boosts: [{key: shinylock, until, pct: 0}]}).
	# A: until = entrada + 60,0 s em 4 entradas (rhydon-1h, typhlosion, S2, S4) e todo abate antes do until tem
	# xpParts.debuff, nenhum depois (7/601, 9/23, 10/27). XP: floor(total × 0,3) (A: 5772 → 1731, 846 → 253, 12 → 3).
	# Loot: 15 drops em 5 entradas contra 68 esperados (0,22×; ×0,3 dá P = 0,13) → chance × 0,3 (F: chance ou
	# quantidade não se separam com esta amostra). Quando aplica (A, T1 em 10/11/2026, confirma o relato do usuário):
	# hunt diferente da última, vindo da cidade (rattata → cidade 29 s → spearow) ou direto pelo mapa (spearow → vulpix),
	# penaliza; voltar à mesma hunt pela cidade (vulpix → cidade → vulpix) não penaliza (sem boosts, 0/15 abates com
	# debuff). Sessão expirada: B-relatado (não gravado). Início: o minuto conta da ENTRADA (A: until − 1º serverNow da
	# instância = 58,9–59,3 s nas 3 entradas do T1, e 60,0–61,4 s nas 9 anteriores; os 29 s na cidade não contaram).
	# "Desde a saída" foi descartado; o S3 segue como exceção sem explicação. ms_desde_saida fica 0 (parâmetro mantido).
	# A sim recebe o fim pronto (cfg.penalidade_ate_ms) ou calcula: inicio_ms − cfg.ms_desde_saida + duração.
	"penalidade_duracao_ms": 60000,
	"penalidade_fator": 0.3,
	"penalidade_loot": "chance",            # "chance" (× fator na chance de cada item) | "quantidade" | "nenhuma"
	# Captura com medidor de investimento (C: tutorial "quanto mais bolas você investe numa espécie, maior a chance";
	# tela Gerenciamento de Captura, /api/game/used-balls: por espécie preço de NPC, ouro gasto, tentativas totais e
	# desde a última captura, que zera ao capturar; Master Ball garante; shiny não usa o medidor).
	# Forma (F, máxima verossimilhança em 10/11/2026 sobre as sequências A de Rattata 1, Spearow 10, Vulpix 20 ×2,
	# Rhydon 80 (Super Ball) e Geodude 1 (C5: Poké, Great, Super, Ultra e Idle); o trecho antes da 1ª captura de cada
	# gravação fica de fora porque o medidor inicial não foi gravado; tentativas em shiny ficam de fora (não usam o medidor):
	#   chance = min(1, c · v / precoNpc · (1 + k · investido_antes / precoNpc) · (1 + bônus))
	# v = ouro pago pela bola desta tentativa (priceGold); investido_antes = ouro das bolas desde a última captura, SEM a atual.
	# Sem fator de nível (o C1 derrubou: Spearow 10 capturou 28/52) nem de raridade (ganho nulo).
	# Valor da bola = OURO (A, C5, Geodude 1, preço 300; esperado pelo ouro × pela eficiência, mesmo c/k): Poké 0,9 × 4,0
	# (observado 0/47), Great 5,1 × 9,8 (6/60), Super 12,9 × 13,7 (10/59), Ultra 33,1 × 20,3 (37/69), Idle 73,0 × 26,2
	# (73/73). logL −190,6 (ouro) contra −294,5 (eficiência); com o valor de cada bola livre o ajuste dá Great 23, Ultra 143
	# (ouro: 20 e 130). As 5 falhas de Idle Ball em todas as gravações (S2, C5, M3) foram em shiny.
	# Medidor que zera ao trocar de bola: logL −191,0 contra −190,6 (indistinguível; fica o que soma tudo, como a tela
	# used-balls, que guarda o total por espécie).
	"captura_c": 0.814,
	"captura_k": 1.14,
	"captura_valor_bola": "ouro",           # A (C5): "ouro" = priceGold; "eficiencia" = catchRate × 50/3 (refutado)
	"captura_eficiencia": {"1": 1, "2": 2, "3": 3, "4": 4, "5": 255, "6": 5, "7": 5},   # A: balls.catalog.catchRate
	"captura_preco_bola": {"1": 5, "2": 20, "3": 50, "4": 130, "5": 0, "6": 400, "7": 400},   # A: balls.catalog.priceGold
	"captura_garantida_eficiencia": 255,    # C/B-relatado: Master Ball (catchRate 255) garante
	# Shiny (C, barra de captura: pct = min(1, shinyBase × catchRate)); shinyBase por tier vem do servidor (F: vazio)
	"captura_shiny_base": {},
	# Shiny (A, 19/11, todas as gravações): só espécies com forma shiny (C: SHINY_BY_DEX) aparecem shiny — 0 em 3.323 abates
	# das outras; nas com forma, 42 em 10.914 abates fora do lock = 1/260. Nenhum durante o lock de entrada (A, C: shinylock).
	# Por tier a taxa variou (C 11/881, B 26/9.156, D 3/511, E 2/366): amostra pequena fora do B; fica a taxa única.
	"shiny_chance": 42.0 / 10914.0,
	"captura_shiny_base_padrao": 0.01,       # classe 3 (balanceamento.json): 0 capturas em 31 tentativas gravadas
	"pedra_garantia_fator": 0.0,            # classe 3 (balanceamento.json): 0 = sem garantia de pedra
	"xp_regiao": {},
	"card_chance_shiny": 0.0,
	"pack_chance_abate": 0.0,                # classe 3 (balanceamento.json combate): Poke Card Pack por abate                # classe 3 (balanceamento.json combate): Shiny Card ao abater um shiny                        # classe 3 (balanceamento.json): multiplicador de XP por região; vazio/1 = sem efeito
	"hp_selvagem_por_stat": 35,             # A
	"hp_selvagem_minimo": 120,              # A
	"golpe_poder_maximo": 599,              # F: golpes de poder 600 (assinatura) nunca aparecem nas gravações
	"chance_shiny": 0.0,
	# Fase 4, lote 2 — parcelas de XP e efeitos de loot (cfg.boosts, cfg.eventos, cfg.streak; zero = saída igual a antes).
	# Streak Points (C, guia e janela do original): +0,1% por ponto na trilha EXP (parcela "streak" do treinador; o
	# pokeXp.parts não tem chave streak, A) e, na trilha Loot, +0,1% de chance de uma rolagem EXTRA inteira de drop
	# (100% = uma rolagem garantida; o excesso vira a chance da próxima, C).
	"streak_pct_por_ponto": 0.001,
	# Boosts (C: "XP Boost +50% trainer XP", "Pokémon XP Boost +50%", "Loot Boost +40% loot chance", "Capture Boost:
	# doubles the catch chance"); o pct vem no próprio boost ({key, until, pct}, A). F: parcela = % da XP base.
	"boost_captura_bonus": 1.0,             # C: dobra a chance (multiplica a chance por arremesso)
	# Tipo do Dia (A: evento "type-of-day", "+20% de XP e +20% de loot em Pokémon do tipo X"): parcela typeDay =
	# floor(20% da base) (A, G8: 61/61); loot em `tipo_do_dia_loot` (A: × 1,4, não 1,2).
	# Loot no tipo do dia (A, G8 × G10, 15/11): chance de cada drop × 1,4 (cap 1). Tyranitar no dia Sombrio (G8, 61 abates):
	# 148 drops, esperado 146,3 com ×1,4 (z 0,2) e 125,4 com ×1,2 (z 2,8: rejeitado); a mesma hunt num dia Veneno (G10, 91
	# abates): 161 × 155,9 pela tabela (controle). ×1,44 (= 1,2²) também cabe: não se separa de 1,4 com uma gravação.
	"tipo_do_dia_loot": 1.4,
	# Insígnias de ginásio (C, Gym Rewards): cada insígnia ATIVA dá +1% de XP e +1% de chance de uma rolagem extra de drop.
	"insignia_pct_xp": 1.0,
	"insignia_pct_drop": 1.0,
	"tipo_do_dia_pct": 20,                    # E: sem shiny na fase 1
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


static func valor_bola(bola: int, p: Dictionary = PARAMETROS) -> float:
	## Quanto uma bola soma ao medidor de investimento (ouro ou equivalente; F, ver captura_valor_bola).
	var k := str(bola)
	if String(p.get("captura_valor_bola", "ouro")) == "ouro":
		return float(p.captura_preco_bola.get(k, 0))
	return float(p.captura_eficiencia.get(k, 0)) * float(p.captura_preco_bola.get("3", 50)) / 3.0


static func chance_captura(bola: int, investido_antes: float, preco_npc: float, bonus: float = 0.0, p: Dictionary = PARAMETROS) -> float:
	## Chance de uma tentativa normal (não shiny); `investido_antes` = valor das bolas desde a última captura, sem a atual.
	var efic := int(p.captura_eficiencia.get(str(bola), 0))
	if efic <= 0:
		return 0.0
	if efic >= int(p.captura_garantida_eficiencia):
		return 1.0
	var preco := maxf(1.0, preco_npc)
	var v := valor_bola(bola, p)
	return clampf(float(p.captura_c) * v / preco * (1.0 + float(p.captura_k) * investido_antes / preco) * (1.0 + bonus), 0.0, 1.0)


static func chance_captura_shiny(bola: int, tier: String, p: Dictionary = PARAMETROS) -> float:
	## C: min(1, shinyBase(tier) × catchRate); sem shinyBase conhecido → 0 (F).
	var base := float(p.captura_shiny_base.get(tier, p.get("captura_shiny_base_padrao", 0.0)))
	return clampf(base * float(p.captura_eficiencia.get(str(bola), 0)), 0.0, 1.0)


static func tipos_de(especie: Dictionary) -> Array:
	var t: Array = especie.get("tipos", [])
	return [t[0] if t.size() > 0 else "", t[1] if t.size() > 1 else ""]


static func dano(nivel: int, poder: int, ataque: float, defesa: float, stab: bool, eff: float, selvagem: bool, aleatorio: float, p: Dictionary = PARAMETROS) -> int:
	## Fórmula candidata (F), coerente com os envelopes medidos (ver CLAUDE.md).
	var piso: int = int(p.piso_selvagem) if selvagem else int(p.piso_aliado)
	if eff == 0.0:
		return piso
	var formula := String(p.get("formula_dano", "sem_piso_divisor"))
	if not selvagem:
		ataque = maxf(ataque, float(p.get("piso_ataque_aliado", 0.0)))
	var divisor := maxf(1e-6, defesa) if formula == "sem_piso_divisor" else maxf(1.0, defesa)
	var k := (2.0 * float(nivel) / 5.0 + 2.0) * float(poder) * ataque / divisor / 50.0
	var mods := 1.0
	if stab:
		mods *= float(p.stab)
	mods *= eff
	if selvagem:
		mods *= float(p.fator_selvagem)
	var v := k * mods * aleatorio
	if formula == "classica":
		v = (k + 2.0) * mods * aleatorio
	var n: int = js_round(v) if String(p.arredondamento_dano) == "round" else int(floor(v))
	if formula == "mais2_fim":
		n += 2
	return maxi(piso, n)


static func escolher_golpe(especie_atk: Dictionary, nivel: int, stats_atk: Dictionary, especie_def: Dictionary, stats_def: Dictionary, p: Dictionary = PARAMETROS) -> Dictionary:
	## Entre os golpes com nivel ≤ nível, de dano e com poder abaixo de 600, o de maior dano esperado (poder × A/D × STAB ×
	## eff amplificada, com os stats do indivíduo); empate → menor cooldown; depois o primeiro da lista.
	## A (fase 3, 10/11/2026; 324 hits do líder em S1–S4 + os 10 pares antigos): desempate pelo primeiro da lista (S1:
	## Rhydon Stone Edge 58/58, Golem Earthquake 59/59), efetividade (S2 Hammer Arm 32/32; S4 Double-Edge 39/39) e A/D
	## por indivíduo (S3: Gyarados usa Aqua Tail em 3 dos 15 Rhyhorn e Hydro Pump nos outros 12, sempre o mesmo golpe por
	## indivíduo, e os 15 são coerentes com a regra dentro dos stats que o maxHp e o dano permitem). Fica F: o critério
	## "maior dano esperado" exato (nenhum caso medido ficou perto do empate fora do empate exato do S1).
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
