@tool
class_name RegrasCombate
extends Resource
## RegrasCombate — combate e dano.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Aleatorio")
## A · origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var aleatorio_max: float = 1.0

## A: máx/mín ≤ 1,17 por indivíduo; aleatório contínuo (16 inteiros 85..100 perdem por ~89 mil de logL em 38 mil
## golpes, arredondamento_dano.py) · origem A (comprovada contra o original) · evidência: arredondamento_dano.py
@export_range(0.0, 1.0, 0.0001)  var aleatorio_min: float = 0.85

@export_group("Ataque")
## A: 1600 ms, grade fixa (as variações de 1200/2000 vêm de field não recebido) · unidade: ticks de 200 ms ·
## origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
@export_range(0, 80, 1, "or_greater")  var ataque_aliado_ticks: int = 8

## F: às vezes +1 tick (média medida ~2050 ms no Kangaskhan) · unidade: segundos · origem F (em aberto) ·
## evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var ataque_selvagem_extra_prob: float = 0.25

## A: ~2000 ms por selvagem · unidade: segundos · origem A (comprovada contra o original) · evidência: comentário
## em `sim/regras.gd`
@export_range(0, 100, 1, "or_greater")  var ataque_selvagem_ticks: int = 10

@export_group("Cadaver")
## E: espécie sem cadáver conhecido (dados/corpos_por_especie.json) deixa corpse 0 = genérico (a vista desenha o
## sprite da própria espécie escurecido). Todos os cadáveres do atlas são Pokémon reconhecíveis: não há um neutro
## para usar. · origem E (desenhada por nós) · evidência: dados/corpos_por_especie.json
@export var cadaver_generico: bool = true

## A aproximado: corpos somem em ~19–20 s · unidade: milissegundos · origem A (comprovada contra o original) ·
## evidência: comentário em `sim/regras.gd`
@export_range(0, 200000, 1, "or_greater")  var cadaver_ms: int = 20000

@export_group("Hp")
## A · unidade: segundos · origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
@export_range(0, 1200, 1, "or_greater")  var hp_selvagem_minimo: int = 120

## A · unidade: segundos · origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
@export_range(0, 350, 1, "or_greater")  var hp_selvagem_por_stat: int = 35

@export_group("Piso")
## A: Gastly × Rattata · origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
@export_range(0, 20, 1, "or_greater")  var piso_aliado: int = 2

## Fase 4, item 2 (F, 15/11): piso do stat de ataque (Atk/SpA) do ALIADO no cálculo do dano. O Geodude Lv.1 das
## gravações geodude-10min/geodeude-2 mostra Atk 1 e tira 6–8 no Rattata (153 golpes): com Atk 1 a fórmula dá 2–3;
## com 3, 6–8. No ajuste com todas as gravações (ajustar_dano.py, variante "e+A3"): aliado nível 1–4 98,1% dos
## golpes explicados (90,5% sem o piso), nenhuma outra faixa nem gravação muda; no selvagem o piso piora (100% →
## 85,1% no nível 1–4), por isso só no aliado. Um atacante só (o Geodude): "piso 3" e "stats do nível 2" não se
## separam (G11). 0 = desligado. Só pesa em stat de ataque < 3 (níveis 1–3, em geral). · origem F (em aberto) · no
## jogo original: não medido (F): o dano no nível 1 pede ~3 · evidência: geodude-10min, ajustar_dano.py, A3, G11
@export_range(0.0, 30.0, 0.0001, "or_greater")  var piso_ataque_aliado: float = 3.0

## A: 880 hits do Rattata no Geodude · unidade: segundos · origem A (comprovada contra o original) · evidência:
## comentário em `sim/regras.gd`
@export_range(0, 10, 1, "or_greater")  var piso_selvagem: int = 1

@export_group("Pocao")
## A: HP ≤ 50% dispara no mesmo tick (91/91 cruzamentos; HP exato na cura ≤ 0,50 · origem A (comprovada contra o
## original) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var pocao_limiar: float = 0.5

## A/F: nenhuma cura adiada observada; menor intervalo real 1988 ms em 409 curas); o Auto-Helper da gravação de 1
## h mostra "Heal when HP ≤ 50%" · unidade: milissegundos · origem A (comprovada contra o original) · evidência:
## comentário em `sim/regras.gd`
@export_range(0, 1, 1, "or_greater")  var pocao_recarga_ms: int = 0

