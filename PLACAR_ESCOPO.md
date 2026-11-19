# Placar do escopo por classe — 19/11/2026

Política em `ESTRATEGIA.md`. Escopo: do zero (treinador 1, Geodude 1) a todas as hunts, com XP, golpes e dano, combate,
loot, Auto-Potion, Auto-Catch, Nurse Joy, depot, IV e Quality. O placar antigo (84 regras, uma conta só) foi
reclassificado: cada regra caiu numa classe e é contada pelo critério dela.

| Classe | Critério | Placar |
| --- | --- | --- |
| **1 — exata** | Igual ao original (gravação, cliente ou Pokepedia) e conferida por teste ou ferramenta | **53/53** |
| **2 — equivalente no resultado** | As 5 métricas a ±10% do real ou dentro do ruído da amostra, em cada trecho (`ferramentas/validar_resultado.py`) | **157/160** em 32 trechos (`dados/relatorios/validar_resultado.md`) |
| **3 — desenhada** | Decidida, documentada em uma linha, valor em `dados/balanceamento.json` | **22/22** decididas (17 com valor no JSON, 5 como regra no código) |

A classe 2 conta pelo resultado, não por regra: as regras dela (lista abaixo) estão prontas quando o validador passa.

## Classe 1 — exata (53/53)

| Área | Regra | Situação | Evidência |
| --- | --- | --- | --- |
| Começo | Treinador nível 1, XP 0 | ✅ | C; `test_jogo_novo` |
| Começo | Kit: 100 Small Potions e 100 Poké Balls | ✅ | C (Pokepedia embutida) |
| Começo | Cidade inicial Cerulean | ✅ | C/A |
| Acesso | Região pelo nível do treinador: Outland 150, Orre 500, Nightmare 2000 | ✅ | C; `test_acesso_hunts` |
| Acesso | Nível do treinador ≥ nível da hunt, com a mensagem do original | ✅ | C |
| Acesso | Aviso de TMs em Orre (Sim/Não) | ✅ | C |
| Acesso | Nada de item, insígnia ou custo de viagem | ✅ | C |
| Acesso | As 451 hunts com mapa, hunt-config e colisão reais | ✅ | A; grade 7/7; 451/451 jogáveis |
| XP | Base por abate = `experience` da espécie | ✅ | A |
| XP | VIP +50% em parcela própria | ✅ | A |
| XP | Lock de entrada: floor(total × 0,3) por 60 s desde a entrada | ✅ | A, 76/76 |
| XP | Tipo do Dia: floor(20% da base); rotação com 5 dias gravados | ✅ | A (G8, G11) |
| XP | Streak: floor(base × 0,1% × pontos) | ✅ | A (G7) |
| XP | Curva de XP do treinador = a do Pokémon | ✅ | A, 19 níveis (109–633) |
| XP | Só o Pokémon ativo ganha XP | ✅ | A, 807/807 |
| XP | Curva de XP do Pokémon | ✅ | A+B, 27 níveis (1–442) |
| XP | Parcelas do Pokémon = as do treinador, sem streak | ✅ | A |
| XP | Subir de nível não cura | ✅ | A |
| Golpe | O mesmo golpe por indivíduo; maior dano esperado com os stats dele | ✅ | A, 100+ indivíduos |
| Golpe | Empate exato → o primeiro da lista | ✅ | A |
| Dano | Aleatório 0,85–1,00 | ✅ | A |
| Dano | Efetividade amplificada (×1,75, ×2,5, ×5,5; ÷1,5) | ✅ | A+B |
| Dano | Piso 2 (aliado) e 1 (selvagem), inclusive com eff 0 | ✅ | A |
| Dano | Selvagem ×1,8 | ✅ | A |
| Dano | Fórmula na faixa 80–199 (o número que aparece na tela) | ✅ | 99,6% dos 4.510 golpes do aliado, 99,2% dos 1.787 do selvagem |
| Combate | Tick 200 ms; field a cada 2 ticks | ✅ | A |
| Combate | HP do aliado max(24, 12×stat) e do selvagem max(120, 35×stat) | ✅ | A |
| Combate | Ritmo: aliado 1600 ms, selvagem ~2000 ms | ✅ | A |
| Combate | Golpes não recebidos vão no próximo field | ✅ | A |
| Combate | Penalidade de entrada (lock de 60 s; a mesma hunt pela cidade não penaliza) | ✅ | A |
| Loot | Tabela do creatures.json, chance em 1/100.000, quantidade min–max | ✅ | A |
| Loot | Uma rolagem por abate, mais as extras do Streak | ✅ | A/C |
| Loot | Tipo do Dia ×1,4 | ✅ | A (G10) |
| Loot | Venda ao Mark pelo `npcPrice`; não compra poção, pedra, revive | ✅ | A/C |
| Loot | 670 itens do snapshot com o id do servidor | ✅ | A |
| Auto-Potion | Dispara no tick em que o HP fica ≤ limite | ✅ | A, 91/91 |
| Auto-Potion | Sem recarga | ✅ | A |
| Auto-Potion | A menor que cobre o que falta, senão a maior | ✅ | A, 408/408 |
| Auto-Potion | Cura até o valor da poção, limitada ao que falta | ✅ | A |
| Auto-Catch | Uma bola por abate (a do Auto-Helper) | ✅ | A |
| Auto-Catch | O capturado chega no nível 1 | ✅ | A |
| Auto-Catch | Filtro de nomes (vírgula; em branco = todos; vale para os dois modos) | ✅ | C; `test_auto_catch_filtro` 3/3 |
| Nurse Joy | Cura o time inteiro, na hora, grátis, sem recarga; resposta `joy-healed` | ✅ | A (G4) |
| Depot | Só itens (bolas ficam na BAG); move a pilha inteira; "guardar tudo" esvazia a BAG | ✅ | A (G4) |
| Depot | Resposta `{inventory, depot}` com os campos do original; time de 6 | ✅ | A/C |
| IV/Quality | IV de 1 a 32 por stat | ✅ | A+C |
| IV/Quality | Quality pelos pesos do cliente (não existe 1,6–1,7) | ✅ | C; capturados χ² 2,8 |
| IV/Quality | Stat = round(L/100 × (base + 2·IV) × Q^exp); Power = round(Σ × Q) | ✅ | A+B+C |
| IV/Quality | O capturado é um sorteio novo (não herda o selvagem) | ✅ | A, 12/57 incompatíveis |
| IV/Quality | Quality e IV do capturado pelo sorteio do cliente | ✅ | A, 218 capturas |
| IV/Quality | Stats exibidos do capturado no nível 1 | ✅ | A+C, 218/218 |
| Evolução | Nível de evolução, pedras mantêm o nível, sem pedra volta ao Lv.1, só em Cerulean | ✅ | C/A (G3) |
| Preços | Bolas e poções pelo `priceGold`, venda de Pokémon pelo `sellValue` | ✅ | A (G1, G2) |

