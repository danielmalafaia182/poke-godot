# Arredondamento do dano e forma do fator aleatório (23/11/2026)

Gerado por `ferramentas/fase4/arredondamento_dano.py` (verossimilhança da distribuição dos valores; ver o cabeçalho do script).

## Gravações das fases 3 e 4

60 grupos (indivíduo × golpe, ≥ 20 golpes, aliado nível ≥ 5), 3479 golpes.

| Modelo | logL |
| --- | --- |
| round, aleatório contínuo | -15955.5 |
| floor, aleatório contínuo | -15958.0 |
| round, aleatório 16 inteiros | -25720.9 |
| floor, aleatório 16 inteiros | -25785.3 |

| Faixa do aliado | round, aleatório contínuo | floor, aleatório contínuo | round, aleatório 16 inteiros | floor, aleatório 16 inteiros |
|---|---|---|---|---|
| 80–199 | -15762.1 | -15764.6 | -25527.5 | -25591.9 |
| 200–+ | -193.4 | -193.4 | -193.4 | -193.4 |

Grupos em que round ou floor vence por mais de 2 de logL: contínuo — round 1, floor 0, empate 59; 16 inteiros — round 20, floor 13, empate 27.

## Gravação livre (18–20/11, por sessão)

1203 grupos (indivíduo × golpe, ≥ 20 golpes, aliado nível ≥ 5), 38417 golpes.

| Modelo | logL |
| --- | --- |
| round, aleatório contínuo | -229828.6 |
| floor, aleatório contínuo | -229835.9 |
| round, aleatório 16 inteiros | -319372.4 |
| floor, aleatório 16 inteiros | -319739.3 |

| Faixa do aliado | round, aleatório contínuo | floor, aleatório contínuo | round, aleatório 16 inteiros | floor, aleatório 16 inteiros |
|---|---|---|---|---|
| 20–79 | -45457.4 | -45459.9 | -69924.4 | -69885.8 |
| 80–199 | -105165.2 | -105166.7 | -146577.3 | -146944.2 |
| 200–+ | -79206.0 | -79209.4 | -102870.7 | -102909.3 |

Grupos em que round ou floor vence por mais de 2 de logL: contínuo — round 3, floor 4, empate 1196; 16 inteiros — round 337, floor 287, empate 579.

