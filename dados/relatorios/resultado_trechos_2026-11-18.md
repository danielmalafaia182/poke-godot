# Movimento: resultado por trecho de hunt (critério de pronto desde 18/11/2026)

Decisão do usuário (18/11): em vez de igualar cada grandeza do movimento, compara-se o resultado de cada trecho de hunt,
real × sim, com tolerância de ±10%. Cinco grandezas: abates/min, XP/h, mortes/h, ouro/h (venda do loot ao Mark) e
selvagens ao lado do herói por field. As gravações MV1–MV3 deixaram de existir; entram os trechos da gravação livre.

**Ferramenta:** `python -I ferramentas/fase4/resultado_trechos.py [gravações ou pastas] --sementes 3`. Sem argumentos,
usa todas as gravações de `poke har/gravacoes`, inclusive `livre/`.
- `segmentar.py` corta os trechos. Os úteis para "resultado" (≥ 5 min, líder conhecido) saem com o contexto: VIP,
  inventário, bolas, Auto-Helper e o time real.
- Cada trecho vira um estado inicial e roda na sim pela mesma duração.
- A penalidade de entrada só entra quando o real teve lock no trecho.

**Tolerâncias:**
- mortes/h também passam se as duas ficarem abaixo de 0,5/h;
- "ao lado/field" também passa se a diferença for de até 0,05 (perto de zero, ±10% é ruído; E).

## Resultado (11 trechos, 3 sementes cada)

| Gravação | Hunt | Líder (níveis) | min | Abates/min real · sim | XP/h real · sim | Mortes/h real · sim | Ouro/h real · sim | Ao lado/field real · sim | Passa |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| G11 | rattata | Vulpix [1, 2, 3] | 8.3 | 3.86 · 2.94 ❌ | 2.582 · 1.964 ❌ | 0.00 · 0.00 ✅ | 3.102 · 2.717 ❌ | 1.16 · 1.09 ✅ | 2/5 |
| C6 | bulbasaur | Venusaur [] | 6.3 | 13.43 · — | 264.675 · — | 0.00 · — | 12.920 · — | 0.15 · — | 0/0 (sem estado) |
| C8 | meowth | Venusaur [] | 8.5 | 10.24 · — | 208.282 · — | 0.00 · — | 16.342 · — | 0.00 · — | 0/0 (sem estado) |
| M1 | kangaskhan | Venusaur [140, 141] | 42.2 | 2.87 · 2.22 ❌ | 975.612 · 759.112 ❌ | 0.00 · 0.00 ✅ | 16.296 · 12.500 ❌ | 1.38 · 1.32 ✅ | 2/5 |
| M2 | kangaskhan | Venusaur [142] | 26.5 | 2.46 · 2.27 ✅ | 832.375 · 770.422 ✅ | 0.00 · 0.00 ✅ | 11.047 · 13.002 ❌ | 1.27 · 1.29 ✅ | 4/5 |
| M3 | rhydon | Golem [387] | 16.8 | 9.97 · 8.58 ❌ | 3.388.474 · 2.821.410 ❌ | 0.00 · 0.00 ✅ | 44.544 · 49.384 ❌ | 0.03 · 0.06 ✅ | 2/5 |
| S1 | oddish | Rhydon [425] | 5.9 | 9.72 · 8.27 ❌ | 7.001 · 5.952 ❌ | 0.00 · 0.00 ✅ | 9.100 · 6.284 ❌ | 0.00 · 0.02 ✅ | 2/5 |
| c2 | vulpix | Venusaur [] | 6.1 | 9.36 · — | 183.236 · — | 0.00 · — | 7.726 · — | 0.02 · — | 0/0 (sem estado) |
| c5 | geodude | Rhydon [425] | 44.6 | 7.26 · 6.67 ✅ | 5.128 · 4.806 ✅ | 0.00 · 0.00 ✅ | 5.385 · 4.279 ❌ | 0.02 · 0.03 ✅ | 4/5 |
| geodude-10min | rattata | Geodude [1, 2, 3] | 5.5 | 2.53 · 2.60 ✅ | 1.824 · 1.872 ✅ | 0.00 · 0.00 ✅ | 1.987 · 2.576 ❌ | 2.62 · 1.13 ❌ | 3/5 |
| rhydon-1h | rhydon | Venusaur [119, 120] | 15.7 | 7.20 · 6.63 ✅ | 2.432.716 · 2.297.020 ✅ | 0.00 · 0.00 ✅ | 29.794 · 40.362 ❌ | 0.39 · 0.49 ❌ | 3/5 |
| rhydon-1h | rhydon | Venusaur [121] | 5.4 | 7.09 · 6.30 ❌ | 2.454.445 · 2.180.693 ❌ | 0.00 · 0.00 ✅ | 57.317 · 33.221 ❌ | 0.40 · 0.40 ✅ | 2/5 |
| rhydon-1h | rhydon | Venusaur [121, 122] | 16.2 | 6.85 · 6.80 ✅ | 2.373.141 · 2.354.462 ✅ | 0.00 · 0.00 ✅ | 29.669 · 29.189 ✅ | 0.42 · 0.49 ❌ | 4/5 |
| rhydon-1h | rhydon | Venusaur [123, 124] | 19.4 | 7.21 · 6.68 ✅ | 2.495.467 · 2.313.161 ✅ | 0.00 · 0.00 ✅ | 33.275 · 33.977 ✅ | 0.41 · 0.50 ❌ | 4/5 |

**32/55 grandezas dentro de ±10%** em 11 trechos (3 sementes cada). Por grandeza: Abates/min 6/11, XP/h 6/11, Mortes/h 11/11, Ouro/h 2/11, Ao lado/field 7/11.

Ficaram sem estado C6, C8 e c2: são gravações antigas sem `pokes` nem `poke-delta` do líder em lugar nenhum, então os IVs
dele são desconhecidos. A gravação livre resolve isso, porque o gravador pega o `pokes.list` ao abrir o jogo.

## Leitura

- **Mortes/h: 11/11.** A sim não mata nem salva a mais.
- **Quando os abates divergem, a sim sempre mata menos.** G11 −24% (o dano do aliado no nível 1, já conhecido), M1 −23%
  (luta longa contra o Kangaskhan), S1 −15%, M3 −14%, rhydon-1h (5 min) −11%. Nos três trechos longos da rhydon-1h e no
  M2, os abates ficam dentro.
  - O XP/h segue os abates (a mesma conta por abate dos dois lados).
  - Candidatos: a perseguição mais lenta do selvagem na sim (ms/tile +18% em luta curta) e o caminho do herói até o alvo.
- **Ouro/h: 2/11.** O loot raro e caro pesa muito em 5–16 min. Exemplo: rhydon-1h de 5,4 min dá 57 mil no real contra
  33 mil na sim; os trechos de 16–19 min ficam dentro. Os trechos longos da gravação livre vão dizer se é só variância.
- **Ao lado/field: 7/11.** Na rhydon-1h a sim junta um pouco mais (0,49–0,50 × 0,39–0,42). Na geodude-10min (nível 1,
  lutas longas) junta menos (1,13 × 2,62).

A regra de movimento da sim não mudou. A próxima mudança só entra se melhorar este placar sem piorar o diferencial.
