# Calibração da simulação — resumo ao fechar a fase 3 (10/11/2026)

Fontes: **A** observado no servidor original (gravações), **B** Pokepedia ou relato do usuário, **C** extraído do
cliente original, **D** testado localmente, **E** decisão do projeto, **F** hipótese.
Os parâmetros vivem em `sim/regras.gd` (`PARAMETROS`, cada um com a origem no comentário). Gravações em
`poke har/gravacoes/` e `poke har/gravacoes/fase3/`. Ferramentas citadas em `ferramentas/`.

Validação de conjunto: o diferencial do Rhydon com o Venusaur passa em 27/30 critérios contra a rhydon-1h e em 23/26
contra a gravação antiga. Os critérios de fora são sempre os mesmos:
- ms/tile do herói e do selvagem: caminho e perseguição (ver Movimento);
- hits selvagens/min lutando na 1h, na borda: acúmulo no herói;
- curas/min na antiga.

## Tempo e passos

| Regra | Fonte | Evidência | Aberto |
| --- | --- | --- | --- |
| Tick de 200 ms; `field` a cada 2 ticks; `seq` conta ticks | A | todos os logs | — |
| Espera antes do passo = stepMs × (2 se diagonal), arredondada para cima ao tick | A | `medir_passos.py`: herói reto 600 ms (354/368), diagonal 1000/1200; selvagem reto 1000/1200, diagonal 2000/2200 | por que às vezes sai 1 tick depois (F: relógio real ±1 ms) |
| Taxa do tick extra: herói diagonal 0,33, selvagem reto 0,36 e diagonal 0,04 | A (taxa) / F (mecanismo) | contagens somadas das gravações | mecanismo |
| Treinador = posição do herói | A | 6613/6613 fields | — |
| Caminho de tempo mínimo, desempate pelas frequências medidas | F | frequências de direção (A) | — |

## Combate

| Regra | Fonte | Evidência | Aberto |
| --- | --- | --- | --- |
| Ataque do aliado a cada 1600 ms (grade fixa) | A | 557 hits de Solar Beam | — |
| Selvagem a cada ~2000 ms (+1 tick com p 0,25); 1º golpe ~2 s depois de encostar | A (ritmo) / F (extra, 1º golpe) | 532 hits selvagens; 4 casos de 1º golpe | distribuição do 1º golpe |
| HP aliado = max(24, round(12 × stat HP)); HP selvagem = max(120, 35 × stat HP) | A + C | todos os maxHp medidos | — |
| Stats: round(L/100 · (base + 2·IV) · Q^exp), exp 0,95 HP/vel e 0,8 nos outros; IV 1–32; rollQuality | B + C | paridade com o cliente; IVs do Venusaur fecham o ivTotal | — |
| Dano = (2L/5+2) · Poder · A/D / 50 · STAB 1,5 · eff · (1,8 se selvagem) · U(0,85..1) | F (forte) | envelopes contêm todos os observados; 15/15 indivíduos na 1h | fator 1,8 e arredondamento (round × floor) |
| Stats no dano: selvagem sem arredondar, aliado exibido | F (forte) | SpD contínua 15/15 × inteira 2/15 (1h) | Geodude nível 1 (Atk exibido 1 tira 6–8) |
| Efetividade amplificada (1,5→1,75; 2→2,5; 4→5,5; ½→⅓; 0 = 1) | B + A | `eff` nos hits | — |
| Piso de dano: 2 aliado, 1 selvagem, mesmo com eff 0 | A | Gastly × Rattata; 880 hits do Rattata | — |
| Golpe do selvagem/aliado: maior dano esperado com os stats do indivíduo; empate exato → primeiro da lista; fixo por indivíduo | A | S1–S4 324 hits; C1, M1, c2, C8 (15/15), T1; S3 15/15 coerentes | desempate por cooldown (só um caso) |
| Golpes de poder 600 nunca usados | F | ausentes em todas as gravações | — |

## Abate, XP, loot, cura

| Regra | Fonte | Evidência | Aberto |
| --- | --- | --- | --- |
| XP base = `experience`; VIP +50% em parcela separada | A | 200+ abates | parcela extra da conta B (×1,554; `guild`, `mentor`) |
| Curva de XP: round(50/3 · (L³ − 6L² + 17L − 12)) | B + A | subidas do Geodude | — |
| Loot: tabela de `creatures.json`, chance /100.000, quantidade min–max | A + C | Rhydon: Horn 83,3% × 83,32% | — |
| Auto-Potion no mesmo tick em que HP ≤ 50%; menor poção que cobre, senão a maior; sem recarga | A | `medir_pocao.py` 91/91 cruzamentos, 408/408 escolhas | — |
| Respawn em 60 s, no spawn, mesmo indivíduo | A | todos os respawns medidos (60,0 s) | onda (`waveRespawnAt`) não estudada |
| Cadáver ~20 s; tabela espécie → cadáver só do que foi gravado | A | `dados/corpos_por_especie.json`: 11 espécies, 4 shiny | as outras espécies (corpo genérico, E) |

