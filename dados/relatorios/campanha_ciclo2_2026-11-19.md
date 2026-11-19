# Campanha do ciclo 2: tudo ligado, VIP e sem VIP

Fonte: `testes/campanha.gd --completo 1` (sim pura, Geodude Lv.1 do jogo novo, política do jogador E no cabeçalho do script). Cada dia de calendário = 16 h de jogo ativo + 8 h de Modo Soneca. Ligado: soneca, Streak (trilha EXP), Daily Gift/Kill/Catch, Quests & Tasks, boosts do Gift, Tipo do Dia, Auto-Catch Shiny, garantia de pedra (3×). Insígnias: 0 (sem luta de ginásio offline).

- **VIP**: 401 h ativas (24.7 dias), treinador 560, Golem 554, 409 sessões, 100 min reais.
- **sem VIP**: 401 h ativas (24.7 dias), treinador 471, Golem 462, 419 sessões, 96 min reais.

## Metas de tempo

| Meta | VIP: horas ativas · dias | Sem VIP: horas ativas · dias |
| --- | --- | --- |
| Graveler | **13 h** · 0.5 d | **18 h** · 1.1 d |
| Golem | **56 h** · 3.3 d | **52 h** · 3.2 d |
| Outland (150) | **52 h** · 3.2 d | **66 h** · 4.1 d |
| Orre (500) | **312 h** · 19.3 d | ~467 h · ~29 d (projeção) |
| Nightmare (2000) | ~14.732 h · ~908 d (projeção) | ~25.932 h · ~1.598 d (projeção) |

Ciclo 1 (sem nada disso, sessões de 60 min, mesma política): Graveler 21 h, Golem 102 h, Outland (150) 109 h; Orre e Nightmare só por projeção.

## De onde veio o XP do treinador (parcelas fora da caça normal)

| Parcela | VIP | Sem VIP |
| --- | --- | --- |
| Modo Soneca (50% da taxa, 8 h/dia) | 1.130.474.353 | 638.594.230 |
| Quests & Tasks | 198.413 | 847.515 |
| Daily Kill | 11.246.976 | 65.407.913 |
| Daily Catch | 10.911 | 280.373 |
| Pontos de Streak comprados (EXP) | 63 | 57 |
| Ouro gasto no Streak | 50.400.000 | 41.325.000 |
| Daily Gift coletados | 25 | 4 |
| Tarefas entregues | 5 | 9 |
| Daily Kill completas | 1 | 5 |
| Shinies abatidos | 103 | 164 |
| Shinies capturados (aprox.) | 0 | 0 |

VIP: 20.2% do XP total veio dessas parcelas.

sem VIP: 21.4% do XP total veio dessas parcelas.

## Metas visíveis no trecho 150–500 (sim/metas.gd)

O que a cidade mostrava como próxima meta, cada vez que mudou (rodada VIP):

| Hora | Treinador | Líder | Hunt recomendada | Próxima meta |
| --- | --- | --- | --- | --- |
| 49 | 143 | Graveler 131→142 | scyther | líder 143: golpe a menos (+22%) |
| 50 | 145 | Graveler 142→145 | scyther | líder 204: golpe a menos (+29%) |
| 52 | 150 | Graveler 147→150 | furious_scyther | líder 152: golpe a menos (+15%) |
| 53 | 152 | Graveler 150→152 | furious_scyther | líder 176: golpe a menos (+18%) |
| 56 | 158 | Golem 157→158 | furious_scyther | líder 163: golpe a menos (+18%) |
| 58 | 163 | Golem 160→163 | furious_scyther | líder 199: golpe a menos (+22%) |
| 63 | 176 | Golem 174→176 | furious_scyther | líder 199: golpe a menos (+22%) |
| 69 | 202 | Golem 198→201 | furious_scyther | líder 283: golpe a menos (+29%) |
| 89 | 251 | Golem 248→250 | furious_scyther | líder 283: golpe a menos (+29%) |
| 113 | 284 | Golem 282→283 | furious_scyther | marco do treinador 300 |
| 122 | 300 | Golem 298→299 | furious_scyther | marco do treinador 350 |
| 160 | 350 | Golem 347→348 | furious_scyther | marco do treinador 400 |
| 200 | 400 | Golem 396→397 | furious_scyther | marco do treinador 450 |
| 254 | 450 | Golem 446→447 | furious_scyther | marco do treinador 500 |
| 312 | 500 | Golem 494→495 | furious_scyther | marco do treinador 750 |

Sessões na hunt recomendada: 46, com 0 mortes (o critério de Power da recomendação não manda o jogador morrer).

Marcos (hora de jogo ativo em que cada um foi visto, rodada VIP): treinador 1 0 h, coleção 1 1 h, treinador 10 2 h, treinador 25 7 h, treinador 50 14 h, treinador 80 19 h, treinador 100 31 h, treinador 150 52 h, treinador 175 63 h, treinador 200 69 h, treinador 250 89 h, treinador 300 122 h, treinador 350 160 h, treinador 400 200 h, coleção 5 214 h, treinador 450 254 h, treinador 500 312 h

## Multiplicador de XP por região (classe 3, proposta; `xp_regiao` em balanceamento.json, padrão 1)

Rodada VIP: 500 → 2000 leva ~14.420 h ativas pela projeção (~889 dias). De 500 a 2000 o jogador caça em Orre (a Nightmare só abre no 2000), então o tempo desse trecho divide pelo multiplicador de Orre:

| Multiplicador de Orre | 500 → 2000 (h ativas) | dias de calendário | Nightmare no total |
| --- | --- | --- | --- |
| ×1 | 14.420 | 889 | ~14.732 h · ~908 d |
| ×2 | 7.210 | 444 | ~7.522 h · ~464 d |
| ×5 | 2.884 | 178 | ~3.196 h · ~197 d |
| ×10 | 1.442 | 89 | ~1.754 h · ~108 d |
| ×20 | 721 | 44 | ~1.033 h · ~64 d |
| ×40 | 361 | 22 | ~672 h · ~41 d |
