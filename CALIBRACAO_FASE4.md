# Calibração da fase 4 — lote 1: evolução, loja e economia, Nurse Joy, depot (10/11/2026)

Fontes:
- **A**: observado no servidor original (gravações);
- **B**: Pokepedia ou relato do usuário;
- **C**: extraído do cliente original. É o chunk `0gx72gz9qjk5j.js` (telas e chamadas) e o `3vooh2axx98am.js` (textos
  do guia e das janelas, em inglês);
- **D**: testado localmente;
- **E**: decisão do projeto;
- **F**: hipótese.

Onde mora: a regra está em `sim/servico_cidade.gd`, que é puro e determinístico. `PARAMETROS` guarda cada regra com
a origem.

O cliente faz três coisas, em `ponte_cidade.gd`:
- monta o estado a partir do save;
- manda o comando;
- aplica as mensagens.

As telas chamam `EstadoJogo`, que passa pela ponte.

Testes:
- `testes/test_sim_cidade.gd`: serviço puro, 40/40;
- `testes/test_ciclo_cidade.gd`: ciclo de ponta a ponta na cena, 20/20.

## Protocolo

| Comando | Original | Fonte |
| --- | --- | --- |
| `evolve-info {capturedId, destId?}` | `GET /api/game/evolve?capturedId=&destId=` | C (os campos da resposta são os que a tela lê: `canEvolve`, `needLevel`, `level`, `keepLevel`, `resetLevel`, `itemOnly`, `hasStones`, `stones[{itemId, name, need, have}]`, `branches`, `destName`) |
| `evolve {capturedId, useStone, destId?}` | `POST /api/game/evolve` → `{name}` | C |
| `shop` | `GET /api/game/shop` → `{gold, balls[{id, name, priceGold, iconUrl, catchRate}], items[{id, name, priceGold, icon, category, description}]}` | **A** (G1); a lista `sell` extra é E (o cliente monta a lista de venda do inventário) |
| `shop-buy {ballId \| itemId, qty}` | `POST /api/game/shop/buy` → `{ok, bought, item, goldSpent, gold}` | **A** (G1: 1 Small Potion por 5) |
| `shop-sell {items[{itemId, qty}]}` | `POST /api/game/shop/sell` → `{ok, soldKinds, soldCount, goldGained, gold}` | **A** (G1: 1 Bag of Pollen por 40) |
| `pokemon-sell {pokeIds}` | `POST /api/game/pokemon/sell` → `{sold, goldGained, gold}` | **A** (G2) |
| `joy-heal` | WS `joy-heal` → `{type: "joy-healed"}` sem campos, no mesmo instante; depois o servidor reenvia a lista de Pokémon | **A** (G4); aqui a lista vai como `poke-delta` dos curados (E) |
| `depot`, `depot-move {itemId, dir} \| {all: true}` | `GET/POST /api/game/depot[/move]` → `{inventory[…], depot[…]}`, itens `{id, name, icon, category, npcPrice, quantity}` | **A** (G4); só itens (bolas recusadas, A) |
| `poke-store {id}`, `poke-withdraw {id}` | WS `poke-store`, `poke-withdraw` | C (nomes); os campos são E |
| Mensagens de estado | `balls {catalog, counts, gold, selected}`, `inventory {items}`, `poke-delta {poke}` | A (formato gravado) |
| | `currency {gold}` | C (o tipo existe) |
| | `pokes-removed`, `evolved` | E |

## Evolução

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Destino e nível: `evolvesToId`/`evolveLevel` do `creatures.json` | A/C | snapshot; o guia diz "unlocks when the Pokémon reaches the target species' hunt level", e `evolveLevel` = nível da hunt do destino em 219/224 |
| Só em Cerulean; travada na hunt | C | "Only works in Cerulean — the button is locked during a hunt" |
| Dois caminhos: com pedras mantém o nível; sem pedras é grátis e volta ao Lv.1 | C | "Evolving with a stone keeps the level"; "free … goes back to Lv.1"; "No gold involved" |
| Quantidade: espécie de hunt ≥ 40 gasta 4 pedras no total, divididas por igual; até 39, 1 de cada | C | texto do guia |
| **Receita**: pedra do tipo principal da origem + pedra de cada tipo que a evolução ganha | **A** num caso (G3) / F no resto | G3 (15/11): Geodude (Pedra/Terra, hunt 1) Lv.40 → Graveler gastou **1 Rock Stone** — só o tipo principal, sem Ground, e 1 porque a hunt da origem é < 40, como a regra previa. `GET /evolve` = `{name, destId, destName, level, needLevel, canEvolve, stones[{itemId, name, icon, need, have}], hasStones, keepLevel, resetLevel, itemOnly}`; `POST /evolve` = `{ok, name, destId, level, usedStone, stonesSpent[{itemId, qty}]}` (a sim emite os mesmos campos; teste campo a campo). Ainda F: origem de hunt ≥ 40 (4 pedras divididas) e evolução que ganha tipo (Charmeleon → Charizard: Fire + Feather) |
| Tipo → pedra (Ghost → Darkness, Normal/Fairy → Heart) | F | nomes do `items.json` |
| Divisão que não fecha em 4 (3 pedras) → arredonda para cima | F | sem caso conhecido |
| Eevee: um destino por pedra, 1 pedra, nível 80; sem pedra → Vaporeon | C (sistema próprio) + B/F (ramos do canon) | o `creatures.json` só traz Vaporeon |
| IV e Quality mantidos; stats recalculados da base nova | C | "Growth/Quality are kept — stats are recalculated from the new species' base" |
| Golpes: a tabela da espécie nova pelo nível | C/A | a sim escolhe entre os golpes da espécie com nível ≤ o do Pokémon |
| HP depois de evoluir: mantém a fração | E | não gravado |
| Ditto não evolui; shiny tem caminho próprio (Shiny Stone) | C | não implementado (sem shiny no time offline) |
| A UI nunca volta ao Lv.1 sem escolha explícita | E | a janela pergunta, como a do original |

