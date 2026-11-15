# O servidor mudou entre 09/11 e 10/11? (fase 4, 15/11)

Gerado por `ferramentas/fase4/comparar_dias.py`: as regras do processador de gravações aplicadas a todas as gravações,
por dia (UTC). Cada célula: confirmou / contradisse / inconclusivo (nº de verificações).

| Regra | 2026-11-09 | 2026-11-10 | 2026-11-11 | 2026-11-13 | 2026-11-15 |
|---|---|---|---|---|---|
| Auto-Potion com poção fixa no Auto-Helper | — | — | — | — | 0/0/1 |
| Auto-Potion dispara no mesmo tick em que o HP fica ≤ 50% | 2/0/0 | 2/0/0 | — | — | — |
| Auto-Potion usa a menor poção que cobre o que falta | 3/0/0 | 2/0/0 | — | — | — |
| Daily Catch: xp = floor(xpAbate × 8/3 × m), m múltiplo de 0,5 em [1,5; 18] | — | — | — | 4/0/0 | 1/0/0 |
| Daily Gift: o mesmo calendário de 28 e nextDay = coletados + 1 | — | — | — | 1/0/0 | 1/0/0 |
| Daily Kill: xp = floor(qtd × xpAbate × 8/3) | — | — | — | 4/0/0 | 1/0/0 |
| Fórmula de dano da sim (aliado, atacante nível 1–4) | 2/0/0 | — | — | — | — |
| Fórmula de dano da sim (aliado, atacante nível 200–+) | — | 3/1/0 | — | — | — |
| Fórmula de dano da sim (aliado, atacante nível 80–199) | 1/0/0 | 2/0/0 | — | — | 1/0/0 |
| Fórmula de dano da sim (selvagem, atacante nível 1–4) | 1/0/0 | — | — | — | — |
| Fórmula de dano da sim (selvagem, atacante nível 20–79) | — | — | — | — | 0/0/1 |
| Fórmula de dano da sim (selvagem, atacante nível 80–199) | 1/0/0 | 2/0/0 | — | — | — |
| Golpe do selvagem: sempre o mesmo por indivíduo | 3/0/0 | 2/0/0 | — | — | 1/0/0 |
| HP de combate do aliado = max(24, 12 × stat HP) | 3/0/0 | 6/0/0 | 1/0/0 | 1/0/0 | 2/0/0 |
| HP do selvagem = max(120, 35 × stat HP) | 3/0/0 | 13/0/0 | 1/0/0 | 3/0/0 | 2/0/0 |
| Loot × tabela (lock, chance × 0.30) | — | 2/0/0 | — | — | 1/0/0 |
| Loot × tabela (normal, chance × 1.00) | 3/0/0 | 13/0/0 | — | 1/0/0 | 1/0/0 |
| Loot × tabela (tipo do dia, chance × 1.40) | — | — | — | 1/0/0 | 1/0/0 |
| Passo do herói em reta: 600 ms | 2/0/0 | 13/0/0 | — | 1/0/0 | 1/0/0 |
| Passo do selvagem em reta: 1000/1200 ms | 3/0/0 | 13/0/0 | — | 2/0/0 | 1/0/0 |
| Penalidade = lock de 60 s: debuff em todo abate antes do until e em nenhum depois | 1/0/0 | 13/0/0 | 1/0/0 | — | 2/0/0 |
| Penalidade de entrada: XP = floor(total × 0,3) | 2/0/0 | 12/0/0 | 1/0/0 | — | 2/0/0 |
| Piso de dano do aliado = 2 | 3/0/0 | 6/0/0 | 1/0/0 | 1/0/0 | 1/0/0 |
| Piso de dano do selvagem = 1 | 3/0/0 | 2/0/0 | 1/0/0 | — | 1/0/0 |
| Ritmo de ataque do aliado: 1600 ms | 2/0/1 | 5/0/3 | — | 1/0/1 | 2/0/0 |
| Streak: n-ésimo ponto custa 25.000 × n; bônus 0,1% por ponto | — | — | — | 1/0/0 | — |
| Tarefa entregue paga o xp/cash da tabela | — | — | — | — | 3/0/0 |
| Tipo do Dia | 3/0/0 | 11/0/0 | 1/0/0 | 3/0/0 | 2/0/0 |
| Tipo do Dia: typeDay = floor(20% da base) | — | — | — | 1/0/0 | 1/0/0 |
| VIP = +50% da base | 3/0/0 | 13/0/0 | 1/0/0 | 3/0/0 | 2/0/0 |
| XP base por abate = experience da espécie | 3/0/0 | 13/0/0 | 1/0/0 | 3/0/0 | 2/0/0 |

