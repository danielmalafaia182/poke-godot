@tool
class_name RegrasVIP
extends Resource
## RegrasVIP — VIP.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Geral")
## A: parcela vip = 50% da base · unidade: fração · origem A (comprovada contra o original) · evidência:
## comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001)  var vip_fracao: float = 0.5
