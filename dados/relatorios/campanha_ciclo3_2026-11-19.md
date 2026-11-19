# Campanha do ciclo 2: tudo ligado, VIP e sem VIP

Fonte: `testes/campanha.gd --completo 1` (sim pura, Geodude Lv.1 do jogo novo, política do jogador E no cabeçalho do script). Cada dia de calendário = 16 h de jogo ativo + 8 h de Modo Soneca. Ligado: soneca, Streak (trilha EXP), Daily Gift/Kill/Catch, Quests & Tasks, boosts do Gift, Tipo do Dia, Auto-Catch Shiny, garantia de pedra (3×). Insígnias: 0 (sem luta de ginásio offline).

- **VIP**: 401 h ativas (24.7 dias), treinador 583, Golem 577, 448 sessões, 89 min reais.
- **sem VIP**: 401 h ativas (24.7 dias), treinador 487, Golem 479, 425 sessões, 86 min reais.

## Metas de tempo

| Meta | VIP: horas ativas · dias | Sem VIP: horas ativas · dias |
| --- | --- | --- |
| Graveler | **16 h** · 1.0 d | **19 h** · 1.1 d |
| Golem | **24 h** · 1.3 d | **62 h** · 3.6 d |
| Outland (150) | **34 h** · 2.1 d | **70 h** · 4.2 d |
| Orre (500) | **275 h** · 17.1 d | ~425 h · ~26 d (projeção) |
| Nightmare (2000) | ~17.412 h · ~1.073 d (projeção) | ~20.407 h · ~1.257 d (projeção) |

Ciclo 1 (sem nada disso, sessões de 60 min, mesma política): Graveler 13 h, Golem 56 h, Outland (150) 52 h; Orre e Nightmare só por projeção.

## De onde veio o XP do treinador (parcelas fora da caça normal)

| Parcela | VIP | Sem VIP |
| --- | --- | --- |
| Modo Soneca (50% da taxa, 8 h/dia) | 1.259.405.122 | 723.064.764 |
| Quests & Tasks | 313.163 | 983.100 |
| Daily Kill | 11.246.976 | 39.723.797 |
| Daily Catch | 161.567 | 482.217 |
| Pontos de Streak comprados (EXP) | 70 | 60 |
| Ouro gasto no Streak | 62.125.000 | 45.750.000 |
| Daily Gift coletados | 25 | 25 |
| Tarefas entregues | 6 | 8 |
| Daily Kill completas | 1 | 3 |
| Shinies abatidos | 67 | 183 |
| Shinies capturados (aprox.) | 2 | 2 |

VIP: 19.9% do XP total veio dessas parcelas.

sem VIP: 20.8% do XP total veio dessas parcelas.

## Metas visíveis no trecho 150–500 (sim/metas.gd)

O que a cidade mostrava como próxima meta, cada vez que mudou (rodada VIP):

| Hora | Treinador | Líder | Hunt recomendada | Próxima meta |
| --- | --- | --- | --- | --- |
| 33 | 149 | Golem 130→149 | scyther | líder 188: golpe a menos (+29%) |
| 34 | 152 | Golem 149→151 | furious_scyther | líder 163: golpe a menos (+18%) |
| 37 | 166 | Golem 161→166 | furious_scyther | líder 199: golpe a menos (+22%) |
| 41 | 177 | Golem 172→176 | furious_scyther | líder 199: golpe a menos (+22%) |
| 51 | 199 | Golem 197→199 | furious_scyther | líder 283: golpe a menos (+29%) |
| 52 | 201 | Golem 199→201 | furious_scyther | líder 283: golpe a menos (+29%) |
| 75 | 251 | Golem 248→250 | furious_scyther | líder 283: golpe a menos (+29%) |
| 94 | 284 | Golem 282→283 | furious_scyther | marco do treinador 300 |
| 101 | 300 | Golem 297→299 | furious_scyther | marco do treinador 350 |
| 135 | 351 | Golem 348→349 | furious_scyther | marco do treinador 400 |
| 174 | 400 | Golem 397→398 | furious_scyther | marco do treinador 450 |
| 222 | 450 | Golem 445→446 | furious_scyther | marco do treinador 500 |
| 276 | 501 | Golem 496→496 | furious_scyther | marco do treinador 750 |

