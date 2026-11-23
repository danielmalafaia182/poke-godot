@tool
class_name RegrasDiarias
extends Resource
## RegrasDiarias — diárias e tarefas.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Catch")
## teto do multiplicador do Daily Catch (A: maior valor gravado) · origem A (comprovada contra o original) ·
## evidência: comentário em `sim/servico_diarias.gd`
@export_range(0.0, 180.0, 0.0001, "or_greater")  var catch_mult_max: float = 18.0

## Daily Catch: multiplicador de XP sorteado em [1,5; 18], múltiplo de 0,5 (A: os 4 valores gravados cabem) ·
## origem A (comprovada contra o original) · evidência: comentário em `sim/servico_diarias.gd`
@export_range(0.0, 15.0, 0.0001, "or_greater")  var catch_mult_min: float = 1.5

## Daily Catch (A, G5): 2 capturas premiadas por dia; faixas por nível do treinador; capturar espécie da tabela
## preenche o próximo slot (C: "capture um Pokémon da tabela"). XP = floor(xpAbate × 8/3 × m): A, os 4 casos
## gravados dão m múltiplo de 0,5 — Larvitar (548) 10 e 14 (G5), Arbok (968) 1,5 e 18 (G9). A regra "m pelo slot"
## (F de 13/11) caiu (Arbok slot 1 = 1,5, slot 2 = 18). F/E: m sorteado (semente = dia e slot) entre os múltiplos
## de 0,5 de 1,5 a 18 (a faixa observada); limitado a [xpMin, xpMax] da faixa. · origem A (comprovada contra o
## original) · evidência: G5, G9
@export_range(0, 20, 1, "or_greater")  var catch_total: int = 2

@export_group("Gift")
## boost do Daily Gift dura 1 h; o mesmo boost ativo soma mais 1 h · unidade: milissegundos · origem E (desenhada
## por nós) · evidência: comentário em `sim/servico_diarias.gd`
@export_range(0.0, 36000000.0, 0.0001, "or_greater")  var gift_boost_ms: float = 3600000.0

## decisão do usuário (ciclo 3): sem VIP, o dia VIP do Daily Gift é pulado em vez de travar o calendário (no
## original trava) · origem E (desenhada por nós) · evidência: comentário em `sim/servico_diarias.gd`
@export var gift_pular_vip: bool = true

@export_group("Kill")
## multiplicador dos itens do prêmio do Daily Kill (classe 3) · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_diarias.gd`
@export_range(0, 20, 1, "or_greater")  var kill_itens_mult: int = 2

## nível mínimo do Daily Kill (C) · origem C (replicada do cliente sem confirmação no servidor) · evidência:
## comentário em `sim/servico_diarias.gd`
@export_range(0, 250, 1, "or_greater")  var kill_min_nivel: int = 25

## Daily Kill oferece 3 opções por dia (A, G9: 3 opções exatas) · origem E (desenhada por nós) · evidência: G9
@export_range(0.0, 30.0, 0.0001, "or_greater")  var kill_opcoes: float = 3.0

## faixas de quantidade do Daily Kill por dificuldade: 15–60 min de caça na hunt sugerida · origem E (desenhada
## por nós) · evidência: comentário em `sim/servico_diarias.gd`
@export var kill_qtd: Dictionary = {
"easy": [200.0, 600.0],
"hard": [500.0, 1500.0],
"medium": [400.0, 1200.0],
"superEasy": [100.0, 300.0]
}

## Daily Kill: XP = qtd × xpAbate × 8/3 (A: 3/3) · unidade: multiplicador · origem A (comprovada contra o
## original) · evidência: comentário em `sim/servico_diarias.gd`
@export_range(0.0, 26.666666666666664, 0.0001, "or_greater")  var kill_xp_fator: float = 2.6666666666666665

@export_group("Geral")
## A: resetAt = 03:00 UTC (meia-noite de Brasília), igual ao Tipo do Dia · unidade: segundos · origem A
## (comprovada contra o original) · evidência: comentário em `sim/servico_diarias.gd`
@export_range(0, 108000, 1, "or_greater")  var dia_virada_utc_s: int = 10800
