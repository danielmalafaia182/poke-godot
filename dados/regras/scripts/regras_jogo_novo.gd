@tool
class_name RegrasJogoNovo
extends Resource
## RegrasJogoNovo — começo de jogo.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Geral")
## o kit (100 Small Potions, 100 Poké Balls) já cobre a primeira hora; o ouro vem da venda do loot · origem E
## (desenhada por nós) · evidência: comentário em `sim/servico_novo_jogo.gd`
@export_range(0.0, 1.0, 0.0001, "or_greater")  var ouro_inicial: float = 0.0
