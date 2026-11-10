# Plano de gravações — fase 3 (calibração)

Gravações curtas e dirigidas para fechar três pontos em aberto no CLAUDE.md: **(a)** seleção de golpe, **(b)** curva de
captura por nível e por bola, **(c)** movimento e perseguição (hipóteses H1–H4). As hunts foram escolhidas pelos dados,
não de cabeça: `ferramentas/fase3/planejar_fase3.gd` calcula, para cada Pokémon das duas contas e cada espécie de cada uma
das 451 hunts, o golpe que a hipótese de seleção prevê, o 2º colocado, a margem entre eles, quantos golpes leva para
abater e quanto dano o selvagem tira (saída: `saida_testes/plano_fase3.json`).

Premissas do cálculo: o Venusaur da conta A é o indivíduo das gravações (IVs 26/5/4/18/17/28, Quality 0,835; stats no
poke-delta). Os outros Pokémon estão com IV 16 e Quality 1,0, porque os reais não estão no projeto. Por isso só escolhi
casos com margem grande, ou empates exatos, que não dependem de IV. Fórmula de dano e seleção = as da sim (F).

## Como gravar (vale para todas)

1. Abra o jogo com o gravador ativo (`ferramentas/gravador/gravador_ws.user.js`, **v1.1**: grava também as respostas de
   `/api/game/*`) **antes** de entrar na hunt, para o
   `field-init` e o `poke-delta` do líder ficarem no arquivo.
2. Entre numa **instância nova**, não na retomada. A penalidade de XP de entrada não atrapalha estas medições.
3. Mantenha a aba **visível e em primeiro plano**: em segundo plano o navegador atrasa o WebSocket e os `field` chegam
   em lotes.
4. Não mexa no jogo além do que a gravação pede (troca de líder, janela). A troca de líder aparece nas mensagens
   (`switch`, `bossActiveIdx`), mas anote a hora num .txt ao lado, por segurança.
5. Nomeie o arquivo `fase3_<ID>_<hunt>_conta<A|B>.jsonl` e coloque-o em `poke har/gravacoes/`.
6. Anote antes e depois o estoque de bolas e poções. A mensagem `balls` também registra isso.
7. Depois de cada gravação: `python -I ferramentas/gravador/atualizar_corpos.py`. Cada hunt nova também ensina o
   cadáver da espécie dela, o que é um ganho extra.

## Situação (10/11/2026)

Conferência: `python -I ferramentas/fase3/conferir_fase3.py` (e `ferramentas/fase3/s3_individuos.py` para o S3).

