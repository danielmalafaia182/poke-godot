@tool
class_name RegrasDitto
extends Resource
## RegrasDitto — Ditto.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Geral")
## −25% de HP, Atk, Def, SpA e SpD ao transformar (C) · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_ditto.gd`
@export_range(0.0, 2.5, 0.0001, "or_greater")  var debuff: float = 0.25

## a transformação dura 12 h (C) · unidade: segundos · origem C (replicada do cliente sem confirmação no servidor)
## · evidência: comentário em `sim/servico_ditto.gd`
@export_range(0, 432000, 1, "or_greater")  var duracao_s: int = 43200

## fonte offline: um Ditto no treinador 100 (classe 3) · origem E (desenhada por nós) · no jogo original: o Ditto
## vem da loja de diamantes (online) · evidência: comentário em `sim/servico_ditto.gd`
@export_range(0, 1000, 1, "or_greater")  var nivel_recebe: int = 100
