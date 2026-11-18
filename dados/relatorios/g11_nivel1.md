# G11 — nível 1–4 na `rattata` (18/11/2026)

Gravação `poke har/gravacoes/fase 4/G11.jsonl`. Líder Vulpix nível 1→3 (Quality 1,72, ivTotal 115), Auto-Catch com Super
Ball (35 tentativas, 22 capturas) e Auto-Potion; no fim, o Larvitar entra no lugar do Vulpix. Relatório automático em
`dados/relatorios/gravacoes/gravacao_G11.md`.
Ferramentas: `ferramentas/fase4/grupos_nivel_baixo.py`, `ajuste_nivel1.py`, `capturado_x_selvagem.py`, `nivel1_individuos.py`.

## O que a G11 mostra (A)

| Fato | Números |
| --- | --- |
| **Dano do aliado no nível 1 só tem valores pares** | Ember do Vulpix nível 1: 14 (31×) e 16 (57×), nenhum 15. É o mesmo sinal da geodude-10min (Tackle do Geodude nível 1: 6 ou 8, 168 golpes). Do nível 2 em diante, valores seguidos (Vulpix nível 2: 11–12; nível 3: 18–22) |
| **No nível 1 o Vulpix tira mais que no nível 2** | 14–16 no nível 1 × 11–12 no nível 2, contra os mesmos Rattata nível 1 |
| **A defesa do Rattata nível 1 é a mesma em todos os indivíduos** | 28 indivíduos, os 120 de maxHp no piso. Com SpD comum 0,81, a fórmula da sim explica 88/88 golpes do Vulpix nível 2 e 89/89 do nível 3 |
| **O Tackle do Rattata nível 1 sobe quando o Vulpix sobe de nível** | No Vulpix nível 1, 5 em 39/39 golpes; no nível 2, 7 em 41/41. Um valor só em cada nível (= 1,8 × 3 ou 4, arredondado). Nenhum ataque constante explica os dois (41/80) |
| **O capturado é um sorteio novo, não o selvagem** | Em 12 das 57 capturas (todas as gravações) com maxHp do selvagem acima de 120, nenhum IV de HP dá o maxHp com a Quality do capturado; por acaso seriam 85% compatíveis, e foram 45/57 (`capturado_x_selvagem.md`). Na G11, os 22 capturados têm Quality de 0,87 a 1,49 e ivTotal de 57 a 134, e todos levaram o mesmo dano |
| **Quality do capturado = sorteio do cliente** | 218 capturas: χ² = 2,8 com 8 graus de liberdade contra os pesos de `rollQuality` (C); nenhuma em 1,6–1,7 |
| **IV do capturado = 1..32 uniforme** | ivTotal médio 97,2, dp 21,7 (esperado 99 e 22,6) |
| **Stats exibidos do capturado no nível 1 = fórmula do cliente** | 218/218 coerentes com Quality + ivTotal |
| Tipo do Dia em 18/11 = Fantasma | `events` (rotação da sim corrigida: a posição 9 passa a Fantasma) |

## Dano de nível 1–4: o que fecha e o que não fecha

Golpes do aliado no Rattata nível 1 (G11 + geodude-10min + geodeude-2), defesa comum varrida, IV do atacante varrido
dentro dos stats exibidos:

| Variante | Melhor defesa comum do Rattata nível 1 | IV SpA Vulpix | IV Atk Geodude | Golpes explicados |
| --- | --- | --- | --- | --- |
| atual | 0.95 | 30 | 27 | 617/747 (82.6%) |
| x2 | 0.85 | 27 | 23 | 625/747 (83.7%) |
| x2exib | 0.86 | 24 | 23 | 523/747 (70.0%) |
| exib | 0.86 | 24 | 23 | 430/747 (57.6%) |

Tackle do Rattata nível 1 no Vulpix (A comum, ×1,8 depois do arredondamento ou junto):

| ×1,8 | Melhor ataque comum | IV Def Vulpix | Golpes explicados |
| --- | --- | --- | --- |
| depois | 1.51 | 5 | 41/80 |
| junto | 1.55 | 5 | 41/80 |

Por grupo, com a melhor defesa de cada golpe (Def para o Tackle do Geodude, SpD para o Ember do Vulpix):

| Grupo | `atual` (sim) | `x2` |
| --- | --- | --- |
| Vulpix nível 1 (14, 16) | 0/88 (prevê 9–11) | 0/88 (prevê 10) |
| Vulpix nível 2 (11, 12) | 88/88 (SpD 0,81) | 88/88 |
| Vulpix nível 3 (18–22) | 89/89 | 89/89 |
| Geodude nível 1 (6, 8) | 168/168 (Def 0,95, piso 3) | 168/168 (Def 0,85, sem piso) |
| Geodude nível 2 (8–10) | 94/121 | 94/121 |
| Geodude nível 3 (9, 12–14) | 27/34 | 27/34 |
| Geodude nível 4 (20–23) | 159/159 | 159/159 |

**Não aplicado.** Nenhuma variante explica o Vulpix no nível 1, nem o Tackle do Rattata subindo de 5 para 7. A `x2`
explica a paridade do nível 1 e tira o piso 3 (F), mas ganha só 1,1 ponto no total, e no Vulpix nível 1 continua 0/88.

Os dois desvios apontam para o mesmo lugar: no nível 1, o aliado bate mais e apanha menos do que a fórmula prevê. É como
se os stats dele no nível 1 fossem maiores que no nível 2. Hipóteses que sobram (F):
- os stats do nível 1 têm um piso próprio (o exibido 1–2 não é o usado);
- o ×2 do nível 1 combina com outro fator que depende do golpe ou do STAB.

Separar pede um aliado de nível 1 com golpe especial sem STAB, ou outra espécie com STAB.