## Loja do Mark e ouro

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Bolas à venda e preços: Poké 5, Great 20, Super 50, Ultra 130; Idle, Golden Idle e Master fora | A | `balls.catalog` (`priceGold`, `buyable`) |
| Itens à venda: os com `priceGold` > 0 (hoje as 5 poções: 5, 10, 22, 55, 135) | C/A | a tela mostra "Preço: priceGold"; `items.json` |
| Venda de item ao NPC: `npcPrice`, só para item com `npcPrice > 0` fora das categorias heal/revive/stone (exceções: ids 205 e 206, Revive e Max Revive aposentados) | C | "Mark paga: npcPrice"; lista de venda do cliente filtra `iV = {heal, revive, stone}` com exceção `iK = {205, 206}`. Poções e pedras não são vendáveis. Tabela completa: `dados/relatorios/precos_npc.md` |
| Venda nunca acima do preço de compra | E (só proteção) | com a regra acima, nenhum item do catálogo chega no teto (0 de 370 vendáveis). No lote 1 a regra tratava poções como vendáveis; o `npcPrice` delas (50 > 5 de compra) não é preço de venda. Não era erro de importação: campos e unidade conferidos contra o snapshot cru, 0 divergências |
| Venda de Pokémon: só da BOX, nunca o inicial nem shiny; vale o `sellValue` da espécie, sem depender de nível, Quality ou IV | **A** (valor) / C (restrições) | G2: 2 Blastoise Lv.1 (Q 1,014 / IV 124 e Q 1,273 / IV 61) → 18000 cada = `valorVenda`; o `sellValue` que o servidor manda é o da espécie em 399/399 Pokémon (níveis 1 a 425). Restrições (C): o cliente lista só Pokémon fora do time, não inicial, não shiny, não anunciado, `sellValue > 0`. A recusa de shiny entrou na sim em 11/11 |
| Ouro vem só de vendas (o `field-kill` não traz ouro) | A | nenhum campo de ouro em 600+ abates |
| Ouro inicial 0 | E | o original dá 100 Small Potions e 100 Poké Balls (C); o saldo inicial não foi gravado |
| Loja, Nurse e depot só nas cidades com o NPC | A | `city-npcs`: Cerulean e Viridian têm `shop`, `nurse` e `pokedepot` |

## Nurse Joy

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Cura o time inteiro, de graça, sem recarga, na hora | **A** (G4) + C | `joy-healed` no mesmo instante do `joy-heal`, nenhuma mensagem de ouro; o Exeggutor ferido voltou a 13188/13188 |
| Só o time (não a BOX) | C/E | "heals your whole team" |

## Depot

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Time de no máximo 6 | C | "Your team only carries 6 — the rest rest here" |
| BOX com até 3000 Pokémon | A (conta VIP) / F (sem VIP) | `auto-helper.pokeCapacity` 3000 |
| Depot de itens com até 200 pilhas | E | G4 chegou a 89 pilhas sem aviso de limite (não contradiz) |
| Mover leva a pilha inteira; "guardar tudo" esvazia a BAG (inclusive poções); vinculada (Golden Idle) fica | **A** (G4) / A (`bound`) / E (vinculada fica) | G4: 24 Bag of Pollen numa vez, 15 Ancient Stone retiradas numa vez, "guardar tudo" levou 62 pilhas e deixou a BAG vazia |
| O inicial não vai para a BOX; depositar o líder passa a liderança ao inicial | E | regras do P04 mantidas |

| Bolas não ficam no depot | **A** (G4) | as bolas nunca aparecem no depot do original; aplicado em 13/11: o serviço recusa `ballId`, "guardar tudo" só leva itens, a tela do depot não lista bolas, e um save antigo com bolas no depot as devolve para a BAG ao carregar (`testes/test_migracao_depot_bolas.gd` 7/7) |

