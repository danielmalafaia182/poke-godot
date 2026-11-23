@tool
class_name RegrasBreeding
extends Resource
## RegrasBreeding — breeding.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Delta")
## Δ de Quality no caminho com feromônio (C: +0,15 a +0,30) · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_breeding.gd`
@export var delta: Array = [0.15, 0.3]

## o caminho livre divide o Δ (C: ~20× menor) · origem C (replicada do cliente sem confirmação no servidor) ·
## evidência: comentário em `sim/servico_breeding.gd`
@export_range(0.0, 200.0, 0.0001, "or_greater")  var delta_livre_div: float = 20.0

@export_group("Geral")
## derrotas nas hunts para o ovo chocar (classe 3; C: chocam com derrotas) · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_breeding.gd`
@export_range(0, 5000, 1, "or_greater")  var abates_chocar: int = 500

## item do caminho cheio: Strange Pheromone (A: existe no catálogo) · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_breeding.gd`
@export_range(0, 444170, 1, "or_greater")  var feromonio_id: int = 44417

## chance de cada IV copiar o melhor pai (classe 3; C: N% copia, senão re-rola) · unidade: % · origem E (desenhada
## por nós) · evidência: comentário em `sim/servico_breeding.gd`
@export_range(0.0, 500.0, 0.0001, "or_greater")  var herdar_pct: float = 50.0

## pedras em dobro: chance de +1 num IV (C: 5%) · unidade: % · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_breeding.gd`
@export_range(0.0, 50.0, 0.0001, "or_greater")  var iv_mais1_pct: float = 5.0

## pedras do tipo principal por ovo (classe 3; C: gasta pedras) · origem E (desenhada por nós) · evidência:
## comentário em `sim/servico_breeding.gd`
@export_range(0, 20, 1, "or_greater")  var pedras_por_ovo: int = 2

## Quality máxima do filho (C: maior faixa do rollQuality) · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_breeding.gd`
@export_range(0.0, 18.0, 0.0001, "or_greater")  var quality_max: float = 1.8

## slots da incubadora (classe 3; mais slots são de diamantes no original) · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_breeding.gd`
@export_range(0, 20, 1, "or_greater")  var slots: int = 2
