@tool
class_name RegrasMovimento
extends Resource
## RegrasMovimento — movimento.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Alvo")
## A (18/11, medir_alvo.py: 2295/2400 trocas × 2067 com Chebyshev): alvo = menor tempo de caminho até encostar.
## "chebyshev" volta à regra anterior (linha reta). Em labirinto (nightmare_elekid) a linha reta mandava o herói a
## um selvagem a > 60 s de caminho e ele não abatia nada em 60 s (13/20 sementes). · origem A (comprovada contra o
## original) · evidência: medir_alvo.py
@export var alvo_criterio: String = "caminho"

## F: o alvo é o selvagem vivo mais próximo entre os alcançáveis (algum tile livre a Chebyshev ≤ 1 dele na ilha do
## herói). Sem isso, o herói fica preso num selvagem de outra ilha e a busca no mapa inteiro roda a cada passo. ·
## unidade: segundos · origem F (em aberto) · evidência: comentário em `sim/regras.gd`
@export var alvo_so_alcancavel: bool = true

## sem caminho até o alvo e com selvagem encostado, ataca o encostado: senão o herói apanha parado · unidade:
## segundos · origem E (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export var alvo_troca_se_bloqueado: bool = true

## Revertido no ciclo 2: o alvo NÃO vem de fora da borda real (A: 0 de 9.120 intervalos fora de 13×13). Fica só
## para experimento. O que vale (A) é o alvo perseguir dentro da borda real: `visao_meia_altura_alvo` 13. · origem
## A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
@export var alvo_vem_ao_encontro: bool = false

@export_group("Desempate")
## Caminho (F: Dijkstra de tempo mínimo com os custos acima). Desempate entre passos igualmente ótimos, por classe
## [reto no eixo maior, diagonal, reto no eixo menor], com pesos = frequências medidas fora do eixo (A), somando
## as gravações antigas e a rhydon-1h (herói 475/146/26 + 1294/325/48; selvagem 385/232/143 + 1152/447/244). ·
## origem F (em aberto) · evidência: rhydon-1h
@export var desempate_heroi: Array = [1769, 471, 74]

## desempate do passo do selvagem pelas frequências medidas (A) · origem A (comprovada contra o original) ·
## evidência: comentário em `sim/regras.gd`
@export var desempate_mob: Array = [1537, 679, 387]

@export_group("Inicio")
## Ilhas da grade (2b.6). 103 hunts têm spawns em tile bloqueado e 9 têm o `start` bloqueado (hunt-config ×
## grade). typhlosion (A, 1 caso): start (54,75) bloqueado; o herói real aparece em (53,74), o 1º tile livre do
## anel 1 em ordem linha → coluna. F: o herói vai para o tile livre mais próximo (anel de Chebyshev, ordem linha →
## coluna). · origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
@export var inicio_bloqueado_anel: bool = true

## start numa ilha sem spawn (nightmare_magby): começa na ilha que alcança mais spawns; sem isso a hunt não tem
## abate · unidade: segundos · origem E (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export var inicio_ilha_com_spawns: bool = true

@export_group("Mob")
## A (ciclo 4, medir_contorno.py): perto do herói o caminho desvia dos outros selvagens · origem A (comprovada
## contra o original) · evidência: medir_contorno.py
@export var mob_contorna_bloqueio: bool = true

## F: até onde (Chebyshev) o caminho conta os outros selvagens como obstáculo · origem F (em aberto) · evidência:
## comentário em `sim/regras.gd`
@export_range(0, 40, 1, "or_greater")  var mob_contorna_raio: int = 4

## F (experimento M3): selvagem só dá passo N ticks depois do último passo do herói; 0 = desligado · unidade:
## ticks de 200 ms · origem F (em aberto) · evidência: M3
@export_range(0, 1, 1, "or_greater")  var mob_espera_apos_heroi_ticks: int = 0

## A: field-init.mobStepMs · unidade: milissegundos · origem A (comprovada contra o original) · evidência:
## comentário em `sim/regras.gd`
@export_range(0, 10000, 1, "or_greater")  var mob_step_ms: int = 1000

@export_group("Passo")
## A: 73/223 esperas de 1000 ms saíram em 1200 · unidade: probabilidade 0–1 · origem A (comprovada contra o
## original) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var passo_extra_prob_heroi_diagonal: float = 0.33

## A: 500 ms não cai num tick exato; 600 em 113/121 · unidade: probabilidade 0–1 · origem A (comprovada contra o
## original) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var passo_extra_prob_heroi_reto: float = 0.0

## A: 10/237 esperas de 2000 ms saíram em 2200 · unidade: probabilidade 0–1 · origem A (comprovada contra o
## original) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var passo_extra_prob_mob_diagonal: float = 0.04

## A: 319/895 esperas de 1000 ms saíram em 1200 · unidade: probabilidade 0–1 · origem A (comprovada contra o
## original) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var passo_extra_prob_mob_reto: float = 0.36

@export_group("Visao")
## F (sim). A borda real medida em 10/11/2026 é 13 nos dois eixos: selvagens se · origem F (em aberto) · no jogo
## original: 13 (A: borda da perseguição 13 × 13) · evidência: comentário em `sim/regras.gd`
@export_range(0, 70, 1, "or_greater")  var visao_meia_altura: int = 7

## A: o alvo persegue até |dy| 13 (os outros, `visao_meia_altura`) · origem A (comprovada contra o original) ·
## evidência: comentário em `sim/regras.gd`
@export_range(0, 130, 1, "or_greater")  var visao_meia_altura_alvo: int = 13

## A: perseguição até |dx| 13, nunca 14+ (rhydon-1h, M1, M2) · origem A (comprovada contra o original) ·
## evidência: rhydon-1h, M1, M2
@export_range(0, 130, 1, "or_greater")  var visao_meia_largura: int = 13

@export_group("Geral")
## F: folga da caixa de busca em volta do herói/alvo (tiles) · origem F (em aberto) · evidência: comentário em
## `sim/regras.gd`
@export_range(0, 60, 1, "or_greater")  var caminho_margem: int = 6

## A (e C: o cliente anima a diagonal com o mesmo custo, dS) Passos (A, ferramentas/gravador/medir_passos.py;
## gravações antigas + rhydon-1h): espera antes de cada passo = stepMs × (2 se o passo é diagonal), arredondada
## para cima ao tick. Herói →reto 600 ms (113/121 e 241/247), →diagonal 1000 ou 1200 (40/19 e 110/54); selvagem
## →reto 1000 ou 1200 (167/93 e 409/226), →diagonal 2000 ou 2200 (89/4 e 138/6). · unidade: multiplicador · origem
## A (comprovada contra o original) · evidência: ferramentas/gravador/medir_passos.py, rhydon-1h
@export_range(0, 20, 1, "or_greater")  var fator_diagonal_passo: int = 2

## A: field-init.heroStepMs (duração da animação) · unidade: milissegundos · origem A (comprovada contra o
## original) · evidência: comentário em `sim/regras.gd`
@export_range(0, 5000, 1, "or_greater")  var hero_step_ms: int = 500

## A: field-init.trainerStepMs · unidade: milissegundos · origem A (comprovada contra o original) · evidência:
## comentário em `sim/regras.gd`
@export_range(0, 5000, 1, "or_greater")  var trainer_step_ms: int = 500