| ID | Gravado | Resultado |
|---|---|---|
| S1 | sim (12 min, 116 abates; Rhydon 425 e Golem 387, troca aos ~5 min; 2 retomadas no meio, sem efeito) | **confirma**: Stone Edge 58/58, Earthquake 59/59 → empate exato = primeiro da lista |
| S2 | sim (4 min, 32 abates; catch ligado com Idle Ball, 1 tentativa: não atrapalha) | **confirma**: Hammer Arm 32/32 |
| S3 | sim (3,6 min, 39 abates) | **confirma por indivíduo**: Hydro Pump 31/39 (o critério de 95% supunha IV 16 e não passa), mas cada Rhyhorn leva sempre o mesmo golpe (15/15) e os 3 com Aqua Tail são coerentes com a regra pelos stats que o maxHp e o dano permitem (15/15; em 12 a escolha restringiu o indivíduo) |
| S4 | sim (4 min, 37 abates; Venusaur já no nível 139, não 124; catch ligado com Super Ball) | **confirma**: Double-Edge 39/39; vale também como **C2**: 2/37 capturas (a curva de 2 pontos previa 29,6%: derrubada; depois a curva por nível foi trocada pelo medidor de investimento, seção b) |
| S5–S8 | não | dispensáveis: S5 e S7 (efetividade sem STAB) e S8 (repete o S4) testam o que S2/S4 já mostraram; S6 (A/D) foi coberto pelo S3. Gravar só se sobrar tempo |
| C1 | sim (4,5 min, 52 tentativas; Venusaur 142, Super Ball; **sem used-balls**: o gravador não gravou nenhuma linha REST) | Spearow 10: 28/52. **Derruba o fator de nível** do modelo (ele previa 3,9). Chance por tentativa desde a última captura: 13/28, 7/14, 7/7 → o medidor existe e a base sai do preço |
| C2 (c2) | sim, extra (57 tentativas) | Vulpix 20: 3/57 (com o S4, 5/94); modelo novo 4,0 esperado no conjunto |
| C6 | sim (6 min, 84 tentativas, sem used-balls) | Bulbasaur 20 RARE (3000): 0/84; modelo novo 2,05 (P = 0,13): **inconclusivo** para raridade (fator ajustado 1,00) |
| M1 | sim (Venusaur 140–141, 121 abates, ~19 min de fields em 2,5 h com pausas) | **Borda da perseguição medida (A)**: ±13 em colunas e ±13 em linhas, não ±7. H1 e H4 explicados por isso no Kangaskhan; H3 cai (o "vaguear" era perseguição em \|dy\| 8–13) |
| M2 | sim (Venusaur 141–142, 65 abates), mas o `view` foi 27×15 do começo ao fim | O cliente calcula o `view` só pelo zoom da câmera (C); o tamanho da janela não muda nada. A pergunta do M2 (a visão acompanha a janela?) não se aplica. Serve como 2ª gravação de luta longa (confirma o M1) |
| C5 | sim (conta B, Rhydon 425, `geodude`, 44,7 min: Poké 61, Great 60, Super 59, Ultra 69 e um trecho extra de Idle 75). Gravador v1.2 com linhas REST, mas **sem used-balls**: foi aberto o `capture-log` (histórico de capturas), não a tela Gerenciamento de Captura | **Valor da bola = ouro pago** (critério fechado). Esperado pelo ouro × pela eficiência, observado: Poké 0,9 × 4,0, 0/47; Great 5,1 × 9,8, 6/60; Super 12,9 × 13,7, 10/59; Ultra 33,1 × 20,3, 37/69; Idle 73,0 × 26,2, 73/73 (logL −190,6 × −294,5). As 2 falhas de Idle foram em shiny (como a do S2). Investimento de antes da gravação: inconclusivo |
| M3 | sim (conta B, Golem 387, `rhydon`, 16,7 min, 167 abates; catch ligado, 5 tentativas) | Abate em 1 golpe: 0,03 adjacentes por field. O selvagem que não é o alvo quase nunca chega ao lado do herói (0,32/min real × 1,88 na sim com caixa 13), mas em luta longa (M1/M2) chega mais que na sim. **Nenhuma regra testada fecha as quatro gravações**: a sim fica com 7 |
| C3, C4, C7, C8, M4 | não | ver "O que falta", abaixo |

### O que falta (em ordem de prioridade, revisto em 10/11/2026, depois do C5 e do M3)

1. **Transições da penalidade (P1, ~10 min).** Grave sem parar o gravador:
   - hunt A → cidade → espere 30 s → hunt B;
   - hunt B → mapa-múndi direto para a hunt C;
   - hunt C → cidade → a mesma hunt C de novo.

   Em 11 entradas o lock acaba 60 s depois da entrada. O S3 é a única exceção. Só uma transição gravada inteira mostra
   de onde o minuto conta e se voltar à mesma hunt penaliza.
2. **C8 com used-balls (P1, ~8 min): Meowth 20, preço 300, Super Ball.** Antes de entrar e logo depois de sair, abra a
   tela **Gerenciamento de Captura** (lista de espécies com Preço de NPC, Total Gasto e tentativas), não o histórico de
   capturas. Responde duas coisas: com o mesmo preço do Geodude 1, o nível pesa? E o investimento de antes da gravação
   entra no medidor? (O `attempts` do início diz quanto já havia.)
3. **M6 (novo, P1 para o movimento): luta de duração média, ~20 min.** Um líder que mate em ~3–4 golpes (luta de 6–10 s)
   numa hunt com grade real conferida (`rhyhorn` ou `kangaskhan`). Em luta curta (M3, 1h) o não-alvo chega ao herói menos
   que na sim; em luta longa (M1/M2), mais. Uma duração intermediária mostra onde isso vira e separa "tempo de luta" de
   "mapa". Hipótese de trabalho (F): o não-alvo só fecha o último tile quando o herói já está lutando.
4. **M4 (P2): Geodude ~10 em `rattata`.** Coleira (H2): falta ver um selvagem que perseguia e ficou para trás voltar ou
   não ao spawn.
5. **M5 (P2): zoom.** Mude o zoom da câmera no meio de uma hunt (o `view` muda com ele, C) e veja se o raio de
   perseguição acompanha.

**Dispensadas:** C5 e M3 (feitas); C3 e C4 (caras e com pouca informação); C7 (coberto pela Super Ball do C5); S5–S8; o
C6 não precisa ser repetido (raridade fica em aberto, sem prioridade); M2 com janela de tamanhos diferentes (a janela
não muda o `view`); outra gravação de valor de bola (o ouro fechou).

