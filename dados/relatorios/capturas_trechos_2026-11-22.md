# Capturas por trecho, real × sim (ciclo 6)

Fonte: `ferramentas/fase4/capturas_trechos.py` sobre os 47 trechos da gravação livre de 18–20/11
(`saida_testes/validar_resultado_c5/livre`, 3 sementes por trecho). O ciclo 5 achou a sim abaixo do real em 20 de 25
trechos fora de ±10%.

## O que se mediu

| Grandeza (soma dos trechos) | Real | Sim (média) |
| --- | --- | --- |
| Abates | 32.606 | 32.276 |
| Abates elegíveis ao Auto-Catch | 32.525 | 32.194 |
| Bolas por abate elegível | 1,002 | 1,003 |
| Tempo do abate até a bola | mesmo tick (0 ms) | mesmo tick (0 ms) |
| Capturas | 151 | 137,7 |
| Tentativas por captura | 216 | 234 |

**A sim não joga menos bolas:** cada abate elegível recebe uma bola no mesmo tick, nos dois lados. Alvo, tempo de luta e
regra do Auto-Catch estão iguais; não há o que corrigir aí.

**O viés está na chance por tentativa, e numa espécie.** Tentativa a tentativa, com o medidor conhecido (depois da 1ª
captura da sessão ou do used-balls; scratchpad `mle_captura.py`):

| Espécie (preço NPC) | Tentativas | Capturas reais | Esperadas pelo modelo da sim | z |
| --- | --- | --- | --- | --- |
| Larvitar (15.000, EPIC) | 22.663 | 116 | 95,6 | +2,1 |
| Ancient Pupitar (32.500, EPIC) | 10.768 | 22 | 21,8 | 0,0 |
| Rattata (80, COMMON) | 168 | 101 | 112,7 | −1,1 |

O Larvitar captura ~21% acima do modelo; o Pupitar, da mesma raridade, bate exato; o Rattata fica um pouco abaixo. Não há
forma simples (preço, raridade, nível da hunt) que separe o Larvitar dos outros dois sem um parâmetro por espécie. O
modelo (c 0,814, k 1,14, classe 2) **não foi mudado**: ajustar só pelo Larvitar seria sobreajuste. Com mais espécies
gravadas com o medidor conhecido, dá para testar raridade × preço de novo.

## Tabela por trecho (antes = depois: a mecânica não mudou)