## VIP

Opção nas Configurações (⚙ na cidade), desligada por padrão (E). Ligada, a simulação soma a parcela `vip` = 50% da XP
base, no treinador e no Pokémon (A: `xpParts.vip`). Vai no save (campo opcional `vip`).

Fica de fora (não medido):
- os outros efeitos do VIP original no Auto-Helper e na capacidade;
- o "+50%" sobre streak, boost e evento (offline não tem).

## Lote 2 (11/11/2026; conferido com G6–G8 em 13/11): sessão, Modo Soneca, Streak Points, boosts e Tipo do Dia

Onde mora: `sim/servico_jogador.gd` (sessão, soneca, Streak, Tipo do Dia) e as parcelas novas em
`sim/simulacao_hunt.gd` (com nada ativo, a saída da sim é **idêntica byte a byte** à de antes: 20 min de Rhydon
conferidos de novo em 13/11). Cliente: `EstadoJogo` (`streak`, `soneca` no save), botão 💤 Zzz na hunt,
`painel_soneca.gd` (janela ao abrir a cidade) e `painel_streak.gd` (⚙ → Streak Points). Testes:
`testes/test_sim_lote2.gd` (36/36, puro; confere campo a campo com as respostas gravadas da G6 e da G7) e
`testes/test_ciclo_lote2.gd` (16/16, na cena com save isolado).

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Sem soneca, 15 min com o jogo fechado matam a sessão (a próxima hunt penaliza); voltar à mesma hunt pela cidade não penaliza | B-relatado (regra do usuário) | não gravado; implementado em `servico_jogador` (comando `sessao`) e usado ao carregar o save |
| Com soneca valendo (amostra completa), a sessão continua | E | dedução: o original mantém o jogador "na hunt" durante a soneca |
| Soneca: botão Zzz na hunt; a caçada segue 5 min (combate, XP, loot, Auto-Potion; **sem bolas**) | C / **A** (G6: `sampleMs` 300.551) | guia "Nap Mode"; a amostra gravada tem 32 abates de Geodude em 300.551 ms |
| Voltar antes dos 5 min cancela a soneca, **mas a parte que já rodou fica** | C / **A** (G6b) | voltou aos 91.981 ms: `offline-notice {notices: [{kind: "cancelled", reason: "reconnect", slug, ms, kills 16, xp 14.016, pokeXp 14.016, poke, id, at}]}` e `GET /offline` = `{report: null}`. Corrigido (antes, E: nada). A amostra guarda a linha do tempo (abates, XP, loot, poções por instante) e o cancelamento entrega até o tempo fora; loot e poções da parte rodada: E (a G6b não mostra a BAG) |
| **Taxa da coleta = XP da amostra ÷ 300 s nominais, com round**: `xp100 = round(xpSample/300 × s)`, `xp50 = round(xpSample/300 × s × 0,5)`, `estKills = round(kills/300 × s)`; s = do fim da amostra até agora, teto 24 h | **A** (G6) | 384 XP, 217 s → 278 / 139 / 23; na coleta, 227 s → 145 / 24: os cinco números batem exatamente (com `sampleMs` 300.551 e floor não batem). Corrigido: antes era floor |
| A coleta entrega **só** os 50% do tempo fora, no treinador e no Pokémon líder | **A** (G6) | o Venusaur tinha 81.113.299 antes e 81.113.444 depois = +145 = `xpGained` = `pokeXpGained`. Corrigido: antes a coleta somava também o XP da amostra |
| O XP, o loot e as poções da amostra entram **antes** da coleta | A (o XP já estava no Pokémon) / E (momento) | offline não há servidor rodando a amostra com o jogo fechado: ela é calculada no Zzz e entregue na 1ª leitura do relatório depois dos 5 min (mensagem `offline-sample`, E). A G6b não trouxe a soneca completa (só o cancelamento): o momento do Zzz e a BAG antes/depois seguem sem gravação |
| Se o time cai na amostra, ela para ali e o rendimento reflete | C | janela: "Your leader fainted during the nap" |
| Turbo (100%, 2💎) | C / A (`boostCost` 2) | recusado offline (E: sem diamantes) |
| Abates da amostra contam para o Streak (por espécie); os estimados não | F | não gravado |
| Formatos: `GET /offline` → `{report: {sample{slug, ghostId, startedAt, endedAt, sampleMs, itemsUsed, fainted, killsBySpecies, leaderId, kills, xpSample, pokeXpSample}, seconds, cappedAt (false ou o teto), estKills, xp50, xp100, pokeXp50, pokeXp100, boostCost, poke{id, speciesId, nickname, level}, pokeStatus}}`; `POST /offline {boost}` → `{xpGained, pokeXpGained, boosted, totalXp, level, seconds, estKills, poke, pokeApplied, pokeStatus, slug, diamonds}`; depois `{report: null}` | **A** (G6) | a sim emite os mesmos campos (sem `ghostId`); teste compara campo a campo |
| Streak Points: 1 ponto a cada 1000 abates totais; o n-ésimo ponto custa 25.000 × n; bônus 0,1% por ponto; os pontos nunca resetam | C / **A** (G7) | conta gravada: 19 pontos gastos → `nextCost` 500.000; gastou 1 em EXP → 525.000, ouro −500.000, `bonusPct.exp` 0,1 |
| Formato: `GET /streak` e `POST /streak/spend {track}` → `{totalKills, killsPerPoint, earned, spent, available, toNext, nextCost, canBuy, gold, tracks{exp, loot, shiny} (pontos), bonusPct{…}, kills[{speciesId, name, looktype, kills}]}` | **A** (G7) | a resposta do spend é o mesmo objeto. Corrigido: `tracks` eram objetos e faltavam `earned`, `canBuy`, `gold`, `bonusPct` e a lista por espécie (agora no save, `streak.bySpecies`) |
| Trilha EXP: parcela `streak` = **floor**(base × 0,1% × pontos), só no treinador | **A** (G7) / A (o `pokeXp.parts` não tem chave streak) | Blastoise base 3848 com 1 ponto: `streak` 3 (round daria 4); 0 antes do spend. Corrigido: antes era round |
| Trilha Loot: +0,1% de chance de uma rolagem extra inteira de drop por ponto (100% = 1 extra garantida, excesso → próxima) | C | texto da janela |
| Trilha Shiny | C | guardada sem efeito (E: sem shiny no time offline) |
| Boosts `xp` +50% treinador, `pokexp` +50% Pokémon, `loot` +40% de chance, `capture` dobra a chance | C | guia "Boost"; formato `{key, until, pct}` (A) |
| Parcela de boost = base × pct | F | nunca vista ≠ 0 |
| Fonte de boosts offline | C/E | o Daily Gift (abaixo) dá XP Boost +50% e Loot Boost +20% por 1 h; os boosts agora vão no save |
| Tipo do Dia: +20% de XP e +20% de loot nos selvagens do tipo; o dia vira às 03:00 UTC | A (formato, texto e horário) | — |
| Parcela `typeDay` = **floor**(base × 20%) | **A** (G8) | Tyranitar base 6008 → 1201 em 61/61 abates (round daria 1202). Corrigido: antes era round |
| Loot no tipo do dia = chance de cada drop **× 1,4** (limite 1) | **A** (G8 × G10) | mesma hunt (Tyranitar): dia Sombrio (G8, 61 abates) 148 drops — esperado 146,3 com ×1,4 (z 0,2), 125,4 com ×1,2 (z 2,8: rejeitado); dia Veneno (G10, 91 abates) 161 × 155,9 pela tabela (controle: 1,03). ×1,44 (= 1,2²) também cabe. `tipo_do_dia_loot` 1,4 (era 1,2) |
| Rotação do Tipo do Dia | E (âncoras A) | quatro dias gravados: 09/11 Dragão, 10/11 Inseto, 13/11 Sombrio, **15/11 Veneno** (G10; a rotação anterior previa Elétrico: corrigida); os outros 14 continuam E. Nome: "Veneno" (A; estava "Venenoso") |

