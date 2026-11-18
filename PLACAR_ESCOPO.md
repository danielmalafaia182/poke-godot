# Placar do escopo (critério de pronto) — 18/11/2026 (atualizado com a G11)

Escopo (decisão do usuário, 18/11): começar do zero com treinador nível 1 e um Geodude nível 1, ir a todas as hunts, XP
do treinador e do Pokémon, escolha e dano dos golpes, combate completo igual ao original em todas as hunts, loot,
Auto-Potion, Auto-Catch, Nurse Joy e depot, e tudo que envolve IV e Quality. Lotes 3 e 4 congelados.

**Como se conta a %.** Cada item foi quebrado nas regras que o original decide. Uma regra conta como **confirmada** quando
cumpre as três condições:
- foi vista no original, por gravação (A) ou no código do cliente quando a regra mora no cliente (C);
- a sim faz igual;
- há teste ou ferramenta que confere.

Regra só da Pokepedia (B), hipótese ajustada (F) ou decisão do projeto (E) **não** conta. % = confirmadas ÷ regras do item.
Decisões do usuário (Geodude como inicial, VIP desligado etc.) ficam fora da conta.

| Item | % | Confirmadas / regras | Falta para 100% |
| --- | --- | --- | --- |
| 1. Começo do jogo | 60% | 3/5 | IV/Quality do inicial e ouro inicial (servidor; gravação NJ1) |
| 2. Acesso às hunts | 71% | 5/7 | O servidor recusar `enter-hunt` sem nível; `hunt-cooldown` |
| 3. XP do treinador | 75% | 6/8 | Parcelas `gym` e `guild` |
| 4. XP do Pokémon | 80% | 4/5 | Parcela `mentor` |
| 5. Escolha do golpe | 67% | 2/3 | Desempate por cooldown (um só caso gravado) |
| 6. Dano dos golpes | 40% | 4/10 | Fórmula (F), aliado no nível 1 (×2 e o Vulpix), Tackle do selvagem subindo com o nível do aliado, faixa 200+ |
| 7. Combate completo | 69% | 9/13 | Resultado por trecho ±10% (hoje 32/55), status, troca após KO (E), respawn exato |
| 8. Loot | 83% | 5/6 | Mecanismo do −73% no lock (chance × quantidade) |
| 9. Auto-Potion | 100% | 4/4 | — |
| 10. Auto-Catch | 50% | 4/8 | Forma do medidor (c, k são F), raridade, shiny, filtro de nomes |
| 11. Nurse Joy | 100% | 3/3 | — |
| 12. Depot | 67% | 4/6 | Limite de pilhas; o que acontece com o time > 6 |
| 13. IV e Quality | 90% | 9/10 | Arredondamento dos stats no dano (F) |
| **Total** | **70%** | **62/88** | |

## Onde jogar (gravador sempre ligado; cobre o que falta)

- **rattata** com um **Slugma** nível 1 (capturado na slugma) — dano no nível 1, golpe especial sem STAB
- **rattata** com um **Oddish** ou **Sunkern** nível 1 — dano no nível 1, especial com STAB
- **rattata** com um **Rattata** ou **Pidgey** nível 1, até o nível 5 — dano físico com STAB no nível 1 e o Tackle do selvagem subindo com o nível do aliado
- **rhydon** ou **kangaskhan** com o **Rhydon 425** (conta B) — dano do aliado 200+
- qualquer hunt com a **conta B** — parcelas `guild` e `mentor`
- **bulbasaur** com Auto-Catch de **Super Ball** — raridade na captura
- várias hunts diferentes no mesmo dia, entrando e saindo — loot no lock (chance × quantidade)
- uma hunt um pouco forte demais com **3 no time** — troca automática depois do desmaio
- sessões de 1 h ou mais na **rhydon** e na **kangaskhan** com o **Venusaur** — resultado por trecho (abates/min, ouro/h)
- uma **conta nova**, uma vez — IV, Quality e ouro do inicial
- o depot com **mais de 200 pilhas**, uma vez — limite do depot

Jogável de ponta a ponta (D, não entra na %): campanha do zero e varredura das 451 hunts em
`dados/relatorios/campanha_2026-11-18.md`. Nenhuma hunt trava (0 abates sem morte, alvo inalcançável, herói parado).

