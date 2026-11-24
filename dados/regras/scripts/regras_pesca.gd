@tool
class_name RegrasPesca
extends Resource
## RegrasPesca — pesca.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Geral")
## faixas da pesca: skill mínima, níveis e espécies (classe 3; C: a forma das faixas) · origem E (desenhada por
## nós) · evidência: comentário em `sim/servico_pesca.gd`
@export var faixas: Array = [{
"fish": ["Magikarp", "Goldeen", "Poliwag"],
"minSkill": 1,
"mobLevel": [5, 15]
}, {
"fish": ["Horsea", "Krabby", "Tentacool"],
"minSkill": 10,
"mobLevel": [20, 35]
}, {
"fish": ["Staryu", "Shellder", "Seel"],
"minSkill": 20,
"mobLevel": [40, 60]
}, {
"fish": ["Seaking", "Kingler", "Poliwhirl"],
"minSkill": 35,
"mobLevel": [70, 100]
}, {
"fish": ["Starmie", "Cloyster", "Dewgong"],
"minSkill": 50,
"mobLevel": [110, 150]
}, {
"fish": ["Tentacruel", "Seadra", "Lanturn"],
"minSkill": 70,
"mobLevel": [160, 220]
}, {
"fish": ["Lapras", "Kingdra", "Gyarados"],
"minSkill": 90,
"mobLevel": [240, 320]
}]

## duração da onda de pesca (classe 3) · unidade: segundos · origem E (desenhada por nós) · evidência: comentário
## em `sim/servico_pesca.gd`
@export_range(0, 100, 1, "or_greater")  var onda_s: int = 10

## A: skill 4 → 12 · origem A (observada (referência declarada, não auditada pelo catálogo)) · evidência:
## comentário em `sim/servico_pesca.gd`
@export_range(0, 30, 1, "or_greater")  var peixes_por_nivel: int = 3

## recarga entre pescas (classe 3; C: ⏳ Aguarde Ns) · unidade: segundos · origem E (desenhada por nós) ·
## evidência: comentário em `sim/servico_pesca.gd`
@export_range(0, 300, 1, "or_greater")  var recarga_s: int = 30

## nível máximo da pesca (classe 3) · origem E (desenhada por nós) · evidência: comentário em
## `sim/servico_pesca.gd`
@export_range(0, 1000, 1, "or_greater")  var skill_max: int = 100