## G5 e G7 (13/11/2026): Daily Gift, Quests & Tasks, Daily Kill e Daily Catch

Onde mora: `sim/servico_diarias.gd` (puro; dados gravados em `dados/fase4/`, gerados por
`ferramentas/gravador/extrair_fase4.py` a partir das respostas REST da G5/G7 — não editar à mão). Cliente:
`EstadoJogo.diarias_tratar` (estado no save: `diarias`, `boosts`), `painel_diarias.gd` (⚙ → Quests, Tasks & Dailys,
4 abas), e a hunt (`caca_sim.gd`) avisa cada abate e cada captura. Testes: `testes/test_sim_diarias.gd` (36/36, puro) e
`testes/test_ciclo_diarias.gd` (14/14, na cena com save isolado).

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Daily Gift: calendário de **28 prêmios** do mês (bolas, poções, Idle Balls VIP, XP Boost +50% 1 h, Loot Boost +20% 1 h) | **A** (G7) | `GET /api/game/daily`: `{ym, vip, total 28, nextDay, canClaim, claimedToday, blockedByVip, rewards[{day, label, icon, qty, tag, kind, locked, claimed, current}]}`; a tabela inteira em `dados/fase4/daily_gift.json` |
| Um prêmio por dia, em sequência (`nextDay` = coletados + 1); dia perdido não pula; recomeça no mês novo | **A** (G7: 13 coletados em 13/11; G9: `nextDay` 13 em 15/11, coletou o 13) / C / E (mês de Brasília) | — |
| Dia VIP bloqueia quem não é VIP (`blockedByVip`) | C ("Today's reward is VIP-exclusive — subscribe to VIP") | o calendário fica parado até o VIP (C: o botão vira "Subscribe to VIP") |
| Boost do Daily Gift ativa na hora por 1 h | C ("{{label}} activated for 1h!") | o mesmo boost ativo soma 1 h (E) |
| Bolas, itens e boosts vão direto para a BAG/boosts | E | no original vão para o Gift Center (A, G9: `toGiftCenter: true`; `GET /gifts` lista `{id, kind, label, icon, grantedBy, createdAt}` e o boost fica lá até ser resgatado em Mensagens). POST /daily (A, G9) = o estado + `claimed {day, kind, refId, qty, label, icon, tag}` + `toGiftCenter`: a sim responde igual, com `toGiftCenter: false` |
| O mesmo calendário todo mês | E | só novembro foi gravado |
| Quests & Tasks: **124 tarefas em 43 cidades**, cada uma `{id, npc, city, goals[{pokeId, name, qty, kind: kill/capture/deliver}], xp, cash}` | **A** (G5) | `GET /api/game/tasks` (`dados/fase4/tarefas.json`, sem o progresso da conta que gravou) |
| Progresso: `goalProgress[{…, have, done, looktype, type1, type2?}]`, `have` limitado a `qty`; `complete` quando todos os objetivos fecham | A (formato; Rattata 15/15 numa conta com 680 mil abates) | — |
| De onde vem o `have` | E | kill/capture: contagem por espécie desde que o contador existe no save (o original mostra o do servidor); deliver: o que está na BAG agora |
| Entregar: `POST /tasks/claim {taskId}` → `{ok, taskId, xp, cash, totalXp, level, leveledUp}`; XP no treinador, `cash` em ouro | **A** (G9: yvette 1350/0, douglas298b 0/2700 — entrega —, george299b 3000/450, todos iguais ao `tasks.json`) | o consumo dos itens da entrega não aparece (nenhum `inventory` depois dos claims): E |
| Cada tarefa paga uma vez; a de entrega consome os itens | E | — |
| Daily Kill: 3 opções por dia, uma escolha (`pick {idx}`), sem reroll offline (`rerollMax` 0), trava abaixo do nível 25 (`minLevel`) | **A** (G5) | `GET/POST /api/game/daily-kill[/pick]` (formato em `dados/fase4/daily_kill.json`) |
| XP da opção = **floor(qtd × xpAbate × 8/3)** | **A** (G5) | 3/3: Furious Pidgeot 798 × 13508 → 28.745.024; Ancient Marowak 1497 × 13508 → 53.923.936; Politoed 1199 × 2948 → 9.425.738 |
| Prêmio do tier hard: 6 Devoted Token + 2 Bronze Dimensional Key = 2 × os itens do tier hard do Daily Catch | A (hard) / E (os outros tiers, mesma regra) | — |
| `have` conta só depois do pick e só a espécie escolhida | A (0 logo depois do pick) / C (a janela soma o `have` da escolhida) | — |
| Coletar: `POST /daily-kill/claim` → `{state, payout{xp, items[{label}], totalXp, level, leveledUp}}` | C | resposta não gravada |
| **Geração das opções** | E | o original sorteia no servidor (não visível): tier pelo nível do treinador na tabela do Daily Catch (acima de 199, hard); espécies sorteadas da lista do tier (das 6 opções gravadas — G5 e G9 — 4 estão na lista do hard; Furious Pidgeot e Ancient Marowak não); qtd por tier: superEasy 100–300, easy 200–600, medium 400–1200, hard 500–1500 (A só no hard: 751–1497); semente = dia. G9: mais 3 opções com xp = floor(qtd × xpAbate × 8/3) exato (Magcargo, Larvitar, Jumpluff) e o `have` contando só depois do pick (8 → 11 abates de Larvitar) |
| Virada do dia às 03:00 UTC (`resetAt`), `dayKey` "AAAA-MM-DD" | **A** (G5) | `resetAt` 1794625200000 em 13/11 |
| Daily Catch: 2 capturas premiadas por dia; faixas superEasy 25–59, easy 60–79, medium 80–149, hard 150–199, com a lista de espécies e os itens de cada uma; só as faixas do nível aparecem ("Faixas liberadas") | **A** (G5) / C | `GET /api/game/daily-catch` (`dados/fase4/daily_catch.json`) |
| Capturar espécie da tabela preenche o próximo slot e paga na hora | C ("Slot livre — capture um Pokémon da tabela") | — |
| XP da captura premiada = floor(xpAbate × 8/3 × m), m múltiplo de 0,5 | A (forma: 4/4) / F (m sorteado entre 1,5 e 18) | Larvitar (548) m 10 e 14 (G5); Arbok (968, easy) m **1,5** no slot 1 e **18** no slot 2 (G9): a regra "m pelo slot" de 13/11 caiu. O que decide m não aparece (as duas capturas do Arbok tinham Q 1,43 e 1,49) |
| Itens da faixa a cada captura premiada; Newbie Gift (`itemId` −1) não entra | F / E | o `rewardText` mostra o dobro da quantidade (2 slots: F) |
| Faixa de uma espécie que está em mais de uma | E | a mais alta liberada |
| `dailys-summary` → `{resetAt, kill{locked, picked, done, claimed, target, have, qty}, catch{used, total}, tasks{ready}}` | **A** (G5) | — |