## 1. Começo do jogo — 3/5 (60%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Treinador começa no nível 1, XP 0 | C | ✅ | `sim/servico_novo_jogo.gd`; `test_jogo_novo` 17/17 |
| Kit: 100 Small Potions e 100 Poké Balls | C (Pokepedia embutida, tutorial) | ✅ | idem |
| Cidade inicial Cerulean | C/A | ✅ | idem |
| Ouro inicial | — (0 é E) | ❌ | não aparece no cliente nem nas gravações |
| IV e Quality do inicial | — (sorteio da sim é E) | ❌ | o servidor sorteia; não gravado |
| *(decisão)* inicial = Geodude Lv.1; os três do original como opção | E | fora da conta | `test_jogo_novo` |

## 2. Acesso às hunts — 5/7 (71%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Região pelo nível do treinador: Outland 150, Orre 500, Nightmare 2000 | C | ✅ | `sim/regras_acesso.gd`; `test_acesso_hunts` 13/13 |
| Hunt pede nível do treinador ≥ nível da hunt (mensagem do original) | C | ✅ | idem |
| Orre: aviso de TMs (Sim/Não), deixa entrar | C | ✅ | idem (sem TMs no jogo, o aviso aparece sempre: E) |
| Nada de item, insígnia ou custo de viagem | C | ✅ | o clique manda direto `enter-hunt` |
| As 451 hunts com mapa, hunt-config e colisão reais | A | ✅ | grade 7/7 idêntica (`test_sim_grade`); 451/451 carregam (`jogabilidade_hunts`) |
| O servidor recusa entrada sem nível | — | ❌ | o cliente nunca manda; não gravado (F: igual ao cliente) |
| `hunt-cooldown {ms}` antes de entrar | C (existe) | ❌ | nunca apareceu em gravação; não simulado |

## 3. XP do treinador — 6/8 (75%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Base por abate = `experience` da espécie | A | ✅ | 200+ abates; `processar_gravacao.py` |
| VIP +50% em parcela própria | A | ✅ | idem |
| Lock de entrada: XP = floor(total × 0,3) por 60 s desde a entrada | A | ✅ | 76/76 abates; T1, C5, M3 |
| Tipo do Dia: floor(20% da base) | A | ✅ | G8 61/61 |
| Streak: floor(base × 0,1% × pontos) | A | ✅ | G7 |
| Curva de XP por nível = a do Pokémon | A | ✅ | 19 níveis de treinador gravados (109–633), todos coerentes |
| Parcela `gym` (insígnias) | C (existe) | ❌ | sempre 0 nas gravações; floor de 1% é F |
| Parcela `guild` | A (existe) | ❌ | vista na conta B (24 em 548), regra desconhecida; não simulada |

## 4. XP do Pokémon — 4/5 (80%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Só o Pokémon ativo ganha XP (um `poke-xp` por abate) | A | ✅ | 807/807 `poke-xp` com um Pokémon (rhydon-1h, M3, S2) |
| Curva de XP (cúbica até 150, termos acima) | A+B | ✅ | 27 níveis gravados (1–442), todos coerentes |
| Parcelas iguais às do treinador, sem streak | A | ✅ | G7/G8 |
| Subir de nível não cura | A | ✅ | HP absoluto mantido nas gravações |
| Parcela `mentor` | A (existe) | ❌ | só na conta B; regra desconhecida |

## 5. Escolha do golpe — 2/3 (67%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Sempre o mesmo golpe por indivíduo; maior dano esperado com os stats do indivíduo | A | ✅ | S1–S4, C1, M1, c2, C8, T1 (324+ golpes, 100 indivíduos) |
| Empate exato (poder, tipo, categoria e cooldown) → o primeiro da lista | A | ✅ | Stone Edge 58/58, Earthquake 59/59 |
| Desempate por cooldown | A (1 caso) | ❌ | só o Solar Beam × Petal Dance |

## 6. Dano dos golpes — 4/8 (50%)