## Classe 2 — equivalente no resultado

Pronta quando o validador passa nos trechos de todas as gravações. As regras abaixo são os meios; o placar é o do
validador.

**Validador (19/11):** 157/160 em 32 trechos, de 14 gravações e da gravação livre (22 h de caça em duas abas). Só com
±10% estrito, 105/160. Por grandeza:

| Grandeza | Dentro |
| --- | --- |
| Abates/min | 32/32 |
| XP/h | 32/32 |
| Mortes/h | 32/32 |
| Capturas/h | 32/32 |
| Ouro/h | 29/32 |

- **O que ficou fora:** 3 trechos de ouro/h (larvitar 13,6 min, tyranitar 6 min, larvitar 5,4 h na borda do percentil 2,5).
  É o loot raro e caro: pelo acaso se esperam ~1,6 trechos fora da faixa de 95%. O ouro por abate dos trechos longos bate
  com a tabela (17,9–21 × 18,6).
- **Ajustes da sim que fecharam o resto:**
  - o alvo vem ao encontro do herói (`alvo_vem_ao_encontro`; fechou M3 e S1, os de abate num golpe só);
  - a borda de perseguição continua em 7, porque com o maxHp gravado ela é a melhor (122 × 118–120 com 10, 11 e 13).
- **Mudanças só no validador (o jogo não muda):**
  - os selvagens da sim têm o maxHp gravado de cada slot, o que tira o ruído de instância (o M1 foi de −23% para −5%);
  - o trecho é cortado quando o Auto-Helper muda;
  - o estado usa o limite da Auto-Potion e a bola gravados.
- **Dano de nível 1:** o G11 tem 32 abates no real contra 24 na sim; está dentro do ruído e foi decidido como classe 3
  (abaixo).

