@tool
class_name RegrasLoot
extends Resource
## RegrasLoot — loot e economia.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Geral")
## C: Derrote shinies selvagens — eles podem dropar o Card da espécie; 10% por shiny abatido (o Card leva ao Altar
## dos bosses) · unidade: segundos · origem C (replicada do cliente sem confirmação no servidor) · evidência:
## comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var card_chance_shiny: float = 0.1

## Poke Card Pack por abate (nenhuma tabela do snapshot dropa o pack): ~0,2 pacote por hora a 7 abates/min ·
## unidade: fração 0–1 · origem E (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var pack_chance_abate: float = 0.0005

## decisão do usuário (ciclo 2): se uma pedra de evolução não cai em 3× os abates esperados para ela (soma das
## chances ≥ 3), cai no próximo; tira os 4–70 h de espera por sorte do Golem · unidade: multiplicador · origem E
## (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 30.0, 0.0001, "or_greater")  var pedra_garantia_fator: float = 3.0
