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

## Lote 2 (11/11/2026): sessão, Modo Soneca, Streak Points, boosts e Tipo do Dia

Onde mora: `sim/servico_jogador.gd` (sessão, soneca, Streak, Tipo do Dia) e as parcelas novas em
`sim/simulacao_hunt.gd` (com nada ativo, a saída da sim é **idêntica byte a byte** à de antes: 20 min de Rhydon
conferidos). Cliente: `EstadoJogo` (`streak`, `soneca` no save), botão 💤 Zzz na hunt, `painel_soneca.gd` (coleta ao
abrir a cidade) e `painel_streak.gd` (⚙ → Streak Points). Testes: `testes/test_sim_lote2.gd` (28/28, puro) e
`testes/test_ciclo_lote2.gd` (14/14, na cena com save isolado).

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Sem soneca, 15 min com o jogo fechado matam a sessão (a próxima hunt penaliza); voltar à mesma hunt pela cidade não penaliza | B-relatado (regra do usuário) | não gravado; implementado em `servico_jogador` (comando `sessao`) e usado ao carregar o save |
| Com soneca valendo (amostra completa), a sessão continua | E | dedução: o original mantém o jogador "na hunt" durante a soneca |
| Soneca: botão Zzz na hunt; a caçada segue 5 min (combate, XP, loot, Auto-Potion; **sem bolas**) | C | guia "Nap Mode" |
| Voltar antes dos 5 min cancela a soneca (sessão nova, sem farm offline) | C | guia |
| Coleta: tempo do fim da soneca até o login, teto de 24 h; rende **50% da taxa de XP da amostra**, no treinador **e** no Pokémon que lutava | C | guia e janela "While you were away" (`xp50`, `seconds`, `cappedAt`, `estKills`) |
| A amostra em si (XP, loot e poções dos 5 min) vale inteira | C | "the hunt continues on the server" (aconteceu de verdade); aplicada na coleta (E: momento) |
| Se o time cai na amostra, ela para ali e o rendimento reflete | C | janela: "Your leader fainted during the nap" |
| Turbo (100%, 2💎) | C | recusado offline (E: sem diamantes) |
| Abates da amostra contam para o Streak; os estimados não | F | não gravado |
| Mensagens: `sleep-mode` → `sleep-ok {ghost: true}`; `GET /offline` → `{report: {sample{slug, kills, fainted, itemsUsed}, seconds, cappedAt, estKills, xp50, xp100, boostCost}}`; `POST /offline {boost}` | C | campos lidos pelo cliente; a resposta da coleta (`offline-claimed`) é E |
| Streak Points: 1 ponto a cada 1000 abates totais; o n-ésimo ponto custa 25.000 × n de ouro; trilhas EXP, Loot, Shiny com +0,1% por ponto; os pontos nunca resetam | C | guia e janela (`totalKills`, `available`, `spent`, `toNext`, `killsPerPoint`) |
| Trilha EXP: parcela `streak` = base × 0,1% × pontos, só no treinador | C (+0,1%) / A (o `pokeXp.parts` não tem chave streak) / F (sobre a base) | nunca vista ≠ 0 nas gravações |
| Trilha Loot: +0,1% de chance de uma rolagem extra inteira de drop por ponto (100% = 1 extra garantida, excesso → próxima) | C | texto da janela |
| Trilha Shiny | C | guardada sem efeito (E: sem shiny no time offline) |
| Boosts `xp` +50% treinador, `pokexp` +50% Pokémon, `loot` +40% de chance, `capture` dobra a chance | C | guia "Boost"; formato `{key, until, pct}` (A) |
| Parcela de boost = base × pct | F | nunca vista ≠ 0 |
| Fonte de boosts offline | E | nenhuma ainda (no original: loja de diamantes, Daily Gift, itens); a sim aceita `cfg.boosts` |
| Tipo do Dia: +20% de XP (parcela `typeDay`) e +20% de loot nos selvagens do tipo; o dia vira às 03:00 UTC | A (formato, texto e horário: `until` 1794366000000) | parcela = 20% da base e loot = chance × 1,2 (F) |
| Rotação do Tipo do Dia | E | ancorada nos dois dias gravados (09/11 Dragão, 10/11 Inseto), ciclo fixo de 18 tipos |
| Tarefas de NPC e Daily Kill / Daily Catch / Daily Gift | — | **não implementados**: o cliente traz só o formato (C: `tasks[{id, city, npc, kind, pokeId, qty, have, complete, claimed, xp, cash}]`, `daily-kill {options[…], pickedIdx, rerolls, rerollMax, rerollCost, resetAt}`); alvos, quantidades e prêmios vêm do servidor (gravações G5 e G6) |

