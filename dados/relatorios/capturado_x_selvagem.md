# Capturado × selvagem (A)

218 capturas casadas com o poke-delta do capturado; 57 com maxHp do selvagem acima do piso de 120.

| Teste | Resultado |
| --- | --- |
| maxHp do selvagem explicado com a Quality do capturado (algum IV_hp 1..32) | **45/57** |
| O mesmo com uma Quality sorteada pelos pesos do cliente (esperado por acaso) | 48.6/57 (85%) |
| Stats exibidos do capturado no nível 1 coerentes com quality + ivTotal (IV 1..32, fórmula C) | **218/218** |

| Faixa de Quality | Capturados | Esperado pelo cliente |
| --- | --- | --- |
| 0.8–0.9 | 13 | 10.9 |
| 0.9–1.0 | 11 | 10.9 |
| 1.0–1.1 | 74 | 74.2 |
| 1.1–1.2 | 36 | 43.6 |
| 1.2–1.3 | 25 | 21.8 |
| 1.3–1.4 | 22 | 21.8 |
| 1.4–1.5 | 25 | 21.8 |
| 1.5–1.6 | 11 | 10.9 |
| 1.7–1.8 | 1 | 1.5 |
| 1.8–1.8 | 0 | 0.6 |
| fora das faixas (a 1,6–1,7 não existe) | 0 | 0 |

χ² = 2.8 (faixas com esperado > 1; 8 graus de liberdade). ivTotal: média 97.2, dp 21.7, de 46 a 152 (seis IV uniformes 1..32: média 99, dp 22,6).

