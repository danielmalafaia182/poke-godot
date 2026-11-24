@tool
class_name RegrasJogador
extends Resource
## RegrasJogador — soneca, Streak e sessão.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Dia")
## dia (unix/86400, deslocado pela virada) de 09/11/2026 em Brasília · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_jogador.gd`
@export_range(0, 207660, 1, "or_greater")  var dia_ancora: int = 20766

## Tipo do Dia (A: evento type-of-day, +20% XP e loot no tipo; termina às 03:00 UTC = meia-noite de Brasília). E:
## offline, rotação fixa ancorada nos cinco dias observados (A: 09/11/2026 Dragão, 10/11 Inseto, 13/11 Sombrio,
## 15/11 Veneno, 18/11 Fantasma — G11); as outras posições são E. · unidade: segundos · origem A (observada
## (referência declarada, não auditada pelo catálogo)) · evidência: G11
@export_range(0, 108000, 1, "or_greater")  var dia_virada_utc_s: int = 10800

@export_group("Soneca")
## C: "the hunt continues on the server for 5 minutes" (combate, XP, loot, Auto-Potion; sem bolas) Modo Soneca (C,
## guia "Nap Mode" e janela "While you were away"): · unidade: segundos · origem C (replicada do cliente sem
## confirmação no servidor) · evidência: comentário em `sim/servico_jogador.gd`
@export_range(0, 3000, 1, "or_greater")  var soneca_amostra_s: int = 300

## C: "Collect: 50% of the sample's XP rate" · unidade: fração · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_jogador.gd`
@export_range(0.0, 1.0, 0.0001)  var soneca_fracao: float = 0.5

## C: "Turbo (2💎): 100%" — sem diamantes offline, o turbo é recusado (E) · unidade: fração · origem C (replicada
## do cliente sem confirmação no servidor) · evidência: comentário em `sim/servico_jogador.gd`
@export_range(0.0, 1.0, 0.0001)  var soneca_fracao_turbo: float = 1.0

## C: "Time counts from the end of the nap until login, with a cap of 24h" · unidade: segundos · origem C
## (replicada do cliente sem confirmação no servidor) · evidência: comentário em `sim/servico_jogador.gd`
@export_range(0, 864000, 1, "or_greater")  var soneca_teto_s: int = 86400

## C · origem C (replicada do cliente sem confirmação no servidor) · evidência: comentário em
## `sim/servico_jogador.gd`
@export_range(0, 20, 1, "or_greater")  var soneca_turbo_custo: int = 2

## o jogo offline não tem diamantes: o turbo da soneca fica desligado · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_jogador.gd`
@export var soneca_turbo_disponivel: bool = false

@export_group("Streak")
## Streak Points (C, guia): 1 ponto a cada 1000 abates; o n-ésimo ponto custa 25.000 × n de ouro; trilhas
## exp/loot/shiny. · origem C (replicada do cliente sem confirmação no servidor) · evidência: comentário em
## `sim/servico_jogador.gd`
@export_range(0, 10000, 1, "or_greater")  var streak_abates_por_ponto: int = 1000

## o n-ésimo ponto custa 25.000 × n (C/A G7) · origem A (observada (referência declarada, não auditada pelo
## catálogo)) · evidência: G7
@export_range(0, 250000, 1, "or_greater")  var streak_custo_base: int = 25000

## trilhas EXP, Loot e Shiny (C) · origem C (replicada do cliente sem confirmação no servidor) · evidência:
## comentário em `sim/servico_jogador.gd`
@export var streak_trilhas: Array = ["exp", "loot", "shiny"]

@export_group("Geral")
## jogo fechado numa hunt continua caçando até 15 min (B-relatado: a sessão morre aos 15 min) · unidade: segundos
## · origem E (desenhada por nós) · evidência: comentário em `sim/servico_jogador.gd`
@export_range(0.0, 9000.0, 0.0001, "or_greater")  var fechado_caca_max_s: float = 900.0

## nomes dos tipos do Tipo do Dia (A: formato gravado) · origem A (observada (referência declarada, não auditada
## pelo catálogo)) · evidência: comentário em `sim/servico_jogador.gd`
@export var nomes_tipos: Dictionary = {
"BUG": ["Inseto", "🐛"],
"DARK": ["Sombrio", "🌑"],
"DRAGON": ["Dragão", "🐉"],
"ELECTRIC": ["Elétrico", "⚡"],
"FAIRY": ["Fada", "🧚"],
"FIGHTING": ["Lutador", "🥊"],
"FIRE": ["Fogo", "🔥"],
"FLYING": ["Voador", "🕊️"],
"GHOST": ["Fantasma", "👻"],
"GRASS": ["Planta", "🌿"],
"GROUND": ["Terra", "⛰️"],
"ICE": ["Gelo", "❄️"],
"NORMAL": ["Normal", "⚪"],
"POISON": ["Veneno", "☠️"],
"PSYCHIC": ["Psíquico", "🔮"],
"ROCK": ["Pedra", "🪨"],
"STEEL": ["Aço", "⚙️"],
"WATER": ["Água", "💧"]
}

## rotação do Tipo do Dia (A nos dias gravados; E nos outros) · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_jogador.gd`
@export var rotacao_tipos: Array = ["DRAGON", "BUG", "FIRE", "WATER", "DARK", "GRASS", "POISON", "ELECTRIC", "ICE", "GHOST", "GROUND", "FLYING", "PSYCHIC", "ROCK", "FIGHTING", "STEEL", "FAIRY", "NORMAL"]

## Sessão (B-relatado / regra do usuário, 11/11): sem soneca, 15 min com o jogo fechado matam a sessão; voltar à
## mesma hunt pela cidade não penaliza (CenarioJogo.penalizar_entrada). Com soneca coletada, a sessão segue (E). ·
## unidade: segundos · origem E (desenhada por nós) · evidência: comentário em `sim/servico_jogador.gd`
@export_range(0, 9000, 1, "or_greater")  var sessao_expira_s: int = 900
