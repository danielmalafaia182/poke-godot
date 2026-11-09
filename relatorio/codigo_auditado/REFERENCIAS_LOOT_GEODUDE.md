# Referência dos drops do Geodude

Página indicada: https://poke.idleworld.online/pokepedia/pokemon/geodude

A leitura pública retornou a estrutura de navegação, sem a tabela da espécie;
a tentativa HTTP direta retornou 403. Não se usaram dados de outros jogos ou
sites semelhantes para preencher a tabela.

A implementação usa `game/creatures.json`, `game/items.json` e os sprites das
respostas do HAR de 03/11/2026 já fornecidos. O módulo de Pokepedia no chunk
`0fllz2m_ktm3s.js` converte `chance / 1000` para exibir a porcentagem. Portanto,
para uma probabilidade entre 0 e 1, o divisor é 100000. Isso resolve a ambiguidade
do denominador que impedia o loot na versão anterior.

| Item | ID | Quantidade | Chance no catálogo | Probabilidade base |
| --- | ---: | --- | ---: | ---: |
| Earth Ball | 39 | 1–4 | 95000 | 95% |
| Small Stone | 120 | 1–4 | 95000 | 95% |
| Stone Orb | 126 | 1 | 28352.11 | 28,35211% |
| Strange Rock | 128 | 1 | 973.84 | 0,97384% |
| Rock Stone | 109 | 1 | 95.3 | 0,0953% |
| Strange Pheromone | 44417 | 1 | 0 | 0% — não é sorteado |

Dados locais editáveis em `dados/referencias/loot_geodude.json`. O catálogo não
recebe as quantidades da conta do print. Os chips mostram somente itens concedidos
no encontro e somam quantidades quando o painel agrupa abates.

Os PNG de Small Stone, Earth Ball, Stone Orb e Strange Rock foram recuperados
diretamente das respostas do HAR. Rock Stone usa o primeiro quadro do GIF
original convertido para PNG; a animação desse item não foi implementada.

## Prioridades de confirmação

1. Comparar estes números com a tabela atual da página; o catálogo extraído pode
   representar outra data de balanceamento. Não foi confirmada a atualidade online.
2. Confirmar se o servidor faz rolagens independentes e qual distribuição usa para
   as quantidades. A versão offline usa sorteio independente por item e inteiro
   uniforme inclusivo entre mínimo e máximo; isso é uma decisão local explícita.
3. Confirmar a ordem de aplicação e arredondamento de bônus de loot (eventos,
   streak, boost, tipo do dia e outros). Nenhum desses bônus foi presumido.
4. Integrar shiny e seus drops somente após existir identidade shiny persistente
   no modelo. Esta versão não inventa shiny por ausência de informação.

XP base 8 já estava confirmado no catálogo e nos eventos field-kill arquivados.
O print com +48 e Base 32 representa bônus e agrupamento, não XP base por abate.
