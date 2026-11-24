@tool
class_name RegrasProfissoes
extends Resource
## RegrasProfissoes — profissões, mentor e crafting.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Craft")
## rank que libera a berry de cura (classe 3) · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_profissoes.gd`
@export var craft_cura_rank: String = "S"

## Fresh Herbs por berry de tipo (classe 3) · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_profissoes.gd`
@export_range(0, 100, 1, "or_greater")  var craft_ervas: int = 10

## rank que libera a berry neutra (classe 3) · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_profissoes.gd`
@export var craft_neutra_rank: String = "A"

## ouro por berry (classe 3) · unidade: ouro · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_profissoes.gd`
@export_range(0, 50000, 1, "or_greater")  var craft_ouro: int = 5000

## segundos por unidade na fila (classe 3; C: unidades uma a uma) · unidade: segundos · origem E (desenhada por
## nós) · evidência: comentário em `sim/servico_profissoes.gd`
@export_range(0, 6000, 1, "or_greater")  var craft_s_unidade: int = 600

## berries de tipo liberadas na árvore por rank (classe 3; C: árvore de talentos) · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_profissoes.gd`
@export var craft_tipos_rank: Dictionary = {
"A": 19,
"B": 19,
"C": 12,
"D": 8,
"E": 4,
"S": 19
}

## Wild Herbs por berry neutra ou de cura (classe 3) · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_profissoes.gd`
@export_range(0, 50, 1, "or_greater")  var craft_wild: int = 5

@export_group("Erva")
## chance de Fresh Herbs por abate do Botânico (classe 3; C: arbustos brotam na hunt) · unidade: fração 0–1 ·
## origem E (desenhada por nós) · evidência: comentário em `sim/servico_profissoes.gd`
@export_range(0.0, 1.0, 0.0001)  var erva_chance_abate: float = 0.03

## fração de Wild Herbs fora de Kanto (classe 3; C: 🍂 Wild Herbs) · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_profissoes.gd`
@export_range(0.0, 2.5, 0.0001, "or_greater")  var erva_wild_fora_kanto: float = 0.25

@export_group("Mentor")
## A · origem A (observada (referência declarada, não auditada pelo catálogo)) · evidência: comentário em
## `sim/servico_profissoes.gd`
@export_range(0, 2000, 1, "or_greater")  var mentor_gap: int = 200

## A · unidade: % · origem A (observada (referência declarada, não auditada pelo catálogo)) · evidência:
## comentário em `sim/servico_profissoes.gd`
@export_range(0.0, 5.0, 0.0001, "or_greater")  var mentor_pct_nivel: float = 0.5

## teto do mentor por rank (A: 60% observado na conta B; os outros ranks classe 3) · origem E (desenhada por nós)
## · evidência: comentário em `sim/servico_profissoes.gd`
@export var mentor_teto_rank: Dictionary = {
"A": 50.0,
"B": 40.0,
"C": 30.0,
"D": 20.0,
"E": 10.0,
"S": 60.0
}

@export_group("Req")
## abates por tipagem para cada rank (classe 3; C: o requisito existe) · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_profissoes.gd`
@export var req_abates_tipo: Dictionary = {
"A": 1500,
"B": 500,
"C": 200,
"D": 50,
"S": 5000
}

## berries criadas (Botânico) ou pictures entregues (Prestígio) por rank (classe 3) · origem E (desenhada por nós)
## · evidência: comentário em `sim/servico_profissoes.gd`
@export var req_craft_pictures: Dictionary = {
"A": 100,
"B": 40,
"C": 15,
"D": 5,
"S": 250
}

## espécies diferentes capturadas por rank (classe 3; C: o requisito existe) · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_profissoes.gd`
@export var req_especies: Dictionary = {
"A": 60,
"B": 30,
"C": 15,
"D": 5,
"S": 100
}

@export_group("Geral")
## Toque de Herbalista: % a mais nas berries por rank (classe 3; C: cresce a cada rank) · origem E (desenhada por
## nós) · evidência: comentário em `sim/servico_profissoes.gd`
@export var berry_bonus_rank: Dictionary = {
"A": 20.0,
"B": 15.0,
"C": 10.0,
"D": 5.0,
"E": 0.0,
"S": 25.0
}

## C: até ×1,18 no S, cumulativo desde o E · unidade: % · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_profissoes.gd`
@export_range(0.0, 30.0, 0.0001, "or_greater")  var captura_pct_rank: float = 3.0

## chance da foto do Prestígio num shiny (A: 2 de 5 no c5; classe 3) · unidade: fração 0–1 · origem E (desenhada
## por nós) · evidência: c5
@export_range(0.0, 1.0, 0.0001)  var foto_chance_shiny: float = 0.4
