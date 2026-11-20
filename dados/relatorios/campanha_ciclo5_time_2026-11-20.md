# Campanha do ciclo 5: time de até 6, Orre e o ×10

Fonte: `testes/campanha.gd --completo 1 --vip 1 --time 1 --horas 600` (sim pura; saída em
`saida_testes/campanha_c5_time.json`, 2,8 h reais). Começo, cidade, diárias, soneca 8 h/dia, Streak, ginásios e Orre ×10
iguais aos do ciclo 3. Novo é a política de time (E, cabeçalho do script):

- Capturas vão para a BOX como indivíduo novo de nível 1 (A).
- O time são os 6 de maior Power, preferindo um tipo e uma espécie novos a cada vaga.
- Só entra no time quem tem golpe de dano no nível atual. Achado: o Poliwag só ataca a partir do 5 e o Metapod nunca;
  sem esse filtro, o "treino" punha em campo um Pokémon que desmaiava sem abater nada.
- O líder de cada hunt é o membro de maior Power × vantagem de tipo.
- Em 1 sessão de cada 4, o líder é o membro mais fraco, numa hunt até 2 níveis acima do dele e escolhida pela vantagem de
  tipo dele.

## Resultado

| | Ciclo 3 (só o líder) | Ciclo 5 (time de 6) |
| --- | --- | --- |
| Treinador 150 (Outland) | 34 h | 60 h |
| Treinador 500 (Orre) | 275 h | 520 h |
| Time às 600 h | Golem | Golem 527, Sunflora 41, Quilava 41, Krabby 40, Ariados 41, Nidorina 40 |
| Ginásios | 168 vitórias / 469 derrotas em 400 h | 235 / 680 em 600 h; até 16 insígnias ao mesmo tempo |

As reservas não acompanham: a XP do Pokémon vai só para quem está em campo (A) e a curva é cúbica. Com 1 sessão em 4, as 5
reservas somam ~40 níveis cada em 600 h, enquanto o carregador vai a 527. Treinar mais as reservas atrasa o treinador
(já foram 245 h a mais até Orre) e elas continuam longe do nível de Orre.

## Orre no nível de acesso (treinador 500–532, hunts de nível 530)

| Hunt (530) | Minutos | XP/h (com ×10) | Mortes |
| --- | --- | --- | --- |
| electrike | 300 | 2,09 M | 0 |
| taillow | 46 | 1,75 M | 1 |
| poochyena | 20 | 0,97 M | 1 |
| riolu | 12 | 0,94 M | 1 |
| aron | 5 | 2,04 M | 1 |
| meditite | 4 | 0,67 M | 1 |
| ralts | 0 | — | 1 |

Para comparar, na mesma rodada a Outland 150 rendeu enraged_typhlosion 15,1 M XP/h, ancient_pinsir 15,1 M e
furious_scyther 12,9 M.

**Orre não é jogável no nível de acesso.** Das 7 hunts de 530, só a electrike se sustenta (elétrico contra Golem), e ela
rende 1/7 da Outland, mesmo com o ×10. O XP base das espécies de 530 é baixo (A: `experience` da espécie). Nas outras, o
time inteiro desmaia em 0–46 min: o carregador cai e as reservas de nível 40 não seguram nada. O time ajuda nos ginásios,
mas não em Orre.

## Até a Nightmare (2000) com o ×10, VIP

| Caminho (horas ativas a partir do treinador 532) | Horas | Dias de 16 h |
| --- | --- | --- |
| Ficar na Outland (~15 M XP/h) | ~8.600 | ~540 |
| Orre 530 com ×10 (electrike, 2,1 M/h) | ~62.000 | ~3.900 |
| Outland até 580 (~50 h) e depois Orre 580 com ×10 (manectric/swellow, ~49 M/h no ciclo 3) | ~2.700 | ~170 |

Soneca, diárias e tarefas somaram 36% do XP do treinador nesta rodada. Os dias de calendário caem ~1/3 com elas.

**Precisa de ajuste:**

1. O ×10 só passa a valer a partir do 580, onde as espécies dão XP alto. No 500–579, Orre rende menos que a Outland,
   então o jogador não tem motivo para entrar.
2. O time de 6 não resolve a dificuldade de Orre sem um jeito de as reservas subirem. Hoje elas não sobem (XP só do
   ativo, Rare Candy congelado com o lote 3). O aviso de Orre no original fala em TMs AoE e de elemento, também do lote 3.

Proposta no bloco de decisões do ciclo.

## Ajuste aplicado: piso de XP em Orre (decisão do usuário, 20/11)

Classe 3, `balanceamento.json` combate.xp_regiao_piso. Em Orre, o multiplicador de cada hunt é
max(×10, 40.524 ÷ XP base médio das espécies da hunt). O piso é 3 × 13.508, o XP base da melhor hunt da Outland: no nível
de acesso o time abate ~3× mais devagar. Multiplicadores: 510 ×596, 520 ×163, 530 ×73,9, 540 ×41,9, 550 ×26,9,
560 ×18,7; de 580 em diante fica o ×10. A base da espécie não muda (classe 1); a diferença entra na parcela `event`.

Medido na sim (`testes/medir_orre.gd`: Golem da campanha com as reservas de nível ~40, VIP, 2 sementes × 60 min):

| Hunt | Nível | XP/h | Abates/min | Mortes em 2 h |
| --- | --- | --- | --- | --- |
| taillow (Orre) | 530 | 15,6 M | 6,37 | 0 |
| electrike (Orre) | 530 | 14,5 M | 5,92 | 0 |
| poochyena (Orre) | 530 | 9,5 M | 3,88 | 0 |
| riolu (Orre) | 530 | 6,2 M | 2,53 | 0 |
| aron, meditite, ralts, wingull, numel (Orre) | 530 | — | — | 2 em 2 (o time cai em 0,4–3,6 min) |
| ancient_pinsir (Outland) | 150 | 16,4 M | 13,45 | 0 |
| enraged_typhlosion (Outland) | 150 | 15,0 M | 12,34 | 0 |
| furious_scyther (Outland) | 150 | 12,1 M | 9,93 | 0 |

Com o Golem no 580, Orre 580 (×10): swellow 53,7 M e manectric 48,4 M XP/h sem morte; mawile 54,0 M e metang 47,5 M com
mortes; as outras 14 derrubam o time.

**Leitura:**

- Orre no nível de acesso passa a valer a pena em 2 das 14 hunts de 530 (taillow e electrike, no nível da melhor Outland),
  e em mais 2 que se sustentam rendendo menos. Antes, rendia 1/7 da Outland.
- O tempo até a Nightmare quase não muda, porque a Outland já rendia isso. O ganho grande continua no 580 (~50 M/h):
  - do treinador 532 ao 580: ~50 h;
  - do 580 ao 2000: ~2.600 h ativas, ou ~1.700 h com soneca, diárias e tarefas (36% do XP);
  - no total, do zero: ~3.200 h ativas com esta política de time.
- A dificuldade de Orre segue aberta: as hunts que derrubam o time só ficam jogáveis com reservas fortes, o que hoje não
  acontece (XP só do ativo).