## O que pede evidência do original (gravações curtas, gravador v1.2)

**G3 — evolução com pedras (3 min), ainda pendente.** Com um Pokémon que já pode evoluir e com pedras na BAG:
1. Abra a janela de evolução (botão ⬆ no time) e espere 5 s.
2. Evolua com pedras.
3. Só abra (sem evoluir) a janela de uma espécie de dois tipos (Ivysaur, Charmeleon ou Geodude) e espere 5 s.

As respostas de `GET /api/game/evolve` trazem a receita real (`stones`): fecham ou derrubam a hipótese F.

**G5 — tarefas e diárias (4 min).**
1. Abra Quests & Tasks e passe por todas as cidades da lista (2 s em cada).
2. Abra Daily Kill e espere 5 s; escolha uma missão.
3. Abra Daily Catch e espere 5 s.
4. Se houver tarefa ou missão completa, resgate uma.

Traz `/api/game/tasks`, `/api/game/daily-kill`, `/api/game/daily-catch` e o formato do resgate (alvos, quantidades, prêmios).

**G6 — Modo Soneca de verdade (≥ 10 min fora).**
1. Numa hunt conhecida, com o gravador ligado, clique 💤 Zzz.
2. Feche o jogo por pelo menos 10 min.
3. Reabra com o gravador já ligado **antes** de carregar a página.
4. Espere a janela "Enquanto você estava fora…" e clique Coletar (sem turbo).

Traz o `report` real (`xp50`, `estKills`, `seconds`) e a resposta da coleta: confere a taxa de 50% e o que a amostra
entrega.

**G7 — Streak Points e Daily Gift (2 min).**
1. Abra a janela Streak Points e espere 5 s (não invista).
2. Abra o Daily Gift e espere 5 s (não colete, se não quiser).

Traz `/api/game/streak` (formato e o `perPoint`/custo reais) e o calendário do Daily Gift (prêmios dos 28 dias).

**G8 — Tipo do Dia num abate (5 min).** Numa hunt de uma espécie do tipo do dia (veja o evento no topo), grave 5 min
de abates.

Mostra a parcela `typeDay` e o efeito no loot: fecha as duas hipóteses F (20% da base e chance × 1,2).

**G1 — feita (11/11).** Compra (Small Potion por 5) e venda de loot (Bag of Pollen por 40) com o formato das respostas (A). Poções e pedras não aparecem para venda: a lista é montada pelo cliente (C); o servidor não foi testado com uma poção.

**G2 — feita (11/11).** O valor é o `sellValue` da espécie (A).

**G3 — evolução com pedras (3 min).** Com um Pokémon que já pode evoluir e com pedras na BAG:
1. Abra a janela de evolução (botão ⬆ no time).
2. Espere 5 s com ela aberta.
3. Evolua com pedras.
4. Repita com uma espécie de dois tipos (ex.: Ivysaur, Charmeleon, Geodude), sem evoluir: só abrir a janela.

As respostas `GET /api/game/evolve` trazem a receita real (`stones`) e confirmam ou derrubam a hipótese F.

**G4 — feita (11/11).** Nurse Joy responde `joy-healed` vazio, sem custo; formato do depot e regras de mover (A).