Golpes explicados pela sim, de 7.567 gravados (`dados/relatorios/ajuste_dano.md`, variante padrão "e" com piso 3): aliado
97,3% e selvagem 99,1%. Por faixa: aliado 1–4 98,1%, 80–199 99,6%, 200+ 80,9%; selvagem 1–4 100%, 80–199 99,2%.

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Aleatório 0,85–1,00 | A | ✅ | máx/mín ≤ 1,17 em 72 indivíduos |
| Efetividade amplificada (×1,75, ×2,5, ×5,5; ÷1,5) | A+B | ✅ | `eff` nos hits |
| Piso 2 (aliado), 1 (selvagem), inclusive com eff 0 | A | ✅ | Gastly × Rattata; 1 em 880 |
| Selvagem ×1,8 | A | ✅ | envelopes de Rhydon, Kangaskhan, Venusaur |
| Fórmula (2L/5+2)·Poder·A/D/50·STAB | F | ❌ | coerente com 97,8% dos golpes, mas é hipótese |
| Stats contínuos no selvagem, arredondados no aliado | F forte | ❌ | 15/15 indivíduos na rhydon-1h |
| Defesa do selvagem nível 1 comum a todos os indivíduos | A (o efeito) | ❌ | G11: SpD 0,81 explica 177/177 golpes do Vulpix nível 2–3; o S1/S2 dá 0,77 e o c5 destoa. Não implementado (a sim sorteia a defesa por indivíduo) |
| Aliado no nível 1: dano só em valores pares (×2) | A (o efeito) | ❌ | G11 (14/16) e geodude-10min (6/8); o modelo `x2` explica o Geodude, mas não o Vulpix (0/88) |
| Tackle do selvagem nível 1 sobe quando o aliado sobe (5 → 7) | A (o efeito) | ❌ | G11, 80 golpes; nenhum ataque constante explica (41/80) |
| Piso 3 no ataque do aliado; faixa 200+ (80,9%) | F | ❌ | geodude-10min; c5 61,7% |

## 7. Combate completo — 9/13 (69%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Tick de 200 ms; field a cada 2 ticks | A | ✅ | todas as gravações |
| HP do aliado max(24, 12×stat) e do selvagem max(120, 35×stat) | A | ✅ | Venusaur, Geodude, 4 espécies selvagens |
| Ritmo: aliado 1600 ms; selvagem ~2000 ms | A | ✅ | diferencial (moda 1600) |
| Passo: herói reto 600, diagonal 1000/1200; selvagem 1000/1200 e 2000 | A | ✅ | `medir_passos.py`, 45 instâncias; a sim tem a mesma cadência |
| Alvo = menor tempo de caminho até encostar | A | ✅ | 2295/2400 trocas; `test_sim_alvo` |
| Perseguição só dentro de 13×13 | A | ✅ (sim usa 7: ver Falta) | rhydon-1h, M1, M2 |
| Golpes que o cliente não recebe vão no próximo field; field-kill antes do golpe final | A | ✅ | rhydon-1h |
| Respawn 60 s no mesmo spawn, o mesmo indivíduo | A | ✅ | diferencial; maxHp constante por slot |
| Penalidade de entrada (lock 60 s; mesma hunt pela cidade não penaliza) | A | ✅ | 12 entradas, T1 |
| Resultado por trecho de hunt, real × sim, ±10% (abates/min, XP/h, mortes/h, ouro/h, ao lado do herói) — critério do movimento desde 18/11 | A × sim | ❌ | 32/55 em 11 trechos (`dados/relatorios/resultado_trechos_2026-11-18.md`): mortes 11/11, ao lado 7/11, abates 6/11, XP 6/11, ouro 2/11; quando diverge, a sim mata menos |
| Troca automática após KO (aleatória, 5 s de recarga) | E | ❌ | decisão do usuário; não gravado |
| Efeitos de status | — | ❌ | não implementado |
| Tempo exato de respawn em onda (`waveRespawnAt`) | — | ❌ | não medido |

## 8. Loot — 5/6 (83%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Tabela do creatures.json, chance em 1/100.000, quantidade min–max | A | ✅ | Rhydon Horn 83,3% × 83,32% (60 abates); `processar_gravacao.py` |
| Uma rolagem por abate, mais as extras do Streak | A/C | ✅ | G7 |
| Tipo do Dia ×1,4 | A | ✅ | G10 (×1,2 rejeitado) |
| Venda ao Mark pelo `npcPrice`; o Mark não compra poção, pedra, revive | A/C | ✅ | G1 |
| Itens e pedras do snapshot (670) com o id do servidor | A | ✅ | `test_catalogo_itens` 12/12 |
| Lock de entrada: drops ~0,27× (chance × quantidade) | A (efeito) | ❌ | mecanismo F |

