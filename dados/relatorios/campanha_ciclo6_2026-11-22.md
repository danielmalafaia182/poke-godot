# Campanha do ciclo 6: revezamento, itens, bosses e profissão; Orre com e sem piso

Fonte: `testes/campanha.gd --completo 1 --vip 1 --time 1 --horas 700` (sim pura, 3,5 h reais; saída
`saida_testes/campanha_c6_time.json`). Política nova (E, cabeçalho do script), além da do ciclo 5:

- A cada 10 min, lidera o membro viável com menos XP (troca por `switch`, 5 s de espera). Foram 239 trocas.
- Bosses Especiais diários (650 vitórias).
- Itens:
  - 50 Rare Candies usados;
  - 1 held sorteado (X-Vitality T2 no Golem);
  - 2 TMs no Golem: Pedra e AoE.
- Botânico chegou ao rank B.
- O mentor vale (A: 0,5%/nível acima de 200, teto por rank).

## Metas de tempo (horas ativas, VIP, 16 h/dia + soneca)

| Meta | Ciclo 3 (só o líder) | Ciclo 5 (time, treino 1 em 4) | Ciclo 6 (revezamento + itens) |
| --- | --- | --- | --- |
| Outland (150) | 34 h | 60 h | **60 h** |
| Treinador 300 | 101 h | — | **165 h** |
| Orre (500) | 275 h | 520 h | **502 h** |
| Time às 600 h | Golem | Golem 527, reservas ~40 | Golem 595 (às 700 h), reservas **86–106** |
| Treinador às 700 h | — | — | **605** |

Em Orre, 60 h com o piso: electrike 24 M XP/h, taillow 20 M, swellow e manectric (580) 92–93 M. Foram 80 mortes em
123 sessões: 22 hunts de Orre ainda derrubam o time.

## Orre no nível de acesso, com e sem piso

`testes/medir_orre.gd --time saida_testes/campanha_c6_time.json --nivel_lider 527`: o time final da campanha com o
carregador no 527; em cada hunt lidera o membro de maior Power × vantagem de tipo; 2 sementes × 60 min.

| Hunt (530) | Com itens, com piso (XP/h · abates/min · mortes) | Com itens, sem piso | Sem itens, sem piso |
| --- | --- | --- | --- |
| electrike | 24,6 M · 10,1 · 0 | 3,5 M · 10,1 · 0 | 2,0 M · 5,9 · 0 |
| taillow | 20,3 M · 8,3 · 0 | 2,9 M · 8,3 · 0 | 2,2 M · 6,4 · 0 |
| aron | 30,5 M · 12,5 · 1 | 4,3 M · 12,5 · 1 | — (cai em 2 min) |
| poochyena | 19,2 M · 7,8 · 0 | 2,7 M · 7,8 · 0 | 1,3 M · 3,9 · 0 |
| riolu | 13,2 M · 5,4 · 0 | 1,9 M · 5,4 · 0 | 0,9 M · 2,5 · 0 |
| meditite | 18,5 M · 7,6 · 2 (27 min) | 2,6 M | — (cai em 1 min) |
| ralts, wingull, numel, snorunt, corphish, nuzleaf | o time cai em 0,4–2,9 min | idem | idem |
| Outland: enraged_typhlosion · ancient_pinsir | 15,0 M · 12,3 · 0 · 16,5 M · 13,6 · 0 | igual | igual |

**Leitura:**

- **Time + itens resolvem a velocidade de abate.** Os TMs (golpe de área de Pedra e o AoE) quase dobram os abates/min em
  Orre (electrike 5,9 → 10,1, perto dos 12,3 da Outland). Aron e meditite passam a aguentar.
- **Não resolvem o XP.** Sem o piso, Orre 530 rende 3,5 M XP/h contra 15–16,5 M da Outland: o XP base das espécies de 530
  é 548, contra 13.508 da melhor Outland (A).
- **Proposta: reduzir o piso**, não remover. Com o abate quase igual, o piso que iguala a XP/h é ~1,2 × 13.508 ≈ 16.500
  (hoje 40.524, calculado no ciclo 5 com o abate 3× mais lento). Com o piso atual e os itens, Orre passa a Outland em
  50–60%.
- **Dificuldade:** 6 das 12 hunts de 530 ainda derrubam o time em minutos, mesmo com itens. O que falta é um time de reservas
  forte; as reservas chegaram a ~100 com o revezamento e o mentor.

## Piso reduzido para 16.500 (decisão do usuário, 22/11)

Mesma medição (time do fim da campanha, carregador no 527, VIP):

| Hunt | Multiplicador | XP/h | Abates/min |
| --- | --- | --- | --- |
| torchic (520) | ×66,5 | 11,9 M | 11,95 |
| electrike (530) | ×30,1 | 10,1 M | 10,07 |
| taillow (530) | ×30,1 | 8,4 M | 8,31 |
| poochyena (530) | ×30,1 | 7,9 M | 7,83 |
| Outland: enraged_typhlosion · ancient_pinsir | ×1 | 15,0 M · 16,5 M | 12,3 · 13,6 |

- **Sem VIP, Orre 530 empata com a Outland** (electrike 10,07 × 16.500 contra 12,32 × 13.508 ≈ 10 M XP/h nos dois).
- **Com VIP, Orre fica em ~2/3:** o VIP soma 50% da base da espécie (A), e a base de Orre é 548 contra 13.508.
- De 560 em diante o piso não age (16.500 ÷ 2.168 = ×7,6 < ×10); 580+ segue no ×10.

## Ciclo 7: o piso vira a base efetiva (decisão do usuário)

O piso passou a substituir o XP base da espécie antes dos bônus: base efetiva = max(base, 16.500 ÷ ×10). Os bônus (VIP,
streak, boosts, Tipo do Dia, insígnias, held, mentor) saem da base efetiva e o ×10 da região vale sobre a soma.

| Hunt | Sem VIP: XP/h | Com VIP: XP/h |
| --- | --- | --- |
| electrike (Orre 530) | 9,97 M | 14,95 M |
| taillow (Orre 530) | 8,23 M | 12,34 M |
| torchic (Orre 520) | 11,83 M | 17,75 M |
| enraged_typhlosion (Outland) | 9,99 M | 14,98 M |
| ancient_pinsir (Outland) | 11,00 M | 16,50 M |

Orre 530 (electrike) empata com a melhor Outland (enraged_typhlosion) nos dois casos.
