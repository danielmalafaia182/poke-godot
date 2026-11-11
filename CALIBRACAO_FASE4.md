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
| `shop` | `GET /api/game/shop` | C (só o `gold` é lido com certeza; o resto da resposta é E) |
| `shop-buy {ballId \| itemId, qty}` | `POST /api/game/shop/buy` → `{gold, bought}` | C |
| `shop-sell {items[{itemId, qty}]}` | `POST /api/game/shop/sell` → `{gold, goldGained, soldCount}` | C |
| `pokemon-sell {pokeIds}` | `POST /api/game/pokemon/sell` → `{gold, goldGained, sold}` | C |
| `joy-heal` | WS `joy-heal` (sem resposta própria no cliente) | C; a resposta `joy-healed` é E |
| `depot`, `depot-move {itemId, dir} \| {all: true}` | `GET/POST /api/game/depot[/move]` | C; `ballId` no `depot-move` é E |
| `poke-store {id}`, `poke-withdraw {id}` | WS `poke-store`, `poke-withdraw` | C (nomes); os campos são E |
| Mensagens de estado | `balls {catalog, counts, gold, selected}`, `inventory {items}`, `poke-delta {poke}` | A (formato gravado) |
| | `currency {gold}` | C (o tipo existe) |
| | `depot`, `pokes-removed`, `evolved`, `shop-*`, `pokemon-sold` | E |

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
| Venda de Pokémon (só da BOX, nunca o inicial) pelo `valorVenda` da espécie | F (valor) / C (restrições) | o cliente lista para venda só Pokémon fora do time, não inicial, não shiny, não anunciado no mercado e com `sellValue > 0` (C); a exclusão de shiny ainda não está na sim (sem shiny no time offline); o valor pago não foi gravado (G2) |
| Ouro vem só de vendas (o `field-kill` não traz ouro) | A | nenhum campo de ouro em 600+ abates |
| Ouro inicial 0 | E | o original dá 100 Small Potions e 100 Poké Balls (C); o saldo inicial não foi gravado |
| Loja, Nurse e depot só nas cidades com o NPC | A | `city-npcs`: Cerulean e Viridian têm `shop`, `nurse` e `pokedepot` |

## Nurse Joy

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Cura o time inteiro, de graça, sem recarga | C | "She heals your whole team for free" e "Nurse Joy heals for free"; o botão manda `joy-heal` direto |
| Só o time (não a BOX) | C/E | "heals your whole team" |

## Depot

| Regra | Fonte | Evidência |
| --- | --- | --- |
| Time de no máximo 6 | C | "Your team only carries 6 — the rest rest here" |
| BOX com até 3000 Pokémon | A (conta VIP) / F (sem VIP) | `auto-helper.pokeCapacity` 3000 |
| Depot de itens com até 200 pilhas | E | limite do P04; o original não mostra limite |
| "Guardar tudo" leva a BAG inteira; bola vinculada (Golden Idle) fica | C (`{all: true}`) / A (`bound`) / E (vinculada fica) | — |
| O inicial não vai para a BOX; depositar o líder passa a liderança ao inicial | E | regras do P04 mantidas |

## VIP

Opção nas Configurações (⚙ na cidade), desligada por padrão (E). Ligada, a simulação soma a parcela `vip` = 50% da XP
base, no treinador e no Pokémon (A: `xpParts.vip`). Vai no save (campo opcional `vip`).

Fica de fora (não medido):
- os outros efeitos do VIP original no Auto-Helper e na capacidade;
- o "+50%" sobre streak, boost e evento (offline não tem).

## O que pede evidência do original (até 4 gravações curtas, gravador v1.2)

**G1 — dispensada.** O cliente (C) mostra que o Mark não compra poções nem pedras (categorias heal/revive/stone).

**G2 — venda de Pokémon (2 min).** Na loja, aba de Pokémon:
1. Venda 1 Pokémon da BOX de nível 1 e Quality comum.
2. Venda 1 de nível alto da mesma espécie, se houver.

O `goldGained` de cada um mostra se o valor é o `sellValue` fixo ou se depende de nível ou Quality.

**G3 — evolução com pedras (3 min).** Com um Pokémon que já pode evoluir e com pedras na BAG:
1. Abra a janela de evolução (botão ⬆ no time).
2. Espere 5 s com ela aberta.
3. Evolua com pedras.
4. Repita com uma espécie de dois tipos (ex.: Ivysaur, Charmeleon, Geodude), sem evoluir: só abrir a janela.

As respostas `GET /api/game/evolve` trazem a receita real (`stones`) e confirmam ou derrubam a hipótese F.

**G4 — Nurse Joy e depot (2 min).**
1. Volte da hunt com o time ferido e clique na Nurse Joy (Heal team).
2. Abra o Depot e guarde 1 item.
3. Retire 1 item.
4. Use "guardar tudo".

Mostra se o servidor responde ao `joy-heal` (e com o quê) e o formato de `/api/game/depot`.
