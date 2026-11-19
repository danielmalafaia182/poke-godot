# Campanha com metas e muros

Fonte: `testes/campanha.gd` (Geodude Lv.1 do jogo novo, política do jogador E no cabeçalho do script), 186 sessões, 303 h simuladas; no fim, treinador 353 e líder Golem 353.

## Metas

| Meta | Tempo de jogo |
| --- | --- |
| Graveler | **22 h** |
| Golem | **40 h** |
| Outland (treinador 150) | **69 h** |
| Orre (treinador 500) | não alcançado em 303 h; projeção pela curva de XP com o ritmo das últimas 20 h (7.9 M XP/h): **~641 h** (estimativa) |
| Nightmare (treinador 2000) | não alcançado em 303 h; projeção pela curva de XP com o ritmo das últimas 20 h (7.9 M XP/h): **~33.736 h** (estimativa) |

XP total pedida (curva A): treinador 150 = 54.042.300, 500 = 3.980.309.125, 2000 = 265.731.159.125.

Comparação com a campanha anterior (300 h, sessões de 60 min): Graveler 21 h, Golem **102 h**, Outland **109 h**.
A diferença está quase toda na sorte das 4 Rock Stones do Golem (abaixo).

## XP por abate por região (A: o XP base é o `experience` da espécie, não o nível da hunt)

| Região (nível da hunt) | XP por abate (mediana) | XP/h a 7 abates/min |
| --- | --- | --- |
| Kanto 80 / 100 | 3.848 / 6.008 | 1,6 M / 2,5 M |
| **Outland 150** (as 47 hunts) | **13.508** | **5,7 M** (a campanha faz 7,6–8,4 M) |
| Orre 510–560 (39 hunts) | 68 a 2.168 | ≤ 0,9 M — **menos que a Outland** |
| **Orre 580–600** (32 hunts) | **19.508** | **8,2 M** (+44% sobre a Outland) |
| Nightmare 2000 (46 hunts) | 548 (máx. 3.848) | 0,2 M |
| Nightmare 3000 (62 hunts) | 6.008 | 2,5 M — menos que a Outland |

## Muros de progressão

O nível do treinador nunca fica parado 10 h seguidas (nenhuma janela de 10 h com ≤ 1 nível). Os muros são outros:

| # | Muro | Tamanho medido | Proposta (não aplicada) |
| --- | --- | --- | --- |
| 1 | **Pedras do Golem**: Graveler → Golem pede 4 Rock Stones (receita da sim, classe 3), que caem a 0,1–1% por abate só em espécies de pedra | Graveler 80 → Golem: **4 h** numa campanha, **70 h** na outra (mesma política, só sorte). A anterior passou ~80 h caçando pedra na `larvitar` (nível 30) | Garantia de pedra: a cada N abates de espécies que dropam a pedra sem ela cair, a próxima cai (N ≈ 400). Ou: Rock Stone à venda no Mark por um preço alto (ex.: 50 mil). Ou: 2 pedras em vez de 4 para hunts de nível < 80 |
| 2 | **Outland 150 → Orre 500**: as 47 hunts da Outland são todas nível 150; de 150 a 500 não há hunt nova | **~550 h** só na Outland (projeção: Orre aos ~620 h) | Distribuir os níveis de acesso das hunts da Outland (150, 200, 250… 450) com o XP crescendo junto; ou uma parcela de XP que cresça com o nível do treinador |
| 3 | **Orre 500–580 não rende**: as hunts de Orre de nível 510–560 dão menos XP que a Outland (são espécies de Kanto 10–60) | O jogador fica na Outland até o treinador 580 | Usar o nível da hunt no XP base em Orre (ex.: experience × nível da hunt / nível de referência da espécie); ou reordenar o acesso (580/600 primeiro) |
| 4 | **Nightmare (treinador 2000)**: da curva de XP, o treinador 2000 pede 265,7 bilhões de XP; o melhor XP/h do jogo (Orre 600) faz ~8–11 M/h | **~26–32 mil horas** (3 a 4 anos jogando 24 h por dia), e as hunts da Nightmare dão menos XP que Orre | Decisão de produto (bloco de perguntas): baixar o portão da Nightmare, ou dar XP próprio às hunts dela, ou mantê-la como meta de anos |

## Janelas de ~10 h com no máximo 1 nível de treinador

| De (h) | Até (h) | Duração | Treinador | Líder | Onde |
| --- | --- | --- | --- | --- | --- |

Nenhuma.