Falta gravar: P1 ≈ 40 min (penalidade, C8, M6); P2 ≈ 40 min (M4, M5).

## (a) Seleção de golpe

**O que os dados já dizem (A):** o Venusaur usa Solar Beam e não Petal Dance. Os dois empatam em tudo, menos no
cooldown (30 s × 50 s) e no nível em que se aprende (53 × 32), o que descarta "primeiro golpe da lista". O Rhydon
selvagem usa Stone Edge contra o Venusaur, onde Stone Edge e Earthquake empatam até no cooldown; Stone Edge é o aprendido
primeiro, o que descarta "aprendido por último".

A regra da sim é a única simples coerente com os dois: maior dano esperado (poder × A/D × STAB × efetividade
amplificada); empate → menor cooldown; persistindo → o aprendido primeiro.

Também já se sabe (A, rhydon-1h) que o cooldown do golpe **não limita** a cadência: o Solar Beam (30 s de cooldown) sai a
cada 1,6 s. Não é preciso gravar isso.

As gravações abaixo testam o que falta: se a efetividade, a razão A/D (físico × especial) e o desempate decidem
como a hipótese diz. Cada abate traz o nome do golpe nos `hits`, e quase todas matam com um golpe, então 3–4 min dão
~25–30 abates, o bastante para ver se a escolha é sempre a mesma.

| ID | Pri. | Conta | Líder | Hunt (nível, espécie) | Duração | Auto-Helper | Previsão da hipótese (F) | O que decide |
|---|---|---|---|---|---|---|---|---|
| S1 | P1 | B | Rhydon 423 → **trocar para** Golem 386 aos 4 min | `oddish` (1, Oddish, Planta/Veneno) | 8 min | poção on; catch off | Rhydon: **Stone Edge**; Golem: **Earthquake** (nos dois, Stone Edge e Earthquake empatam até no cooldown; vale o aprendido primeiro) | A regra de desempate. "Aprendido por último" daria Earthquake no Rhydon e Stone Edge no Golem |
| S2 | P1 | B | Rhydon 423 | `rattata` (1, Rattata, Normal) | 4 min | idem | **Hammer Arm** (Lutador ×2), margem 1,67 sobre Stone Edge | A efetividade entra na escolha. "Sempre o golpe com STAB" daria Stone Edge |
| S3 | P1 | B | Gyarados 214 | `rhyhorn` (30, Rhyhorn, Terra/Pedra) | 4 min | idem | **Hydro Pump** (especial), margem 1,47 sobre Aqua Tail (físico, mesmo tipo) | A razão A/D (SpA/SpD × Atk/Def). Sem ela, Aqua Tail (Atk 125 > SpA 60) |
| S4 | P1 | A | Venusaur 124 | `vulpix` (20, Vulpix, Fogo) | 4 min | idem | **Double-Edge** (Solar Beam resistido fica abaixo de Take Down) | Efetividade numa conta já calibrada (IVs exatos) |
| S5 | P2 | B | Gyarados 214 | `hoppip` (1, Hoppip, Planta/Voador) | 3 min | idem | **Ice Fang**, margem 2,98 | Efetividade ×4 (amplificada 5,5) num golpe sem STAB |
| S6 | P2 | B | Exeggutor 413 | `chansey` (60, Chansey, Normal) | 4 min | idem | **Wood Hammer** (físico), margem 1,50 sobre Seed Bomb | Especialista em SpA escolhendo físico pela defesa do alvo |
| S7 | P2 | B | Rhydon 423 → trocar para Golem 386 | `exeggcute` (10, Exeggcute, Planta/Psíquico) | 6 min | idem | Rhydon **Megahorn** (4,40); Golem **Steamroller** (2,38) | Golpe sem STAB de outro tipo ganhando por efetividade |
| S8 | P2 | A | Venusaur 124 | `bulbasaur` (20, Bulbasaur, Planta/Veneno) | 4 min | idem | **Double-Edge** | Repete o S4 com outro tipo; Bulbasaur é RARE (serve também para o C6 se o catch estiver ligado) |

Critério: a hipótese passa se, em cada gravação, ≥ 95% dos hits do líder usarem o golpe previsto. Se outro golpe
aparecer de forma consistente, a gravação mostra qual regra o servidor usa no lugar.

## (b) Captura: medidor de investimento por espécie (revisto em 10/11/2026)

