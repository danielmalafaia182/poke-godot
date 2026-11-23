@tool
class_name RegrasEventos
extends Resource
## RegrasEventos — Streak, boosts e Tipo do Dia.
## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.
## O padrão de cada campo é o valor atual do jogo (perfil "original"); os perfis em dados/regras/<perfil>/ e
## user://regras/<perfil>/ guardam só o que muda.

@export_group("Insignia")
## +1% de chance de rolagem extra de drop por insígnia ativa, como o texto do cliente · unidade: % · origem E
## (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 10.0, 0.0001, "or_greater")  var insignia_pct_drop: float = 1.0

## parcela gym: floor(1% da base por insígnia ativa), o texto do cliente diz +1% por insígnia · unidade: % ·
## origem E (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 10.0, 0.0001, "or_greater")  var insignia_pct_xp: float = 1.0

@export_group("Tipo")
## Tipo do Dia (A: evento "type-of-day", "+20% de XP e +20% de loot em Pokémon do tipo X"): parcela typeDay =
## floor(20% da base) (A, G8: 61/61); loot em `tipo_do_dia_loot` (A: × 1,4, não 1,2). Loot no tipo do dia (A, G8 ×
## G10, 15/11): chance de cada drop × 1,4 (cap 1). Tyranitar no dia Sombrio (G8, 61 abates): 148 drops, esperado
## 146,3 com ×1,4 (z 0,2) e 125,4 com ×1,2 (z 2,8: rejeitado); a mesma hunt num dia Veneno (G10, 91 abates): 161 ×
## 155,9 pela tabela (controle). ×1,44 (= 1,2²) também cabe: não se separa de 1,4 com uma gravação. · origem A
## (comprovada contra o original) · evidência: G8, G10
@export_range(0.0, 14.0, 0.0001, "or_greater")  var tipo_do_dia_loot: float = 1.4

## E: sem shiny na fase 1 · unidade: % · origem E (desenhada por nós) · evidência: comentário em `sim/regras.gd`
@export_range(0, 200, 1, "or_greater")  var tipo_do_dia_pct: int = 20

@export_group("Geral")
## Fase 4, lote 2 — parcelas de XP e efeitos de loot (cfg.boosts, cfg.eventos, cfg.streak; zero = saída igual a
## antes). Streak Points (C, guia e janela do original): +0,1% por ponto na trilha EXP (parcela "streak" do
## treinador; o pokeXp.parts não tem chave streak, A) e, na trilha Loot, +0,1% de chance de uma rolagem EXTRA
## inteira de drop (100% = uma rolagem garantida; o excesso vira a chance da próxima, C). · unidade: % · origem C
## (replicada do cliente sem confirmação no servidor) · evidência: comentário em `sim/regras.gd`
@export_range(0.0, 1.0, 0.0001, "or_greater")  var streak_pct_por_ponto: float = 0.001