## Lote 3 (15/11/2026, começo): itens de uso, breeding e coleção

Onde mora: `sim/servico_itens.gd` (Rare Candy e berries, puro) e o efeito das berries em `sim/simulacao_hunt.gd`
(sem berry ativa, a saída da sim é idêntica). Cliente: `EstadoJogo.usar_item` (campo `itens_uso` no save),
`painel_itens_uso.gd` (⚙ → Usar itens) e a hunt recebe as berries ativas (`cfg.berries`). Testes:
`testes/test_sim_itens.gd` (18/18, puro, inclusive o efeito no combate) e `testes/test_ciclo_itens.gd` (6/6, na cena).

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Rare Candy (90124): +1 nível na hora, com exatamente o XP que falta para o próximo | C ("goes up exactly 1 level right away") / A (descrição do items.json) | — |
| Só no time; nível ≤ 100; no máximo 10 por Pokémon | C ("Pokémon in the depot, above level 100, or already at the limit cannot receive it"; "at most 10") | contagem por Pokémon no save (`itens_uso.candy`) |
| Resposta do uso | E | não gravada (`candy-used {pokeId, xpGained, level, used, max}`) |
| Berries: escolhe um Pokémon do time, consumida na hora, efeito por 30 min | C ("It is consumed right away and the effect lasts 30 minutes"; "Used on 1 Pokémon in your team") | — |
| A mesma berry não acumula ("já ativa (N min)"); berries diferentes valem juntas | C ("Identical berries do not stack"; `berryActiveRow`) / E (diferentes somam) | — |
| Efeito e % de cada berry: os da descrição do items.json — 38 reduzem o dano de golpes de um tipo (5% e 10%, "FORTEMENTE"), 2 aumentam a cura das poções (+40% e +80%) | **A** (dado do servidor, 40/40 lidas) | "Noturno" = DARK; "Neutro" = golpes neutros dos bosses (C) |
| Redução: dano recebido × (1 − pct), arredondado, piso 1; cura: poção × (1 + pct), ainda limitada ao que falta | F (aplicação) | teste: berry de Pedra 10% → dano recebido 0,9× do Stone Edge; cura +80% → Hyper passa de 1000 |
| ~~O itens.json gerado perde os acentos~~ — **errado** (15/11): o arquivo está em UTF-8 correto; os "�" vinham do console do Windows (cp1252) ao imprimir. O importador agora imprime em UTF-8 e a regeneração não muda nada | D | o leitor compara só as letras a–z, então funciona com e sem acento |