| Trecho | Abates real · sim | Elegíveis real · sim | Bolas/elegível real · sim | Bolas real · sim | Capturas real · sim | Tentativas/captura real · sim | ms abate→bola real · sim |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 001_larvitar | 98 · 104 | 97 · 103 | 1.01 · 1.01 | 98 · 104 | 1 · 0.7 | 98 · 156 | 0 · 0 |
| 002_larvitar | 45 · 50 | 45 · 50 | 1.00 · 1.00 | 45 · 50 | 0 · 0.0 | — · — | 0 · 0 |
| 003_tyranitar | 32 · 30 | 32 · 30 | 1.00 · 1.00 | 32 · 30 | 0 · 0.0 | — · — | 0 · 0 |
| 004_larvitar | 45 · 48 | 45 · 48 | 1.00 · 1.00 | 45 · 48 | 1 · 0.3 | 45 · 145 | 0 · 0 |
| 005_tyranitar | 30 · 28 | 30 · 28 | 1.00 · 1.00 | 30 · 28 | 0 · 0.0 | — · — | 0 · 0 |
| 006_larvitar | 59 · 60 | 59 · 60 | 1.00 · 1.00 | 59 · 60 | 0 · 0.7 | — · 91 | 0 · 0 |
| 007_tyranitar | 37 · 37 | 37 · 37 | 1.00 · 1.00 | 37 · 37 | 0 · 0.0 | — · — | 0 · 0 |
| 008_tyranitar | 50 · 49 | 50 · 49 | 1.00 · 1.00 | 50 · 49 | 0 · 0.0 | — · — | 0 · 0 |
| 009_larvitar | 50 · 56 | 50 · 56 | 1.00 · 1.01 | 50 · 56 | 0 · 0.3 | — · 168 | 0 · 0 |
| 010_rattata | 33 · 37 | 33 · 36 | 1.00 · 1.01 | 33 · 37 | 17 · 22.3 | 2 · 2 | 0 · 0 |
| 011_larvitar | 73 · 74 | 73 · 74 | 1.00 · 1.00 | 73 · 74 | 0 · 0.0 | — · — | 0 · 0 |
| 012_larvitar | 554 · 556 | 553 · 554 | 1.00 · 1.00 | 554 · 556 | 2 · 2.7 | 277 · 208 | 0 · 0 |
| 013_larvitar | 480 · 486 | 477 · 485 | 1.01 · 1.00 | 480 · 486 | 1 · 3.3 | 480 · 146 | 0 · 0 |
| 014_larvitar | 3365 · 3548 | 3358 · 3534 | 1.00 · 1.00 | 3365 · 3548 | 19 · 16.3 | 177 · 217 | 0 · 0 |
| 015_larvitar | 4055 · 3879 | 4041 · 3866 | 1.00 · 1.00 | 4055 · 3879 | 19 · 16.7 | 213 · 233 | 0 · 0 |
| 016_ancient_pupitar | 678 · 688 | 676 · 688 | 1.00 · 1.00 | 678 · 688 | 4 · 2.3 | 170 · 295 | 0 · 0 |
| 017_ancient_pupitar | 1963 · 1977 | 1959 · 1977 | 1.00 · 1.00 | 1963 · 1977 | 4 · 4.7 | 491 · 424 | 0 · 0 |
| 019_larvitar | 1035 · 959 | 1031 · 955 | 1.00 · 1.00 | 1035 · 959 | 7 · 2.3 | 148 · 411 | 0 · 0 |
| 021_larvitar | 231 · 213 | 229 · 212 | 1.01 · 1.00 | 231 · 213 | 1 · 0.3 | 231 · 639 | 0 · 0 |
| 022_ancient_pupitar | 151 · 154 | 151 · 154 | 1.00 · 1.00 | 151 · 154 | 0 · 0.3 | — · 463 | 0 · 0 |
| 023_larvitar | 63 · 60 | 63 · 60 | 1.00 · 1.01 | 63 · 60 | 0 · 0.3 | — · 180 | 0 · 0 |
| 024_larvitar | 360 · 333 | 358 · 332 | 1.01 · 1.00 | 360 · 333 | 3 · 1.3 | 120 · 250 | 0 · 0 |
| 025_ancient_pupitar | 243 · 247 | 241 · 247 | 1.01 · 1.00 | 243 · 247 | 0 · 1.0 | — · 247 | 0 · 0 |
| 026_ancient_pupitar | 101 · 101 | 101 · 101 | 1.00 · 1.00 | 101 · 101 | 1 · 0.0 | 101 · — | 0 · 0 |
| 027_larvitar | 103 · 97 | 103 · 97 | 1.00 · 1.00 | 103 · 97 | 1 · 0.3 | 103 · 292 | 0 · 0 |
| 028_larvitar | 103 · 98 | 103 · 98 | 1.00 · 1.00 | 103 · 98 | 1 · 0.3 | 103 · 295 | 0 · 0 |
| 029_ancient_pupitar | 69 · 71 | 69 · 71 | 1.00 · 1.00 | 69 · 71 | 0 · 0.3 | — · 212 | 0 · 0 |
| 030_larvitar | 171 · 164 | 170 · 164 | 1.01 · 1.00 | 171 · 164 | 2 · 0.3 | 86 · 492 | 0 · 0 |
| 031_ancient_pupitar | 59 · 59 | 59 · 59 | 1.00 · 1.00 | 59 · 59 | 2 · 0.3 | 30 · 178 | 0 · 0 |
| 032_ancient_pupitar | 58 · 59 | 58 · 59 | 1.00 · 1.00 | 58 · 59 | 0 · 0.3 | — · 178 | 0 · 0 |
| 033_larvitar | 136 · 130 | 135 · 129 | 1.01 · 1.00 | 136 · 130 | 0 · 0.3 | — · 389 | 0 · 0 |
| 034_larvitar | 126 · 119 | 125 · 119 | 1.01 · 1.00 | 126 · 119 | 0 · 0.3 | — · 357 | 0 · 0 |
| 035_ancient_pupitar | 55 · 55 | 55 · 55 | 1.00 · 1.00 | 55 · 55 | 0 · 0.0 | — · — | 0 · 0 |
| 036_larvitar | 167 · 161 | 167 · 161 | 1.00 · 1.00 | 167 · 161 | 1 · 0.3 | 167 · 484 | 0 · 0 |
| 037_ancient_pupitar | 118 · 115 | 118 · 115 | 1.00 · 1.00 | 118 · 115 | 0 · 0.7 | — · 173 | 0 · 0 |
| 038_larvitar | 3930 · 3622 | 3924 · 3605 | 1.00 · 1.00 | 3930 · 3622 | 23 · 16.3 | 171 · 222 | 0 · 0 |
| 039_ancient_pupitar | 2704 · 2672 | 2702 · 2672 | 1.00 · 1.00 | 2704 · 2672 | 4 · 4.3 | 676 · 617 | 0 · 0 |
| 040_ancient_pupitar | 470 · 469 | 470 · 469 | 1.00 · 1.00 | 470 · 469 | 2 · 1.0 | 235 · 469 | 0 · 0 |
| 041_larvitar | 155 · 146 | 154 · 146 | 1.01 · 1.00 | 155 · 146 | 1 · 0.3 | 155 · 438 | 0 · 0 |
| 042_larvitar | 459 · 425 | 458 · 424 | 1.00 · 1.00 | 459 · 425 | 2 · 1.3 | 230 · 319 | 0 · 0 |
| 043_larvitar | 239 · 239 | 239 · 238 | 1.00 · 1.00 | 239 · 239 | 0 · 0.0 | — · — | 0 · 0 |
| 044_ancient_pupitar | 176 · 178 | 174 · 178 | 1.01 · 1.00 | 176 · 178 | 0 · 0.0 | — · — | 0 · 0 |
| 045_larvitar | 5131 · 5285 | 5121 · 5264 | 1.00 · 1.00 | 5131 · 5285 | 24 · 23.7 | 214 · 223 | 0 · 0 |
| 046_ancient_pupitar | 4026 · 4010 | 4014 · 4010 | 1.00 · 1.00 | 4026 · 4010 | 5 · 11.0 | 805 · 365 | 0 · 0 |
| 047_larvitar | 179 · 186 | 178 · 185 | 1.01 · 1.00 | 179 · 186 | 2 · 0.0 | 90 · — | 0 · 0 |
| 048_ancient_pupitar | 85 · 84 | 84 · 84 | 1.01 · 1.00 | 85 · 84 | 0 · 0.0 | — · — | 0 · 0 |
| 049_ancient_pupitar | 56 · 55 | 56 · 55 | 1.00 · 1.00 | 56 · 55 | 1 · 0.0 | 56 · — | 0 · 0 |
| **total** | 32606 · 32276 | 32525 · 32194 | 1.002 · 1.003 | 32606 · 32276 | 151 · 137.7 | 216 · 234 | |
