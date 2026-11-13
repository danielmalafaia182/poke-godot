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
| **Receita**: pedra do tipo principal da origem + pedra de cada tipo que a evolução ganha | **F** | bate com os dois exemplos do guia (Ivysaur = 4× Leaf; Charmeleon = 2× Fire + 2× Feather); a receita real vem do servidor |
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
| Voltar antes dos 5 min cancela a soneca (sessão nova, sem farm offline) | C | guia; o que o original faz com a amostra parcial não foi gravado → offline não entrega nada dela (E) |
| **Taxa da coleta = XP da amostra ÷ 300 s nominais, com round**: `xp100 = round(xpSample/300 × s)`, `xp50 = round(xpSample/300 × s × 0,5)`, `estKills = round(kills/300 × s)`; s = do fim da amostra até agora, teto 24 h | **A** (G6) | 384 XP, 217 s → 278 / 139 / 23; na coleta, 227 s → 145 / 24: os cinco números batem exatamente (com `sampleMs` 300.551 e floor não batem). Corrigido: antes era floor |
| A coleta entrega **só** os 50% do tempo fora, no treinador e no Pokémon líder | **A** (G6) | o Venusaur tinha 81.113.299 antes e 81.113.444 depois = +145 = `xpGained` = `pokeXpGained`. Corrigido: antes a coleta somava também o XP da amostra |
| O XP, o loot e as poções da amostra entram **antes** da coleta | A (o XP já estava no Pokémon) / E (momento) | offline não há servidor rodando a amostra com o jogo fechado: ela é calculada no Zzz e entregue na 1ª leitura do relatório depois dos 5 min (mensagem `offline-sample`, E) |
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
| Loot no tipo do dia = chance × 1,2 | F (indício contra) | G8: 148 drops em 61 abates contra 104,5 pela tabela (×1,42; ×1,2 esperaria 125,4, 2,9σ abaixo do observado); controle G5 (sem tipo do dia): ×1,03. Uma gravação só: mantido ×1,2 e registrado o indício de ×1,4 (pede G10) |
| Rotação do Tipo do Dia | E (âncoras A) | três dias gravados: 09/11 Dragão, 10/11 Inseto, 13/11 **Sombrio** (a rotação antiga previa Planta: corrigida, Sombrio entra na 5ª posição; os outros 15 continuam E) |

## G5 e G7 (13/11/2026): Daily Gift, Quests & Tasks, Daily Kill e Daily Catch

