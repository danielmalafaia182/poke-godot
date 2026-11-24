@tool
class_name RegrasCaptura
extends Resource
## RegrasCaptura — captura e shiny.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Captura")
## F: coeficiente da fórmula candidata de captura, ajustado às sequências observadas (A); não é fórmula revelada
## pelo servidor. · origem F (em aberto) · evidência: sim/regras.gd: bloco da fórmula de captura;
## CALIBRACAO_FASE3.md; CALIBRACAO_FASE4.md
@export_range(0.0, 8.139999999999999, 0.0001, "or_greater")  var captura_c: float = 0.814

## A: balls.catalog.catchRate · origem A (observada (referência declarada, não auditada pelo catálogo)) ·
## evidência: comentário em `sim/regras.gd`
@export var captura_eficiencia: Dictionary = {
"1": 1,
"2": 2,
"3": 3,
"4": 4,
"5": 255,
"6": 5,
"7": 5
}

## C/B-relatado: Master Ball (catchRate 255) garante · origem C (replicada do cliente sem confirmação no servidor)
## · evidência: comentário em `sim/regras.gd`
@export_range(0, 2550, 1, "or_greater")  var captura_garantida_eficiencia: int = 255

## F: coeficiente da fórmula candidata de captura, ajustado às sequências observadas (A); não é fórmula revelada
## pelo servidor. · origem F (em aberto) · evidência: sim/regras.gd: bloco da fórmula de captura;
## CALIBRACAO_FASE3.md; CALIBRACAO_FASE4.md
@export_range(0.0, 11.399999999999999, 0.0001, "or_greater")  var captura_k: float = 1.14

## C: o cliente trava 4 s entre lançamentos manuais · unidade: milissegundos · origem C (replicada do cliente sem
## confirmação no servidor) · evidência: comentário em `sim/regras.gd`
@export_range(0, 40000, 1, "or_greater")  var captura_manual_recarga_ms: int = 4000

## A: balls.catalog.priceGold · origem A (observada (referência declarada, não auditada pelo catálogo)) ·
## evidência: comentário em `sim/regras.gd`
@export var captura_preco_bola: Dictionary = {
"1": 5,
"2": 20,
"3": 50,
"4": 130,
"5": 0,
"6": 400,
"7": 400
}

## chance base de captura do shiny por tier (×catchRate da bola, C); o servidor não mostra o valor. Gradiente do
## tier raro (A) ao comum (E), coerente com 0 capturas em 31 tentativas gravadas (B, C, Super/Idle) · origem E
## (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export var captura_shiny_base: Dictionary = {
"A": 0.004,
"B": 0.007,
"C": 0.01,
"D": 0.015,
"E": 0.02
}

## shiny de espécie sem tier na tabela do cliente: o mesmo do tier C · origem E (desenhada por nós) · evidência:
## comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001, "or_greater")  var captura_shiny_base_padrao: float = 0.01

## A (C5): "ouro" = priceGold; "eficiencia" = catchRate × 50/3 (refutado) · origem A (observada (referência
## declarada, não auditada pelo catálogo)) · evidência: C5
@export var captura_valor_bola: String = "ouro"

@export_group("Geral")
## C: dobra a chance (multiplica a chance por arremesso) Boosts (C: "XP Boost +50% trainer XP", "Pokémon XP Boost
## +50%", "Loot Boost +40% loot chance", "Capture Boost: doubles the catch chance"); o pct vem no próprio boost
## ({key, until, pct}, A). F: parcela = % da XP base. · origem F (em aberto) · evidência: comentário em
## `sim/regras.gd`
@export_range(0.0, 10.0, 0.0001, "or_greater")  var boost_captura_bonus: float = 1.0

## chance de shiny (nome antigo; ver shiny_chance) · unidade: fração 0–1 · origem A (observada (referência
## declarada, não auditada pelo catálogo)) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var chance_shiny: float = 0.0

## A: selvagem capturável por 20,0 s depois do abate (fase3 M1/M2) · unidade: milissegundos · origem A (observada
## (referência declarada, não auditada pelo catálogo)) · evidência: M1, M2
@export_range(0, 200000, 1, "or_greater")  var pendente_vida_ms: int = 20000

## Shiny (A, 19/11, todas as gravações): só espécies com forma shiny (C: SHINY_BY_DEX) aparecem shiny — 0 em 3.323
## abates das outras; nas com forma, 42 em 10.914 abates fora do lock = 1/260. Nenhum durante o lock de entrada
## (A, C: shinylock). Por tier a taxa variou (C 11/881, B 26/9.156, D 3/511, E 2/366): amostra pequena fora do B;
## fica a taxa única. · unidade: fração 0–1 · origem A (observada (referência declarada, não auditada pelo
## catálogo)) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var shiny_chance: float = 0.0038482682792743265