Não implementado ainda, com o que já se sabe (para não inventar números do servidor):

| Sistema | O que o cliente/os dados mostram | Falta (A) |
| --- | --- | --- |
| Held items (64, tiers 1–5) e Held Machine | C: troca de Devoted Tokens por 1 held aleatório de um tier ("Trade {{n}}× {{token}} for 1 random held"); `use-held`, `held-replace-confirm`; "Random Held T5" abre 1 held tier 5 | efeito de cada held (X-Attack, X-Defense, X-Experience, X-Boost, X-Lucky…): nem o items.json nem os textos trazem números; custo da máquina e pool por tier |
| TMs (19 discos) e TM Researcher | C: "Trade {{n}}× TM Disk Piece for one disk"; AoE TM: "all of the Pokémon's Normal moves start splashing"; Ditto não usa TM | o que o disco elemental muda no golpe (tipo? poder?), nº de peças |
| Borage Flower | C/A: 2 h de chance de shiny muito maior | sem shiny no jogo offline (E): fica guardada |
| Breeding | C: pais da mesma espécie, da BOX, consumidos; filho = qualidade do melhor pai + Δ; com feromônios Δ +0,15 a +0,30, sem feromônios ~20× menor; IV por stat: copia o do pai de maior qualidade com uma chance (`{{pct}}%`), senão sorteia 1..32; "dobrar as pedras" dá 5% de +1 IV; um pai shiny → filho shiny e sem regra de diferença de qualidade; dois normais nunca dão shiny; ovo choca com abates nas hunts; inicial e Ditto não cruzam; libera num nível do treinador | o `{{pct}}` da herança, a diferença máxima de qualidade, o teto, a taxa em ouro, as pedras por elemento, os abates para chocar e o nível de liberação (todos vêm do servidor em `/api/game/breeding`) |
| Ditto / Shiny Ditto | C: entra como Ditto nível 1 com stats fixos (IV 15/15/15/15/14/15, Q 1,4; shiny IV 20…/19, Q 2,0); transforma por 12 h (shiny: permanente); −25% em HP, Atk, Def, SpA, SpD (shiny: −25%/−20%) | como se obtém offline (no original é item da loja de diamantes) |
| Pokédex | C: "Claim +25% XP bonus" depois de derrotar N da espécie; bônus de captura pela soma de derrotas | o N por espécie e o efeito exato do +25% (`/api/game/pokedex`) |
| Golden Stars (Poke Slot Machine) | **A** (G9): slot com estrela ativa `{speciesId, bonusType (exp, critDamage…), pct (10, 13), rarity, startedAt, expiresAt}` com duração de **6 h**; rolagem grátis a cada **12 h** (freeRollAt); 9 candidatos por rolagem; slots 2 e 3 travados (10.000.000 de ouro, VIP, ou 5 cartas por 24 h); C: o bônus só vale ao interagir com a espécie sorteada | a tabela de bônus × raridade × pct e a chance de cada um |
| Pokécards | A: `pokecards.json` (sets e cartas, no snapshot); C: "Poke Card Pack" abre 1 carta aleatória para o álbum | a chance de cada carta e o efeito do álbum |