| Regra (meio) | Situação hoje |
| --- | --- |
| Movimento: passo, perseguição (13×13 no real, 7 na sim), caminho até o alvo, chegada de selvagens | Cadência por passo igual (A); o resultado é medido pelo validador |
| Alvo = menor tempo de caminho até encostar | A, 2295/2400 |
| Dano nos extremos: aliado no nível 1 (valores pares), defesa comum do selvagem nível 1, Tackle do selvagem subindo com o nível do aliado, faixa 200+ (80,9%) | Medido (G11); fechado pelo resultado (abates/min), não pela fórmula |
| Lock de entrada nos drops (~0,27×) | Ouro/h no validador |
| Medidor de captura (forma c, k; valor da bola = ouro) | Capturas/h no validador |
| Respawn 60 s no mesmo spawn | A |

## Classe 3 — desenhada (22/22 decididas)

Os valores com número estão em `dados/balanceamento.json`, cada um com uma linha de motivo, e são lidos por
`sim/balanceamento.gd`. O teste `test_balanceamento` confere que mudar o JSON muda o jogo.

| Regra | Decisão | Onde |
| --- | --- | --- |
| Ouro inicial | 0: o kit cobre a primeira hora | `jogo_novo.ouro_inicial` |
| Troca automática após desmaio | Aleatória entre os vivos do time, 5 s sem troca manual | `combate.troca_cooldown_ms` |
| Parcela `gym` e drop das insígnias | +1% da base e +1% de rolagem extra por insígnia ativa | `combate.insignia_pct_*` |
| Sem caminho até o alvo | Ataca o encostado | `combate.alvo_troca_se_bloqueado` |
| `start` numa ilha sem spawn | Começa na ilha que alcança mais spawns | `combate.inicio_ilha_com_spawns` |
| Cadáver de espécie sem dado | O próprio sprite escurecido | `combate.cadaver_generico` |
| Golpes de poder 600 (assinatura) | Fora da escolha | `combate.golpe_poder_maximo` |
| Shiny na captura | Vazio enquanto a sim não sorteia shiny (backlog) | `combate.captura_shiny_base` |
| Cartão de derrota | 4,5 s (shiny 7 s), até 30 por instância | `apresentacao.*` |
| Limites do depot e da BOX | 200 pilhas, 3000 Pokémon | `cidade.capacidade_*` |
| Inicial fora da BOX | Sempre no time | `cidade.starter_no_time` |
| Limite por compra | 100 mil | `cidade.qtd_max_por_compra` |
| Daily Gift | Boost de 1 h, somando se repetir | `diarias.gift_boost_ms` |
| Daily Kill | 3 opções; quantidades por dificuldade | `diarias.kill_*` |
| Daily Catch | Multiplicador de XP em [1,5; 18], múltiplo de 0,5 | `diarias.catch_mult_*` |
| Turbo da soneca | Desligado (sem diamantes) | `jogador.soneca_turbo_disponivel` |
| Jogo fechado numa hunt | Continua até 15 min | `jogador.fechado_caca_max_s` |
| IV e Quality do inicial | Sorteio do cliente (o mesmo do capturado, A) | `sim/servico_novo_jogo.gd` (regra) |
| Receita das pedras | Tipo principal + tipos ganhos; 4 pedras a partir de hunt nível 40 | `sim/servico_cidade.gd` (regra) |
| Dano do aliado no nível 1–5 | Fórmula do nível alto com piso 3 no ataque; a diferença para o real (G11, rattata livre) fica dentro do ruído dos trechos | `sim/regras.gd` `piso_ataque_aliado` |
| Sem servidor | Entrada sem nível barrada no mapa como no cliente; `hunt-cooldown` 0; sem guilda nem mentor (parcelas 0); golpes de status sem efeito | regras sem número |
| Inicial do jogo novo | Geodude nível 1 (decisão do usuário) | `sim/servico_novo_jogo.gd` |

## Onde jogar (só para conferir; nada espera gravação)

- **rattata** com um **Slugma**, um **Oddish** e um **Rattata** nível 1 — dano no nível 1
- **rhydon** ou **kangaskhan** com o **Rhydon 425** (conta B) — dano 200+
- sessões longas em qualquer hunt, com o gravador ligado — resultado por trecho (validador)