Sessões na hunt recomendada: 46, com 2 mortes (o critério de Power da recomendação não manda o jogador morrer).

Marcos (hora de jogo ativo em que cada um foi visto, rodada VIP): insignias_0 0 h, treinador 1 0 h, coleção 1 1 h, treinador 10 2 h, insignias_1 3 h, treinador 25 7 h, insignias_2 9 h, insignias_3 10 h, treinador 50 14 h, insignias_5 19 h, treinador 80 19 h, insignias_6 25 h, treinador 100 25 h, insignias_7 27 h, insignias_8 32 h, treinador 150 34 h, insignias_9 36 h, treinador 175 41 h, insignias_10 50 h, coleção 5 50 h, treinador 200 52 h, insignias_11 59 h, treinador 250 75 h, insignias_12 82 h, treinador 300 101 h, insignias_13 131 h, treinador 350 135 h, treinador 400 174 h, insignias_14 180 h, treinador 450 222 h, insignias_15 275 h, treinador 500 276 h, insignias_16 295 h, insignias_17 377 h

## Multiplicador de XP por região (classe 3, proposta; `xp_regiao` em balanceamento.json, padrão 1)

Rodada VIP: 500 → 2000 leva ~17.137 h ativas pela projeção (~1.056 dias). De 500 a 2000 o jogador caça em Orre (a Nightmare só abre no 2000), então o tempo desse trecho divide pelo multiplicador de Orre:

| Multiplicador de Orre | 500 → 2000 (h ativas) | dias de calendário | Nightmare no total |
| --- | --- | --- | --- |
| ×1 | 17.137 | 1.056 | ~17.412 h · ~1.073 d |
| ×2 | 8.568 | 528 | ~8.843 h · ~545 d |
| ×5 | 3.427 | 211 | ~3.702 h · ~228 d |
| ×10 | 1.714 | 106 | ~1.989 h · ~123 d |
| ×20 | 857 | 53 | ~1.132 h · ~70 d |
| ×40 | 428 | 26 | ~704 h · ~43 d |

## Ciclo 3: ginásios e Orre ×10 — o que a campanha mostra

- **Insígnias:** só com o líder (política da campanha), VIP chegou a 17 insígnias ativas ao mesmo tempo (168 vitórias e 469
  derrotas em 400 h), sem VIP a 14. As derrotas são os ginásios de tipo forte contra o Golem, que pedem time.
- **Orre ×10 não entrou em ação:** a rodada VIP chegou a Orre (treinador 500) às 275 h, mas o Golem sozinho morre em quase
  todas as hunts de Orre (41 mortes depois das 275 h: grovyle, lombre, kirlia… 1 sessão e 1 morte cada) e volta para a
  Outland (`enraged_typhlosion`, 10,9 M XP/h). Por isso a projeção da tabela acima (Nightmare ~17 mil h) ainda é a do ritmo
  da Outland.
- **Onde sobreviveu em Orre, com ×10:** `manectric`/`swellow` (580) deram **46–52 M XP/h** (5× a Outland), com 1 morte a
  cada ~35 min; `electrike`/`taillow` (530) só 2,3 M XP/h (espécies fracas, XP base baixo, A).
- **Meta até a Nightmare com ×10, caçando Orre 580 a ~50 M XP/h:** de 580 a 2000 são ~5.200 h ativas (~325 dias de 16 h),
  contra ~24.000 h (~1.500 dias) no ritmo da Outland. Depende de o time aguentar Orre (o aviso de Orre no original fala em
  TMs AoE e de elemento); a campanha com só o líder não aguenta.
