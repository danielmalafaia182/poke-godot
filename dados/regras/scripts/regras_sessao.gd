@tool
class_name RegrasSessao
extends Resource
## RegrasSessao — penalidade e sessão.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Penalidade")
## Penalidade de entrada = boost "shinylock" (C: texto do boost, "Por 1 minuto: nenhum Pokémon Shiny aparece e
## você recebe 70% menos EXP e drops"; o servidor manda {type: boosts, boosts: [{key: shinylock, until, pct:
## 0}]}). A: until = entrada + 60,0 s em 4 entradas (rhydon-1h, typhlosion, S2, S4) e todo abate antes do until
## tem xpParts.debuff, nenhum depois (7/601, 9/23, 10/27). XP: floor(total × 0,3) (A: 5772 → 1731, 846 → 253, 12 →
## 3). Loot: 15 drops em 5 entradas contra 68 esperados (0,22×; ×0,3 dá P = 0,13) → chance × 0,3 (F: chance ou
## quantidade não se separam com esta amostra). Quando aplica (A, T1 em 10/11/2026, confirma o relato do usuário):
## hunt diferente da última, vindo da cidade (rattata → cidade 29 s → spearow) ou direto pelo mapa (spearow →
## vulpix), penaliza; voltar à mesma hunt pela cidade (vulpix → cidade → vulpix) não penaliza (sem boosts, 0/15
## abates com debuff). Sessão expirada: B-relatado (não gravado). Início: o minuto conta da ENTRADA (A: until − 1º
## serverNow da instância = 58,9–59,3 s nas 3 entradas do T1, e 60,0–61,4 s nas 9 anteriores; os 29 s na cidade
## não contaram). "Desde a saída" foi descartado; o S3 segue como exceção sem explicação. ms_desde_saida fica 0
## (parâmetro mantido). A sim recebe o fim pronto (cfg.penalidade_ate_ms) ou calcula: inicio_ms −
## cfg.ms_desde_saida + duração. · unidade: milissegundos · origem F (em aberto) · evidência: rhydon-1h, S2, S4,
## T1
@export_range(0, 600000, 1, "or_greater")  var penalidade_duracao_ms: int = 60000

## XP e drops × 0,3 durante o lock de entrada (A: 76/76 abates) · unidade: multiplicador · origem A (observada
## (referência declarada, não auditada pelo catálogo)) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var penalidade_fator: float = 0.3

## "chance" (× fator na chance de cada item) | "quantidade" | "nenhuma" · origem E (desenhada por nós) ·
## evidência: comentário em `sim/regras.gd`
@export var penalidade_loot: String = "chance"
