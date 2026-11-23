@tool
class_name RegrasCaptura
extends Resource
## RegrasCaptura — captura e shiny.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Captura")
## Captura com medidor de investimento (C: tutorial "quanto mais bolas você investe numa espécie, maior a chance";
## tela Gerenciamento de Captura, /api/game/used-balls: por espécie preço de NPC, ouro gasto, tentativas totais e
## desde a última captura, que zera ao capturar; Master Ball garante; shiny não usa o medidor). Forma (F, máxima
## verossimilhança em 10/11/2026 sobre as sequências A de Rattata 1, Spearow 10, Vulpix 20 ×2, Rhydon 80 (Super
## Ball) e Geodude 1 (C5: Poké, Great, Super, Ultra e Idle); o trecho antes da 1ª captura de cada gravação fica de
## fora porque o medidor inicial não foi gravado; tentativas em shiny ficam de fora (não usam o medidor): chance =
## min(1, c · v / precoNpc · (1 + k · investido_antes / precoNpc) · (1 + bônus)) v = ouro pago pela bola desta
## tentativa (priceGold); investido_antes = ouro das bolas desde a última captura, SEM a atual. Sem fator de nível
## (o C1 derrubou: Spearow 10 capturou 28/52) nem de raridade (ganho nulo). Valor da bola = OURO (A, C5, Geodude
## 1, preço 300; esperado pelo ouro × pela eficiência, mesmo c/k): Poké 0,9 × 4,0 (observado 0/47), Great 5,1 ×
## 9,8 (6/60), Super 12,9 × 13,7 (10/59), Ultra 33,1 × 20,3 (37/69), Idle 73,0 × 26,2 (73/73). logL −190,6 (ouro)
## contra −294,5 (eficiência); com o valor de cada bola livre o ajuste dá Great 23, Ultra 143 (ouro: 20 e 130). As
## 5 falhas de Idle Ball em todas as gravações (S2, C5, M3) foram em shiny. Medidor que zera ao trocar de bola:
## logL −191,0 contra −190,6 (indistinguível; fica o que soma tudo, como a tela used-balls, que guarda o total por
## espécie). · origem C (replicada do cliente sem confirmação no servidor) · evidência: C5, C1, S2, M3
@export_range(0.0, 8.139999999999999, 0.0001, "or_greater")  var captura_c: float = 0.814

## A: balls.catalog.catchRate · origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
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

## peso do investimento desde a última captura no medidor (forma F; c e k por máxima verossimilhança) · origem F
## (em aberto) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 11.399999999999999, 0.0001, "or_greater")  var captura_k: float = 1.14

## C: o cliente trava 4 s entre lançamentos manuais · unidade: milissegundos · origem C (replicada do cliente sem
## confirmação no servidor) · evidência: comentário em `sim/regras.gd`
@export_range(0, 40000, 1, "or_greater")  var captura_manual_recarga_ms: int = 4000

## A: balls.catalog.priceGold · origem A (comprovada contra o original) · evidência: comentário em `sim/regras.gd`
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
## tier raro (A) ao comum (E), coerente com 0 capturas em 31 tentativas gravadas (B, C, Super/Idle) · unidade:
## segundos · origem E (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export var captura_shiny_base: Dictionary = {
"A": 0.004,
"B": 0.007,
"C": 0.01,
"D": 0.015,
"E": 0.02
}

## shiny de espécie sem tier na tabela do cliente: o mesmo do tier C · unidade: segundos · origem E (desenhada por
## nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001, "or_greater")  var captura_shiny_base_padrao: float = 0.01

## A (C5): "ouro" = priceGold; "eficiencia" = catchRate × 50/3 (refutado) · origem A (comprovada contra o
## original) · evidência: C5
@export var captura_valor_bola: String = "ouro"

@export_group("Geral")
## C: dobra a chance (multiplica a chance por arremesso) Boosts (C: "XP Boost +50% trainer XP", "Pokémon XP Boost
## +50%", "Loot Boost +40% loot chance", "Capture Boost: doubles the catch chance"); o pct vem no próprio boost
## ({key, until, pct}, A). F: parcela = % da XP base. · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 10.0, 0.0001, "or_greater")  var boost_captura_bonus: float = 1.0

## chance de shiny (nome antigo; ver shiny_chance) · unidade: segundos · origem A (comprovada contra o original) ·
## evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var chance_shiny: float = 0.0

## A: selvagem capturável por 20,0 s depois do abate (fase3 M1/M2) · unidade: milissegundos · origem A (comprovada
## contra o original) · evidência: M1, M2
@export_range(0, 200000, 1, "or_greater")  var pendente_vida_ms: int = 20000

## Shiny (A, 19/11, todas as gravações): só espécies com forma shiny (C: SHINY_BY_DEX) aparecem shiny — 0 em 3.323
## abates das outras; nas com forma, 42 em 10.914 abates fora do lock = 1/260. Nenhum durante o lock de entrada
## (A, C: shinylock). Por tier a taxa variou (C 11/881, B 26/9.156, D 3/511, E 2/366): amostra pequena fora do B;
## fica a taxa única. · unidade: fração 0–1 · origem A (comprovada contra o original) · evidência: comentário em
## `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var shiny_chance: float = 0.0038482682792743265