## Lote 4 (15/11/2026, começo): ginásios e bosses, profissões, invasão

Onde mora: `sim/servico_ginasios.gd` (insígnias e catálogo de bosses), `sim/servico_invasao.gd` (calendário) e a parcela
`gym` em `sim/simulacao_hunt.gd` (com 0 insígnias, a saída da sim é idêntica). Save: campo opcional `ginasios`; a hunt
recebe `cfg.insignias`. Teste: `testes/test_sim_mundo.gd` (14/14, puro).

| Sistema | O que já entrou (fonte) | O que falta e por quê |
| --- | --- | --- |
| **Ginásios** | Insígnia dura 48 h e vencer de novo renova; cada insígnia ATIVA dá +1% de XP e +1% de chance de uma rolagem extra de drop; 18 ginásios, 8 em Kanto e 10 na outra região (C, janela Gym Rewards). Na hunt: parcela `gym` = floor(base × 1% × insígnias) no treinador e no Pokémon (a chave existe no `xpParts`, A; floor e o Pokémon, F) e +1% de rolagem extra por insígnia (mesmo mecanismo do Streak Loot, C). Ginásios conhecidos (A, `gym-global`): spikemuth DARK (Piers, NPC), cerulean WATER, mahogany ICE (Pryce, NPC), pewter ROCK | A lista dos 18 com os líderes e os times, as regras da luta (time livre no modo insígnia, C) e as recompensas vêm de `/api/game/gyms` (não gravado). Sem a luta, a insígnia entra por `insignia-ganha` (E) e o jogo ainda não tem como ganhá-la. Liderança e pagamento diário: online |
| **Bosses** | Catálogo (A, `bossCatalog.json`): 87 bosses com nome, categoria, nível e nomes dos drops; 85 dos 258 drops casam com itens do catálogo (fichas e baús não estão no items.json). C: entrada com ficha; Auto Boss repete lutas até acabar a fila ou as fichas, perde a ficha se o time cair, só fora de hunt; formato `auto-boss {active, bossKey, total, wins, losses, loot, fee, spent, elapsedMs}` (A, G10, inativo). Altar: sacrifica uma Shiny Card para enfrentar o shiny lendário (C) | HP, golpes e rounds da luta, custo em fichas, chance de cada drop: `/api/game/boss/*` e as mensagens da luta (não gravados). Altar depende de shiny (ausente offline, E) |
| **Profissões** | C: Botânico (ervas das hunts → berries; talentos por rank: berry de tipo, neutra, de cura; "Lasts 30 minutes", "Identical berries do not stack"), Prestige Trainer (foto automática de shiny → Rare Pokémon Picture, item de rank), Cientista e Pesquisador "em breve"; ranks E, D, C, B, A, S; bônus de captura direta por rank até ×1,18 no S; bônus "mentor" de XP quando o treinador está mais de N níveis acima do Pokémon (é a parcela `mentor` vista na conta B, A). A (c5): `profession-photo {ok, msg, slot, row, col, speciesId, itemName, pictures}` — 2 de 5 fotos deram certo. Pesca (C): habilidade por nível, faixas bloqueadas acima da habilidade, faixa menor dá 50% do progresso, recarga | N e % do mentor, % por rank, custo das receitas do Botânico e chance das ervas, chance da foto, tabela da pesca: servidor (`/api/game/professions/*`, `fishing*`). Nada implementado: sem esses números não há regra para escrever |
| **Invasão** | Calendário (A, 8 invasões de 09/11 a 15/11): a cada 2 h nas horas UTC ímpares; entrada até hh:10, fim às hh:30; mensagens `invasion-state`, `invasion-energy` (máx. 10) e `invasion-announce` (texto com `{nome}` literal) no formato gravado; entrada vista aberta às hh−1:58 e hh:00, fechada de hh:08:48 em diante; `live` falso 71 s antes do fim (bordas exatas F) | A luta (ondas? chefes? prêmio por energia?): nenhuma gravação de dentro da invasão |

