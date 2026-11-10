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

1. Abra o jogo com o gravador ativo (`ferramentas/gravador/gravador_ws.user.js`) **antes** de entrar na hunt, para o
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

Duração total: **~4 h 30**. Prioridade 1 (P1) ≈ 2 h fecha o essencial de cada ponto; P2 dá folga estatística.

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

## (b) Captura por nível e por bola

**Hoje (A):** Super Ball, nível 1: 35/59 (59%); nível 80: 5/608 (~0,8%). A sim interpola no logit e ignora a espécie (F).
Faltam pontos no meio da curva, as outras bolas e o efeito da espécie. `capturaBase` está vazio em 420 de 647 espécies;
o campo que varia entre hunts do mesmo nível é a `raridade`.

Uma tentativa por abate (auto-catch). As durações supõem ~8 abates/min com abate em 1 golpe. É uma estimativa: a
rhydon-1h fez 6,9/min com 2–3 golpes por abate. As tentativas miram ~12 sucessos pela curva atual.

| ID | Pri. | Conta | Líder | Hunt (nível, espécie, raridade) | Duração | Auto-Helper | Esperado pela curva atual (F) | O que mede |
|---|---|---|---|---|---|---|---|---|
| C1 | P1 | A | Venusaur 124 | `spearow` (10, Spearow, COMMON) | 5 min | catch **on**, Super Ball; poção on | ~45% → ~40 tentativas | Ponto da curva no nível 10 |
| C2 | P1 | A | Venusaur 124 | `vulpix` (20, Vulpix, COMMON) | 6 min | catch on, **Super Ball** | ~30% → ~45 tentativas | Nível 20 (base das comparações C5/C6). Pode ser a mesma sessão do S4, se o catch estiver ligado nela |
| C3 | P1 | B | Rhydon 423 | `arbok` (40, Arbok, COMMON) | 15 min | catch on, Super Ball | ~10% → ~120 tentativas | Nível 40 |
| C4 | P2 | B | Rhydon 423 | `pikachu` (60, Pikachu, COMMON) | 30 min | catch on, Super Ball | ~3% → ~240 tentativas (~7 sucessos) | Nível 60. Longa porque a chance é baixa; com 30 min o intervalo fica largo, mas já separa curvas |
| C5 | P1 | A | Venusaur 124 | `vulpix` (20) | 3 × 6 min | catch on: **Poké**, depois **Great**, depois **Ultra** Ball (trocar a bola no Auto-Helper e anotar a hora) | — | Efeito da bola com nível e espécie fixos (a Super Ball vem do C2) |
| C6 | P2 | A | Venusaur 124 | `bulbasaur` (20, Bulbasaur, **RARE**) | 6 min | catch on, Super Ball | se a raridade não importa, igual ao C2 (~30%) | Efeito da espécie/raridade no mesmo nível e bola |

Antes do C3–C5, confira o estoque: são ~120 Super Balls no C3, ~240 no C4 e ~45 de cada bola no C5. Se faltar alguma
bola, pule a linha e me avise; o resto continua valendo.

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
