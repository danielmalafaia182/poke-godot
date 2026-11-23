# REGRAS — mapa completo das regras e parâmetros do jogo

Gerado por `ferramentas/regras/catalogo.py` a partir do código (valores em execução, comentários de origem), dos motivos
de classe 3 e das tabelas do `PLACAR_ESCOPO.md`. Não edite à mão: mude o código ou os Resources e gere de novo.
Origem: A observado no original · B Pokepedia · C cliente · D teste · E decisão nossa · F hipótese.

| Status | Parâmetros e regras |
| --- | --- |
| desenhada por nós | 116 |
| comprovada contra o original | 111 |
| replicada do cliente sem confirmação no servidor | 48 |
| em aberto | 16 |
| **total** | **291** (204 parâmetros editáveis no Game Master + 87 regras de fórmula) |

## Ditto

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `debuff` — −25% de HP, Atk, Def, SpA e SpD ao transformar (C) | `0.25` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_ditto.gd` |  | `dados/regras/<perfil>/RegrasDitto.tres → debuff` |
| `duracao_s` — a transformação dura 12 h (C) | `43200` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_ditto.gd` |  | `dados/regras/<perfil>/RegrasDitto.tres → duracao_s` |
| `nivel_recebe` — fonte offline: um Ditto no treinador 100 (classe 3) | `100` | E | desenhada por nós | comentário em `sim/servico_ditto.gd` | o Ditto vem da loja de diamantes (online) | `dados/regras/<perfil>/RegrasDitto.tres → nivel_recebe` |

## Evolução

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| Nível de evolução, pedras mantêm o nível, sem pedra volta ao Lv.1, só em Cerulean | (regra no código) | A | comprovada contra o original | C/A (G3) | | código da sim |

## Golden Stars

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `candidatos` — A | `9` | A | comprovada contra o original | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → candidatos` |
| `duracao_s` — A: 6 h | `21600` | A | comprovada contra o original | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → duracao_s` |
| `escolha_direta_ouro` — C: "Escolha direta" (pick-species); custo classe 3 | `50000` | E | desenhada por nós | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → escolha_direta_ouro` |
| `perm_ouro` — A | `10000000` | A | comprovada contra o original | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → perm_ouro` |
| `raridade` — [nome, pct, peso] — A viu 10 e 13 | `[["comum", 10, 60], ["rara", 13, 30], ["épica", 16, 10]]` | E | desenhada por nós | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → raridade` |
| `reroll_bonus_ouro` — C: "Trocar bônus" (reroll-bonus); custo classe 3 | `50000` | E | desenhada por nós | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → reroll_bonus_ouro` |
| `roll_gratis_s` — A: 12 h | `43200` | A | comprovada contra o original | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → roll_gratis_s` |
| `roll_pago_ouro` — custo da rolagem antes das 12 h (classe 3) | `100000` | E | desenhada por nós | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → roll_pago_ouro` |
| `temp_cartas` — A | `5` | A | comprovada contra o original | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → temp_cartas` |
| `temp_s` — A: 24 h | `86400` | A | comprovada contra o original | comentário em `sim/servico_golden_stars.gd` |  | `dados/regras/<perfil>/RegrasGoldenStars.tres → temp_s` |

## IV e Quality

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| IV de 1 a 32 por stat | (regra no código) | A | comprovada contra o original | A+C | | código da sim |
| Quality pelos pesos do cliente (não existe 1,6–1,7) | (regra no código) | C | replicada do cliente sem confirmação no servidor | C; capturados χ² 2,8 | | código da sim |
| Stat = round(L/100 × (base + 2·IV) × Q^exp); Power = round(Σ × Q) | (regra no código) | A | comprovada contra o original | A+B+C | | código da sim |
| O capturado é um sorteio novo (não herda o selvagem) | (regra no código) | A | comprovada contra o original | A, 12/57 incompatíveis | | código da sim |
| Quality e IV do capturado pelo sorteio do cliente | (regra no código) | A | comprovada contra o original | A, 218 capturas | | código da sim |
| Stats exibidos do capturado no nível 1 | (regra no código) | A | comprovada contra o original | A+C, 218/218 | | código da sim |

## Preços

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| Bolas e poções pelo `priceGold`, venda de Pokémon pelo `sellValue` | (regra no código) | A | comprovada contra o original | A (G1, G2) | | código da sim |

## Shiny

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| Só espécies com forma shiny (SHINY_BY_DEX) aparecem shiny; 1/260 por abate nelas; nenhum no lock | (regra no código) | A | comprovada contra o original | A (42/10.914 e 0/3.323, livre) + C; `test_shiny` 7/7 | | código da sim |
| Auto-Catch Shiny com bola própria; desligado o normal, só shinies recebem bola | (regra no código) | A | comprovada contra o original | C + A (M3); `test_shiny` | | código da sim |
| O capturado shiny fica shiny (sprite e cadáver shiny do cliente) | (regra no código) | A | comprovada contra o original | A (field marca o selvagem) + C; `test_janelas_ciclo2` | | código da sim |

## Streak, boosts e Tipo do Dia

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `insignia_pct_drop` — +1% de chance de rolagem extra de drop por insígnia ativa, como o texto do cliente | `1.0` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasEventos.tres → insignia_pct_drop` |
| `insignia_pct_xp` — parcela gym: floor(1% da base por insígnia ativa), o texto do cliente diz +1% por insígnia | `1.0` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasEventos.tres → insignia_pct_xp` |
| `streak_pct_por_ponto` — Fase 4, lote 2 — parcelas de XP e efeitos de loot (cfg.boosts, cfg.eventos, cfg.streak; zero = saída igual a antes). Streak Points (C, guia e janela do original | `0.001` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasEventos.tres → streak_pct_por_ponto` |
| `tipo_do_dia_loot` — Tipo do Dia (A: evento "type-of-day", "+20% de XP e +20% de loot em Pokémon do tipo X"): parcela typeDay = floor(20% da base) (A, G8: 61/61); loot em `tipo_do_d | `1.4` | A | comprovada contra o original | G8, G10 |  | `dados/regras/<perfil>/RegrasEventos.tres → tipo_do_dia_loot` |
| `tipo_do_dia_pct` — E: sem shiny na fase 1 | `20` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasEventos.tres → tipo_do_dia_pct` |