Onde mora: `sim/servico_diarias.gd` (puro; dados gravados em `dados/fase4/`, gerados por
`ferramentas/gravador/extrair_fase4.py` a partir das respostas REST da G5/G7 — não editar à mão). Cliente:
`EstadoJogo.diarias_tratar` (estado no save: `diarias`, `boosts`), `painel_diarias.gd` (⚙ → Quests, Tasks & Dailys,
4 abas), e a hunt (`caca_sim.gd`) avisa cada abate e cada captura. Testes: `testes/test_sim_diarias.gd` (36/36, puro) e
`testes/test_ciclo_diarias.gd` (14/14, na cena com save isolado).

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Daily Gift: calendário de **28 prêmios** do mês (bolas, poções, Idle Balls VIP, XP Boost +50% 1 h, Loot Boost +20% 1 h) | **A** (G7) | `GET /api/game/daily`: `{ym, vip, total 28, nextDay, canClaim, claimedToday, blockedByVip, rewards[{day, label, icon, qty, tag, kind, locked, claimed, current}]}`; a tabela inteira em `dados/fase4/daily_gift.json` |
| Um prêmio por dia, em sequência (`nextDay` = coletados + 1); recomeça no mês novo | A (13 coletados em 13/11 → `nextDay` 14) / C ("Come back every day and collect the month's 28 rewards") / E (mês de Brasília; dia perdido não pula) | — |
| Dia VIP bloqueia quem não é VIP (`blockedByVip`) | C ("Today's reward is VIP-exclusive — subscribe to VIP") | o calendário fica parado até o VIP (C: o botão vira "Subscribe to VIP") |
| Boost do Daily Gift ativa na hora por 1 h | C ("{{label}} activated for 1h!") | o mesmo boost ativo soma 1 h (E) |
| Bolas e itens vão direto para a BAG | E | no original vão para o Gift Center (C: "sent to the Gift Center! Claim it in 📨 Messages"); a resposta do POST não foi gravada (C: devolve o estado e `claimed.label`) |
| O mesmo calendário todo mês | E | só novembro foi gravado |
| Quests & Tasks: **124 tarefas em 43 cidades**, cada uma `{id, npc, city, goals[{pokeId, name, qty, kind: kill/capture/deliver}], xp, cash}` | **A** (G5) | `GET /api/game/tasks` (`dados/fase4/tarefas.json`, sem o progresso da conta que gravou) |
| Progresso: `goalProgress[{…, have, done, looktype, type1, type2?}]`, `have` limitado a `qty`; `complete` quando todos os objetivos fecham | A (formato; Rattata 15/15 numa conta com 680 mil abates) | — |
| De onde vem o `have` | E | kill/capture: contagem por espécie desde que o contador existe no save (o original mostra o do servidor); deliver: o que está na BAG agora |
| Entregar: `POST /tasks/claim {taskId}` → `{xp, cash, totalXp, level, leveledUp}`; XP no treinador, `cash` em ouro | C | resposta não gravada |
| Cada tarefa paga uma vez; a de entrega consome os itens | E | — |
| Daily Kill: 3 opções por dia, uma escolha (`pick {idx}`), sem reroll offline (`rerollMax` 0), trava abaixo do nível 25 (`minLevel`) | **A** (G5) | `GET/POST /api/game/daily-kill[/pick]` (formato em `dados/fase4/daily_kill.json`) |
| XP da opção = **floor(qtd × xpAbate × 8/3)** | **A** (G5) | 3/3: Furious Pidgeot 798 × 13508 → 28.745.024; Ancient Marowak 1497 × 13508 → 53.923.936; Politoed 1199 × 2948 → 9.425.738 |
| Prêmio do tier hard: 6 Devoted Token + 2 Bronze Dimensional Key = 2 × os itens do tier hard do Daily Catch | A (hard) / E (os outros tiers, mesma regra) | — |
| `have` conta só depois do pick e só a espécie escolhida | A (0 logo depois do pick) / C (a janela soma o `have` da escolhida) | — |
| Coletar: `POST /daily-kill/claim` → `{state, payout{xp, items[{label}], totalXp, level, leveledUp}}` | C | resposta não gravada |
| **Geração das opções** | E | o original sorteia no servidor (não visível): tier pelo nível do treinador na tabela do Daily Catch (acima de 199, hard); espécies sorteadas da lista do tier (as gravadas — Furious Pidgeot, Ancient Marowak — **não** estão nela: a lista real é outra, desconhecida); qtd por tier: superEasy 100–300, easy 200–600, medium 400–1200, hard 500–1500 (A só no hard: 798–1497); semente = dia, então o dia sorteia sempre o mesmo |
| Virada do dia às 03:00 UTC (`resetAt`), `dayKey` "AAAA-MM-DD" | **A** (G5) | `resetAt` 1794625200000 em 13/11 |
| Daily Catch: 2 capturas premiadas por dia; faixas superEasy 25–59, easy 60–79, medium 80–149, hard 150–199, com a lista de espécies e os itens de cada uma; só as faixas do nível aparecem ("Faixas liberadas") | **A** (G5) / C | `GET /api/game/daily-catch` (`dados/fase4/daily_catch.json`) |
| Capturar espécie da tabela preenche o próximo slot e paga na hora | C ("Slot livre — capture um Pokémon da tabela") | — |
| XP do slot = floor(xpAbate × 8/3 × (10 + 4 × (slot − 1))), limitado a [xpMin, xpMax] da faixa | **F** | os dois casos gravados: Larvitar (548) → 14.613 no slot 1 e 20.458 no slot 2 |
| Itens da faixa a cada captura premiada; Newbie Gift (`itemId` −1) não entra | F / E | o `rewardText` mostra o dobro da quantidade (2 slots: F) |
| Faixa de uma espécie que está em mais de uma | E | a mais alta liberada |
| `dailys-summary` → `{resetAt, kill{locked, picked, done, claimed, target, have, qty}, catch{used, total}, tasks{ready}}` | **A** (G5) | — |

