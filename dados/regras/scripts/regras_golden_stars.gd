@tool
class_name RegrasGoldenStars
extends Resource
## RegrasGoldenStars — Golden Stars.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Roll")
## A: 12 h · unidade: segundos · origem A (observada (referência declarada, não auditada pelo catálogo)) ·
## evidência: comentário em `sim/servico_golden_stars.gd`
@export_range(0, 432000, 1, "or_greater")  var roll_gratis_s: int = 43200

## custo da rolagem antes das 12 h (classe 3) · unidade: ouro · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_golden_stars.gd`
@export_range(0, 1000000, 1, "or_greater")  var roll_pago_ouro: int = 100000

@export_group("Temp")
## A · origem A (observada (referência declarada, não auditada pelo catálogo)) · evidência: comentário em
## `sim/servico_golden_stars.gd`
@export_range(0, 50, 1, "or_greater")  var temp_cartas: int = 5

## A: 24 h · unidade: segundos · origem A (observada (referência declarada, não auditada pelo catálogo)) ·
## evidência: comentário em `sim/servico_golden_stars.gd`
@export_range(0, 864000, 1, "or_greater")  var temp_s: int = 86400

@export_group("Geral")
## A · origem A (observada (referência declarada, não auditada pelo catálogo)) · evidência: comentário em
## `sim/servico_golden_stars.gd`
@export_range(0, 90, 1, "or_greater")  var candidatos: int = 9

## A: 6 h · unidade: segundos · origem A (observada (referência declarada, não auditada pelo catálogo)) ·
## evidência: comentário em `sim/servico_golden_stars.gd`
@export_range(0, 216000, 1, "or_greater")  var duracao_s: int = 21600

## C: "Escolha direta" (pick-species); custo classe 3 · unidade: ouro · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_golden_stars.gd`
@export_range(0, 500000, 1, "or_greater")  var escolha_direta_ouro: int = 50000

## A · unidade: ouro · origem A (observada (referência declarada, não auditada pelo catálogo)) · evidência:
## comentário em `sim/servico_golden_stars.gd`
@export_range(0, 100000000, 1, "or_greater")  var perm_ouro: int = 10000000

## [nome, pct, peso] — A viu 10 e 13 · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_golden_stars.gd`
@export var raridade: Array = [["comum", 10, 60], ["rara", 13, 30], ["épica", 16, 10]]

## C: "Trocar bônus" (reroll-bonus); custo classe 3 · unidade: ouro · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_golden_stars.gd`
@export_range(0, 500000, 1, "or_greater")  var reroll_bonus_ouro: int = 50000
