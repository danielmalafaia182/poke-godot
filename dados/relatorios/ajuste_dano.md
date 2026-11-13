# Ajuste da fórmula de dano (fase 4, item 1)

Gerado por `ferramentas/fase4/ajustar_dano.py` sobre 26 gravações. Golpe explicado = cabe no envelope [aleatório 0,85; 1,00] com o melhor valor do stat desconhecido do selvagem (um por indivíduo × golpe). Erro = soma, nos não explicados, da distância ao envelope, dividida pelo nº de golpes.

## Aliado → selvagem (faixa = nível do atacante)

| faixa | golpes | c: explicados · erro médio | a: explicados · erro médio | b: explicados · erro médio | e: explicados · erro médio | d: explicados · erro médio |
|---|---|---|---|---|---|---|
| 1–4 | 472 | 32.6% · 2.15 | 66.5% · 1.09 | 66.5% · 1.09 | 90.5% · 0.96 | 90.5% · 0.64 |
| 80–199 | 4376 | 99.6% · 0.01 | 99.8% · 0.00 | 99.7% · 0.00 | 99.6% · 0.01 | 100.0% · 0.00 |
| 200–+ | 653 | 47.3% · 133582.59 | 47.3% · 133579.42 | 47.3% · 133581.54 | 80.9% · 21691.40 | 80.9% · 21576.50 |

## Selvagem → aliado (faixa = nível do atacante)

| faixa | golpes | c: explicados · erro médio | a: explicados · erro médio | b: explicados · erro médio | e: explicados · erro médio | d: explicados · erro médio |
|---|---|---|---|---|---|---|
| 1–4 | 101 | 100.0% · 0.00 | 0.0% · 1.00 | 0.0% · 1.00 | 100.0% · 0.00 | 100.0% · 0.00 |
| 80–199 | 1787 | 99.2% · 0.21 | 98.9% · 0.21 | 98.8% · 0.21 | 99.2% · 0.21 | 99.3% · 0.20 |

## Por gravação (os dois lados)

| gravação | golpes | c | a | b | e | d |
|---|---|---|---|---|---|---|
| G7.jsonl | 7 | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| M1.jsonl | 2222 | 99.5% | 99.5% | 99.4% | 99.5% | 99.8% |
| M2.jsonl | 1095 | 99.5% | 99.5% | 99.4% | 99.5% | 99.5% |
| M3.jsonl | 167 | 99.4% | 99.4% | 99.4% | 99.4% | 99.4% |
| S1.jsonl | 117 | 0.0% | 0.0% | 0.0% | 100.0% | 100.0% |
| S2.jsonl | 32 | 0.0% | 0.0% | 0.0% | 100.0% | 100.0% |
| c5.jsonl | 324 | 40.1% | 40.1% | 40.1% | 61.7% | 61.7% |
| g1.jsonl | 7 | 100.0% | 100.0% | 100.0% | 100.0% | 100.0% |
| geodeude-2.jsonl | 241 | 86.3% | 66.0% | 66.0% | 100.0% | 100.0% |
| geodude-10min.jsonl | 332 | 14.2% | 46.7% | 46.7% | 86.4% | 86.4% |
| poke_ws_todas(1)).jsonl | 203 | 99.5% | 99.5% | 99.5% | 99.5% | 99.5% |
| poke_ws_todas(2)(20.jsonl | 302 | 99.7% | 99.7% | 99.7% | 99.7% | 99.7% |
| rhydon-1h.jsonl | 2340 | 99.5% | 99.6% | 99.5% | 99.5% | 99.9% |