## 9. Auto-Potion — 4/4 (100%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Dispara no tick em que o HP fica ≤ limite (50% padrão) | A | ✅ | 42/42 + 49/49 cruzamentos |
| Sem recarga | A | ✅ | menor intervalo 1988 ms |
| Escolha: a menor que cobre o que falta, senão a maior | A | ✅ | 208/208 + 200/200 |
| Cura até o valor da poção, limitada ao que falta | A | ✅ | 60+ curas |

## 10. Auto-Catch — 4/8 (50%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Joga uma bola por abate (a do Auto-Helper, não `balls.selected`) | A | ✅ | gravações |
| O capturado chega no nível 1 (poke-delta) | A | ✅ | 5/5 na rhydon-1h |
| A chance sobe com o investimento desde a última captura; `goldSpent` zera com ela | A | ✅ | Rattata 15/34, 15/18, 3/3; Spearow; C8 |
| Valor da bola no medidor = ouro pago; o nível não pesa | A | ✅ | C5 (logL −190,6 × −294,5); Meowth 20 × Geodude 1 |
| Forma do medidor: c 0,814, k 1,14 | F | ❌ | ajuste em 8 espécies; esperado × observado bate (C5 125/127, C8 18,4/17) |
| Raridade | — | ❌ | Bulbasaur RARE 2,05/0 inconclusivo |
| Shiny (shinyBase por tier) | C (existe) | ❌ | desconhecido |
| Filtro de nomes do Auto-Catch | C | ❌ | não repassado à sim |

## 11. Nurse Joy — 3/3 (100%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Cura o time inteiro, na hora | A | ✅ | G4; `test_sim_cidade` 48/48 |
| Grátis, sem recarga | A/C | ✅ | idem |
| Resposta `joy-healed` sem campos | A | ✅ | idem |

## 12. Depot — 4/6 (67%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| Guarda só itens (bolas ficam na BAG) | A | ✅ | G4; `test_migracao_depot_bolas` 7/7 |
| Mover leva a pilha inteira | A | ✅ | G4 |
| "Guardar tudo" esvazia a BAG (inclusive poções) | A | ✅ | G4 |
| Resposta `{inventory, depot}` com `{id, name, icon, category, npcPrice, quantity}` | A | ✅ | G4 |
| Limite de pilhas (89 sem aviso no original; 200 é E) | — | ❌ | não visto o teto |
| BOX 3000 (conta VIP) e time de 6 | A/C | ❌ | o limite da conta sem VIP não foi visto |

## 13. IV e Quality — 9/10 (90%)

| Regra | Fonte | Situação | Evidência |
| --- | --- | --- | --- |
| IV de 1 a 32 por stat | A+C | ✅ | `rollGrowthSet`; `ivTotal` gravados; `dados/correcoes.json` |
| Quality pelos pesos do cliente (não existe 1,6–1,7) | C | ✅ | `rollQuality`; `test_sim_regras` |
| Stat = round(L/100 × (base + 2·IV) × Q^exp) (0,95 HP/vel, 0,8 demais) | B+C+A | ✅ | Venusaur 109 com IVs 26/5/4/18/17/28 fecha os stats e o Power 562 |
| Power = round(Σ stats × Q) | C+A | ✅ | idem |
| HP de combate a partir do stat de HP | A | ✅ | ver item 7 |
| Stats contínuos no dano do selvagem | F | ❌ | item 6 |
| O capturado é um sorteio novo (não herda o IV e a Quality do selvagem) | A | ✅ | 12 de 57 capturas incompatíveis com o maxHp do selvagem (por acaso: 15%); `dados/relatorios/capturado_x_selvagem.md` |
| Quality do capturado pelos pesos do cliente | A+C | ✅ | 218 capturas, χ² = 2,8 (8 gl); o jogo sorteia com a mesma tabela (`dados_pokemon.gd`) |
| IV do capturado 1..32 uniforme por stat | A+C | ✅ | ivTotal médio 97,2 (dp 21,7) × 99 (22,6) |
| Stats exibidos do capturado no nível 1 = fórmula com Quality e IV | A+C | ✅ | 218/218 |