## TMs, held items, Rare Candy e berries

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `berry_duracao_s` — C: "the effect lasts 30 minutes" | `1800` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_itens.gd` |  | `dados/regras/<perfil>/RegrasItens.tres → berry_duracao_s` |
| `candy_id` — A: items.json "Rare Candy" | `90124` | A | comprovada contra o original | items.json |  | `dados/regras/<perfil>/RegrasItens.tres → candy_id` |
| `candy_max_por_pokemon` — C | `10` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_itens.gd` |  | `dados/regras/<perfil>/RegrasItens.tres → candy_max_por_pokemon` |
| `candy_nivel_max` — C: "level 100 or below" | `100` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_itens.gd` |  | `dados/regras/<perfil>/RegrasItens.tres → candy_nivel_max` |
| `tipos_berry` — Nome do tipo na descrição (A, português) → tipo do jogo, comparado só pelas letras a–z ("Aço" → "ao", "Água" → "gua"). "Neutro" = golpes neutros dos bosses (C,  | `{ "ao": "STEEL", "drago": "DRAGON", "eltrico": "ELECTRIC"…` | A | comprovada contra o original | comentário em `sim/servico_itens.gd` |  | `dados/regras/<perfil>/RegrasItens.tres → tipos_berry` |

## VIP

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `vip_fracao` — A: parcela vip = 50% da base | `0.5` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasVIP.tres → vip_fracao` |

## XP e níveis

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `xp_regiao` — decisão do usuário (ciclo 3): Orre ×10 (500 → 2000 em ~89 dias de calendário em vez de ~2,5 anos, campanha do ciclo 2); Nightmare sem multiplicador; parcela eve | `{ "kanto": 1.0, "nightmare": 1.0, "orre": 10.0, "outland"…` | E | desenhada por nós | comentário em `sim/regras.gd` | sem multiplicador por região (×1 em toda parte) | `dados/regras/<perfil>/RegrasXP.tres → xp_regiao` |
| `xp_regiao_piso` — decisão do usuário (ciclo 6): em Orre o multiplicador de cada hunt é max(×10, piso ÷ XP base médio das espécies da hunt). Piso = 1,22 × 13.508 (o XP base da mel | `{ "orre": 16500.0 }` | E | desenhada por nós | comentário em `sim/regras.gd` | sem piso (a base da espécie vale) | `dados/regras/<perfil>/RegrasXP.tres → xp_regiao_piso` |
| Base por abate = `experience` da espécie | (regra no código) | A | comprovada contra o original | A | | código da sim |
| VIP +50% em parcela própria | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Lock de entrada: floor(total × 0,3) por 60 s desde a entrada | (regra no código) | A | comprovada contra o original | A, 76/76 | | código da sim |
| Tipo do Dia: floor(20% da base); rotação com 5 dias gravados | (regra no código) | A | comprovada contra o original | A (G8, G11) | | código da sim |
| Streak: floor(base × 0,1% × pontos) | (regra no código) | A | comprovada contra o original | A (G7) | | código da sim |
| Curva de XP do treinador = a do Pokémon | (regra no código) | A | comprovada contra o original | A, 19 níveis (109–633) | | código da sim |
| Só o Pokémon ativo ganha XP | (regra no código) | A | comprovada contra o original | A, 807/807 | | código da sim |
| Curva de XP do Pokémon | (regra no código) | A | comprovada contra o original | A+B, 27 níveis (1–442) | | código da sim |
| Parcelas do Pokémon = as do treinador, sem streak | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Subir de nível não cura | (regra no código) | A | comprovada contra o original | A | | código da sim |

## acesso às hunts e regiões

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| Região pelo nível do treinador: Outland 150, Orre 500, Nightmare 2000 | (regra no código) | C | replicada do cliente sem confirmação no servidor | C; `test_acesso_hunts` | | código da sim |
| Nível do treinador ≥ nível da hunt, com a mensagem do original | (regra no código) | C | replicada do cliente sem confirmação no servidor | C | | código da sim |
| Aviso de TMs em Orre (Sim/Não) | (regra no código) | C | replicada do cliente sem confirmação no servidor | C | | código da sim |
| Nada de item, insígnia ou custo de viagem | (regra no código) | C | replicada do cliente sem confirmação no servidor | C | | código da sim |
| As 451 hunts com mapa, hunt-config e colisão reais | (regra no código) | A | comprovada contra o original | A; grade 7/7; 451/451 jogáveis | | código da sim |

## bosses

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `altar_chance_captura` — C: 'A captura é muito rara'; 3% por vitória no altar | `0.03` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → altar_chance_captura` |
| `altar_especies` — o shiny lendário do altar sai entre os três das Lendary Beasts do catálogo | `["Raikou", "Entei", "Suicune"]` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → altar_especies` |
| `altar_nivel` — nível do shiny lendário do altar (o das Lendary Beasts do catálogo vai de 425 a 525) | `500.0` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → altar_nivel` |
| `auto_max_lutas` — teto da fila do Auto Boss | `50.0` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → auto_max_lutas` |
| `baus` — o baú abre na hora: ouro e pedras de evolução sorteadas (o conteúdo do original não foi gravado) | `{ "Dungeon Chest": { "ouro": [20000.0, 60000.0], "pedras"…` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → baus` |
| `cadencia_boss_ms` — ritmo de um selvagem (A: ~2000 ms) | `2000.0` | A | comprovada contra o original | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → cadencia_boss_ms` |
| `fator_dano_boss` — o boss bate um pouco mais que um treinador (o selvagem tem ×1,8, A) | `1.2` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → fator_dano_boss` |
| `historico_max` — lutas guardadas no histórico de bosses | `30` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → historico_max` |
| `iv_boss` — boss é mais forte que o selvagem médio | `25.0` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → iv_boss` |
| `lista` — 87 bosses do snapshot (A: nome, categoria, nível, drops); espécie, entrada, HP e chances desenhados (ferramentas/balanceamento/gerar_bosses.py); ciclo 6: TM Dis | `[{ "categoria": "Especiais", "drops": [{ "chance": 0.6, "…` | A | comprovada contra o original | ferramentas/balanceamento/gerar_bosses.py |  | `dados/regras/<perfil>/RegrasBosses.tres → lista` |
| `quality_boss` — boss é mais forte que o selvagem médio | `1.3` | E | desenhada por nós | comentário em `sim/servico_bosses.gd` |  | `dados/regras/<perfil>/RegrasBosses.tres → quality_boss` |

## breeding

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `abates_chocar` — derrotas nas hunts para o ovo chocar (classe 3; C: chocam com derrotas) | `500` | E | desenhada por nós | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → abates_chocar` |
| `delta` — Δ de Quality no caminho com feromônio (C: +0,15 a +0,30) | `[0.15, 0.3]` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → delta` |
| `delta_livre_div` — o caminho livre divide o Δ (C: ~20× menor) | `20.0` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → delta_livre_div` |
| `feromonio_id` — item do caminho cheio: Strange Pheromone (A: existe no catálogo) | `44417` | E | desenhada por nós | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → feromonio_id` |
| `herdar_pct` — chance de cada IV copiar o melhor pai (classe 3; C: N% copia, senão re-rola) | `50.0` | E | desenhada por nós | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → herdar_pct` |
| `iv_mais1_pct` — pedras em dobro: chance de +1 num IV (C: 5%) | `5.0` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → iv_mais1_pct` |
| `pedras_por_ovo` — pedras do tipo principal por ovo (classe 3; C: gasta pedras) | `2` | E | desenhada por nós | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → pedras_por_ovo` |
| `quality_max` — Quality máxima do filho (C: maior faixa do rollQuality) | `1.8` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → quality_max` |
| `slots` — slots da incubadora (classe 3; mais slots são de diamantes no original) | `2` | E | desenhada por nós | comentário em `sim/servico_breeding.gd` |  | `dados/regras/<perfil>/RegrasBreeding.tres → slots` |

## captura e shiny

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `boost_captura_bonus` — C: dobra a chance (multiplica a chance por arremesso) Boosts (C: "XP Boost +50% trainer XP", "Pokémon XP Boost +50%", "Loot Boost +40% loot chance", "Capture Bo | `1.0` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → boost_captura_bonus` |
| `captura_c` — Captura com medidor de investimento (C: tutorial "quanto mais bolas você investe numa espécie, maior a chance"; tela Gerenciamento de Captura, /api/game/used-ba | `0.814` | C | replicada do cliente sem confirmação no servidor | C5, C1, S2, M3 |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_c` |
| `captura_eficiencia` — A: balls.catalog.catchRate | `{ "1": 1, "2": 2, "3": 3, "4": 4, "5": 255, "6": 5, "7": 5 }` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_eficiencia` |
| `captura_garantida_eficiencia` — C/B-relatado: Master Ball (catchRate 255) garante | `255` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_garantida_eficiencia` |
| `captura_k` — peso do investimento desde a última captura no medidor (forma F; c e k por máxima verossimilhança) | `1.14` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_k` |
| `captura_manual_recarga_ms` — C: o cliente trava 4 s entre lançamentos manuais | `4000` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_manual_recarga_ms` |
| `captura_preco_bola` — A: balls.catalog.priceGold | `{ "1": 5, "2": 20, "3": 50, "4": 130, "5": 0, "6": 400, "…` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_preco_bola` |
| `captura_shiny_base` — chance base de captura do shiny por tier (×catchRate da bola, C); o servidor não mostra o valor. Gradiente do tier raro (A) ao comum (E), coerente com 0 captura | `{ "A": 0.004, "B": 0.007, "C": 0.01, "D": 0.015, "E": 0.02 }` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_shiny_base` |
| `captura_shiny_base_padrao` — shiny de espécie sem tier na tabela do cliente: o mesmo do tier C | `0.01` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_shiny_base_padrao` |
| `captura_valor_bola` — A (C5): "ouro" = priceGold; "eficiencia" = catchRate × 50/3 (refutado) | `"ouro"` | A | comprovada contra o original | C5 |  | `dados/regras/<perfil>/RegrasCaptura.tres → captura_valor_bola` |
| `chance_shiny` — chance de shiny (nome antigo; ver shiny_chance) | `0.0` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → chance_shiny` |
| `pendente_vida_ms` — A: selvagem capturável por 20,0 s depois do abate (fase3 M1/M2) | `20000` | A | comprovada contra o original | M1, M2 |  | `dados/regras/<perfil>/RegrasCaptura.tres → pendente_vida_ms` |
| `shiny_chance` — Shiny (A, 19/11, todas as gravações): só espécies com forma shiny (C: SHINY_BY_DEX) aparecem shiny — 0 em 3.323 abates das outras; nas com forma, 42 em 10.914 a | `0.0038482682792743265` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCaptura.tres → shiny_chance` |
| Uma bola por abate (a do Auto-Helper) | (regra no código) | A | comprovada contra o original | A | | código da sim |
| O capturado chega no nível 1 | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Filtro de nomes (vírgula; em branco = todos; vale para os dois modos) | (regra no código) | C | replicada do cliente sem confirmação no servidor | C; `test_auto_catch_filtro` 3/3 | | código da sim |

## cards

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `pesos_raridade` — peso de cada raridade no sorteio do Poke Card Pack (o original não mostra): a comum é ~60% e as hiper-raras ~1 em 2000 | `{ "classic_collection": 0.4, "common": 60.0, "double_rare…` | E | desenhada por nós | comentário em `sim/servico_cards.gd` |  | `dados/regras/<perfil>/RegrasCards.tres → pesos_raridade` |

## combate e dano

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `aleatorio_max` — A | `1.0` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → aleatorio_max` |
| `aleatorio_min` — A: máx/mín ≤ 1,17 por indivíduo | `0.85` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → aleatorio_min` |
| `arredondamento_dano` — F: round (Math.round) ou floor; sem evidência | `"round"` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → arredondamento_dano` |
| `ataque_aliado_ticks` — A: 1600 ms, grade fixa (as variações de 1200/2000 vêm de field não recebido) | `8` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → ataque_aliado_ticks` |
| `ataque_selvagem_extra_prob` — F: às vezes +1 tick (média medida ~2050 ms no Kangaskhan) | `0.25` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → ataque_selvagem_extra_prob` |
| `ataque_selvagem_ticks` — A: ~2000 ms por selvagem | `10` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → ataque_selvagem_ticks` |
| `cadaver_generico` — espécie sem cadáver conhecido usa o próprio sprite escurecido: o jogador vê onde o selvagem caiu | `true` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → cadaver_generico` |
| `cadaver_ms` — A aproximado: corpos somem em ~19–20 s | `20000` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → cadaver_ms` |
| `fator_selvagem` — F: fórmula candidata | `1.8` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → fator_selvagem` |
| `formula_dano` — Fase 4, item 1 (F, `ferramentas/fase4/ajustar_dano.py`, tabela em dados/relatorios/ajuste_dano.md): variante da fórmula. "atual" = a de sempre, com o divisor ≥  | `"sem_piso_divisor"` | F | em aberto | /ajustar_dano.py, dados/relatorios/ajuste_dano.md |  | `dados/regras/<perfil>/RegrasCombate.tres → formula_dano` |
| `golpe_poder_maximo` — golpes de poder 600 (assinatura) ficam fora da escolha: nunca apareceram nas gravações | `599.0` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → golpe_poder_maximo` |
| `hp_selvagem_minimo` — A | `120` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → hp_selvagem_minimo` |
| `hp_selvagem_por_stat` — A | `35` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → hp_selvagem_por_stat` |
| `piso_aliado` — A: Gastly × Rattata | `2` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → piso_aliado` |
| `piso_ataque_aliado` — Fase 4, item 2 (F, 15/11): piso do stat de ataque (Atk/SpA) do ALIADO no cálculo do dano. O Geodude Lv.1 das gravações geodude-10min/geodeude-2 mostra Atk 1 e t | `3.0` | F | em aberto | geodude-10min, ajustar_dano.py, A3, G11 | não medido (F): o dano no nível 1 pede ~3 | `dados/regras/<perfil>/RegrasCombate.tres → piso_ataque_aliado` |
| `piso_selvagem` — A: 880 hits do Rattata no Geodude | `1` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → piso_selvagem` |
| `pocao_limiar` — A: HP ≤ 50% dispara no mesmo tick (91/91 cruzamentos; HP exato na cura ≤ 0,50 | `0.5` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → pocao_limiar` |
| `pocao_recarga_ms` — A/F: nenhuma cura adiada observada; menor intervalo real 1988 ms em 409 curas); o Auto-Helper da gravação de 1 h mostra "Heal when HP ≤ 50%" | `0` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → pocao_recarga_ms` |
| `primeiro_ataque_selvagem_ticks` — F: 1º golpe ~2000 ms depois de encostar (4 casos: 1600–3200 ms) | `10` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → primeiro_ataque_selvagem_ticks` |
| `respawn_ms` — A: 7 respawns medidos, todos 60 s, no ponto de spawn, mesmo indivíduo aproximam com \|dy\| até 13 (0,16–0,43 por intervalo em \|dy\| 8–13, centenas de intervalos na | `60000` | A | comprovada contra o original | rhydon-1h, M1, M2, M3 |  | `dados/regras/<perfil>/RegrasCombate.tres → respawn_ms` |
| `stab` — B | `1.5` | B | replicada do cliente sem confirmação no servidor | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → stab` |
| `stats_dano_aliado` — stats do aliado no dano: os exibidos, arredondados (F forte: 15/15 indivíduos) | `"inteiro"` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → stats_dano_aliado` |
| `stats_dano_selvagem` — "inteiro" volta ao modelo antigo Stats na fórmula de dano (F, forte). Selvagem sem arredondar: na rhydon-1h o Solar Beam é explicado por uma SpD inteira em 2/15 | `"continuo"` | F | em aberto | rhydon-1h |  | `dados/regras/<perfil>/RegrasCombate.tres → stats_dano_selvagem` |
| `tick_ms` — A: todos os logs | `200` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → tick_ms` |
| `ticks_por_field` — A: field a cada 400 ms | `2` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → ticks_por_field` |
| `tm_aoe_splash_fator` — ciclo 6: fração do dano do golpe normal que espirra nos selvagens do quadro de 12×12 com o AoE TM; o texto do cliente ('passam a espirrar em cada selvagem') não | `1.0` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → tm_aoe_splash_fator` |
| `troca_cooldown_ms` — depois da troca automática por desmaio, 5 s sem troca manual: evita trocar no meio do golpe | `5000.0` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasCombate.tres → troca_cooldown_ms` |
| O mesmo golpe por indivíduo; maior dano esperado com os stats dele | (regra no código) | A | comprovada contra o original | A, 100+ indivíduos | | código da sim |
| Empate exato → o primeiro da lista | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Aleatório 0,85–1,00 | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Efetividade amplificada (×1,75, ×2,5, ×5,5; ÷1,5) | (regra no código) | A | comprovada contra o original | A+B | | código da sim |
| Piso 2 (aliado) e 1 (selvagem), inclusive com eff 0 | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Selvagem ×1,8 | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Fórmula na faixa 80–199 (o número que aparece na tela) | (regra no código) | B | replicada do cliente sem confirmação no servidor | 99,6% dos 4.510 golpes do aliado, 99,2% dos 1.787 do selvagem | | código da sim |
| Tick 200 ms; field a cada 2 ticks | (regra no código) | A | comprovada contra o original | A | | código da sim |
| HP do aliado max(24, 12×stat) e do selvagem max(120, 35×stat) | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Ritmo: aliado 1600 ms, selvagem ~2000 ms | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Golpes não recebidos vão no próximo field | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Penalidade de entrada (lock de 60 s; a mesma hunt pela cidade não penaliza) | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Dispara no tick em que o HP fica ≤ limite | (regra no código) | A | comprovada contra o original | A, 91/91 | | código da sim |
| Sem recarga | (regra no código) | A | comprovada contra o original | A | | código da sim |
| A menor que cobre o que falta, senão a maior | (regra no código) | A | comprovada contra o original | A, 408/408 | | código da sim |
| Cura até o valor da poção, limitada ao que falta | (regra no código) | A | comprovada contra o original | A | | código da sim |

## começo de jogo

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `ouro_inicial` — o kit (100 Small Potions, 100 Poké Balls) já cobre a primeira hora; o ouro vem da venda do loot | `0.0` | E | desenhada por nós | comentário em `sim/servico_novo_jogo.gd` |  | `dados/regras/<perfil>/RegrasJogoNovo.tres → ouro_inicial` |
| Treinador nível 1, XP 0 | (regra no código) | C | replicada do cliente sem confirmação no servidor | C; `test_jogo_novo` | | código da sim |
| Kit: 100 Small Potions e 100 Poké Balls | (regra no código) | C | replicada do cliente sem confirmação no servidor | C (Pokepedia embutida) | | código da sim |
| Cidade inicial Cerulean | (regra no código) | A | comprovada contra o original | C/A | | código da sim |

## decisões (classe 3)

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| Ouro inicial: 0: o kit cobre a primeira hora | (regra no código) | E | desenhada por nós | `jogo_novo.ouro_inicial` | | código da sim |
| Troca automática após desmaio: Aleatória entre os vivos do time, 5 s sem troca manual | (regra no código) | E | desenhada por nós | `combate.troca_cooldown_ms` | | código da sim |
| Parcela `gym` e drop das insígnias: +1% da base e +1% de rolagem extra por insígnia ativa | (regra no código) | E | desenhada por nós | `combate.insignia_pct_*` | | código da sim |
| Sem caminho até o alvo: Ataca o encostado | (regra no código) | E | desenhada por nós | `combate.alvo_troca_se_bloqueado` | | código da sim |
| `start` numa ilha sem spawn: Começa na ilha que alcança mais spawns | (regra no código) | E | desenhada por nós | `combate.inicio_ilha_com_spawns` | | código da sim |
| Cadáver de espécie sem dado: O próprio sprite escurecido | (regra no código) | E | desenhada por nós | `combate.cadaver_generico` | | código da sim |
| Golpes de poder 600 (assinatura): Fora da escolha | (regra no código) | E | desenhada por nós | `combate.golpe_poder_maximo` | | código da sim |
| Shiny na captura: shinyBase por tier A 0,4% … E 2% × catchRate da bola (0 em 31 tentativas gravadas; Master garante) | (regra no código) | E | desenhada por nós | `combate.captura_shiny_base` | | código da sim |
| Garantia de pedra: Se a pedra não cai em 3× os abates esperados, cai no próximo (decisão do usuário) | (regra no código) | E | desenhada por nós | `combate.pedra_garantia_fator` | | código da sim |
| Metas visíveis: Hunt recomendada pelo XP/min estimado, Power dos selvagens ≤ Power do líder, 4 s fora da luta por abate (rhydon-1h), marcos 150–500 a cada 25–50 | (regra no código) | E | desenhada por nós | `metas.*` | | código da sim |
| Auto-Catch Shiny: Ligado por padrão, com a melhor bola que tiver (decisão do usuário) | (regra no código) | E | desenhada por nós | `configuracao_auto_helper.gd` | | código da sim |
| XP por região: **Proposta, não aplicada**: multiplicador na parcela `event`, sem mudar o XP da espécie; padrão 1 | (regra no código) | E | desenhada por nós | `combate.xp_regiao` | | código da sim |
| Cartão de derrota: 4,5 s (shiny 7 s), até 30 por instância | (regra no código) | E | desenhada por nós | `apresentacao.*` | | código da sim |
| Limites do depot e da BOX: 200 pilhas, 3000 Pokémon | (regra no código) | E | desenhada por nós | `cidade.capacidade_*` | | código da sim |
| Inicial fora da BOX: Sempre no time | (regra no código) | E | desenhada por nós | `cidade.starter_no_time` | | código da sim |
| Limite por compra: 100 mil | (regra no código) | E | desenhada por nós | `cidade.qtd_max_por_compra` | | código da sim |
| Daily Gift: Boost de 1 h, somando se repetir | (regra no código) | E | desenhada por nós | `diarias.gift_boost_ms` | | código da sim |
| Daily Kill: 3 opções; quantidades por dificuldade | (regra no código) | E | desenhada por nós | `diarias.kill_*` | | código da sim |
| Daily Catch: Multiplicador de XP em [1,5; 18], múltiplo de 0,5 | (regra no código) | E | desenhada por nós | `diarias.catch_mult_*` | | código da sim |
| Turbo da soneca: Desligado (sem diamantes) | (regra no código) | E | desenhada por nós | `jogador.soneca_turbo_disponivel` | | código da sim |
| Jogo fechado numa hunt: Continua até 15 min | (regra no código) | E | desenhada por nós | `jogador.fechado_caca_max_s` | | código da sim |
| IV e Quality do inicial: Sorteio do cliente (o mesmo do capturado, A) | (regra no código) | E | desenhada por nós | `sim/servico_novo_jogo.gd` (regra) | | código da sim |
| Receita das pedras: Tipo principal + tipos ganhos; 4 pedras a partir de hunt nível 40 | (regra no código) | E | desenhada por nós | `sim/servico_cidade.gd` (regra) | | código da sim |
| Dano do aliado no nível 1–5: Fórmula do nível alto com piso 3 no ataque; a diferença para o real (G11, rattata livre) fica dentro do ruído dos trechos | (regra no código) | E | desenhada por nós | `sim/regras.gd` `piso_ataque_aliado` | | código da sim |
| Sem servidor: Entrada sem nível barrada no mapa como no cliente; `hunt-cooldown` 0; sem guilda nem mentor (parcelas 0); golpes de status sem efeito | (regra no código) | E | desenhada por nós | regras sem número | | código da sim |
| Inicial do jogo novo: Geodude nível 1 (decisão do usuário) | (regra no código) | E | desenhada por nós | `sim/servico_novo_jogo.gd` | | código da sim |

## diárias e tarefas

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `catch_mult_max` — teto do multiplicador do Daily Catch (A: maior valor gravado) | `18.0` | A | comprovada contra o original | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → catch_mult_max` |
| `catch_mult_min` — Daily Catch: multiplicador de XP sorteado em [1,5; 18], múltiplo de 0,5 (A: os 4 valores gravados cabem) | `1.5` | A | comprovada contra o original | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → catch_mult_min` |
| `catch_total` — Daily Catch (A, G5): 2 capturas premiadas por dia; faixas por nível do treinador; capturar espécie da tabela preenche o próximo slot (C: "capture um Pokémon da  | `2` | A | comprovada contra o original | G5, G9 |  | `dados/regras/<perfil>/RegrasDiarias.tres → catch_total` |
| `dia_virada_utc_s` — A: resetAt = 03:00 UTC (meia-noite de Brasília), igual ao Tipo do Dia | `10800` | A | comprovada contra o original | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → dia_virada_utc_s` |
| `gift_boost_ms` — boost do Daily Gift dura 1 h; o mesmo boost ativo soma mais 1 h | `3600000.0` | E | desenhada por nós | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → gift_boost_ms` |
| `gift_pular_vip` — decisão do usuário (ciclo 3): sem VIP, o dia VIP do Daily Gift é pulado em vez de travar o calendário (no original trava) | `true` | E | desenhada por nós | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → gift_pular_vip` |
| `kill_itens_mult` — multiplicador dos itens do prêmio do Daily Kill (classe 3) | `2` | E | desenhada por nós | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → kill_itens_mult` |
| `kill_min_nivel` — nível mínimo do Daily Kill (C) | `25` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → kill_min_nivel` |
| `kill_opcoes` — Daily Kill oferece 3 opções por dia (A, G9: 3 opções exatas) | `3.0` | E | desenhada por nós | G9 |  | `dados/regras/<perfil>/RegrasDiarias.tres → kill_opcoes` |
| `kill_qtd` — faixas de quantidade do Daily Kill por dificuldade: 15–60 min de caça na hunt sugerida | `{ "easy": [200.0, 600.0], "hard": [500.0, 1500.0], "mediu…` | E | desenhada por nós | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → kill_qtd` |
| `kill_xp_fator` — Daily Kill: XP = qtd × xpAbate × 8/3 (A: 3/3) | `2.6666666666666665` | A | comprovada contra o original | comentário em `sim/servico_diarias.gd` |  | `dados/regras/<perfil>/RegrasDiarias.tres → kill_xp_fator` |

## ginásios

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `cadencia_lider_ms` — o líder ataca no ritmo de um selvagem (A: ~2000 ms); o jogador no do aliado (A: 1600 ms) | `2000.0` | A | comprovada contra o original | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → cadencia_lider_ms` |
| `fator_dano_lider` — o líder não tem o ×1,8 do selvagem (é um treinador; o ×1,8 é medido só em selvagem) | `1.0` | E | desenhada por nós | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → fator_dano_lider` |
| `ginasios_conhecidos` — ginásios vistos no gym-global (A) | `{ "cerulean": { "tipo": "WATER" }, "mahogany": { "lider_n…` | A | comprovada contra o original | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → ginasios_conhecidos` |
| `ginasios_por_regiao` — C (a 2ª região é Johto no texto; a lista vem do servidor) | `{ "kanto": 8, "outra": 10 }` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → ginasios_por_regiao` |
| `ginasios_total` — C | `18` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → ginasios_total` |
| `insignia_duracao_s` — C: "A badge LASTS 48h" | `172800` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → insignia_duracao_s` |
| `iv_lider` — IV dos Pokémon do líder: um pouco acima do médio (16,5) para a luta pedir preparo | `20.0` | E | desenhada por nós | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → iv_lider` |
| `lista` — 18 ginásios do cliente (C) com tipos A/B; times, níveis e desbloqueio desenhados para o ritmo da campanha (ferramentas/balanceamento/gerar_ginasios.py) | `[{ "id": "pewter", "insignia": "Boulder Badge", "lider": …` | E | desenhada por nós | ferramentas/balanceamento/gerar_ginasios.py |  | `dados/regras/<perfil>/RegrasGinasios.tres → lista` |
| `luta_max_s` — teto da luta (10 min de luta simulada); passou, perde | `600.0` | E | desenhada por nós | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → luta_max_s` |
| `quality_lider` — Quality dos Pokémon do líder: acima da média do sorteio (≈1,0) | `1.15` | E | desenhada por nós | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → quality_lider` |
| `recarga_derrota_s` — depois de perder, 60 s até poder desafiar de novo (o cliente mostra cooldownMs; valor do servidor não gravado) | `60.0` | E | desenhada por nós | comentário em `sim/servico_ginasios.gd` |  | `dados/regras/<perfil>/RegrasGinasios.tres → recarga_derrota_s` |

## interface e desempenho

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| Quadro p99 ≤ 16,7 ms com a janela em foco (5 hunts mais pesadas) | (regra no código) | E | desenhada por nós | test_todas_hunts.py --velocidade 1; v1.0: medianas 7,45–10,73 ms | | código da sim |
| Sem foco, desenho a 10 quadros/s e a sim segue o relógio (atraso recuperado até 1 h) | (regra no código) | E | desenhada por nós | test_modo_fundo; EstadoJogo.definir_modo_fundo | | código da sim |
| Entrada na hunt em no máximo 1 s (cache e atlas prontos) | (regra no código) | E | desenhada por nós | ferramentas/build/medir_entrada_hunt.gd | | código da sim |
| Save em thread, atômico (.tmp, conferência byte a byte, .bak) | (regra no código) | E | desenhada por nós | test_save_thread.py (15/15 mortes sem perda) | | código da sim |
| HUD na referência 1880 px do original; zoom 25×13 (1), 0.75 e 0.5 | (regra no código) | C | replicada do cliente sem confirmação no servidor | C: cameraZoom; janela_base.gd | | código da sim |

## interface e metas

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `cartao_ms` — cartão de derrota na tela por 4,5 s (P04): dá para ler XP e loot sem tapar a hunt | `4500.0` | E | desenhada por nós | P04 |  | `dados/regras/<perfil>/RegrasInterface.tres → cartao_ms` |
| `cartao_shiny_ms` — shiny fica mais tempo: é o evento raro que o jogador quer ver | `7000.0` | E | desenhada por nós | comentário em `sim/regras_apresentacao.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → cartao_shiny_ms` |
| `cartoes_por_instancia` — decisão do usuário: no máximo 30 cartões por instância; limita só a apresentação | `30.0` | E | desenhada por nós | comentário em `sim/regras_apresentacao.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → cartoes_por_instancia` |
| `metas_busca_niveis` — a próxima meta é procurada até 100 níveis do líder à frente | `100.0` | E | desenhada por nós | comentário em `sim/metas.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → metas_busca_niveis` |
| `metas_fator_poder` — hunt recomendada só se o Power médio dos selvagens (IV médio, Quality 1) não passa do Power do líder; a campanha confere que a recomendada não mata | `1.0` | E | desenhada por nós | comentário em `sim/metas.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → metas_fator_poder` |
| `metas_ganho_min` — a próxima meta só aparece se render ≥ 5% a mais de XP/min (abaixo disso não vale trocar) | `0.05` | E | desenhada por nós | comentário em `sim/metas.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → metas_ganho_min` |
| `metas_iv_selvagem` — IV médio do sorteio 1..32 (A: uniforme) para estimar o selvagem típico | `16.5` | A | comprovada contra o original | comentário em `sim/metas.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → metas_iv_selvagem` |
| `metas_marcos_colecao` — espécies diferentes capturadas; mais a 'Pokédex da região' (espécies das hunts liberadas) | `[1.0, 5.0, 10.0, 25.0, 50.0, 75.0, 100.0, 150.0, 200.0, 3…` | E | desenhada por nós | comentário em `sim/metas.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → metas_marcos_colecao` |
| `metas_marcos_nivel` — marcos do treinador; 150/500/2000 são os desbloqueios de região (C); de 150 a 500, um a cada 25–50 níveis para o trecho sem hunt nova ter meta visível | `[10.0, 25.0, 50.0, 80.0, 100.0, 150.0, 175.0, 200.0, 250.…` | E | desenhada por nós | comentário em `sim/metas.gd` |  | `dados/regras/<perfil>/RegrasInterface.tres → metas_marcos_nivel` |
| `metas_s_extra_abate` — segundos por abate fora da luta (andar e respawn): rhydon-1h (A) tem 8,7 s por abate com 2,91 golpes de 1,6 s → 4,0 s | `4.0` | E | desenhada por nós | rhydon-1h |  | `dados/regras/<perfil>/RegrasInterface.tres → metas_s_extra_abate` |

## loja, Nurse Joy, depot e evolução

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `bolas_catalogo` — A: mensagem balls.catalog (gravações): priceGold, buyable, catchRate HP depois de evoluir: mantém a fração da vida (E; o original não foi gravado). Loja | `[{ "bound": false, "buyable": true, "catchRate": 1, "id":…` | A | comprovada contra o original | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → bolas_catalogo` |
| `capacidade_box` — BOX da conta VIP (A); sem VIP não medido, vale o mesmo para não punir quem joga offline | `3000.0` | E | desenhada por nós | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → capacidade_box` |
| `capacidade_depot_pilhas` — o original não mostrou teto (89 pilhas sem aviso); 200 é folgado e evita lista infinita | `200.0` | E | desenhada por nós | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → capacidade_depot_pilhas` |
| `casas_liberadas` — decisão do usuário (ciclo 5): a casa à direita da porta do Pokémon Center fica transitável; no original ela é bloqueada pela peça invisível 8274 (A, collision.j | `[[-2.0, -4.0]]` | E | desenhada por nós | collision.json | a casa (−2,−4) bloqueada pela peça 8274 (A/C) | `dados/regras/<perfil>/RegrasEconomia.tres → casas_liberadas` |
| `evolucao_cidade` — C: "Only works in Cerulean — the button is locked during a hunt" Evolução | `"cerulean"` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → evolucao_cidade` |
| `evolucao_nivel_alto` — C: "Species from Lv.40+ hunts require 4 stones total"; até 39: 1 de cada | `40` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → evolucao_nivel_alto` |
| `evolucao_nivel_reset` — C: sem pedra "goes back to Lv.1" | `1` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → evolucao_nivel_reset` |
| `evolucao_pedras_total_alto` — C: "4 stones total — split equally across combos" | `4` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → evolucao_pedras_total_alto` |
| `limite_time` — C: "Your team only carries 6 — the rest rest here" Depot | `6` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → limite_time` |
| `pedra_por_tipo` — F: receita = pedra do tipo principal da espécie de origem + pedra de cada tipo que a evolução GANHA. Bate com os dois exemplos do guia (C): Ivysaur → Venusaur = | `{ "BUG": "Cocoon Stone", "DARK": "Darkness Stone", "DRAGO…` | F | em aberto | items.json |  | `dados/regras/<perfil>/RegrasEconomia.tres → pedra_por_tipo` |
| `qtd_max_por_compra` — limite de sanidade por operação de compra | `100000.0` | E | desenhada por nós | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → qtd_max_por_compra` |
| `ramos_eevee` — C: "Eevee is a special case (its own stone system)"; os ramos (cada pedra leva a um Pokémon) seguem o canon (B/F). O caminho sem pedra vai para o destino do cre | `{ "134": "Water Stone", "135": "Thunder Stone", "136": "F…` | C | replicada do cliente sem confirmação no servidor | creatures.json |  | `dados/regras/<perfil>/RegrasEconomia.tres → ramos_eevee` |
| `starter_no_time` — o inicial não vai para a BOX: o jogador nunca fica sem o Pokémon do começo | `true` | E | desenhada por nós | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → starter_no_time` |
| `venda_categorias_excluidas` — Compra de item: priceGold > 0 do items.json (C: a tela mostra "Preço: priceGold"; hoje só as 5 poções). Venda: npcPrice (C: "Mark paga: npcPrice"), só para as c | `["heal", "revive", "stone"]` | C | replicada do cliente sem confirmação no servidor | items.json |  | `dados/regras/<perfil>/RegrasEconomia.tres → venda_categorias_excluidas` |
| `venda_excecoes_ids` — exceções da regra acima, itens 205 e 206 (C) | `[205, 206]` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → venda_excecoes_ids` |
| `venda_pokemon` — A (G1): Pokémon vendido pelo sellValue da espécie (valorVenda), sem depender de nível, Quality ou IV: 2 Blastoise Lv.1 (Q 1,014 / IV 124 e Q 1,273 / IV 61) → 18 | `"valorVenda"` | A | comprovada contra o original | G1 |  | `dados/regras/<perfil>/RegrasEconomia.tres → venda_pokemon` |
| `venda_teto_preco_compra` — E (proteção): nunca vender acima do preço de compra. Com a regra acima nenhum item do catálogo chega nele. | `true` | E | desenhada por nós | comentário em `sim/servico_cidade.gd` |  | `dados/regras/<perfil>/RegrasEconomia.tres → venda_teto_preco_compra` |
| Cura o time inteiro, na hora, grátis, sem recarga; resposta `joy-healed` | (regra no código) | A | comprovada contra o original | A (G4) | | código da sim |
| Só itens (bolas ficam na BAG); move a pilha inteira; "guardar tudo" esvazia a BAG | (regra no código) | A | comprovada contra o original | A (G4) | | código da sim |
| Resposta `{inventory, depot}` com os campos do original; time de 6 | (regra no código) | A | comprovada contra o original | A/C | | código da sim |

## loot e economia

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `card_chance_shiny` — C: Derrote shinies selvagens — eles podem dropar o Card da espécie; 10% por shiny abatido (o Card leva ao Altar dos bosses) | `0.1` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasLoot.tres → card_chance_shiny` |
| `pack_chance_abate` — Poke Card Pack por abate (nenhuma tabela do snapshot dropa o pack): ~0,2 pacote por hora a 7 abates/min | `0.0005` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasLoot.tres → pack_chance_abate` |
| `pedra_garantia_fator` — decisão do usuário (ciclo 2): se uma pedra de evolução não cai em 3× os abates esperados para ela (soma das chances ≥ 3), cai no próximo; tira os 4–70 h de espe | `3.0` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasLoot.tres → pedra_garantia_fator` |
| Tabela do creatures.json, chance em 1/100.000, quantidade min–max | (regra no código) | A | comprovada contra o original | A | | código da sim |
| Uma rolagem por abate, mais as extras do Streak | (regra no código) | A | comprovada contra o original | A/C | | código da sim |
| Tipo do Dia ×1,4 | (regra no código) | A | comprovada contra o original | A (G10) | | código da sim |
| Venda ao Mark pelo `npcPrice`; não compra poção, pedra, revive | (regra no código) | A | comprovada contra o original | A/C | | código da sim |
| 670 itens do snapshot com o id do servidor | (regra no código) | A | comprovada contra o original | A | | código da sim |

## movimento

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `alvo_criterio` — A (18/11, medir_alvo.py: 2295/2400 trocas × 2067 com Chebyshev): alvo = menor tempo de caminho até encostar. "chebyshev" volta à regra anterior (linha reta). Em | `"caminho"` | A | comprovada contra o original | medir_alvo.py |  | `dados/regras/<perfil>/RegrasMovimento.tres → alvo_criterio` |
| `alvo_so_alcancavel` — F: o alvo é o selvagem vivo mais próximo entre os alcançáveis (algum tile livre a Chebyshev ≤ 1 dele na ilha do herói). Sem isso, o herói fica preso num selvage | `true` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → alvo_so_alcancavel` |
| `alvo_troca_se_bloqueado` — sem caminho até o alvo e com selvagem encostado, ataca o encostado: senão o herói apanha parado | `true` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → alvo_troca_se_bloqueado` |
| `alvo_vem_ao_encontro` — Revertido no ciclo 2: o alvo NÃO vem de fora da borda real (A: 0 de 9.120 intervalos fora de 13×13). Fica só para experimento. O que vale (A) é o alvo perseguir | `false` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → alvo_vem_ao_encontro` |
| `caminho_margem` — F: folga da caixa de busca em volta do herói/alvo (tiles) | `6` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → caminho_margem` |
| `desempate_heroi` — Caminho (F: Dijkstra de tempo mínimo com os custos acima). Desempate entre passos igualmente ótimos, por classe [reto no eixo maior, diagonal, reto no eixo meno | `[1769, 471, 74]` | F | em aberto | rhydon-1h |  | `dados/regras/<perfil>/RegrasMovimento.tres → desempate_heroi` |
| `desempate_mob` — desempate do passo do selvagem pelas frequências medidas (A) | `[1537, 679, 387]` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → desempate_mob` |
| `fator_diagonal_passo` — A (e C: o cliente anima a diagonal com o mesmo custo, dS) Passos (A, ferramentas/gravador/medir_passos.py; gravações antigas + rhydon-1h): espera antes de cada  | `2` | A | comprovada contra o original | ferramentas/gravador/medir_passos.py, rhydon-1h |  | `dados/regras/<perfil>/RegrasMovimento.tres → fator_diagonal_passo` |
| `hero_step_ms` — A: field-init.heroStepMs (duração da animação) | `500` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → hero_step_ms` |
| `inicio_bloqueado_anel` — Ilhas da grade (2b.6). 103 hunts têm spawns em tile bloqueado e 9 têm o `start` bloqueado (hunt-config × grade). typhlosion (A, 1 caso): start (54,75) bloqueado | `true` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → inicio_bloqueado_anel` |
| `inicio_ilha_com_spawns` — start numa ilha sem spawn (nightmare_magby): começa na ilha que alcança mais spawns; sem isso a hunt não tem abate | `true` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → inicio_ilha_com_spawns` |
| `mob_contorna_bloqueio` — A (ciclo 4, medir_contorno.py): perto do herói o caminho desvia dos outros selvagens | `true` | A | comprovada contra o original | medir_contorno.py |  | `dados/regras/<perfil>/RegrasMovimento.tres → mob_contorna_bloqueio` |
| `mob_contorna_raio` — F: até onde (Chebyshev) o caminho conta os outros selvagens como obstáculo | `4` | F | em aberto | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → mob_contorna_raio` |
| `mob_espera_apos_heroi_ticks` — F (experimento M3): selvagem só dá passo N ticks depois do último passo do herói; 0 = desligado | `0` | F | em aberto | M3 |  | `dados/regras/<perfil>/RegrasMovimento.tres → mob_espera_apos_heroi_ticks` |
| `mob_step_ms` — A: field-init.mobStepMs | `1000` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → mob_step_ms` |
| `passo_extra_prob_heroi_diagonal` — A: 73/223 esperas de 1000 ms saíram em 1200 | `0.33` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → passo_extra_prob_heroi_diagonal` |
| `passo_extra_prob_heroi_reto` — A: 500 ms não cai num tick exato; 600 em 113/121 | `0.0` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → passo_extra_prob_heroi_reto` |
| `passo_extra_prob_mob_diagonal` — A: 10/237 esperas de 2000 ms saíram em 2200 | `0.04` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → passo_extra_prob_mob_diagonal` |
| `passo_extra_prob_mob_reto` — A: 319/895 esperas de 1000 ms saíram em 1200 | `0.36` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → passo_extra_prob_mob_reto` |
| `trainer_step_ms` — A: field-init.trainerStepMs | `500` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → trainer_step_ms` |
| `visao_meia_altura` — F (sim). A borda real medida em 10/11/2026 é 13 nos dois eixos: selvagens se | `7` | F | em aberto | comentário em `sim/regras.gd` | 13 (A: borda da perseguição 13 × 13) | `dados/regras/<perfil>/RegrasMovimento.tres → visao_meia_altura` |
| `visao_meia_altura_alvo` — A: o alvo persegue até \|dy\| 13 (os outros, `visao_meia_altura`) | `13` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasMovimento.tres → visao_meia_altura_alvo` |
| `visao_meia_largura` — A: perseguição até \|dx\| 13, nunca 14+ (rhydon-1h, M1, M2) | `13` | A | comprovada contra o original | rhydon-1h, M1, M2 |  | `dados/regras/<perfil>/RegrasMovimento.tres → visao_meia_largura` |

## penalidade e sessão

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `penalidade_duracao_ms` — Penalidade de entrada = boost "shinylock" (C: texto do boost, "Por 1 minuto: nenhum Pokémon Shiny aparece e você recebe 70% menos EXP e drops"; o servidor manda | `60000` | C | replicada do cliente sem confirmação no servidor | rhydon-1h, S2, S4, T1 |  | `dados/regras/<perfil>/RegrasSessao.tres → penalidade_duracao_ms` |
| `penalidade_fator` — XP e drops × 0,3 durante o lock de entrada (A: 76/76 abates) | `0.3` | A | comprovada contra o original | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasSessao.tres → penalidade_fator` |
| `penalidade_loot` — "chance" (× fator na chance de cada item) \| "quantidade" \| "nenhuma" | `"chance"` | E | desenhada por nós | comentário em `sim/regras.gd` |  | `dados/regras/<perfil>/RegrasSessao.tres → penalidade_loot` |

## pesca

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `faixas` — faixas da pesca: skill mínima, níveis e espécies (classe 3; C: a forma das faixas) | `[{ "fish": ["Magikarp", "Goldeen", "Poliwag"], "minSkill"…` | E | desenhada por nós | comentário em `sim/servico_pesca.gd` |  | `dados/regras/<perfil>/RegrasPesca.tres → faixas` |
| `onda_s` — duração da onda de pesca (classe 3) | `10` | E | desenhada por nós | comentário em `sim/servico_pesca.gd` |  | `dados/regras/<perfil>/RegrasPesca.tres → onda_s` |
| `peixes_por_nivel` — A: skill 4 → 12 | `3` | A | comprovada contra o original | comentário em `sim/servico_pesca.gd` |  | `dados/regras/<perfil>/RegrasPesca.tres → peixes_por_nivel` |
| `recarga_s` — recarga entre pescas (classe 3; C: ⏳ Aguarde Ns) | `30` | E | desenhada por nós | comentário em `sim/servico_pesca.gd` |  | `dados/regras/<perfil>/RegrasPesca.tres → recarga_s` |
| `skill_max` — nível máximo da pesca (classe 3) | `100` | E | desenhada por nós | comentário em `sim/servico_pesca.gd` |  | `dados/regras/<perfil>/RegrasPesca.tres → skill_max` |

## profissões, mentor e crafting

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `berry_bonus_rank` — Toque de Herbalista: % a mais nas berries por rank (classe 3; C: cresce a cada rank) | `{ "A": 20.0, "B": 15.0, "C": 10.0, "D": 5.0, "E": 0.0, "S…` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → berry_bonus_rank` |
| `captura_pct_rank` — C: até ×1,18 no S, cumulativo desde o E | `3.0` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → captura_pct_rank` |
| `craft_cura_rank` — rank que libera a berry de cura (classe 3) | `"S"` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → craft_cura_rank` |
| `craft_ervas` — Fresh Herbs por berry de tipo (classe 3) | `10` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → craft_ervas` |
| `craft_neutra_rank` — rank que libera a berry neutra (classe 3) | `"A"` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → craft_neutra_rank` |
| `craft_ouro` — ouro por berry (classe 3) | `5000` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → craft_ouro` |
| `craft_s_unidade` — segundos por unidade na fila (classe 3; C: unidades uma a uma) | `600` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → craft_s_unidade` |
| `craft_tipos_rank` — berries de tipo liberadas na árvore por rank (classe 3; C: árvore de talentos) | `{ "A": 19, "B": 19, "C": 12, "D": 8, "E": 4, "S": 19 }` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → craft_tipos_rank` |
| `craft_wild` — Wild Herbs por berry neutra ou de cura (classe 3) | `5` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → craft_wild` |
| `erva_chance_abate` — chance de Fresh Herbs por abate do Botânico (classe 3; C: arbustos brotam na hunt) | `0.03` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → erva_chance_abate` |
| `erva_wild_fora_kanto` — fração de Wild Herbs fora de Kanto (classe 3; C: 🍂 Wild Herbs) | `0.25` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → erva_wild_fora_kanto` |
| `foto_chance_shiny` — chance da foto do Prestígio num shiny (A: 2 de 5 no c5; classe 3) | `0.4` | E | desenhada por nós | c5 |  | `dados/regras/<perfil>/RegrasProfissoes.tres → foto_chance_shiny` |
| `mentor_gap` — A | `200` | A | comprovada contra o original | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → mentor_gap` |
| `mentor_pct_nivel` — A | `0.5` | A | comprovada contra o original | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → mentor_pct_nivel` |
| `mentor_teto_rank` — teto do mentor por rank (A: 60% observado na conta B; os outros ranks classe 3) | `{ "A": 50.0, "B": 40.0, "C": 30.0, "D": 20.0, "E": 10.0, …` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → mentor_teto_rank` |
| `req_abates_tipo` — abates por tipagem para cada rank (classe 3; C: o requisito existe) | `{ "A": 1500, "B": 500, "C": 200, "D": 50, "S": 5000 }` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → req_abates_tipo` |
| `req_craft_pictures` — berries criadas (Botânico) ou pictures entregues (Prestígio) por rank (classe 3) | `{ "A": 100, "B": 40, "C": 15, "D": 5, "S": 250 }` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → req_craft_pictures` |
| `req_especies` — espécies diferentes capturadas por rank (classe 3; C: o requisito existe) | `{ "A": 60, "B": 30, "C": 15, "D": 5, "S": 100 }` | E | desenhada por nós | comentário em `sim/servico_profissoes.gd` |  | `dados/regras/<perfil>/RegrasProfissoes.tres → req_especies` |

## soneca, Streak e sessão

| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |
| --- | --- | --- | --- | --- | --- | --- |
| `dia_ancora` — dia (unix/86400, deslocado pela virada) de 09/11/2026 em Brasília | `20766` | E | desenhada por nós | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → dia_ancora` |
| `dia_virada_utc_s` — Tipo do Dia (A: evento type-of-day, +20% XP e loot no tipo; termina às 03:00 UTC = meia-noite de Brasília). E: offline, rotação fixa ancorada nos cinco dias obs | `10800` | A | comprovada contra o original | G11 |  | `dados/regras/<perfil>/RegrasJogador.tres → dia_virada_utc_s` |
| `fechado_caca_max_s` — jogo fechado numa hunt continua caçando até 15 min (B-relatado: a sessão morre aos 15 min) | `900.0` | E | desenhada por nós | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → fechado_caca_max_s` |
| `nomes_tipos` — nomes dos tipos do Tipo do Dia (A: formato gravado) | `{ "BUG": ["Inseto", "🐛"], "DARK": ["Sombrio", "🌑"], "DRAG…` | A | comprovada contra o original | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → nomes_tipos` |
| `rotacao_tipos` — rotação do Tipo do Dia (A nos dias gravados; E nos outros) | `["DRAGON", "BUG", "FIRE", "WATER", "DARK", "GRASS", "POIS…` | E | desenhada por nós | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → rotacao_tipos` |
| `sessao_expira_s` — Sessão (B-relatado / regra do usuário, 11/11): sem soneca, 15 min com o jogo fechado matam a sessão; voltar à mesma hunt pela cidade não penaliza (CenarioJogo.p | `900` | E | desenhada por nós | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → sessao_expira_s` |
| `soneca_amostra_s` — C: "the hunt continues on the server for 5 minutes" (combate, XP, loot, Auto-Potion; sem bolas) Modo Soneca (C, guia "Nap Mode" e janela "While you were away"): | `300` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → soneca_amostra_s` |
| `soneca_fracao` — C: "Collect: 50% of the sample's XP rate" | `0.5` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → soneca_fracao` |
| `soneca_fracao_turbo` — C: "Turbo (2💎): 100%" — sem diamantes offline, o turbo é recusado (E) | `1.0` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → soneca_fracao_turbo` |
| `soneca_teto_s` — C: "Time counts from the end of the nap until login, with a cap of 24h" | `86400` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → soneca_teto_s` |
| `soneca_turbo_custo` — C | `2` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → soneca_turbo_custo` |
| `soneca_turbo_disponivel` — o jogo offline não tem diamantes: o turbo da soneca fica desligado | `false` | E | desenhada por nós | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → soneca_turbo_disponivel` |
| `streak_abates_por_ponto` — Streak Points (C, guia): 1 ponto a cada 1000 abates; o n-ésimo ponto custa 25.000 × n de ouro; trilhas exp/loot/shiny. | `1000` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → streak_abates_por_ponto` |
| `streak_custo_base` — o n-ésimo ponto custa 25.000 × n (C/A G7) | `25000` | A | comprovada contra o original | G7 |  | `dados/regras/<perfil>/RegrasJogador.tres → streak_custo_base` |
| `streak_trilhas` — trilhas EXP, Loot e Shiny (C) | `["exp", "loot", "shiny"]` | C | replicada do cliente sem confirmação no servidor | comentário em `sim/servico_jogador.gd` |  | `dados/regras/<perfil>/RegrasJogador.tres → streak_trilhas` |

## Em aberto e o que fecharia cada ponto

- **pedra_por_tipo** (loja, Nurse Joy, depot e evolução): F: receita = pedra do tipo principal da espécie de origem + pedra de cada tipo que a evolução GANHA. Bate com os dois exemplos do guia (C):  — fecha com: gravação do original que mostre esse valor
- **alvo_so_alcancavel** (movimento): F: o alvo é o selvagem vivo mais próximo entre os alcançáveis (algum tile livre a Chebyshev ≤ 1 dele na ilha do herói). Sem isso, o herói fi — fecha com: gravação de luta média (MV1–MV3) ou mais trechos da gravação livre no validador
- **arredondamento_dano** (combate e dano): F: round (Math.round) ou floor; sem evidência — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **ataque_selvagem_extra_prob** (combate e dano): F: às vezes +1 tick (média medida ~2050 ms no Kangaskhan) — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **caminho_margem** (movimento): F: folga da caixa de busca em volta do herói/alvo (tiles) — fecha com: gravação de luta média (MV1–MV3) ou mais trechos da gravação livre no validador
- **captura_k** (captura e shiny): peso do investimento desde a última captura no medidor (forma F; c e k por máxima verossimilhança) — fecha com: gravações de captura de outras espécies EPIC (viés do Larvitar) e o shinyBase por tier
- **desempate_heroi** (movimento): Caminho (F: Dijkstra de tempo mínimo com os custos acima). Desempate entre passos igualmente ótimos, por classe [reto no eixo maior, diagona — fecha com: gravação de luta média (MV1–MV3) ou mais trechos da gravação livre no validador
- **fator_selvagem** (combate e dano): F: fórmula candidata — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **formula_dano** (combate e dano): Fase 4, item 1 (F, `ferramentas/fase4/ajustar_dano.py`, tabela em dados/relatorios/ajuste_dano.md): variante da fórmula. "atual" = a de semp — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **mob_contorna_raio** (movimento): F: até onde (Chebyshev) o caminho conta os outros selvagens como obstáculo — fecha com: gravação de luta média (MV1–MV3) ou mais trechos da gravação livre no validador
- **mob_espera_apos_heroi_ticks** (movimento): F (experimento M3): selvagem só dá passo N ticks depois do último passo do herói; 0 = desligado — fecha com: gravação de luta média (MV1–MV3) ou mais trechos da gravação livre no validador
- **piso_ataque_aliado** (combate e dano): Fase 4, item 2 (F, 15/11): piso do stat de ataque (Atk/SpA) do ALIADO no cálculo do dano. O Geodude Lv.1 das gravações geodude-10min/geodeud — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **primeiro_ataque_selvagem_ticks** (combate e dano): F: 1º golpe ~2000 ms depois de encostar (4 casos: 1600–3200 ms) — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **stats_dano_aliado** (combate e dano): stats do aliado no dano: os exibidos, arredondados (F forte: 15/15 indivíduos) — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **stats_dano_selvagem** (combate e dano): "inteiro" volta ao modelo antigo Stats na fórmula de dano (F, forte). Selvagem sem arredondar: na rhydon-1h o Solar Beam é explicado por uma — fecha com: gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2
- **visao_meia_altura** (movimento): F (sim). A borda real medida em 10/11/2026 é 13 nos dois eixos: selvagens se — fecha com: gravação de luta média (MV1–MV3) ou mais trechos da gravação livre no validador
- **Orre** (hipótese F): a dificuldade depende do dano dos selvagens de nível alto na sim — fecha com gravação de Orre.
- **Viés do Larvitar** na captura (z 2,1) — fecha com gravações de captura de outras espécies EPIC.
