# Captura de shiny — chance por bola (ciclo 4, item 5)

## A regra

- **C (barra de captura do cliente):** chance = min(1, shinyBase(tier) × catchRate da bola).
  - O shiny não usa o medidor de investimento das capturas comuns.
  - O texto da barra é `hud.captureBar.tierChance`.
- **A (`balls.catalog`):** catchRate de cada bola: Poké 1, Great 2, Super 3, Ultra 4, Idle 5, Master 255.
- **Classe 3 (`dados/balanceamento.json`, `combate.captura_shiny_base`):** shinyBase por tier. O servidor não mostra
  esse valor; o gradiente vai do tier raro (A) ao comum (E).
- **Conferido** (`testes/test_shiny_captura.gd` 3/3):
  - a sim usa essa tabela;
  - chance = shinyBase × catchRate em todas as bolas;
  - 40.000 Poké Balls num shiny do tier C, pela própria sim, deram 393 capturas (esperado 400 ± 20).

## Chance por bola

| Tier | Poké | Great | Super | Ultra | Idle | Master |
| --- | --- | --- | --- | --- | --- | --- |
| A | 0,4% | 0,8% | 1,2% | 1,6% | 2,0% | 100% |
| B | 0,7% | 1,4% | 2,1% | 2,8% | 3,5% | 100% |
| C | 1,0% | 2,0% | 3,0% | 4,0% | 5,0% | 100% |
| D | 1,5% | 3,0% | 4,5% | 6,0% | 7,5% | 100% |
| E | 2,0% | 4,0% | 6,0% | 8,0% | 10,0% | 100% |

"Quase impossível" (o relato do usuário sobre o original) bate com isto: fora da Master Ball, nenhuma bola passa de 10%,
e com a Poké Ball do começo fica entre 0,4% e 2%.

## Os 0 capturados da campanha são esperados

- **Campanha de 20 h do ciclo 4** (`saida_testes/campanha_c4_teste2.json`): 32 shinies abatidos, 0 capturados.
  - Ela só compra Poké Balls (`testes/campanha.gd`), e os shinies das hunts dela são de tier B e C (0,7–1,0%).
  - Esperado: 32 × 0,7–1,0% = **0,22–0,32 capturas**; a chance de nenhuma é **72–80%**.
- **Campanha do ciclo 3** (0 em 23): tinha um defeito de medição. Uma captura de shiny só era contada se a bola do
  shiny fosse diferente da do Auto-Catch, e na campanha as duas eram a Poké Ball. Corrigido no ciclo 4: o shiny é
  reconhecido pela casa do abate.
  - Mesmo assim, o esperado para 23 era 0,16–0,23 captura, e o 0 era o resultado mais provável.
- **Gravações do original:** 0 capturas em 31 tentativas (tiers B e C, Super e Idle Ball).
  - Pela tabela, o esperado é ~0,7–1,2 captura; a chance de nenhuma é 30–50%. A tabela é coerente com o observado.
  - A chance exata por tier só sai com mais tentativas gravadas em shiny.
