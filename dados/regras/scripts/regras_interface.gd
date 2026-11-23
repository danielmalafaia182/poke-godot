@tool
class_name RegrasInterface
extends Resource
## RegrasInterface — interface e metas.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Cartao")
## cartão de derrota na tela por 4,5 s (P04): dá para ler XP e loot sem tapar a hunt · unidade: milissegundos ·
## origem E (desenhada por nós) · evidência: P04
@export_range(0.0, 45000.0, 0.0001, "or_greater")  var cartao_ms: float = 4500.0

## shiny fica mais tempo: é o evento raro que o jogador quer ver · unidade: milissegundos · origem E (desenhada
## por nós) · evidência: comentário em `sim/regras_apresentacao.gd`
@export_range(0.0, 70000.0, 0.0001, "or_greater")  var cartao_shiny_ms: float = 7000.0

@export_group("Metas")
## a próxima meta é procurada até 100 níveis do líder à frente · origem E (desenhada por nós) · evidência:
## comentário em `sim/metas.gd`
@export_range(0.0, 1000.0, 0.0001, "or_greater")  var metas_busca_niveis: float = 100.0

## hunt recomendada só se o Power médio dos selvagens (IV médio, Quality 1) não passa do Power do líder; a
## campanha confere que a recomendada não mata · unidade: multiplicador · origem E (desenhada por nós) ·
## evidência: comentário em `sim/metas.gd`
@export_range(0.0, 10.0, 0.0001, "or_greater")  var metas_fator_poder: float = 1.0

## a próxima meta só aparece se render ≥ 5% a mais de XP/min (abaixo disso não vale trocar) · origem E (desenhada
## por nós) · evidência: comentário em `sim/metas.gd`
@export_range(0.0, 1.0, 0.0001, "or_greater")  var metas_ganho_min: float = 0.05

## IV médio do sorteio 1..32 (A: uniforme) para estimar o selvagem típico · unidade: segundos · origem A
## (comprovada contra o original) · evidência: comentário em `sim/metas.gd`
@export_range(0.0, 165.0, 0.0001, "or_greater")  var metas_iv_selvagem: float = 16.5

## espécies diferentes capturadas; mais a 'Pokédex da região' (espécies das hunts liberadas) · origem E (desenhada
## por nós) · evidência: comentário em `sim/metas.gd`
@export var metas_marcos_colecao: Array = [1.0, 5.0, 10.0, 25.0, 50.0, 75.0, 100.0, 150.0, 200.0, 300.0, 400.0]

## marcos do treinador; 150/500/2000 são os desbloqueios de região (C); de 150 a 500, um a cada 25–50 níveis para
## o trecho sem hunt nova ter meta visível · origem E (desenhada por nós) · evidência: comentário em
## `sim/metas.gd`
@export var metas_marcos_nivel: Array = [10.0, 25.0, 50.0, 80.0, 100.0, 150.0, 175.0, 200.0, 250.0, 300.0, 350.0, 400.0, 450.0, 500.0, 750.0, 1000.0, 1500.0, 2000.0]

## segundos por abate fora da luta (andar e respawn): rhydon-1h (A) tem 8,7 s por abate com 2,91 golpes de 1,6 s →
## 4,0 s · unidade: segundos · origem E (desenhada por nós) · evidência: rhydon-1h
@export_range(0.0, 40.0, 0.0001, "or_greater")  var metas_s_extra_abate: float = 4.0

@export_group("Geral")
## decisão do usuário: no máximo 30 cartões por instância; limita só a apresentação · origem E (desenhada por nós)
## · evidência: comentário em `sim/regras_apresentacao.gd`
@export_range(0.0, 300.0, 0.0001, "or_greater")  var cartoes_por_instancia: float = 30.0