**O que mudou.** A captura não é uma curva por nível. O cliente (C) diz que há um **medidor de investimento por
espécie**:
- o tutorial diz "quanto mais bolas você investe numa espécie, maior a chance";
- a tela Gerenciamento de Captura (`/api/game/used-balls`) mostra o preço de NPC, o ouro gasto, as tentativas totais e as
  tentativas desde a última captura, que zeram ao capturar.

As gravações confirmam (A): no Rattata 1 a chance foi 15/34 na 1ª tentativa depois de uma captura, 15/18 na 2ª e
3/3 na 3ª.

Modelo da sim (F; refeito em 10/11/2026 depois do C1, sobre Rattata, Spearow, Vulpix, Bulbasaur, Rhydon e Blastoise):

  chance = min(1, 0,735 · v/P · (1 + 1,44 · investido_antes/P))

v é o valor da bola da tentativa, P o preço de NPC e investido_antes o valor das bolas desde a última captura, sem a
atual. Não há fator de nível: o C1 derrubou o modelo anterior (0,68 · nível^−0,86). Com Super Ball, a 1ª tentativa
depois de uma captura sai com 0,735 · 50/P: Rattata 0,46, Spearow 0,37, Vulpix 0,037, Rhydon 0,003.

**O que falta medir:**
- **Valor de cada bola.** Ou é a eficiência convertida (Super = 50; padrão, porque a Idle Ball falhou no Rattata), ou é
  o ouro pago.
- **Nível × preço.** Cada ponto medido é de uma espécie diferente, então os dois ainda não se separam.
- **Raridade.**
- **Medidor de antes da gravação.** Precisa ver se o investimento feito antes conta (o used-balls do início responde).

**O que isso muda no plano:**
- Contar capturas informa pouco em espécie cara. Arbok, Pikachu e Bulbasaur, que custam 3000 a 8000, dão 1 a 3
  capturas em 15 a 30 min.
- Informam mais as espécies **baratas**, que fecham um ciclo a cada poucas tentativas: cada ciclo é uma medida da
  chance contra o investimento.
- C3 (Arbok) e C4 (Pikachu) **deixam de ser necessários**. O nível alto já tem o Rhydon 80 (5/608).
- C5 passa do Vulpix (1–3 capturas por bola) para o Geodude 1, onde dá 6 a 20.
- Entram C7 (Geodude 1, preço 300) e C8 (Meowth 20, preço 300). Eles separam preço de nível:
  - C7 × Rattata: mesmo nível, preço 3,75×;
  - C7 × C8: mesmo preço, nível 1 × 20;
  - C8 × C2: mesmo nível, preço 300 × 1000.

**Como gravar (além das regras gerais):**
- Use o **gravador v1.1**.
- Abra a tela **Gerenciamento de Captura** (menu superior) **antes de entrar e logo depois de sair** da hunt. No C5,
  abra também em cada troca de bola. Cada abertura grava o used-balls com o medidor naquele momento.
- Na primeira abertura, anote se a espécie já foi capturada (✓) e quantas "tentativas mais recentes" ela tem. Isso
  separa espécie já capturada × nunca capturada, e medidor zerado × acumulado.
- A conferência é `python -I ferramentas/fase3/conferir_fase3.py`. Ela mostra capturas × esperado pelo modelo,
  partindo do medidor do início.

As capturas esperadas abaixo são do modelo (F), com ~8 tentativas/min (abate em 1 golpe):

| ID | Pri. | Conta | Líder | Hunt (nível, preço, raridade) | Duração | Auto-Helper | Esperado (F) | O que mede |
|---|---|---|---|---|---|---|---|---|
| C1 | P1 | A | Venusaur | `spearow` (10, 100, C) | 8 min (~60 tentativas) | catch on, Super Ball; poção on | ~10 capturas | Chance × investimento no nível 10 (ciclos curtos) |
| C2 | feito | A | Venusaur | `vulpix` (20, 1000, C) | (S4) | Super | 1,2 (observado 2/37) | — |
| C7 | P1 | B | Rhydon | `geodude` (1, 300, C) | 6 min (~45) | catch on, Super Ball | ~12 | Preço no nível 1 (× Rattata 80, já medido) |
| C8 | P1 | A ou B | Venusaur ou Rhydon | `meowth` (20, 300, C) | 15 min (~120) | catch on, Super Ball | ~9 | Nível com preço fixo (× C7) e preço com nível fixo (× C2) |
| C5 | P1 | **B** (tem Poké 398, Great 736, Ultra 3936; a conta A tem 6 Great e nenhuma Ultra) | Rhydon | `geodude` (1, 300) | 3 × 8 min (~60 por bola) | catch on: **Poké**, depois **Great**, depois **Ultra** (abrir o used-balls em cada troca) | Poké 6 / Great 9 / Ultra 13 (pela eficiência) contra 3 / 7 / 20 (pelo ouro) | Valor da bola no medidor: eficiência ou ouro |
| C6 | P2 | A | Venusaur | `bulbasaur` (20, 3000, **R**) | 12 min (~90) | catch on, Super Ball | ~1,8 | Raridade. Pouca informação (1–2 capturas): só se sobrar tempo |
| C3, C4 | — | — | — | `arbok`, `pikachu` | — | — | 1,7 e 1,8 em 15/30 min | **Dispensados** (caros e com pouca informação) |

