@tool
class_name RegrasItens
extends Resource
## RegrasItens — TMs, held items, Rare Candy e berries.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Candy")
## A: items.json "Rare Candy" · origem A (observada (referência declarada, não auditada pelo catálogo)) ·
## evidência: items.json
@export_range(0, 901240, 1, "or_greater")  var candy_id: int = 90124

## C · origem C (replicada do cliente sem confirmação no servidor) · evidência: comentário em
## `sim/servico_itens.gd`
@export_range(0, 100, 1, "or_greater")  var candy_max_por_pokemon: int = 10

## C: "level 100 or below" · origem C (replicada do cliente sem confirmação no servidor) · evidência: comentário
## em `sim/servico_itens.gd`
@export_range(0, 1000, 1, "or_greater")  var candy_nivel_max: int = 100

@export_group("Geral")
## C: "the effect lasts 30 minutes" · unidade: segundos · origem C (replicada do cliente sem confirmação no
## servidor) · evidência: comentário em `sim/servico_itens.gd`
@export_range(0, 18000, 1, "or_greater")  var berry_duracao_s: int = 1800

## Nome do tipo na descrição (A, português) → tipo do jogo, comparado só pelas letras a–z ("Aço" → "ao", "Água" →
## "gua"). "Neutro" = golpes neutros dos bosses (C, talentos do Botânico: "Berry that protects from Neutral-type
## moves"). · origem A (observada (referência declarada, não auditada pelo catálogo)) · evidência: comentário em
## `sim/servico_itens.gd`
@export var tipos_berry: Dictionary = {
"ao": "STEEL",
"drago": "DRAGON",
"eltrico": "ELECTRIC",
"fada": "FAIRY",
"fantasma": "GHOST",
"fogo": "FIRE",
"gelo": "ICE",
"gua": "WATER",
"inseto": "BUG",
"lutador": "FIGHTING",
"neutro": "NEUTRAL",
"normal": "NORMAL",
"noturno": "DARK",
"pedra": "ROCK",
"planta": "GRASS",
"psquico": "PSYCHIC",
"terra": "GROUND",
"veneno": "POISON",
"voador": "FLYING"
}
