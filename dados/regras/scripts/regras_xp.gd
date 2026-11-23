@tool
class_name RegrasXP
extends Resource
## RegrasXP — XP e níveis.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Xp")
## decisão do usuário (ciclo 3): Orre ×10 (500 → 2000 em ~89 dias de calendário em vez de ~2,5 anos, campanha do
## ciclo 2); Nightmare sem multiplicador; parcela event, XP da espécie igual · origem E (desenhada por nós) · no
## jogo original: sem multiplicador por região (×1 em toda parte) · evidência: comentário em `sim/regras.gd`
@export var xp_regiao: Dictionary = {
"kanto": 1.0,
"nightmare": 1.0,
"orre": 10.0,
"outland": 1.0
}

## decisão do usuário (ciclo 6): em Orre o multiplicador de cada hunt é max(×10, piso ÷ XP base médio das espécies
## da hunt). Piso = 1,22 × 13.508 (o XP base da melhor hunt da Outland): com o time e os itens do jogo (TMs), Orre
## 530 abate 10,1/min contra 12,3 na Outland (campanha do ciclo 6), então Orre 510–579 rende o mesmo que a melhor
## Outland. Antes (ciclo 5) era 40.524 (3×), com o abate 3× mais lento sem itens; de 580 em diante (base 19.508 ×
## 10) nada muda · origem E (desenhada por nós) · no jogo original: sem piso (a base da espécie vale) · evidência:
## comentário em `sim/regras.gd`
@export var xp_regiao_piso: Dictionary = {
"orre": 16500.0
}