Estoque: C1, C7 e C8 gastam juntos ~230 Super Balls; C5, ~60 de cada bola (Poké, Great e Ultra).

**Penalidade de entrada (para todas as gravações).** É o boost `shinylock` (C): 1 minuto com −70% de XP e de drops. O
until vem na mensagem `boosts` e já está medido (A, 4 entradas). Falta saber de onde o minuto conta. Para fechar isso,
grave uma vez a sequência hunt A → cidade → espere ~30 s → hunt B, sem parar o gravador entre as hunts. Assim o
`boosts` sai no arquivo mesmo se chegar antes da entrada. Não precisa de nenhuma gravação separada.

## (c) Movimento e perseguição (H1–H4)

As hipóteses estão na tabela "Investigação de movimento" do CLAUDE.md. Medição: `ferramentas/gravador/medir_movimento.py`
(adjacentes por field, selvagens na visão se aproximando, distância ao spawn fora da visão, caminho do herói até o alvo).

| ID | Pri. | Conta | Líder | Hunt (nível) | Duração | Auto-Helper | O que mede |
|---|---|---|---|---|---|---|---|
| M1 | P1 | A | Venusaur 124 | `kangaskhan` (80) — grade real conferida (`dados/testes/field_init_kangaskhan.json`) | 30 min | poção on; catch off | **H1/H4** com lutas longas (~22 s e ~14 golpes por abate; o selvagem tira ~140 por golpe): os outros selvagens da visão têm tempo de vir. É a quantidade de "se aproximando por field" e "adjacentes" com luta longa, contra a rhydon-1h (luta de ~3 s) |
| M2 | P1 | A | Venusaur 124 | `kangaskhan` (80) | 2 × 12 min | idem | **H1 e visão**: os primeiros 12 min com a janela do navegador pequena (ex.: 1280×720, ou zoom 150%), os outros 12 maximizada em 1920×1080. O cliente manda `view {hc, hr}` com o tamanho da vista. Se o raio de perseguição acompanhar o `view`, a sim deve usar o valor recebido e não 27×15 fixo |
| M3 | P2 | B | Golem 386 | `rhydon` (80) — mesma hunt da rhydon-1h | 20 min | idem | **H4 e encontro com o alvo**: o mesmo mapa e os mesmos selvagens da referência, com abate em 1 golpe (Earthquake, margem 1,67). Separa o efeito do tempo de luta do efeito do mapa no "tiles ÷ Chebyshev" (real 0,62 × sim 0,67) |
| M4 | P2 | A | Geodude (nível ~10) | `rattata` (1) — grade real conferida | 20 min | poção on (barata); catch off | **H2/H3**: herói lento (Tackle, ~2 golpes por abate) num mapa aberto; com o herói andando entre alvos distantes, um selvagem que perseguia sai da visão. Mostra se ele volta ao spawn (coleira) ou fica onde estava. O Rattata tira 1 por golpe: sem risco |

Critério: as métricas do `medir_movimento.py` de cada gravação entram como novas colunas na tabela de movimento.
Uma hipótese só vira regra da sim quando reproduzir as colunas reais de pelo menos duas gravações diferentes
(ex.: M1 e rhydon-1h).

## Depois das gravações

- `python -I ferramentas/gravador/analisar_gravacao.py <arquivo>`: cadência, golpes por líder, capturas.
- `python -I ferramentas/gravador/medir_movimento.py <arquivo>`: métricas H1–H4.
- `python -I ferramentas/gravador/atualizar_corpos.py`: cadáveres das espécies novas.
- Regerar o protocolo (`ferramentas/protocolo/regenerar.sh`) se aparecerem mensagens novas.