@export_group("Stats")
## stats do aliado no dano: os exibidos, arredondados (F forte: 15/15 indivíduos) · origem F (em aberto) ·
## evidência: comentário em `sim/regras.gd`
@export var stats_dano_aliado: String = "inteiro"

## "inteiro" volta ao modelo antigo Stats na fórmula de dano (F, forte). Selvagem sem arredondar: na rhydon-1h o
## Solar Beam é explicado por uma SpD inteira em 2/15 indivíduos e por uma SpD contínua em 15/15. Aliado
## arredondado (o valor exibido no poke-delta): com a SpA exibida 15/15; com a SpA recalculada sem arredondar (IVs
## e Q exatos) só 10/15. · unidade: segundos · origem F (em aberto) · evidência: rhydon-1h
@export var stats_dano_selvagem: String = "continuo"

@export_group("Geral")
## F: round (Math.round) ou floor; sem evidência — empate em 41.896 golpes (arredondamento_dano.py, 23/11): no
## nível ≥ 20 meio ponto não aparece; fecha com aliado nível 5–15 na rattata · origem F (em aberto) · evidência:
## arredondamento_dano.py
@export var arredondamento_dano: String = "round"

## F: fórmula candidata · unidade: segundos · origem F (em aberto) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 18.0, 0.0001, "or_greater")  var fator_selvagem: float = 1.8

## Fase 4, item 1 (F, `ferramentas/fase4/ajustar_dano.py`, tabela em dados/relatorios/ajuste_dano.md): variante da
## fórmula. "atual" = a de sempre, com o divisor ≥ 1; "sem_piso_divisor" = igual, sem o max(1, D) (stats contínuos
## do selvagem no nível 1–4 ficam em 0,3–1,0); "classica" = (K + 2) × mods; "mais2_fim" = K × mods + 2. Padrão
## desde 15/11 (E, decisão do usuário sobre a tabela F): "sem_piso_divisor", igual ou melhor que "atual" em todas
## as gravações (aliado 1–4: 90,5% × 32,6% dos golpes explicados; o resto igual). · origem F (em aberto) ·
## evidência: /ajustar_dano.py, dados/relatorios/ajuste_dano.md
@export var formula_dano: String = "sem_piso_divisor"

## golpes de poder 600 (assinatura) ficam fora da escolha: nunca apareceram nas gravações · origem E (desenhada
## por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 5990.0, 0.0001, "or_greater")  var golpe_poder_maximo: float = 599.0

## F: 1º golpe ~2000 ms depois de encostar (4 casos: 1600–3200 ms) · unidade: segundos · origem F (em aberto) ·
## evidência: comentário em `sim/regras.gd`
@export_range(0, 100, 1, "or_greater")  var primeiro_ataque_selvagem_ticks: int = 10

## A: 7 respawns medidos, todos 60 s, no ponto de spawn, mesmo indivíduo aproximam com |dy| até 13 (0,16–0,43 por
## intervalo em |dy| 8–13, centenas de intervalos na rhydon-1h; M1/M2 iguais) e nunca com 14+. Com 13 na sim, o
## Kangaskhan (M1, M2) passa a bater e o Rhydon piora (0,58 adjacentes × 0,40; curas/min fora da faixa no
## diferencial): falta o que limita o acúmulo em luta curta (F). Fica 7 até isso fechar (M3). A sim ainda persegue
## com |dx| = 14 (0,26–0,41), o real nunca: a checagem real usa a posição de antes do passo (F). C: view = {hc:
## ceil(25/zoom/2)+2, hr: ceil(13/zoom/2)+2} — só o zoom muda o view · unidade: milissegundos · origem A
## (comprovada contra o original) · evidência: rhydon-1h, M1, M2, M3
@export_range(0, 600000, 1, "or_greater")  var respawn_ms: int = 60000

## B · origem B (replicada do cliente sem confirmação no servidor) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 15.0, 0.0001, "or_greater")  var stab: float = 1.5

## ciclo 6: fração do dano do golpe normal que espirra nos selvagens do quadro de 12×12 com o AoE TM; o texto do
## cliente ('passam a espirrar em cada selvagem') não fala em redução · unidade: segundos · origem E (desenhada
## por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 10.0, 0.0001, "or_greater")  var tm_aoe_splash_fator: float = 1.0

## depois da troca automática por desmaio, 5 s sem troca manual: evita trocar no meio do golpe · unidade:
## milissegundos · origem E (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 50000.0, 0.0001, "or_greater")  var troca_cooldown_ms: float = 5000.0
