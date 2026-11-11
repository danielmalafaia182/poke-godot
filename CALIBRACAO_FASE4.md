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
| `depot`, `depot-move {itemId, dir} \| {all: true}` | `GET/POST /api/game/depot[/move]` → `{inventory[…], depot[…]}`, itens `{id, name, icon, category, npcPrice, quantity}` | **A** (G4); `ballId`/`balls` são E (no original as bolas não ficam no depot) |
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

| Bolas no depot | **A** × E | G4: as bolas nunca aparecem no depot (nem na lista da BAG, nem na do depot); o P04 guarda bolas no depot e isso **ficou como está** até decisão |

## VIP

Opção nas Configurações (⚙ na cidade), desligada por padrão (E). Ligada, a simulação soma a parcela `vip` = 50% da XP
base, no treinador e no Pokémon (A: `xpParts.vip`). Vai no save (campo opcional `vip`).

Fica de fora (não medido):
- os outros efeitos do VIP original no Auto-Helper e na capacidade;
- o "+50%" sobre streak, boost e evento (offline não tem).

## O que pede evidência do original (até 4 gravações curtas, gravador v1.2)

**G1 — feita (11/11).** Compra (Small Potion por 5) e venda de loot (Bag of Pollen por 40) com o formato das respostas (A). Poções e pedras não aparecem para venda: a lista é montada pelo cliente (C); o servidor não foi testado com uma poção.

**G2 — feita (11/11).** O valor é o `sellValue` da espécie (A).

**G3 — evolução com pedras (3 min).** Com um Pokémon que já pode evoluir e com pedras na BAG:
1. Abra a janela de evolução (botão ⬆ no time).
2. Espere 5 s com ela aberta.
3. Evolua com pedras.
4. Repita com uma espécie de dois tipos (ex.: Ivysaur, Charmeleon, Geodude), sem evoluir: só abrir a janela.

As respostas `GET /api/game/evolve` trazem a receita real (`stones`) e confirmam ou derrubam a hipótese F.

**G4 — feita (11/11).** Nurse Joy responde `joy-healed` vazio, sem custo; formato do depot e regras de mover (A).