## Contradições

- Fórmula de dano da sim (aliado, atacante nível 200–+) — c5.jsonl (2026-11-10): 61.7% de 324 golpes explicados

## maxHp dos selvagens por espécie e hunt (indivíduos) em mais de um dia

| Hunt, espécie | Dia: n, mín–média–máx, múltiplos de 35 |
|---|---|
| larvitar, 246 | 2026-11-13: 15, 525–936–1505, 100% · 2026-11-15: 15, 700–978–1435, 100% |
| rattata, 19 | 2026-11-09: 30, 120–120–120, 100% · 2026-11-10: 30, 120–120–120, 100% |
| rhydon, 112 | 2026-11-09: 15, 3430–4471–5915, 100% · 2026-11-10: 15, 3045–3925–5285, 100% |

## maxHp dos selvagens × o previsto pela fórmula da sim (grupos com 10+ indivíduos)

Se o servidor tivesse mudado a forma de sortear os stats dos selvagens, os dias depois de 09/11 sairiam deslocados.

| Dia | Hunt | Espécie | Nível | Indivíduos | Média obs. | Média prevista | z |
|---|---|---|---|---|---|---|---|
| 2026-11-15 | arbok | Arbok | 40 | 15 | 1430 | 1518 | -0.88 |
| 2026-11-13 | blastoise | Blastoise | 80 | 15 | 3715 | 3656 | 0.27 |
| 2026-11-11 | brave_nidoqueen | Brave Nidoqueen | 150 | 15 | 8176 | 7523 | 1.57 |
| 2026-11-10 | bulbasaur | Bulbasaur | 20 | 15 | 637 | 636 | 0.03 |
| 2026-11-10 | geodude | Geodude | 1 | 15 | 120 | 120 | sem informação: o piso de 120 cobre todos (previsto) |
| 2026-11-10 | kangaskhan | Kangaskhan | 80 | 30 | 4073 | 4513 | -2.62 |
| 2026-11-13 | larvitar | Larvitar | 30 | 15 | 936 | 1019 | -1.16 |
| 2026-11-15 | larvitar | Larvitar | 30 | 15 | 978 | 1019 | -0.58 |
| 2026-11-10 | meowth | Meowth | 20 | 15 | 523 | 595 | -1.58 |
| 2026-11-10 | oddish | Oddish | 1 | 15 | 120 | 120 | sem informação: o piso de 120 cobre todos (previsto) |
| 2026-11-09 | rattata | Rattata | 1 | 30 | 120 | 120 | sem informação: o piso de 120 cobre todos (previsto) |
| 2026-11-10 | rattata | Rattata | 1 | 30 | 120 | 120 | sem informação: o piso de 120 cobre todos (previsto) |
| 2026-11-09 | rhydon | Rhydon | 80 | 15 | 4471 | 4506 | -0.15 |
| 2026-11-10 | rhydon | Rhydon | 80 | 15 | 3925 | 4506 | -2.46 |
| 2026-11-10 | rhyhorn | Rhyhorn | 30 | 15 | 1545 | 1383 | 2.02 |
| 2026-11-10 | spearow | Spearow | 10 | 30 | 296 | 297 | -0.07 |
| 2026-11-09 | typhlosion | Rattata | 80 | 15 | 120 | 2062 | fora: todos no piso 120, o nível do selvagem não é o da hunt |
| 2026-11-09 | typhlosion | Typhlosion | 80 | 15 | 3316 | 3625 | -1.45 |
| 2026-11-13 | tyranitar | Tyranitar | 100 | 15 | 5203 | 5436 | -0.80 |
| 2026-11-10 | vulpix | Vulpix | 20 | 60 | 596 | 579 | 0.72 |

z médio por dia: 2026-11-09 -0.80 (2 grupos), 2026-11-10 -0.57 (7 grupos), 2026-11-11 1.57 (1 grupos), 2026-11-13 -0.56 (3 grupos), 2026-11-15 -0.73 (2 grupos)