## O que ainda pede evidência do original (gravador v1.2)

Feitas: G1, G2, G4 (11/11); G5, G7, G8 (13/11); G3, G9, G10 (15/11). G6 e G6b parciais: só a volta e o cancelamento.

**Pendentes da fase 4:**

**G6c — soneca completa, do Zzz à coleta (≥ 10 min fora).** A G6b só trouxe o cancelamento.
1. Numa hunt, abra a BAG e espere 3 s; volte à hunt.
2. Clique 💤 Zzz e deixe o gravador ligado até a página sair.
3. Feche o jogo por 10 min. Reabra com o gravador já ligado.
4. **Antes** de coletar, abra a BAG (3 s). Colete (sem turbo). Abra a BAG de novo (3 s).

Mostra a mensagem do Zzz e se o loot e as poções da amostra já estão na BAG antes da coleta (hoje E).

**G11 — dano em nível baixo, com os stats do selvagem (10 min)** (já combinada). Hunt do Geodude ou do Rattata, time de
nível 1–4 (Larvitar ou Geodude), Auto-Catch com Super Ball; depois de cada captura, abra o capturado em My Pokes (2 s).
Separa "piso 3 no ataque do aliado" de "stats do nível 2" e explica a faixa estreita do dano real no nível 1.

**Lote 4 (no máximo 4; ginásios, bosses, profissões e invasão):**

**GB1 — ginásio (5 min).** Abra a janela de Ginásios no modo Insígnia e espere 5 s; clique em 3 ginásios (2 s cada);
desafie um líder que o time vença e espere a luta acabar; abra a janela de novo.
Traz `/api/game/gyms` (os 18, líderes, times, níveis), as mensagens da luta e a resposta da insígnia.

**BS1 — boss (5 min).** Abra Bosses e espere 5 s; enfrente 1 boss (o de entrada grátis, se houver) até o fim; abra a BAG.
Traz HP, golpes e rounds do boss, a ficha gasta e o loot.

**PR1 — profissões e pesca (6 min).** Abra Professions e espere 5 s em cada aba (rank, talentos do Botânico); pesque
3 min na faixa da sua habilidade.
Traz o N e o % do mentor, o bônus por rank, as receitas do Botânico e as taxas da pesca.

**IV1 — invasão (até 30 min, numa hora UTC ímpar: 14:00, 16:00, 18:00… de Brasília).** Entre na invasão às hh:00–hh:08
e grave até o fim.
Traz a luta inteira (inimigos, ondas, energia, prêmio).

**Lote 3 (no máximo 4):**

**L1 — held items (8 min).**
1. Abra a Held Machine e espere 5 s (não troque, se não quiser gastar tokens).
2. Equipe um held conhecido (X-Attack ou X-Defense) no líder: abra o Pokémon antes e depois (2 s cada).
3. Grave 5 min numa hunt conhecida (rhydon ou geodude) com o held equipado.

Traz o formato do `use-held`, o pool da máquina e o efeito no dano (comparado com as gravações da mesma hunt sem held).

**L2 — breeding (5 min).**
1. Abra o Breeding Center e espere 5 s.
2. Escolha dois Pokémon da mesma espécie na BOX (pode cancelar antes de criar) e espere 5 s com o par escolhido.
3. Se puder gastar, crie 1 ovo e abra o incubador; quando chocar, abra o filhote em My Pokes.

Traz `/api/game/breeding`: a chance da herança de IV, a diferença máxima de qualidade, o teto, a taxa, as pedras, os
abates para chocar e o nível de liberação.

**L3 — Pokédex, Golden Stars e Pokécards (4 min).**
1. Abra a Pokédex, abra o detalhe de 2 espécies (uma com o bônus disponível) e resgate um "+25% XP", se houver.
2. Abra a Poke Slot Machine e espere 5 s (a rolagem grátis, se estiver pronta).
3. Se tiver um Poke Card Pack, abra-o e abra o álbum.

Traz o N de derrotas e o efeito do bônus da Pokédex, a tabela de bônus das Golden Stars e o formato das cartas.

**L4 — TM e Rare Candy (4 min).**
1. Abra o TM Researcher e espere 5 s.
2. Se tiver um disco, use-o num Pokémon e abra o Pokémon antes e depois (2 s cada).
3. Use 1 Rare Candy num Pokémon do time e 1 berry (qualquer), com o Pokémon aberto antes e depois.

Traz o efeito do TM no golpe e as respostas do `use-candy` e do `use-berry` (hoje E).