## O que ainda pede evidência do original (gravador v1.2; no máximo 5)

**G3 — evolução com pedras (3 min), ainda pendente.** Com um Pokémon que já pode evoluir e com pedras na BAG:
1. Abra a janela de evolução (botão ⬆ no time) e espere 5 s.
2. Evolua com pedras.
3. Só abra (sem evoluir) a janela de uma espécie de dois tipos (Ivysaur, Charmeleon ou Geodude) e espere 5 s.

As respostas de `GET /api/game/evolve` trazem a receita real (`stones`): fecham ou derrubam a hipótese F.

**G6b — soneca do começo ao fim (≥ 10 min fora) e o cancelamento.** A G6 só tem a volta (10 s).
1. Numa hunt, abra o inventário (BAG) e espere 3 s; volte à hunt; clique 💤 Zzz e deixe gravar até a página sair.
2. Feche o jogo por 10 min. Reabra com o gravador já ligado; **antes** de coletar, abra a BAG (3 s).
3. Colete (sem turbo) e abra a BAG de novo (3 s).
4. Outra vez: Zzz, feche por **2 min**, reabra, abra a BAG.

Mostra a mensagem do Zzz, se loot/poções da amostra já estão na BAG antes da coleta (A: o XP estava) e o que o
cancelamento faz com a amostra parcial (hoje E: nada).

**G9 — resgates (5 min, no dia seguinte à G7).**
1. Daily Gift: colete o prêmio do dia.
2. Daily Kill: se a missão estiver completa, colete; senão escolha uma e grave a janela.
3. Quests & Tasks: entregue uma tarefa completa (de preferência uma de entrega de item).
4. Daily Catch: capture **uma** espécie da tabela de uma faixa diferente de hard (ex.: Bellsprout em superEasy) e
   abra a janela.

Traz as respostas dos POST (formato de `claimed`, `payout`, `tasks/claim`), confere o Gift Center e testa o XP do
Daily Catch (F: 10 × / 14 × pelo slot) com outra espécie e outra faixa.

**G10 — Tipo do Dia, controle de loot (10 min).** Na **mesma hunt da G8** (Tyranitar), num dia em que o tipo do dia
**não** é Sombrio, grave 10 min com o mesmo time e as mesmas configurações. Anote o tipo do dia mostrado.

Separa ×1,2 de ×1,4 no loot (G8 deu ×1,42) e acrescenta um dia à rotação.

**G11 — dano em nível baixo, com os stats do selvagem (10 min).** Na hunt do Geodude (ou Rattata), com um time de
nível 1–4 (Larvitar ou Geodude), Auto-Catch ligado com Super Ball. Depois de cada captura, abra o Pokémon capturado
em My Pokes (2 s).

O `poke-delta` do capturado traz stats/IV/Quality exatos de um selvagem de nível 1–4 que apanhou do time: fecha o
resíduo do item 1 (o erro está no limite de baixo da faixa de stat do selvagem de nível baixo).

**G1, G2, G4 — feitas (11/11).** G1: compra e venda com o formato das respostas (A); poções e pedras não aparecem
para venda (C). G2: valor = `sellValue` da espécie (A). G4: Nurse Joy `joy-healed` vazio e regras do depot (A).
**G5, G7, G8 — feitas (13/11); G6 parcial (só a volta).**