## Penalidade de entrada (boost `shinylock`)

| Regra | Fonte | Evidência | Aberto |
| --- | --- | --- | --- |
| −70% de XP (floor × 0,3) e de drops por 60 s; sem shiny | C (texto) + A | 76/76 abates; drops 0,27× (42 × 153,5 esperados) | drops: chance × quantidade (F: chance) |
| O minuto conta da entrada | A | 12 entradas, 58,9–61,4 s; T1: 29 s na cidade não contaram | o S3 (lock de 20–30 s, sem `boosts`) |
| Hunt diferente penaliza; mesma hunt pela cidade não | A | T1 (rattata → cidade → spearow; spearow → vulpix; vulpix → cidade → vulpix sem lock); S1 | — |
| Sessão expirada (15 min com o jogo fechado) penaliza | B-relatado | não gravado | gravar se importar |
| O lock atravessa a retomada `:rN` | A | rhydon-1h | — |

## Captura

| Regra | Fonte | Evidência | Aberto |
| --- | --- | --- | --- |
| Medidor por espécie: o investimento desde a última captura aumenta a chance e zera nela | C (tutorial, tela) + A | hazards Rattata 15/34 → 15/18 → 3/3; Spearow 13/28 → 7/14 → 7/7; `goldSpent` do used-balls = ouro desde a última captura | — |
| Valor da bola = ouro pago (priceGold) | A | C5 (Geodude 1): logL −190,6 × −294,5 pela eficiência; valores livres Great 23 e Ultra 143 (ouro 20 e 130) | — |
| chance = min(1, c · v/P · (1 + k · investido_antes/P) · (1 + bônus)), c 0,814, k 1,14 | F | máxima verossimilhança em 7 espécies; esperado × observado: Rattata 35,1/33, Spearow 26,5/27, Vulpix 4,1/3, Rhydon 2,7/4, Geodude 125,2/127, Meowth 18,4/17 | a forma exata, e se é linear em `investido` |
| Sem fator de nível | A | Spearow 10 × Rattata 1; Meowth 20 × Geodude 1 com o mesmo preço (ganho de logL 0,13) | — |
| Raridade | F (sem efeito medido) | Bulbasaur RARE 0/84, esperado 2,0 (P = 0,13) | inconclusivo |
| Master Ball garante | C / B-relatado | não gravado | — |
| Shiny fora do medidor: min(1, shinyBase(tier) · catchRate) | C | as 5 falhas de Idle Ball foram em shiny | shinyBase por tier (servidor) |
| Bônus de guild "Mestre das Pokébolas" | C | texto do talento | valor por nível; as contas A e B podem diferir |
| O capturado chega como nível 1 | A | 5/5 na 1h | — |

## Movimento dos selvagens (desvio conhecido)

| Regra | Fonte | Evidência | Aberto |
| --- | --- | --- | --- |
| Perseguem só com \|dx\| ≤ 13 e \|dy\| ≤ 13; fora disso ficam parados | A | rhydon-1h, M1, M2, M3 | a sim usa 13 × 7 (E/F, ver abaixo) |
| `view` vem do zoom, não da janela | C | chunk do cliente; M2 | se o raio acompanha o zoom (M5) |
| Coleira (volta ao spawn) | F | nenhum retorno observado | M4 |
| O que limita o acúmulo de não-alvos no herói | aberto | chegadas/min, real × sim 13: M1 3,35 × 1,07; M2 1,45; 1h 0,76 × 2,64; M3 0,32 × 1,88 | sem regra que feche as quatro gravações; M6 |

## Regras do projeto (E) que a simulação aplica

- Troca automática aleatória após KO, sem curar, com 5 s de bloqueio da troca manual.
- Fim da hunt sem reserva viva.
- Um cartão de derrota por vez, até 30 por instância.
- Contador Capture por instância.
- IV 1–32.
- VIP desligado no jogo offline.
- Cores do treinador.
- Corpo genérico para espécie sem cadáver gravado.
- Saves espaçados em 10 s na hunt.

## O que ficou em aberto, por peso no jogo

1. **Acúmulo no herói em luta curta.** Mexe em dano recebido e curas nas hunts rápidas. Sem regra; a sim fica com 7.
2. **Bônus de captura:** guild, shinyBase, raridade. Hoje é 0 ou vazio, e o jogo offline não tem guild.
3. **Fator 1,8 e arredondamento do dano.** F forte; nenhum caso medido contradiz.
4. **Parcela extra de XP da conta B** (`guild`, `mentor`): sistemas que o offline não tem.
5. **Detalhes isolados:** expiração de sessão (B-relatado), o S3, o 1º golpe do selvagem, `waveRespawnAt`.
