# Gravação noturna na Outland (19/11, 03:37–12:31) — validador da classe 2

Fonte: `poke har/gravacoes/livre/` (sessão `2026-11-19T06-36`), hunt `ancient_pupitar` (Outland, nível 150; a primeira
faixa 150+ gravada), líder Gyarados 195 → 219, 478 min e 3.596 abates em 23 trechos. O segmentador
(`ferramentas/gravador/segmentar.py`) deixa como trechos de resultado (≥ 5 min, sem buraco, líder conhecido) os dois
longos; os outros 21 são cortes curtos (zoom, troca de aba, retomada). Validador: `ferramentas/validar_resultado.py`
(3 sementes; critério formal de `ESTRATEGIA.md`, intervalo de 95%).

| Trecho | min | Abates/min real · sim | XP/h real · sim | Ouro/h real · sim | Mortes/h | Capturas/h real · sim | Passa |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gyarados 195–203 | 93,1 | 7,28 · 7,41 | 9.010.106 · 9.005.817 | 126.787 · 114.515 | 0 · 0 | 2,58 · 1,07 | 5/5 |
| Gyarados 203–219 | 262,0 | 7,49 · 7,55 | 9.275.124 · 9.173.202 | 125.696 · 116.986 | 0 · 0 | 0,92 · 0,69 | 5/5 |

**Nada saiu do intervalo; nenhuma regra mudou.** Abates e XP ficam a menos de 2%; o ouro da sim fica 7–10% abaixo
nos dois (dentro da faixa sorteada da tabela de loot). As capturas/h da sim ficam abaixo nos dois trechos (4 e 3
capturas a menos em 5,9 h), dentro do ruído de Poisson; com dois trechos o sinal não é teste (fica anotado para a
próxima gravação longa na Outland). No conjunto, o validador passa 159/160; a única grandeza fora é o ouro de um trecho
de 6 min na `tyranitar` (loot raro), não da Outland.