| Gravação | Hunt (nível) | Espécie | maxHp do selvagem | Quality do capturado | ivTotal | IV_hp compatíveis | Por acaso |
| --- | --- | --- | --- | --- | --- | --- | --- |
| G9.jsonl | arbok (40) | Arbok | 1225 | 1.429 | 61 | 1–1 | 89% |
| G9.jsonl | arbok (40) | Arbok | 1015 | 1.493 | 83 | nenhum | 64% |
| C1.jsonl | spearow (10) | Spearow | 280 | 1.05 | 88 | 16–20 | 100% |
| C1.jsonl | spearow (10) | Spearow | 245 | 1.297 | 104 | 6–9 | 100% |
| C1.jsonl | spearow (10) | Spearow | 315 | 1.117 | 103 | 19–22 | 100% |
| C1.jsonl | spearow (10) | Spearow | 245 | 1.526 | 98 | 2–5 | 100% |
| C1.jsonl | spearow (10) | Spearow | 350 | 1.175 | 106 | 21–25 | 95% |
| C1.jsonl | spearow (10) | Spearow | 245 | 1.495 | 63 | 3–5 | 100% |
| C1.jsonl | spearow (10) | Spearow | 420 | 0.874 | 77 | nenhum | 52% |
| C1.jsonl | spearow (10) | Spearow | 245 | 1.251 | 81 | 7–10 | 100% |
| C1.jsonl | spearow (10) | Spearow | 385 | 0.808 | 83 | nenhum | 84% |
| C1.jsonl | spearow (10) | Spearow | 245 | 1.09 | 126 | 10–14 | 100% |
| C1.jsonl | spearow (10) | Spearow | 280 | 1.499 | 101 | 6–8 | 100% |
| C1.jsonl | spearow (10) | Spearow | 280 | 1.044 | 123 | 16–20 | 100% |
| C1.jsonl | spearow (10) | Spearow | 245 | 1.425 | 85 | 4–6 | 100% |
| C1.jsonl | spearow (10) | Spearow | 315 | 1.081 | 135 | 20–24 | 99% |
| C1.jsonl | spearow (10) | Spearow | 245 | 1.082 | 104 | 11–14 | 100% |
| C1.jsonl | spearow (10) | Spearow | 245 | 0.899 | 103 | 16–21 | 100% |
| C1.jsonl | spearow (10) | Spearow | 210 | 0.824 | 93 | 14–19 | 98% |
| C1.jsonl | spearow (10) | Spearow | 280 | 1.108 | 104 | 15–18 | 100% |
| C1.jsonl | spearow (10) | Spearow | 420 | 1.009 | 54 | nenhum | 54% |
| C1.jsonl | spearow (10) | Spearow | 385 | 1.052 | 99 | 31–32 | 87% |
| C1.jsonl | spearow (10) | Spearow | 210 | 1.054 | 106 | 7–10 | 98% |
| C8.jsonl | meowth (20) | Meowth | 455 | 1.458 | 116 | 2–3 | 98% |
| C8.jsonl | meowth (20) | Meowth | 245 | 1.194 | 85 | nenhum | 4% |
| C8.jsonl | meowth (20) | Meowth | 455 | 1.121 | 88 | 9–10 | 99% |
| C8.jsonl | meowth (20) | Meowth | 455 | 1.296 | 97 | 5–6 | 99% |
| C8.jsonl | meowth (20) | Meowth | 490 | 1.101 | 104 | 11–13 | 100% |
| C8.jsonl | meowth (20) | Meowth | 735 | 1.53 | 112 | 15–15 | 90% |
| C8.jsonl | meowth (20) | Meowth | 525 | 1.015 | 126 | 16–18 | 100% |
| C8.jsonl | meowth (20) | Meowth | 455 | 1.012 | 92 | 11–13 | 98% |
| C8.jsonl | meowth (20) | Meowth | 595 | 1.078 | 92 | 19–20 | 100% |
| C8.jsonl | meowth (20) | Meowth | 630 | 1.337 | 81 | 14–15 | 99% |
| C8.jsonl | meowth (20) | Meowth | 315 | 1.544 | 130 | nenhum | 52% |
| C8.jsonl | meowth (20) | Meowth | 700 | 1.358 | 98 | 17–18 | 93% |
| c2.jsonl | vulpix (20) | Vulpix | 385 | 1.471 | 80 | nenhum | 90% |
| c2.jsonl | vulpix (20) | Vulpix | 525 | 1.149 | 83 | 13–14 | 100% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 385 | 1.28 | 86 | 22–25 | 88% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 315 | 1.179 | 66 | 17–20 | 100% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 385 | 1.15 | 105 | 26–30 | 87% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 210 | 1.055 | 136 | 7–10 | 98% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 210 | 1.27 | 56 | 2–5 | 98% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 315 | 1.498 | 98 | 9–12 | 99% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 455 | 1.536 | 95 | 22–24 | 35% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 315 | 1.025 | 61 | 22–26 | 100% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 210 | 0.963 | 109 | 9–13 | 98% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 315 | 1.38 | 128 | 12–14 | 100% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 175 | 1.217 | 115 | 1–2 | 78% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 210 | 0.88 | 76 | 12–16 | 100% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 280 | 1.232 | 134 | 11–14 | 100% |
| t1_transacoes.jsonl | spearow (10) | Spearow | 455 | 0.922 | 54 | nenhum | 36% |
| t1_transacoes.jsonl | vulpix (20) | Vulpix | 700 | 1.281 | 101 | 20–21 | 93% |
| rhydon-1h.jsonl | rhydon (80) | Rhydon | 4235 | 0.856 | 117 | nenhum | 50% |
| rhydon-1h.jsonl | rhydon (80) | Rhydon | 4760 | 1.538 | 115 | 4–4 | 48% |
| rhydon-1h.jsonl | rhydon (80) | Rhydon | 4235 | 1.195 | 78 | nenhum | 46% |
| rhydon-1h.jsonl | rhydon (80) | Rhydon | 3920 | 1.493 | 74 | nenhum | 42% |
| rhydon-1h.jsonl | rhydon (80) | Rhydon | 5495 | 1.772 | 95 | nenhum | 22% |
