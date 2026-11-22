# Poke Idle em Godot — instruções para o Claude Code

Leia este arquivo inteiro antes de qualquer mudança. Ele é o ponto de entrada do projeto.

> **Estratégia desde 19/11 (`ESTRATEGIA.md`): o melhor poke idle possível, sem esperar gravação.**
> - **Classe 1, exata:** o que o jogador vê ou compara com a Pokepedia (XP, stats, IV ≤ 32, Quality, preços, loot,
>   evolução, nível das hunts) é igual ao original.
> - **Classe 2, equivalente no resultado:** movimento, dano nos extremos, chegada de selvagens. Pronto quando abates/min,
>   XP/h, ouro/h, mortes/h e capturas/h ficam a ±10% do real por trecho (`ferramentas/validar_resultado.py`).
> - **Classe 3, desenhada:** sem dado ou original incoerente. Decidir pelo design, documentar em uma linha e pôr o valor
>   em `dados/balanceamento.json`, nunca fixo no código.
> - Gravações livres (`poke har/gravacoes/livre/`) só conferem; se contradisserem uma decisão, corrigir.
> - Perguntar só decisões de produto, em bloco no fim do ciclo. Conteúdo (sprites, nomes, sons) em pacotes trocáveis.
>
> A regra "não afirme fidelidade sem medir" continua valendo, mas só para a classe 1. Na classe 2 vale o validador; na 3,
> a decisão documentada.
Plano completo (documento vivo): https://claude.ai/artifact/8Fzh6gME8oREBhWN5paLe8

## Objetivo

Jogo instalável em Godot 4 / GDScript, 2D, offline, que **replica fielmente o Poke Idle World**
(https://poke.idleworld.online), com desempenho e fluidez melhores que o original no navegador.
Depois: usar a réplica como base para evoluir, e por fim uma versão online com servidor autoritativo.

O original é um cliente web fino (Next.js + PixiJS, motor estilo Tibia chamado internamente de "stonegy")
com **toda a regra no servidor**, que fala por WebSocket. A réplica copia essa arquitetura:

- **Simulação (`sim/`)**: decide tudo, em ticks de 200 ms, e emite as mesmas mensagens que o servidor original.
- **Cliente Godot**: só desenha o que a simulação manda (porta da lógica do cliente JS original).
- Offline, os dois rodam no mesmo processo (chamada direta). Online, a simulação vira um servidor headless
  sem reescrever o jogo.

## Onde está cada coisa

Esta pasta é a raiz do projeto Godot (conteúdo de `PROJETO_ATUAL`, checkpoint P04 revisada) mais o kit da fase 0:

| Caminho | O que é |
| --- | --- |
| `project.godot`, `*.gd`, `*.tscn`, `assets/` | Projeto atual: cidade Cerulean, mapa-múndi, painéis, hunt antiga, save |
| `ferramentas/coletor/coletor_poke.js` | Coleta um snapshot do servidor (rodar no navegador; modo "Baixar como ZIPs") |
| `ferramentas/gravador/gravador_ws.user.js` | Grava mensagens WS do jogo original (userscript ou console) |
| `ferramentas/gravador/analisar_gravacao.py` | Resume gravações: cadência, faixas de dano, XP, loot, capturas |
| `ferramentas/protocolo/gerar_protocolo.py`, `regenerar.sh` | Gera `dados/protocolo.json` (`regenerar.sh` fixa as fontes: 5 chunks do jogo + todas as gravações) |
| `ferramentas/gravador/medir_passos.py`, `medir_pocao.py` | Medem nas gravações a duração dos passos (por tick exato) e o gatilho/escolha do Auto-Potion |
| `caca_sim.gd`, `caca_sim.tscn` | Cena de hunt sobre a simulação (mapa real, sim em processo, save atualizado pelas mensagens). Única cena de hunt desde o ciclo 3 (a antiga, `Caca.tscn`, foi removida) |
| `render/` | Fase 2: `regras_desenho.gd` (ordem/posição dos sprites do mapa), `mapa_renderizador.gd` (desenho em lote), `interpolacao.gd` (walkFrom/stepStartAt/relógio). Portes conferidos contra o JS original rodado no Node (`ferramentas/render/referencia_*.js`) |
| `ferramentas/gravador/medir_movimento.py` | Adjacentes/perseguição por field, coleira (spawn), caminho do herói até o alvo |
| `ferramentas/gravador/relatorio_individuos.py` | Por indivíduo selvagem: maxHp → stat HP → faixa de IV/Quality → dano previsto × observado (para a fase 3) |
| `ponte/servidor_sim.gd`, `ferramentas/ponte/ponte_poke_local.py` | Ponte: o cliente original (poke-local) desenha a hunt da simulação. `python ferramentas/ponte/ponte_poke_local.py` e abrir http://127.0.0.1:8000 |
| `ferramentas/importador/importar_snapshot.py` | Snapshot → `dados/gerados/*.json` (determinístico) |
| `ferramentas/importador/diff_snapshots.py` | Diferenças entre snapshots |
| `testes/test_todas_hunts.py` (+ `.gd`) | Varredura 2b.6: entra em cada hunt pela cena nova e registra carga, erros, abates, XP, quadro (p99/pior, render CPU/GPU, draw calls, composição dos quadros lentos), saves. `--velocidade 1` cobra p99 < 16,7 ms; acelerado, o quadro é só informativo |
| `ferramentas/gravador/atualizar_corpos.py` | Mantém `dados/corpos_por_especie.json` (espécie → cadáver, A) somando as observações de qualquer gravação nova (cada arquivo entra uma vez, por sha256) |
| `testes/diag_ilhas.gd` | Ilha da grade do `start` e de cada spawn do hunt-config, por hunt |
| `render/atlas_mapa.gd` | Atlas por mapa (só os quadros usados, numa textura) em `cache/mapas/<slug>.atlas.bin`; pré-geração junto com o cache (`ferramentas/render/gerar_cache_mapas.gd`) |
| `sim/metas.gd`, `painel_metas.gd` | Ciclo 2: metas visíveis (hunt recomendada pelo XP/min estimado, próxima meta, marcos de nível e coleção); classe 3 em `balanceamento.json` "metas" |
| `textos.gd`, `dados/pacotes/textos_pt.json` | Pacote de textos do cliente original (trocável), gerado por `ferramentas/inventario/gerar_pacote_textos.py` |
| `janela_base.gd`, `janelas_dock.gd` | Janelas do ciclo 2 nos ícones do dock: Perfil, Bolas usadas, Log de Capturas, Hunt Analyzer, Pokédex, Todos os Shinys, Inventário, Streak, Diário |
| `avisos_hud.gd`, `painel_tutorial.gd` | Avisos da hunt (level up, shiny, barra de boosts) e o tutorial do Professor Carvalho |
| `ferramentas/build/montar_build.sh` | Monta `builds/<nome>/` (exe do template oficial + pck + `jogo/` + `dados/` mínimos) e verifica em 3 fases com APPDATA isolado (`verificar_build.gd`) |
| `ferramentas/build/gerar_pacote_jogo.gd` | Pacote de execução `jogo/`: mapas `.json.zst`, atlas, outfits, cadáveres, hunt-config, ícones (sem o snapshot bruto) |
| `sim/servico_ginasios.gd`, `painel_ginasios.gd` | Ciclo 3: 18 ginásios, luta automática, insígnias; times em `balanceamento.json` "ginasios" (`ferramentas/balanceamento/gerar_ginasios.py`) |
| `sim/servico_bosses.gd`, `painel_bosses.gd` | Ciclo 3: 87 bosses, token, Auto Boss, Altar; `balanceamento.json` "bosses" (`gerar_bosses.py`) |
| `sim/servico_cards.gd`, `painel_album.gd` | Ciclo 3: álbum de Pokécards (430, `dados/gerados/pokecards.json`) |
| `seletor_visual.gd`, `painel_visual.gd` | Ciclo 3: visual do treinador (criação e Perfil), desenhado pelo `render/outfits.gd` |
| `dados/gerados/` | especies (647), golpes (407), itens (670), hunts (451), cidades (3), regras, relatório |
| `dados/protocolo.json` | 146 tipos de mensagem; 65 comandos que o cliente envia; 72 eventos que ele escuta; 59 vistos nas gravações; 36 caminhos REST (com as gravações da fase 4) |
| `ferramentas/fase3/conferir_fase3.py`, `s3_individuos.py` | Conferem as gravações da fase 3 (`poke har/gravacoes/fase3/<ID>.jsonl`) contra `PLANO_GRAVACOES_FASE3.md`: configuração, golpes do líder por indivíduo, capturas × modelo do medidor (partindo do used-balls do início), lock de entrada |
| `ferramentas/gravador/rest.py` | Lê as linhas `dir: "rest"` do gravador v1.1 (respostas de `/api/game/*`); medidor de captura do used-balls e a diferença entre duas respostas |
| `dados/correcoes.json` | Correções sobre o publicado (IV até 32) |
| `sim/servico_cidade.gd`, `ponte_cidade.gd` | Fase 4, lote 1: serviços da cidade (evolução, loja do Mark, Nurse Joy, depot) puros na `sim/`; a ponte monta o estado do save, manda o comando e aplica as mensagens no `EstadoJogo`. Regras e fontes em `CALIBRACAO_FASE4.md` |
| `sim/servico_jogador.gd` | Fase 4, lote 2: sessão, Modo Soneca (amostra de 5 min pela própria sim, coleta de 50%), Streak Points e Tipo do Dia; parcelas `streak`/`boost`/`typeDay` e efeitos de loot na `simulacao_hunt.gd`. Regras em `CALIBRACAO_FASE4.md` |
| `painel_soneca.gd`, `painel_streak.gd` | Coleta da soneca ao abrir a cidade e janela de Streak Points (⚙ → Streak Points); botão 💤 Zzz na HUD da hunt |
| `sim/servico_diarias.gd`, `painel_diarias.gd` | Fase 4, item 3: Daily Gift, Quests & Tasks (124 tarefas, 43 cidades), Daily Kill e Daily Catch, puros na `sim/` com os dados gravados em `dados/fase4/` (gerados por `ferramentas/gravador/extrair_fase4.py`); janela ⚙ → Quests, Tasks & Dailys |
| `sim/servico_itens.gd`, `painel_itens_uso.gd` | Fase 4, lote 3: Rare Candy e berries (efeito das berries no combate em `simulacao_hunt.gd`); janela ⚙ → Usar itens |
| `sim/servico_ginasios.gd`, `sim/servico_invasao.gd` | Fase 4, lote 4: insígnias de ginásio (+ parcela `gym` na hunt), catálogo de bosses e calendário da invasão |
| `ferramentas/gravador/segmentar.py` | Gravação livre (pasta `poke har/gravacoes/livre/`, uma exportação por dia): junta sem repetir e corta em trechos (cidade × hunt, entrada × retomada e lock, troca de time, zoom, buraco de aba), com o uso de cada um |
| `ferramentas/processar_gravacao.py` | Um comando por gravação: quais regras de CALIBRACAO_FASE3/4 ela cobre, o que confirmou, o que contradisse (com números) e o que não cobre → `dados/relatorios/gravacoes/gravacao_<nome>.md`. Teste `testes/test_processar_gravacao.py` (as conclusões já registradas) |
| `sim/servico_novo_jogo.gd`, `painel_novo_jogo.gd` | Jogo novo como o original: Bulbasaur/Charmander/Squirtle no nível 1, 100 Small Potions e 100 Poké Balls, primeira hunt recomendada; a tela só abre quando o jogo começa de verdade sem save |
| `ferramentas/fase4/comparar_nivel_baixo.py` | Item 2: real × sim por minuto (abates, desmaios, HP, dano dado/recebido, níveis) para time de nível baixo |
| `ferramentas/fase4/ajustar_dano.py` | Item 1: confere variantes da fórmula de dano contra todos os golpes gravados → `dados/relatorios/ajuste_dano.md` |
| `painel_loja.gd`, `painel_evolucao.gd` | Telas novas (só desenham e mandam comandos): loja do Mark (comprar, vender itens, vender Pokémon) e janela de evolução (com pedras mantém o nível; sem pedras volta ao Lv.1) |
| `ferramentas/gravador/medir_alvo.py` | Escolha de alvo do herói nas gravações: mais próximo em linha reta × menor tempo de caminho, por hunt |
| `dados/testes/field_init_<slug>.json` | Grades reais enviadas pelo servidor em 7 hunts (geodude, rhyhorn, rhydon, kangaskhan, typhlosion, blastoise, rattata): gabarito da colisão |

Dados grandes/de referência — **ficam dentro desta pasta**, fora do git (`.gitignore`) e fora do scan do Godot (`.gdignore`).
As pastas `Desktop\poke har\` e `Desktop\poke-local\` fora do projeto existem, mas estão vazias.
A simulação acha o snapshot por `POKE_SNAPSHOT` ou pelo caminho relativo abaixo (`sim/fontes.gd`).

| Caminho (relativo à raiz) | O que é |
| --- | --- |
| `poke har/extraido/snapshot_2026-11-09/` | Snapshot do servidor: `game/maps/<slug>.json` (455 mapas), `api/hunt-config/`, `api/city-npcs/`, `game/creatures.json`, `items.json`, `collision.json`, `offsets.json`, `draworder.json`, `corpses/`, `asset-packs/` (97 páginas do atlas), `assets/` (ícones), `manifest.json` com SHA-256 |
| `poke har/gravacoes/` | Gravações reais + `ANALISE_GRAVACOES_2026-11-09.md` + `gravacoes_unicas_2026-11-09.jsonl` |
| `poke-local/public/_next/static/chunks/0gx72gz9qjk5j.js` | Cliente original (renderer, interpolação, protocolo). Referência para portar |
| `poke-local/` | Servidor Python local que serve o cliente original com um WS falso (`serve.py`, `hunt.py`) |

Arquivos `*.json` gerados nunca são editados à mão: correção vai em `dados/correcoes.json` e o importador roda de novo.
O snapshot é grande (582 MB): não copie para dentro do projeto nem para o git.

## Regras de trabalho

- **Separe sempre a origem do que afirma**: (A) observado no servidor original, (B) publicado na Pokepedia,
  (C) extraído do cliente, (D) testado localmente, (E) decisão do projeto, (F) hipótese. Nunca apresente F como A.
- **Não afirme fidelidade sem medir.** "Implementado" não é "fiel". Registre fonte e limites de cada regra.
- Não reaplique patches antigos nem reabra correções comprovadas sem evidência nova.
- Não peça coletas novas antes de consultar `dados/`, as gravações e o cliente original.
- **Nunca rode testes contra o save real do usuário.** Use diretório de dados isolado por teste.
- Preserve os `.gd.uid` existentes. Entregue arquivos completos; nada de trechos para colar.
- Testes de verdade: reproduza com fixture, rode no Godot, registre o resultado. Número de asserções não é cobertura.
- Ao terminar um item, atualize a seção "Estado" deste arquivo (curta: o que mudou, teste, limitação).

### Decisões do usuário (E — valem mesmo sem confirmação no original)

- **Jogo idle roda em segundo plano** (15/11): o critério de quadro (p99 ≤ 16,7 ms) vale com a janela em foco; sem foco, o
  que se cobra é a simulação seguir o relógio (nenhum tick perdido) e gastar pouco. Sem foco ou minimizado, o desenho cai
  para 10 quadros/s (`EstadoJogo.definir_modo_fundo`); atraso de ticks é recuperado, com teto de 1 h.

- **Escopo atual (18/11)**: lotes 3 e 4 congelados. Foco: do zero (treinador 1, Geodude 1) a todas as hunts, com XP,
  golpes e dano, combate, loot, Auto-Potion, Auto-Catch, Nurse Joy, depot, IV e Quality iguais ao original. Critério de
  pronto: o placar em `PLACAR_ESCOPO.md`.
- **Inicial do jogo novo: Geodude nível 1** (18/11). Os iniciais do original (Bulbasaur, Charmander, Squirtle) ficam como
  opção na tela de jogo novo (caixa "Iniciais do original"). Primeira hunt recomendada para o Geodude: Rattata (A: geodude-10min).
- Troca automática após KO: **aleatória** entre membros vivos e válidos do TIME (não do box), sem curar;
  depois dela, 5 s de cooldown para troca manual. Volta à cidade só quando não há reserva viva.
- Interações da cidade por **clique** (NPCs/depot); nada de tecla obrigatória. HUD responsivo, referência 1920×1080.
- **IV de 1 a 32 por atributo** (total 192). A Pokepedia cita 31 em parte do texto; vale 32.
- Mostrar IV individual exato no depot é melhoria deliberada (o original mostra total/faixas).
- Um cartão de derrota por vez, sem fila, no máximo 30 exibições por instância (limita apresentação, não prêmios).
- Contador "Capture" reinicia a cada nova instância de hunt; sem mensagem "X captured...".
- Captura manual e efeito de Speed na cadência: adiados.
- Fase 2: a hunt jogável é uma cena nova (`caca_sim.tscn`) em vez de reescrever `caca.gd`/`caca_base.gd` por dentro: ~30 testes antigos
  dependem da lógica interna da cena antiga. O mapa-múndi decide qual abrir (simulada se houver mapa e hunt-config no snapshot).
- VIP: opção nas Configurações (⚙ na cidade), **desligada por padrão**; ligada, +50% da XP base como no original
  (parcela `vip`). Ouro inicial 0. Revenda ao NPC nunca acima do preço de compra (evita ouro infinito com poções).
- **Piso de XP em Orre** (20/11; reduzido em 22/11): o multiplicador de cada hunt de Orre é max(×10, 16.500 ÷ XP base médio da
  hunt), classe 3 em `balanceamento.json` combate.xp_regiao_piso (era 40.524 no ciclo 5). Com time e TMs, Orre 510–579 rende o
  mesmo que a melhor Outland; 580+ fica no ×10.
- Outfits: desde 09/11 o snapshot tem os 846 do índice (545 categorias); o substituto (200) só entra se faltar algum.

Resumo da calibração da fase 3 (cada regra, fonte, evidência, o que ficou aberto): `CALIBRACAO_FASE3.md`.
Proposta da fase 4 (não implementada): `PLANO_FASE4.md`.

## Fatos confirmados (fonte A, salvo indicação)

| Regra | Evidência |
| --- | --- |
| Servidor em ticks de 200 ms; snapshot `field` a cada 2 ticks (400 ms); `seq` conta ticks | todos os logs |
| `field-init` anuncia heroStepMs 500, trainerStepMs 500, mobStepMs 1000. Espera real antes de cada passo = stepMs × (2 se diagonal), arredondada para cima ao tick: herói →reto 600 ms, →diagonal 1000/1200; selvagem →reto 1000/1200, →diagonal 2000. Treinador = posição do herói, sempre | `medir_passos.py`, 45 instâncias |
| Em todo `field`, stepStartAt = serverNow; walkFrom ≠ posição só no field do tick em que o passo começou | 4046 fields |
| Ritmo de ataque: aliado ~1600 ms; cada selvagem ~2000 ms (às vezes +1 tick) | 557 hits de Solar Beam, 532 selvagens, Gastly, Bulbasaur |
| HP de combate do aliado = max(24, 12 × stat de HP) | Venusaur 120→1440, 121→1452; Geodude 2→24, 3→36 |
| HP do selvagem = max(120, 35 × stat de HP) | todos os maxHp de Rhyhorn, Rhydon, Kangaskhan, Blastoise; Geodude nível 1 no piso |
| Stat = round(L/100 × (base + 2·IV) × Quality^exp); exp 0,95 HP/vel, 0,8 demais; Power = round(Σstats × Quality) | (B)+(C), paridade testada antes |
| Fator aleatório 0,85–1,00 por golpe | máx/mín ≤ 1,17 dentro do mesmo indivíduo (72 indivíduos) |
| Efetividade amplificada: ×1,5→1,75; ×2→2,5; ×4→5,5; resistência ÷1,5 (×½ → 0,333); ×0 e ×1 iguais | (B) + `eff` nos hits |
| Golpe do líder: sempre o mesmo por indivíduo selvagem; a efetividade e a razão A/D do indivíduo mudam a escolha; empate exato (poder, tipo, categoria e cooldown iguais) → o primeiro da lista | fase3 S1–S4: 324 hits; Stone Edge 58/58 no Rhydon e Earthquake 59/59 no Golem (empate), Hammer Arm 32/32, Double-Edge 39/39, Gyarados com Aqua Tail em 3 e Hydro Pump em 12 Rhyhorn (15/15 coerentes com os stats possíveis) |
| **Piso de dano: 2 para o aliado, 1 para o selvagem — inclusive com eff 0 ou resistido** | Gastly×Rattata (eff 0: 2 e 1); Rattata→Geodude resistido: 1 em 880 hits |
| XP base por abate = `experience` da espécie; VIP soma +50% em parcela separada (`xpParts`) | 200+ abates |
| Penalidade de entrada = boost `shinylock` (C: "Por 1 minuto: nenhum Pokémon Shiny aparece e você recebe 70% menos EXP e drops"): `boosts {key: shinylock, until}` chega logo depois do field-init; until = entrada + 60 s (o minuto conta da **entrada**); todo abate antes do until sai com `xpParts.debuff` (XP = floor(total × 0,3)), nenhum depois; drops ~0,27×; o lock atravessa a retomada `:rN`. **Quando**: hunt diferente da última penaliza, vindo da cidade ou direto pelo mapa; voltar à mesma hunt pela cidade não penaliza. Sessão expirada (15 min com o jogo fechado) penaliza: B-relatado, não gravado | 12 entradas com `boosts`: until − entrada 58,9–61,4 s (no T1, pelo serverNow; o relógio local estava 77 s atrás); 76/76 abates no lock com XP = floor(total × 0,3); drops 42 contra 153,5 esperados. T1: rattata → cidade (29 s) → spearow, lock de 60 s desde a entrada (os 29 s na cidade não contaram); spearow → vulpix pelo mapa, lock; vulpix → cidade → vulpix, **sem lock** (0/15 abates com debuff). S3 é a única exceção (sem `boosts`, lock acabando 20–30 s após a entrada) |
| Os hits do `field` que o cliente não recebe não se perdem: vão no próximo field entregue; o `field-kill` sai no tick do abate, antes do field com o golpe final | rhydon-1h: hits/field 0,18 com Δseq 2, 0,91 com Δseq 10 |
| XP acumulada = round(50/3 × (L³ − 6L² + 17L − 12)) → 100/200/400/800 para níveis 2–5 | (B) + Geodude subiu com 102, 210; nível 4 com 714 |
| Loot: tabela de `creatures.json`, chance em 1/100.000, quantidade min–max | Rhydon 60 abates: Horn 83,3% vs 83,32% |
| Hyper Potion cura até 1000, limitado ao HP que falta | 60+ auto-heals |
| Auto-Potion dispara no mesmo tick em que o HP fica ≤ 50% (sem recarga observada); usa a menor poção do inventário que cobre o que falta, ou a maior se nenhuma cobre | `medir_pocao.py`: 42/42 cruzamentos; 208/208 escolhas |
| Golpes: o mesmo nome tem cooldown diferente por espécie (234 de 407 variam) | catálogo; por isso golpes ficam dentro de cada espécie |
| Captura com Super Ball: 59% em Rattata nível 1 (35/59); no Rhydon 80, 0 em 167 (gravações antigas) e 5 em 608 na rhydon-1h (~0,8%); Vulpix nível 20: 2 em 37 (fase3/S4); o capturado chega como poke-delta de nível 1 | gravações; `hunt-config.catchChance` é 0 em todas |
| A chance sobe com o investimento desde a última captura da espécie (medidor, C: tutorial e tela used-balls). **`goldSpent` do used-balls = ouro gasto desde a última captura** (zera com ela, como `attempts`): Rattata attempts 1 → 50, Vulpix 16 → 800, Spearow 0 → 0 (Super Ball = 50). Por tentativa desde a última captura: Rattata 1 (preço 80) 15/34, 15/18, 3/3; Spearow 10 (preço 100) 13/28, 7/14, 7/7. **O nível não pesa**: Meowth 20 e Geodude 1, os dois com preço 300, ajustam o mesmo fator (0,75 × 0,84, ganho de logL 0,13); Meowth 17/87 partindo de medidor zero (espécie ausente do used-balls do início), o modelo esperava 18,4 | geodude-10min, geodeude-2, C1, S4, c2, C6, C5, C8, T1, rhydon-1h (A); forma da sim F |
| **Valor da bola no medidor = ouro pago (priceGold), não catchRate.** Geodude 1 (preço 300), mesma conta e hunt, esperado pelo ouro × pela eficiência (mesmo c/k): Poké 0,9 × 4,0 (obs. 0/47), Great 5,1 × 9,8 (6/60), Super 12,9 × 13,7 (10/59), Ultra 33,1 × 20,3 (37/69), Idle 73,0 × 26,2 (73/73); logL −190,6 × −294,5; valor livre por bola: Great 23, Ultra 143 (ouro 20, 130). Toda falha de Idle Ball (5: S2, C5, M3) foi em shiny | fase3/C5 (conta B), S2, M3 |
| **Alvo do herói = selvagem vivo com o menor tempo de caminho até encostar** (não o mais perto em linha reta). Os dois critérios discordam em 457 trocas: o caminho acerta 408 delas, a linha reta 180 | `medir_alvo.py`, 16 hunts, 2400 trocas de alvo: caminho 2295 (95,6%) × Chebyshev 2067 (86,1%); rhydon-1h 605/636 × 530/636 |
| Selvagens perseguem o herói só com \|dx\| ≤ 13 **e** \|dy\| ≤ 13 (0,16–0,43 de chance de se aproximar por intervalo até 13; zero a partir de 14 nos dois eixos). Fora disso ficam parados no lugar (100% dos intervalos com a caixa 13×13) | rhydon-1h (centenas de intervalos por distância), M1, M2 |
| `view {hc, hr}` = {ceil(25/zoom/2) + 2, ceil(13/zoom/2) + 2}, enviado no field-init e quando o zoom muda; o tamanho da janela não entra. 27×15 (zoom 0,5) em todas as gravações | (C) chunk 0gx72gz9qjk5j.js; M2 |
| 15 spawns por hunt em Kanto/Outland, 16 em Orre, até 56 em Nightmare | `hunt-config` |

### Fórmula de dano candidata (F, coerente com todos os casos medidos)

```
dano = max(piso, (2·L/5 + 2) · Poder · A/D / 50 · STAB(1,5) · eff_amplificada · (1,8 se selvagem) · aleatório(0,85..1,00))
A/D = SpA/SpD (golpe especial) ou Atk/Def (físico); piso = 2 aliado / 1 selvagem
stats do selvagem SEM arredondar; stats do aliado = os exibidos (arredondados)   ← padrão desde 09/11 (F, forte)
```

Evidência do arredondamento (`relatorio_individuos.py`, rhydon-1h, 40–160 hits por indivíduo): com SpA do aliado exibida e
SpD do selvagem contínua, 15/15 indivíduos explicados; SpD inteira, 2/15; SpA do aliado também contínua, 10/15.
Parâmetros `stats_dano_selvagem` / `stats_dano_aliado` ("continuo"/"inteiro") voltam ao modelo antigo.

Envelopes previstos contêm os observados em: Venusaur 109 Solar Beam → Rhydon 80 (910–2282) e → Kangaskhan 80 (128–230);
Rhydon Stone Edge → Venusaur (241–432); Kangaskhan Mega Punch → Venusaur (136–207).
Em aberto (**desvio conhecido, medido em 11/11; ajuste tentado em 13/11, não aplicado**): no nível 1 o Geodude tira 6 ou 8 em Rattata (A, geodude-10min, 153 hits; nível 2: 8–10, nível 3: 12–14, nível 4: 20–23) e a sim tira 2 (o piso); um time de nível 1 não abate nada em 60 s na sim (40/40 sementes, `testes/varrer_sementes_sim.gd`).
Ajuste (`ferramentas/fase4/ajustar_dano.py` → `dados/relatorios/ajuste_dano.md`; 26 gravações, 7389 golpes; stat desconhecido do selvagem varrido na faixa contínua que o maxHp permite, indivíduo separado a cada captura). % de golpes explicados:

| Variante (`formula_dano`) | aliado 1–4 (472) | aliado 80–199 (4376) | aliado 200+ (653, C5) | selvagem 1–4 (101) | selvagem 80–199 (1787) | dif. 1h | dif. antiga | 40 sementes sem abate (HP cheio a cada passo) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| c `atual` (piso, divisor ≥ 1) | 32,6 | 99,6 | 47,3 | 100 | 99,2 | 27/30 | 23/26 | 40/40 (40/40) |
| a `classica` (+2 antes dos mods) | 66,5 | 99,8 | 47,3 | **0** | 98,9 | 26/30 | 23/26 | 40/40 (9/40) |
| b `mais2_fim` (+2 no fim) | 66,5 | 99,7 | 47,3 | **0** | 98,8 | 25/30 | 23/26 | 40/40 (4/40) |
| e `sem_piso_divisor` (D contínuo < 1 permitido) | 90,5 | 99,6 | 80,9 | 100 | 99,2 | 27/30 | 23/26 | 40/40 (40/40) |

a e b caem para 0% no selvagem de nível 1 (o +2 passa do envelope em todos os golpes; erro médio 1,0) e pioram o diferencial; e é ≥ c em toda gravação, mas não explica todas as faixas (o resto fica no limite de baixo da faixa de stat do selvagem de nível baixo). Em 13/11 nenhuma foi aplicada; **desde 15/11 a e é o padrão** (decisão do usuário: igual ou melhor em todas as gravações; diferencial 27/30 e 23/26, iguais). Nas 40 sementes (Larvitar Lv.1 no geodude, 60 s), e não muda nada: a Def do Geodude é ≥ 1 e o divisor nunca entra.
**15/11, causa do 0/40 (item 2):** reproduzindo na sim o estado da `geodude-10min` (Geodude Lv.1, Q 1,137, IV 173, hunt
`rattata`, VIP, Small Potion, Super Ball; `dados/testes/estado_rattata_geodude_nivel1.json`) e comparando por minuto
(`ferramentas/fase4/comparar_nivel_baixo.py`, 20 sementes × 8 min, só fields do Geodude na `rattata`), a única grandeza
que diverge é o **dano do aliado no nível 1**: real 6–8 (média 7,24, 153 golpes), sim 2–6 (2,82). HP do aliado (0,755 × 0,778),
HP do selvagem (120 × 120) e dano recebido (1 × 1) batem; HP 24 = max(24, 12×stat) confere. O servidor mostra Atk 1 nesse
Geodude e o dano pede ~3: **piso 3 no ataque do aliado** (`piso_ataque_aliado`, F) → aliado 1–4 98,1% dos golpes
explicados (90,5% sem), nenhuma outra faixa ou gravação muda; no selvagem o piso piora (100% → 85,1%), então só no aliado.

| Por minuto (geodude-10min, rattata) | Real | Sim antes (p05–p95) | Sim com o piso (p05–p95) |
| --- | --- | --- | --- |
| Abates | 2,55 | 0,75 (0,62–1,12) | **2,62** (2,25–3,00) |
| Níveis ganhos | 0,232 | 0 (0–0,125) | **0,25** (0,25–0,25) |
| Dano dado no nível 1 (mín–média–máx) | 6–7,24–8 | 2–2,82–6 | 5–8,69–19 |
| HP médio do aliado | 0,755 | 0,778 | 0,775 |
| Golpes recebidos | 72,9 | 52,1 | 31,1 |
| Curas | 5,8 | 4,38 | 2,62 |

Ficam abertos: a dispersão do dano no nível 1 (o real é estreito, 6–8, como se a Def do Rattata ficasse perto de 1 em todos
os indivíduos; a sim sorteia Def contínua 0,3–1,4) e os golpes recebidos/curas (desvio de movimento: menos selvagens
encostam na sim). "Piso 3" e "stats do nível 2" não se separam com um atacante só (G11). Teste das 40 sementes (Larvitar
Lv.1 na hunt do Geodude, sem poção e sem reserva): 38/40 sem abate, porque o Larvitar desmaia depois de 11–18 golpes; não
há gravação desse cenário.
**15/11, dispersão do dano no nível 1 (5–19 na sim × 6–8 no real):** não vem de golpe, efetividade, STAB nem crítico
(Geodude Lv.1 só usa Tackle, eficácia 1, nos dois lados). Vem da **defesa do selvagem por indivíduo**: na sim, dentro de cada
indivíduo o dano varia só pelo aleatório e entre indivíduos vai de 5 a 18. No real, os 10 Rattata atingidos no nível 1 levam
6–8 todos, inclusive os capturados com Def exibida 0 (contínua < 0,5) e 1. `ferramentas/fase4/stat_comum.py` →
`dados/relatorios/defesa_comum.md` (intervalo de defesa comum a todos os indivíduos):

| Gravação | Selvagem (nível) | Golpe do aliado | Indivíduos | Defesa comum |
| --- | --- | --- | --- | --- |
| S1 | Oddish (1) | Stone Edge, Earthquake (Rhydon 425, Golem 387) | 15 | **0,767–0,774** |
| S2 | Rattata (1) | Hammer Arm (Rhydon 425) | 13 | **0,765–0,773** |
| geodude-10min | Rattata (1) | Tackle (Geodude Lv.1, com o piso 3) | 10 | 0,942–0,960 |
| c5 | Geodude (1) | Earthquake (Rhydon 425) | 52 | vazio (1,54 > 0,77) |
| rhydon-1h, M1–M3, G9 | Rhydon 80, Kangaskhan 80, Arbok 40 | vários | 9–26 | vazio (os indivíduos diferem) |

Leitura: no selvagem de nível 1 a defesa no dano parece **não depender do indivíduo nem da espécie** (Oddish e Rattata, bases 55 e
35, dão o mesmo 0,77); nos níveis 40–80 depende. O c5 (Geodude nível 1) contradiz, e a geodude-10min (09/11) pede outro valor
(0,95 com piso 3 no ataque; com 0,77, o ataque efetivo do Geodude teria de ser 2,43): pode ser mudança no servidor entre
09/11 e 10/11, ou uma regra que ainda não aparece. **Não corrigido** (a causa da dispersão está clara, a regra não). A G11
(capturas de nível 1 com stats exatos, depois de apanharem) decide.
**15/11, mudança no servidor entre 09/11 e 10/11?** (`ferramentas/fase4/comparar_dias.py` → `dados/relatorios/servidor_09x10.md`):
nenhuma outra grandeza mudou. HP do aliado e do selvagem, XP base, VIP, debuff, typeDay, loot × tabela (normal, lock e tipo do
dia), passos, cadência, Auto-Potion, pisos e o lock de 60 s confirmam igual em 09/11 e em 10/11–15/11. O maxHp dos selvagens
contra o previsto pela fórmula (IV 1–32, Quality pelos pesos do cliente) dá z médio −0,80 em 09/11 e −0,57 em 10/11 (sem
deslocamento entre os dias; o Rhydon de 10/11 sai −2,46, mas o Rhyhorn do mesmo dia +2,02). A diferença de defesa
(0,95 × 0,77) fica sem explicação por data: a geodude-10min é a única com atacante de nível 1, e S1/S2 têm atacante 425 —
pode depender do atacante, não do dia. Achado de passagem (A): na hunt typhlosion os Rattata ficam no piso de 120 de HP,
ou seja, não estão no nível 80 da hunt.
Teste de calibração disponível: 680 hits do Geodude níveis 1–4 (`gravacoes/geodude-*.jsonl`).

### Em aberto (não invente; deixe parametrizado e marcado)

Seleção de golpe: o critério exato de "maior dano esperado" (A em S1–S4, ver Fatos; não houve caso perto do empate fora do empate exato), e o desempate por cooldown (só o Solar Beam × Petal Dance),
IA de movimento dos selvagens (desvio conhecido, seção abaixo), medidor de captura (raridade; c e k são F; shinyBase por tier desconhecido), penalidade de entrada (o S3 e a expiração de sessão, B-relatada), parcela extra de XP
vista na conta B (×1,554 em vez de ×1,5; a conta B tem uma parcela `guild`, 24 em 548 no Rhyhorn, A, e o Pokémon dela recebe `mentor`), efeitos de status,
regras de respawn (tempo exato).

### Sombras e iluminação do cliente (portadas em 15/11; ligadas por padrão)

Receita (C, `makeShadow`/`syncShadow`/`applyShadowFilters`/`sb`/`sj`/`feetBaseY`): `render/sombras.gd`. Sprite do mapa com
zIndex > 7,5e6 e altura > 32, toda criatura: cópia preta na camada do andar (zIndex 7,5e6), âncora nos pés, altura ×
tan(latitude), skew x = −longitude; camada com blur (`soft`) e alpha de grupo diffuse/(ambient + diffuse) = 0,45 (luz 45°/45°,
0,55/0,45; `rock-tunnel` e `mt-moon` 20°, 0,7/0,3 — nenhum dos 455 mapas do snapshot tem esses nomes). Porte: um canvas group
por andar (`render/sombra_grupo.gdshader`, blur de 9 pontos: aproximação F) com a transformação linear da luz; sombras dos
sprites estáticos em lote por chunk, as dos animados e das criaturas com item próprio. Conferido contra o original no Node
(`testes/test_render_sombras.sh`, `ferramentas/render/referencia_sombras.js`): rhydon 15.360, geodude 12.972 e
nightmare_steelix 45.217 sombras com os mesmos sprites, a mesma ordem e a mesma geometria; luz e sombra de criatura iguais.
Desliga com `POKE_SOMBRAS=0` (ou `mapa_renderizador.sombras_ligadas`); `POKE_SOMBRAS=simples` usa o modo sem grupo (não
ficou mais barato). p99: `dados/relatorios/p99_sombras_2026-11-15.md`.

### Desvio conhecido: movimento dos selvagens (fase 3 fechada; a sim fica com `visao_meia_altura` 7)

Medido com `ferramentas/gravador/medir_movimento.py` (caixa 13×13) e contagem de chegadas ao herói (A = gravações reais;
sim = 2–3 instâncias de 20–60 min com o estado inicial de cada gravação).

**Borda da perseguição (A):** \|dx\| ≤ 13 **e** \|dy\| ≤ 13 (zero a partir de 14 nos dois eixos; fora dela, 100% parados).
A sim usa 13 × 7: com 13 × 13 ela junta selvagens demais no herói em luta curta, e o diferencial do Rhydon perde um
critério em cada caso (1h 26/30, antiga 22/26). A sim também persegue com \|dx\| = 14 e o real nunca (F: a checagem
real deve usar a posição de antes do passo).

**O desvio:** selvagem que não é o alvo chegando ao lado do herói (vindo de d ≥ 2), por minuto:

| Gravação (luta) | Real | Sim 7 | Sim 13 |
| --- | --- | --- | --- |
| M1, Kangaskhan, Venusaur (~22 s por abate) | 3,35 | 1,06 | 1,07 |
| M2, Kangaskhan, Venusaur (~22 s) | 1,45 | (mesmo estado do M1) | (idem) |
| rhydon-1h, Venusaur (~3 s) | 0,76 | 1,37 | 2,64 |
| M3, Rhydon, Golem (1 golpe) | 0,32 | 0,57 | 1,88 |

Em luta curta o real junta **menos** não-alvos que a sim; em luta longa, **mais**. Outras métricas (caixa 13×13):

| Métrica | rhydon-1h real · sim 7 · sim 13 | M1 / M2 real · sim 7 · sim 13 | M3 real · sim 7 · sim 13 |
| --- | --- | --- | --- |
| Adjacentes por field (média) | 0,40 · 0,44 · 0,58 | 1,38 / 1,28 · 1,08 · 1,25 | 0,03 · 0,06 · 0,13 |
| Perseguindo por field | 0,66 · 0,51 · 0,55 | 0,16 / 0,22 · 0,11 · 0,11 | 0,92 · 0,66 · 0,68 |
| Caminho do herói: tiles ÷ Chebyshev (mediana) | 0,62 · 0,67 · 0,64 | 0,66 / 0,67 · 1,08 · 0,67 | 0,42 · 0,63 · 0,50 |
| ms por tile: herói; selvagem | 758; 1136 · 820; 1316 · 827; 1282 | 786; 1314 / 763; 1233 · 801; 1238 · 759; 1300 | 809; 1124 · 832; 1403 · 832; 1288 |

**Hipóteses (F → resultado):**
- H1, persegue mais na visão: explicada em parte pela borda de 13 (Kangaskhan). Em luta curta sobra o desvio acima.
- H2, coleira (volta ao spawn): nenhum retorno observado; em aberto (M4, opcional).
- H3, vaguear fora da visão: **descartada** (era perseguição com \|dy\| 8–13).
- H4, o alvo vem ao encontro: a borda de 13 aproxima (M3 0,42 real × 0,50 sim 13 × 0,63 sim 7).

**Testado e descartado como causa do desvio:**
- Tempo de respawn: 60,0 s nos dois lados.
- Selvagens vivos por field: real 5,4 / 8,0 / 12,4 × sim 5,7 / 7,5 / 12,9.
- Taxa de passo por intervalo dos não-alvos: 0,16–0,31 real × ~0,25 sim.
- Intervalo entre passos: 1000/1200 ms nos dois lados.
- Troca de alvo com o alvo vivo: 0 no real (M1, M3, 1h), como na sim.
- "Selvagem só anda N ticks depois do passo do herói" (`mob_espera_apos_heroi_ticks`, 0 = desligado): N = 5 acerta os
  adjacentes nos quatro casos, mas o selvagem passa a 3054 ms/tile (real 1136) e para de vir ao encontro do herói.
- "Selvagem só anda logo depois do passo do herói": artefato de amostragem (o cliente recebe fields a cada 2 ticks
  sobretudo quando o herói anda).

A sim fica com 7 até haver evidência nova. Opcionais: M4 (coleira), M5 (zoom × raio), M6 (luta de duração média, para
achar onde o desvio muda de sinal); ver `PLANO_GRAVACOES_FASE3.md`.
**Critério de pronto trocado em 18/11** (decisão do usuário): resultado por trecho de hunt, real × sim, ±10% — abates/min,
XP/h, mortes/h, ouro/h e selvagens ao lado do herói (`ferramentas/validar_resultado.py` (antes `ferramentas/fase4/resultado_trechos.py`),
`dados/relatorios/resultado_trechos_2026-11-18.md`). Hoje 32/55 em 11 trechos. MV1–MV3 deixaram de existir; entram os
trechos da gravação livre. O que segue é a análise anterior por grandeza, mantida como referência.
**Reaberto em 18/11** (depois do alvo pelo tempo de caminho; `dados/relatorios/movimento_2026-11-18.md`, ferramenta
`ferramentas/fase4/comparar_movimento.py`):
- A cadência de cada passo é igual nos dois lados (A × sim, pelo tick exato).
- Com 7, as chegadas de não-alvos ficam dentro em rhydon-1h, M2 e M3; só o M1 fica fora (o M2, mesmo estado, fica
  dentro). Com 13, junta demais em luta curta.
- O selvagem perseguindo anda ~18% mais devagar na sim em luta curta. Parte disso pode ser amostragem (pares Δseq = 2).
- O real se aproxima mais com o herói parado sem lutar e menos durante a luta.
- Hipóteses que sobram: H5 (histerese), H6 (borda = `view`), H7 (reação à posição antiga do herói), H8 (amostragem), H2.
- Gravações MV1 (luta média, `blastoise`), MV2 (zoom, `rhydon`) e MV3 (herói lento, `rattata`), com o roteiro no relatório.

## Protocolo (resumo; detalhes em `dados/protocolo.json` e nos logs)

Cliente → servidor: `enter-hunt {slug, resume}`, `leave-hunt`, `field-get`, `view {hc, hr}`, `switch`, `catch`,
`use-heal`, `set-city {slug}`, `pokes-get`, `balls-get`, `pending-get`, `badge-refresh`…

Servidor → cliente (hunt):
- `field-init {huntKey, slug, rows, cols, minTx, minTy, grid[rows][cols] (bool transitável), heroStepMs, bike, mobStepMs, trainerStepMs, tickMs}`
- `field {seq, serverNow, heroLooktype, heroName, bossTeam[{hp,maxHp}], bossActiveIdx, hero{row,col,facing,walkFrom,stepStartAt}, trainer{…}, mobs[{row,col,facing,walkFrom,stepStartAt,slot,speciesId,hp,maxHp,dead,respawning,shiny}], corpses[{row,col,corpse}], targetSlot, fighting, heroHp, heroMaxHp, fainted, reviveInMs, allMobsDead, waveRespawnAt, hits[{slot (−1 = no herói), amount, eff, move, type}]}`
- `field-kill {xpGained, totalXp, level, leveledUp, loot[{itemId,name,qty}], speciesId, looktype, speciesName, shiny, xpParts{base,streak,boost,vip,event,gym,typeDay}, pokeXp{…}, row, col, slot}`
- `poke-xp`, `poke-delta {poke{…stats, quality, ivTotal, power…}}`, `catch-result {auto, success, speciesName, ballName, ballId, row, col}`,
  `auto-heal {kind, name, heal}`, `inventory {items[{itemId,quantity}]}`, `balls {catalog, counts, gold, selected}`, `field-none`.

Grade: `rows`/`cols` cobrem o retângulo de tiles do mapa; `col = x − minTx`, `row = y − minTy`.
Exemplo real: Geodude e Snorlax → 88×109, minTx −54, minTy −43 (mapa com x de −54 a 54 e y de −43 a 44).
As grades reais de 7 hunts estão em `dados/testes/field_init_<slug>.json` (Geodude: 757 tiles `true`; Rhyhorn: 994; Rattata: 514…):
**use como teste de aceitação da derivação de colisão** (`collision.json` → `blocking`; tiles do mapa em `groundZ`).
Mapa `stonegy-map-compact-v1`: `tiles = [[x, y, z, idChao, [[ids de itens…]]], …]`, `_meta = {range, center, walk, tileCount, groundZ}`.
Alias de mapa no cliente: `cerulean`/`pesca` → `cerulean_novo`, `aero_boss` → `golem`.
Corpo a corpo no cliente: distância Chebyshev ≤ 1 entre herói e selvagem.
Interpolação no cliente: funções `dT`/`dM`/`dS` perto de `stepStartAt` no chunk `0gx72gz9qjk5j.js`; o dano flutuante usa `dmgDelayMs`.

## Fase 1 — simulação mínima de hunt (concluída; escopo original)

**Escopo**
1. `sim/` em GDScript puro (`RefCounted`; sem `Node`, `Timer`, `await`, nem relógio real). Entrada: estado + intenções; saída: lista de mensagens com os mesmos nomes e campos do original.
2. RNG com semente; mesma entrada → mesma saída, byte a byte.
3. Carregar `dados/gerados/` e o mapa real da hunt (`snapshot/game/maps/<slug>.json`) e o `hunt-config` (15 spawns e ponto inicial).
4. Derivar a grade transitável e **bater com a grade real do Geodude** (teste).
5. Tick 200 ms: movimento do herói/treinador (500 ms/passo) e selvagens (1000 ms/passo) na grade; escolha de alvo; ataque com o ritmo observado; dano pela fórmula candidata (parametrizada); HP 12×/35×; KO, corpo, respawn; XP com `xpParts`; loot pela tabela; Auto-Potion; Auto-Catch com chance parametrizada.
6. Emissão de `field-init`, `field` (a cada 2 ticks), `field-kill`, `poke-xp`, `inventory`, `auto-heal`, `catch-result`.
7. Gravar a saída da simulação em JSONL no formato do gravador (`{sessao,t,dir,msg}`) para rodar o mesmo `analisar_gravacao.py`.

**Testes mínimos (headless)**
- Grade derivada == grade real nas 7 hunts de `dados/testes/` (mesmos rows, cols, minTx, minTy e tiles).
- Determinismo: duas execuções com a mesma semente geram JSONL idêntico.
- 1 h simulada em segundos sem erro; mensagens validam contra `dados/protocolo.json`.
- Diferencial: na hunt do Rhydon com o Venusaur 109 (stats exatos nas gravações), cadência, faixa de dano, HP dos selvagens,
  XP/abate e loot/abate da simulação ficam dentro das faixas medidas no original.

**Critério para considerar a fase pronta:** o cliente original (via `poke-local`) desenha a hunt gerada pela nossa simulação sem erros
(a simulação como servidor WS headless, ou uma ponte para o `serve.py`).

**Fora da fase 1:** trocar a cena atual de hunt (fase 2), renderer próprio (fase 2), calibração fina (fase 3), demais sistemas (fase 4).

**Comando de teste (exemplo)**: `godot --headless --path . --script res://testes/test_sim_grade.gd`
com dados isolados (no Windows, um projeto/`user://` de teste separado; nunca o save real).

## Estado

- 09/11/2026 — Fase 0 concluída (snapshot, protocolo, importador, gravações e análise).
- 09/11/2026 — Ambiente: git iniciado; projeto P04 extraído de `PROJETO_ATUAL.rar` na raiz; Godot 4.7.2 em
  `C:\Users\dmala\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe`. Testes headless via `testes/rodar.sh <res://script>`,
  que isola `user://` com `APPDATA` temporário (o save real nunca é tocado). Sem `.godot/` ainda: o autoload `EstadoJogo`
  falha ao carregar no modo `--script` (erro inofensivo; a `sim/` não usa autoload nem `class_name`, só `preload`).
- 09/11/2026 — Fase 1, passo 1 (grade): `sim/mapa_hunt.gd`. Regra (C+D): caixa = tiles do andar `groundZ`; livre = tile em
  `groundZ`, chão/itens fora de `blocking`, dentro de `_meta.walk`; sem filtro de alcançabilidade (o servidor manda ilhas).
  Teste `testes/test_sim_grade.gd`: **7/7 grades idênticas** (rows, cols, minTx, minTy e cada tile). Limite: só 7 hunts conferidas.
- 09/11/2026 — Fase 1, passo 2 (núcleo): `sim/` = `rng.gd` (xoshiro128**, sem RNG do Godot), `regras.gd` (regras + `PARAMETROS`
  com a origem de cada um), `simulacao_hunt.gd` (tick 200 ms), `cenario.gd`, `dados_jogo.gd`, `json_canonico.gd`, `gravador_jsonl.gd`.
  Estado inicial real em `dados/testes/estado_rhydon_venusaur.json` (gerado por `ferramentas/gravador/extrair_estado_inicial.py`).
  Portado do cliente (C, chunk `0fllz2m_ktm3s.js`): `rollQuality` (pesos; não existe faixa 1,6–1,7), IV = 1+floor(32·rand),
  `computeStats`, `combatHp` = max(24, round(12·hp)), `totalXpForLevel` (incl. > 150), tabela de tipos.
  Medido nas gravações do Rhydon (A): ataque do aliado em grade fixa de 1600 ms (os 1200/2000 vêm de `field` que o cliente não
  recebeu; `hits` acumulam até o próximo `field`); selvagens perseguem só dentro da visão 27×15 (`view {hc,hr}`), todos os
  adjacentes atacam, 1º golpe ~2 s após encostar; alvo = vivo mais próximo (Chebyshev; 19/23); respawn 60 s no spawn com o
  **mesmo indivíduo** (maxHp constante por slot); cadáver ~20 s; herói anda em 8 direções (~754 ms/tile); treinador = herói.
  D: os stats exibidos do Venusaur 109 só fecham com IVs 26/5/4/18/17/28 (soma 98 = `ivTotal`; Power 562 bate).
  F (em `PARAMETROS`): seleção de golpe (maior dano esperado, empate → menor cooldown; exclui STATUS e poder 600) — bate nos
  10 pares gravados; passo diagonal 2×; limiar/recarga de poção (0,5 / 2 s); +1 tick no ataque selvagem com p = 0,25; dano com round.
  Testes: `test_sim_regras.gd` 28/28; `test_sim_determinismo.gd` OK (mesma semente → JSONL idêntico; 1 h em ~6 s).
  Bug achado e corrigido: `randf()` sem `self` dentro de um script resolve para o RNG global do Godot (quebrava o determinismo).
- 09/11/2026 — Fase 1, passo 3 (mensagens/JSONL): emite `field-init`, `field` (ticks pares), `field-kill`, `poke-xp`, `catch-result`,
  `poke-delta` (level-up), `inventory`, `balls`, `auto-heal`, `field-none` (leave-hunt), com chaves na ordem do servidor;
  JSONL `{sessao,t,dir,msg}`. Validador `ferramentas/protocolo/validar_jsonl.py`: o `protocolo.json` gerado (logs antigos;
  2 dos 5 logs-fonte não existem mais) reprova a própria gravação real (poke-delta de forma final, `invasion-*`), então
  `--referencia <gravação>` amplia o esquema com o observado (A) sem editar o arquivo gerado. Teste `testes/test_sim_protocolo.sh`:
  1 h simulada, 11.726 mensagens, 0 erro; controle real também 0 erro. Achado (A): a bola da auto-captura não é
  `balls.selected` (selected = 1, mas as tentativas gastam a bola 3). Limite: `targetSlot` quando não há selvagem vivo é null (F).
- 09/11/2026 — Fase 1, passo 4 (diferencial): `ferramentas/gravador/comparar_sim.py` (usa `analisar()` do `analisar_gravacao.py`
  nos dois lados) e `testes/test_sim_diferencial.sh`: 20 instâncias × 10 min contra a gravação real do Rhydon (9,3 min, 55 abates,
  **uma** instância). Critério revisto após a 1ª rodada (registrado): cada semente é uma instância com 15 indivíduos fixos e a
  variação entre instâncias é grande; comparar 5 h agregadas com uma instância real subestimava a variância. Agora métricas de
  ritmo/dano passam se o valor real cair entre p05 e p95 das instâncias. Resultado: **22/26**. Dentro: XP/abate (igual),
  cadência do aliado (moda 1600), faixas de dano dos dois lados, HP dos selvagens (faixa, múltiplos de 35, média), loot (5 itens,
  taxa e quantidade), abates/min, hits selvagens/min, cura média. **Fora (todas F, para a fase 3):** hits do aliado por abate
  (real 4,05; sim p95 4,04 → a sim mata um pouco rápido: fórmula de dano/HP), curas por minuto (real 7,22 = p95 da sim → regra
  da poção), ms/tile do herói (real 754; sim 770–1005 → passo diagonal 2× provavelmente caro demais) e do selvagem (real 1018;
  sim 1035–1126 → bloqueios na perseguição). Sensibilidade (não adotada): sem recarga de poção ou com limiar 0,6 as curas sobem,
  mas o limiar 0,6 derruba a cura média. Não feito: o critério de pronto da fase (cliente original via `poke-local` desenhando a
  hunt simulada) e 1 h de gravação real para o diferencial ter amostra maior.
- 09/11/2026 — Protocolo regenerado (`ferramentas/protocolo/regenerar.sh`): 5 chunks do jogo + as 12 gravações que existem
  (9 do gravador novo, deduplicadas por sessão+instante+conteúdo, e 3 logs crus antigos da raiz). 139 tipos, 28 vistos.
  O `--referencia` saiu do validador: a gravação real e 1 h simulada passam no esquema gerado (0 erro, 0 aviso).
- 09/11/2026 — Medições diretas (A) e ajuste da sim. `medir_passos.py` reconstrói o tick exato de cada passo
  (stepStartAt = serverNow sempre; walkFrom só no tick do passo — encadear walkFrom de fields diferentes perdia os passos
  dos ticks ímpares). A espera antes de cada passo depende do passo que vai ser dado: herói →reto 600 ms (113/121),
  →diagonal 1000 (40) ou 1200 (19); selvagem →reto 1000 (167) ou 1200 (93), →diagonal 2000 (89) ou 2200 (4). A sim usa
  stepMs × (1 ou 2) arredondado ao tick, mais 1 tick com a taxa medida quando a espera cai num tick exato (mecanismo F).
  `medir_pocao.py` (209 curas): gatilho HP ≤ 50% no mesmo tick (42/42), HP exato na cura nunca > 0,50, sem recarga
  observada (menor intervalo 1988 ms); poção = menor que cobre o que falta, senão a maior (208/208). Sim ajustada.
  Caminho (F): Dijkstra de tempo mínimo com esses custos, desempate pelas frequências medidas (herói fora do eixo: reto no
  eixo maior 475, diagonal 146, eixo menor 26). Teste novo `test_sim_caminho.gd` 8/8. 1 h simulada agora em ~15 s.
  Diferencial **22/26**. Fora: hits do aliado por abate (real 4,05; sim 3,08–3,96) e, por consequência, curas/min (real
  7,22; sim 3,09–5,54) — o dano recebido por cura é igual (real 883; sim 890–918), mas a sim luta 4,3–5,7 s por abate
  contra 6,7 s no real (fase 3: dano/HP). ms/tile do herói (real 754; sim 792–849) e do selvagem (real 1018; sim
  1277–1362): métrica grossa (posição a cada 400 ms) que mistura escolha de caminho (F) com o ritmo já medido; na única
  instância real do Rhydon o selvagem anda em 37% dos intervalos, em todas as gravações em 28% e na sim em 30%.
- 09/11/2026 — **Critério de pronto da fase 1 cumprido**: o cliente original (poke-local) desenhou por 10 min a hunt do
  Rhydon gerada pela simulação. `ponte/servidor_sim.gd` (Godot headless, TCP 127.0.0.1:8765, JSON por linha; dá só o
  relógio real à sim pura) + `ferramentas/ponte/ponte_poke_local.py` (subclasse do Handler do `serve.py`, que fica
  inalterado; encaminha enter-hunt/leave-hunt/field-get/view; o resto continua nas fixtures). Mapa, atlas 06563563679b,
  creatures/items, hunt-config e ícones vêm do snapshot. E: sem outfit/imagem local, o Venusaur (22) aparece com o sprite
  do Rhydon (200) e o retrato com o do Snorlax (143), só na tela. Sessão: 608 s, 0 erro no console e 0 recurso falho
  (monitor injetado `ferramentas/ponte/monitor_erros.js`), 64 abates, 56 respawns (60 s), 39 curas, loot e captura no
  cartão; as 1923 mensagens da hunt que o navegador recebeu (gravador injetado) são idênticas, na ordem, às que a sim
  emitiu. `analisar_gravacao.py` lê a gravação; o validador acusa 1 erro, na mensagem `balls` da fixture do serve.py
  (sem a bola 2), não da sim. Teste `testes/test_ponte_tcp.py` 11/11. Limites: o painel do time vem de `pokes-get`
  (fixture: Rhydon Lv 50) e não bate com o time da sim; o poke-local não tem outfits/retratos fora Rhydon/Snorlax;
  trade-get, restart-state e auto-boss-get respondem "não implementada" (fixture).
- 09/11/2026 — Relatório por indivíduo para a fase 3 (`ferramentas/gravador/relatorio_individuos.py`; saída atual em
  `relatorio/individuos_rhydon_2026-11-09.md`). Indivíduo = (huntKey sem ":rN", slot, espécie): A, os 15 maxHp do Rhydon
  são os mesmos em r1..r8. maxHp → stat HP → pares (IV, Q) → faixa de SpD/Atk → dano previsto × observado (fórmula F),
  com os stats do aliado de cada hit; hits do selvagem atribuídos só quando há um único selvagem adjacente.
  Resultado na gravação real: Solar Beam explicado por uma SpD inteira em 12/15 indivíduos e por uma SpD **sem
  arredondar** em 15/15 (os 3 que falham caem em janelas não inteiras, ex. 50,11–50,65) — reforça a hipótese do Geodude
  (stats sem arredondar no dano); Stone Edge 14/15 (o 1 fora é coerente com o ruído da atribuição: 96% na sim).
  Autoteste na sim (fórmula exata, stats inteiros): 294/294 indivíduos×golpe compatíveis em 20 instâncias.
  Hits por abate previstos pela SpD compatível ficam perto dos observados (ex. slot 11: 6,22 × 6). Não mexi na fórmula.
- 09/11/2026 — Gravação nova `poke har/gravacoes/rhydon-1h.jsonl` (88 min, 608 abates, Venusaur 119–124, mesma
  conta e configuração) virou a referência principal; estado inicial em `dados/testes/estado_rhydon_venusaur_1h.json`
  (o extrator agora pega o poke-delta do herói: o primeiro poke-delta dessa gravação é de um Rhydon nível 1 capturado).
  Medições refeitas, todas confirmam as anteriores (A): herói →reto 600 ms (241/247), →diagonal 1000/1200 (110/54);
  selvagem →reto 1000/1200 (409/226), →diagonal 2000/2200 (138/6); treinador = herói em 6613/6613 fields.
  Auto-Potion: 49/49 cruzamentos de 50% curados no mesmo tick, HP exato na cura ≤ 0,50 em 200/200, menor intervalo
  3024 ms; poção = menor que cobre (200/200, sempre Hyper com Great+Hyper no inventário). O print do Auto-Helper
  ("Potion: Automatic (best)", "Heal when HP ≤ 50%") confere com o gatilho medido. PARAMETROS ficaram com as contagens
  somadas (extra de tick 0,33/0,36/0,04; desempate herói 1769/471/74, selvagem 1537/679/387). Captura: 5/608 no
  Rhydon 80 (a sim usa catchChance 0 do hunt-config: ainda F). Protocolo: 140 tipos, 34 vistos.
  Diferencial agora por caso (`testes/test_sim_diferencial.sh antiga|1h`): antiga **23/26**, 1h **26/30**. Com a amostra
  maior sumiram: curas/min (antiga 7,22 fora; 1h 2,34 dentro de 1,94–3,71) e hits do aliado por abate (1h 2,91 dentro de
  2,54–3,46). Continuam fora: ms/tile do herói (757 × 809–870) e do selvagem (1136 × 1293–1334) — caminho/perseguição
  (F); novos: hits selvagens/min lutando (18,4 × 19,8–27,8: a sim junta selvagens demais no herói) e XP por abate
  (debuff de entrada, não modelado). Relatório por indivíduo da 1h em `relatorio/individuos_rhydon_1h_2026-11-09.md`:
  Solar Beam compatível com SpD inteira em só 2/15 indivíduos e com SpD sem arredondar em 15/15 (60–160 hits cada) —
  evidência forte de que o dano usa stats sem arredondar; Stone Edge 13/15. Correção no relatório: o golpe final chega
  no field depois do field-kill (antes ele caía na vida seguinte e dava hits/abate < 1).
- 09/11/2026 — Fechamento da fase 1 (fase aprovada): (1) penalidade de XP na entrada: `debuff_entrada_abates` 7,
  `debuff_entrada_fator` 0,3 (A); só em entrada nova (huntKey sem ":rN"; a ponte sempre entra nova); mecanismo contado em
  abates (F). (2) Captura: `captura_pontos` {Super Ball: nível 1 = 35/59, nível 80 = 5/608} (A), interpolação no logit
  e espécie ignorada (F); `Regras.chance_captura`. (3) Dano: stats do selvagem sem arredondar e do aliado arredondados
  (F forte, ver a fórmula acima); parâmetros por lado. Autoteste na sim: o relatório explica 146/150 indivíduo×golpe com
  SpD contínua. Diferencial: antiga 23/26, 1h **27/30** (XP por abate passou com o debuff; fora: ms/tile de herói e
  selvagem e hits selvagens/min lutando na borda, 18,4 × 18,7–25,8). (4) Investigação de movimento aberta (tabela e
  hipóteses acima). Testes: regras 35/35 (novos: captura e debuff), caminho 8/8, determinismo, protocolo, ponte.
- 09/11/2026 — Fase 2, passo 1 (mapa): `render/regras_desenho.gd` porta buildTile/placeSprite/frameIndexFor (C, modo HD do
  original: cada sprite com seu zIndex exato, sem "bake"). Teste `testes/test_render_regras.sh` roda o código ORIGINAL
  extraído do chunk no Node e compara sprite a sprite (asset, quadro, andar, x, y, zIndex, ordem): **idêntico** em rhydon
  (94.752), geodude (81.175), blastoise (26.651) e nightmare_steelix (301.712). `render/mapa_renderizador.gd`: canvas items
  do RenderingServer (sem Node por tile), um pai por andar deslocado (z − groundZ)·32, draw_index = posto estável do
  zIndex (ímpares reservados para entidades), streaming por chunk 8×8 com margem de 10 tiles (streamChunks, C), andar de
  cima escondido pelo computeFirstVisibleFloor com fade de 180 ms (C), animação de itens pelo tick original (C).
  Rhydon: 2,6 s para carregar, ~32 mil sprites no ar. `render/interpolacao.gd` porta dT/dI/dM/dL/dS/dk/dy/dC/dE e o relógio
  dc/dm/dh (C); `testes/test_render_interpolacao.sh` compara com o original sobre 1500 fields reais da rhydon-1h:
  388.560 amostras iguais (tol. 1e-5 tile, float32). Não portado ainda: sombras e iluminação do Pixi (efeito visual).
- 09/11/2026 — Fase 2, passo 2 (entidades): `render/estado_vista.gd` porta o laço por quadro do cliente (C: quando chamar
  dT/dI/dM, treinador seguindo o tile anterior do herói por BFS, selvagem morto parado onde caiu, efeito de respawn de
  1,2 s, direção por dP/dj); `render/outfits.gd` lê o formato de outfit original (índice → manifest → página;
  "{quadro}_…_{dir}"; quadro 0 parado, passos pela fase) com substituto (E: 200/Rhydon) para o que não existe localmente
  (hoje: Venusaur 22, Geodude 196, Steelix 369; o treinador 5759 é real); colorização do treinador ainda não portada.
  `render/vista_hunt.gd` junta mapa, entidades (draw_index pelo zIndex original de criatura e cadáver), placas (nome +
  barra 31×4/29×2, C) e números de dano (950 ms, sobe 60 px, entra em 16%, dmgDelayMs, C; cores das classes CSS: F).
  `testes/ver_hunt.gd` roda a sim em processo e em tempo real numa janela sem borda de 1920×1080 e mede o frame time
  (capturas fora da medição). RTX 4060, vsync ligado, 60 s: **rhydon** média 7,7 ms, p99 **11,1 ms**, máx 16,1, 0 quadros
  acima de 16,7 ms em 7364; **nightmare_steelix** (56 spawns, 301.712 sprites) média 7,6, p99 **10,8 ms**, máx 14,7, 0 acima
  de 16,7 em 7469. Para chegar aí: páginas do atlas decodificadas na carga e chunks montados por fila com orçamento de
  3 ms/quadro (F de desempenho; o original monta de uma vez). Limite: carga do Nightmare leva 10 s (montar() em GDScript).
  O projeto foi importado uma vez (`godot --headless --import`, `.godot/` fora do git).
- 09/11/2026 — Fase 2, passo 4 (regras E na simulação): troca automática após KO aleatória entre membros vivos do time,
  sem curar, seguida de 5 s (`troca_cooldown_ms`) sem troca manual; troca manual pelo comando `switch {teamIndex}` (C),
  recusada com `{type: error}` (E: o texto real não foi gravado); sem reserva viva, `field-none {motivo: "sem-reserva"}` e
  a instância acaba (a cena volta à cidade). `sim/regras_apresentacao.gd`: cartão de derrota um por vez e sem fila
  (abate com cartão na tela é ignorado; 4500/7000 ms + 220, como no P04), até 30 por instância; contador Capture por
  instância (retomada mantém, instância nova zera). Teste `testes/test_sim_regras_usuario.gd` 17/17.
- 09/11/2026 — Fase 2, passos 3 e 5 (adaptador e desempenho) — **critério de pronto da fase 2 cumprido**. `sim/cenario_jogo.gd`
  monta a simulação a partir do save (time com IVs/Quality/XP/HP, potions, bolas, Auto-Helper; VIP desligado, E; entrada
  nova, A; poção escolhida à mão vira `pocao_fixa`, E). `caca_sim.gd`: relógio real para a sim, vista desenhando, e o save
  atualizado pelas mensagens: XP do treinador (field-kill) e do Pokémon (poke-xp), loot (`receber_loot`; itens fora do
  catálogo do jogo, hoje só Ancient Stone, ficam registrados e não entram), poções (auto-heal) e bolas (catch-result),
  captura como DadosPokemon nível 1 (A: 5/5 na rhydon-1h) e HP do time ao sair; cartões pela regra E da sim; troca manual
  por clique no time. `testes/test_caca_sim.gd` (save isolado): cidade → mapa-múndi (mesmo handler do clique) → Rhydon
  com o mapa real → 4 min simulados → voltar → cidade → save gravado: **14/14**. Frame time na própria cena (HUD inclusa),
  60 s em tempo real, 1920×1080, RTX 4060, vsync: média 7,4 ms, p99 **10,4 ms**, 10 de 7748 quadros acima de 16,7 ms (máx
  33,7). Limites: HUD mínima (time, Capture, cartões, voltar) — os painéis da cena antiga (hud_caca, Auto-Helper na hunt)
  não foram ligados; filtro de nomes e bola shiny do Auto-Catch não repassados; cadáver só das espécies vistas nas
  gravações (Rhydon, Kangaskhan); sprites substitutos (E) até baixarmos os outfits.
- 09/11/2026 — 2b.1 (sprites reais): `render/outfits.gd` lê primeiro os outfits do snapshot (545 categorias, 846 no índice)
  e porta a colorização do treinador (colorizeFrame/getOutfitColor, C): máscara amarela/vermelha/verde/azul = cabeça/
  corpo/pernas/pés, cor multiplicada por pixel, paleta de 133 índices. `testes/test_outfits.sh`: paleta igual à do
  original (Node) em 0..140; treinador 5759 colorido; **0 outfits faltando** entre as 453 espécies das 451 hunts e o
  time. Cores do treinador: o save não as tem — padrão E = as do personagem do poke-local (head 94, body 95, 0, 0).
  Não portado: sprite shiny (o field manda `shiny`; a vista ainda usa o outfit normal).
- 09/11/2026 — 2b.2 (cadáveres): a vista lê `game/corpses/corpses.json` do snapshot (503 assets, como loadCorpses, C) e as
  páginas do snapshot ou, na falta, do poke-local (mesmo atlas: 501 assets em comum com frames idênticos). Faltam as
  páginas `corpses-g-00` e `corpses-h-00` (2 assets: 21366, 14794): o coletor não baixava as páginas de cadáver — agora
  baixa (etapa atlas; o coletor do repositório foi atualizado para a versão do `coletor_poke.zip`). Tabela espécie →
  cadáver: **dado do servidor** (o cliente só desenha o id que vem em `field.corpses`); `dados/corpos_observados.json`
  (gerado por `ferramentas/gravador/extrair_cadaveres.py`, A) cobre só 4 das 453 espécies (Blastoise 2931, Rattata 2848,
  Rhydon 2858 / shiny 31489, Kangaskhan 6073). As outras ficam sem corpo até haver gravação delas (não inventado).
  Teste `testes/test_cadaveres.gd` 3/3.
- 09/11/2026 — 2b.3 (catálogo de itens): `regras_loot.gd` passa a ter como base `dados/gerados/itens.json` (665 materiais
  = 670 itens − as 5 poções do jogo, que continuam poções). Convenção do P04 mantida: ids 1..7 do servidor colidem com
  as bolas e viram 1.000.000 + id (Ancient Stone 2 → 1000002, que já existia no catálogo antigo; a cena nova agora
  converte o id do loot com `id_interno`). Os 183 itens do catálogo antigo ficam com o mesmo id, nome e ícone res://;
  os novos usam o ícone do snapshot, lido em tempo de execução por `LOOT.textura` (depot e cartões); 7 ícones são GIF e o
  Godot não os lê (ficam sem ícone). Categorias: loot/stone = "Materials" (como antes), as outras com o nome do gerado (E).
  Teste `testes/test_catalogo_itens.gd` 10/10 com um save ANTIGO (`dados/testes/save_antigo_inventario.json`, gerado
  pelo código de antes da migração): materiais e depot preservados, itens novos entram e fazem ida e volta no save.
  `test_loot_hunts.gd` (P04) ajustado só na checagem de ícone: 10574 verificações, 0 falhas.
  `test_compatibilidade_save.gd` (P04) falha igual antes e depois (depende de um fixture que o runner antigo copia).
- 09/11/2026 — 2b.4 (carga dos mapas grandes): `render/cache_mapa.gd` grava, por mapa, o resultado de `montar()` já
  ordenado por andar (arrays compactados, índice de chunks, páginas por chunk, tiles com chão) em `cache/mapas/<slug>.bin`
  (zstd; fora do git e do scan; inválido se mudar o mapa, draworder, offsets, colisão, versão do atlas ou VERSAO). O
  renderizador lê do cache, decodifica só as páginas dos chunks em volta do herói e o resto numa thread de fundo
  (WorkerThreadPool; chunk sem página espera na fila). nightmare_steelix: **0,91 s** (manifest 0,20 + cache 0,06 + 15
  páginas 0,60) contra 10,4 s; 2,8 MB em disco. Montar o cache a frio ainda custa ~8 s uma vez por mapa:
  `ferramentas/render/gerar_cache_mapas.gd` pré-monta todos. Regressão: desenho idêntico ao original (3/3), fluxo da
  cena 14/14, p99 7,6 ms na cena.
- 09/11/2026 — 2b.5 (HUD da hunt): a cena nova usa a HUD da cena antiga sem mudar `hud_caca.gd`/`painel_auto_helper.gd`
  (painel de perfil/time com cooldown, menu superior, My Pokes, Pokepedia, mapa-múndi dentro da hunt, cartões de derrota,
  painel Capture com estoque de bolas e contador de wilds, Auto-Helper). `caca_sim.gd` implementa a interface de
  controlador que eles usam. Integração: o líder do save começa em campo; trocar o líder no painel troca o ativo na
  simulação, pelo `EstadoJogo.validador_troca_lider` (regra dos 5 s da sim, E); troca por KO vira o líder no save; HP do
  time no save a cada field; Auto-Helper mudado na hunt vale na hora; sair pelo mapa-múndi da hunt também grava.
  `testes/test_caca_sim.gd` **21/21** (7 checagens novas de HUD), p99 11,9 ms na cena. Visual: as placas do herói e do
  treinador se sobrepõem quando estão no mesmo tile.
- 09/11/2026 — 2b.6 (escala): `testes/test_todas_hunts.py` entra nas **451 hunts** pela cena nova (time de teste E, save
  isolado), 60 s simulados a 10×: **451/451 sem erro**, 0 tempo esgotado, carga máx. **1,59 s** (p50 0,89; nightmare_steelix
  1,21), 4553 abates, 9,39 M de XP, 0 outfit substituto, só 1 hunt sem abate em 60 s (nightmare_snorunt: labirinto; abate
  na repetição). Correções que a varredura exigiu:
  (1) loot "Pile Of Seeds" (Skiddo) sem itemId: o importador casa nome sem caixa quando é único (F; vira 5303) e a sim
  ignora item sem id. (2) Ilhas: 9 hunts com `start` em tile bloqueado e 103 com spawns bloqueados (hunt-config × grade;
  a grade bate nas 7 conferidas). typhlosion (A, 1 caso): start (54,75) bloqueado e o herói real aparece em (53,74), o 1º
  livre do anel 1 em linha → coluna → regra F `inicio_bloqueado_anel`; se a ilha do herói não alcança spawn
  (nightmare_magby), ele começa na ilha que alcança mais (E); alvo só entre os alcançáveis (F); sem caminho até o alvo e
  com selvagem encostado, ataca o encostado (F; banette ficava apanhando parado). Rhydon 20 min: saída da sim **idêntica
  byte a byte** antes/depois. Caminho: campo do herói no mapa inteiro guardado por destino e laço com índices planos
  (pior tick 36 → 11 ms; 1 h simulada 17,5 → 10 s). (3) Quadro: placas só reaplicam o que muda e somem fora da tela;
  animação dos itens por agenda (mesmo quadro que a regra antiga em 6000 quadros, `test_render_animacao.gd`); BFS do
  treinador com índices inteiros e falha guardada (mesmo caminho em 1200 buscas, `test_render_bfs_treinador.gd`; antes
  40 ms/quadro com destino inalcançável); estoque de bolas e Auto-Helper atualizados no lugar (`hud_caca.gd`,
  `painel_auto_helper.gd`, mesmo comportamento); saves na hunt espaçados em 10 s (E; cada save custa ~15 ms e cada
  abate/poção pedia um; ao sair, save imediato); **atlas por mapa** (draw calls 2200 → ~140 em electabuzz; pixels iguais ao
  modo por páginas fora de linhas de 1 px da escala da janela). Testados e descartados: renderer Vulkan (pior) e
  Texture2DArray (mesmo p99, +1 s de carga; fica como opção `usar_array`).
  **p99 a 1×** (60 s, 1920×1080, RTX 4060), 16 hunts mais pesadas: última rodada 12/16 abaixo de 16,7 ms (piores:
  ancient_pinsir 20,4, nightmare_elekid 20,0, nightmare_luxray 19,7, nightmare_raichu 17,1); as mesmas deram 12,9–17,3
  na rodada anterior. Nos quadros lentos restantes o jogo gasta pouco (script 1–2 ms, render CPU ~4, GPU ~2) ou é o save
  de 10 em 10 s; a máquina tinha Firefox/Discord abertos e a variação entre rodadas (±3–5 ms) é do tamanho da margem.
  **Critério de p99 não confirmado** nas hunts mais pesadas (4 de 16 acima do limite na última rodada). Limites: atlas por mapa ocupa ~3,8 MB/mapa em
  `cache/` (1,7 GB se pré-gerar as 451; sem pré-gerar, a 1ª entrada monta em 0,25–1 s); tabela espécie → cadáver só de 4
  espécies (dado do servidor; 4 hunts desenham corpos); time de teste da varredura é E.
- 09/11/2026 — 2b.7 (sombras e iluminação): não portadas; registradas como pendência visual (seção acima) com a receita do
  cliente (C) e estimativa de meio dia. Motivo: risco para a ordem de desenho e para o frame time, que ainda está no limite
  nas hunts mais pesadas (2b.6). Não bloqueia.
- 09/11/2026 — Pós-2b, item 1 (save fora da thread principal): `coordenador_salvamento.gd` monta só a cópia dos dados
  (`construir_dados`) na thread principal; validação, JSON, sha256, escrita do `.tmp`, releitura byte a byte, `.bak` e
  renames rodam numa thread de trabalho (`salvamento_local.gd` `gravar`, que não toca o estado do jogo). Uma gravação por
  vez: pedido durante a gravação fica pendente e sai depois com o estado de então; `salvar_agora` (fechar o jogo, testes)
  espera a que está em andamento. A validação lê recursos, que são aquecidos ao iniciar. A releitura de conferência
  passou de "decodificar + validar de novo" para comparação byte a byte (o texto já saiu validado). Formato do arquivo
  inalterado (JSON sem compressão: saves antigos seguem compatíveis; não havia compressão a mover). Teste
  `testes/test_save_thread.py` (APPDATA isolado): save antigo 8/8 (carrega, grava em thread, arquivo confere, nunca duas
  gravações simultâneas, último estado no disco, depot preservado); thread principal 9,6 ms × 46 ms síncrono com 300 no
  box; **15/15 mortes do processo no meio da gravação** sem perda (XP carregada entre a última gravação confirmada e a
  última iniciada; 6 deixaram `.tmp` pela metade e a carga usou o principal). `test_caca_sim` 23/23.
- 09/11/2026 — Pós-2b, item 3 (corpos por espécie): **não há padrão** que ligue espécie e cadáver nos dados públicos:
  `creatures.json` não tem campo de cadáver; a ordem dos 503 ids do `corpses.json` não segue Pokédex nem looktype (os 4
  conhecidos estão nas posições 12, 15, 33 e 124 para as espécies 19, 112, 9 e 115); o cliente só desenha o id que vem em
  `field.corpses` (`corpseTexture`, C); o `hunt.py` do poke-local usa um id fixo (2989). Os cadáveres são o próprio Pokémon
  desmaiado (folha de contato), então o vínculo é por espécie, mas só o servidor o conhece. `dados/corpos_por_especie.json`
  (A) substitui o `corpos_observados.json`: `ferramentas/gravador/atualizar_corpos.py` soma as observações de qualquer
  gravação nova (idempotente; cada arquivo entra uma vez por sha256), com contagem e conflitos. Hoje: 4 espécies normais
  (Blastoise 2931, Rattata 2848, Rhydon 2858, Kangaskhan 6073) e 2 shiny (Rattata 2848, Rhydon 31489). Na sim: shiny sem
  dado usa o normal (F); espécie sem dado emite `corpse: 0`, o **genérico (E)**, que a vista desenha como o sprite parado da
  própria espécie, escurecido, na camada do cadáver (não há cadáver neutro no atlas: todos são espécies reconhecíveis).
  Rhydon 20 min: saída da sim idêntica. `test_cadaveres` 3/3; pichu (sem dado) desenha os genéricos, sem erro.
- 09/11/2026 — Pós-2b, item 4 (pendências menores): **ícones GIF** — o cliente mostra ícone de item com `<img>` e o
  navegador anima GIF (C), então os quadros ficam: `ferramentas/importador/gif_para_folha.py` (Python puro: LZW,
  entrelaçamento, transparência, descarte) gera na importação uma folha PNG por GIF em `dados/gerados/icones/`
  (determinístico; `.gdignore`) e o `itens.json` ganha `iconeAnimado` {quadros, largura, altura, duracoesMs, folha};
  `regras_loot.textura` monta uma `AnimatedTexture` com as durações do GIF. 8 GIFs convertidos (os 7 sem ícone + Ancient
  Stone, que segue com o ícone do catálogo antigo). `test_catalogo_itens` 12/12 (7/7 animados com o nº de quadros certo;
  0 item sem ícone). **Placas**: herói e treinador perto um do outro → a do treinador sobe e fica empilhada 16 px lógicos
  acima, suave com a distância (E; `vista_hunt.empilhar_placa`, `testes/test_placas.gd` 8/8). `test_caca_sim` 23/23.
- 09/11/2026 — Pós-2b, item 5: `PLANO_GRAVACOES_FASE3.md` (18 gravações; P1 ≈ 2 h, total ≈ 4 h 30), com as hunts
  escolhidas por `ferramentas/fase3/planejar_fase3.gd` (golpe previsto, 2º colocado, margem e custo da luta para cada
  Pokémon das contas A e B × cada espécie das 451 hunts). Achado com dado existente (A): "primeiro golpe da lista" e
  "aprendido por último" já estão descartados (Venusaur usa Solar Beam e não Petal Dance; Rhydon selvagem usa Stone Edge
  no empate exato com Earthquake), e o cooldown do golpe não limita a cadência (Solar Beam a cada 1,6 s); a regra da sim
  (maior dano esperado → menor cooldown → aprendido primeiro) é a única simples coerente. Fica para gravar: desempate
  no Golem (S1), efetividade (S2/S4/S5/S7), razão A/D (S3/S6), captura nos níveis 10/20/40/60, por bola e por raridade
  (C1–C6), e movimento com luta longa, tamanho de janela (`view`), mapa da referência e herói lento (M1–M4).
- 10/11/2026 — Pós-2b, item 2 (**p99 com critério estatístico — cumprido**): Firefox e Discord fechados pelo usuário;
  16 hunts mais pesadas × 3 rodadas, 60 s a 1×, 1920×1080, RTX 4060 (`testes/test_todas_hunts.py --velocidade 1`;
  saídas `saida_testes/p99_rodada{1,2,3}.json`). Critério: mediana dos 3 p99 ≤ 16,7 ms em cada hunt → **16/16**. Medianas:
  nightmare_elekid 11,0; ancient_pinsir 10,3; nightmare_luxray 10,3; nightmare_raichu 9,1; rhydon 7,5; nightmare_magby
  7,4; rapidash 7,1; nightmare_snorunt 7,0; magneton 6,6; electabuzz 6,3; as outras 6 entre 5,7 e 5,9 ms. Variação entre
  rodadas ≤ 0,8 ms (com os programas abertos era ±3–5 ms: o ruído da rodada anterior era da máquina). 0 erro. Ainda há
  quadros isolados lentos (pior por hunt 12–74 ms, poucos por minuto), que não pesam no p99. Não foi preciso mexer na
  montagem de chunks.
- 10/11/2026 — Fase 3, gravações S1–S4 (`poke har/gravacoes/fase3/`; conferência `ferramentas/fase3/conferir_fase3.py` e
  `s3_individuos.py`; situação no `PLANO_GRAVACOES_FASE3.md`). Configuração: bate com o plano, salvo níveis (Rhydon 425,
  Golem 387, Venusaur 139) e catch ligado no S2/S4. Seleção de golpe (A, 324 hits): **confirma** em S1 (empate exato →
  primeiro da lista: Stone Edge 58/58 no Rhydon, Earthquake 59/59 no Golem), S2 (Hammer Arm 32/32) e S4 (Double-Edge
  39/39); S3 não passa no critério de 95% (Hydro Pump 31/39), mas porque o critério supunha IV 16: cada Rhyhorn leva sempre
  o mesmo golpe e os 15 são coerentes com "maior dano esperado com os stats do indivíduo" (a sim já faz assim). A regra da
  sim não mudou (só o comentário). Captura: S4 vale como C2 — Super Ball no Vulpix 20: **2/37**, contra 29,6% da curva de 2
  pontos (P = 0,0003) → o ponto entrou em `captura_pontos` (A); a forma entre os pontos continua F e nível × espécie não se
  separam. Penalidade de entrada: 0/9/6/10 abates (S1..S4) → não é por abates (o parâmetro de 7 abates fica, marcado F);
  a duração não fecha em ~60 s (S3 acaba antes de 30 s). Conta B tem parcela `guild` (24 em 548). Cadáveres: 7 espécies
  normais (+ Oddish, Rhyhorn, Vulpix). Protocolo regenerado com as gravações da fase 3: 141 tipos, 38 vistos. Testes:
  regras 36/36, caminho 8/8, determinismo, regras do usuário 17/17, cadáveres 3/3, grade 7/7, protocolo OK, cena 22/22,
  catálogo 12/12; Rhydon 20 min idêntico byte a byte; diferencial 1h 27/30 e antiga 23/26 (iguais a antes).
- 10/11/2026 — Fase 3, penalidade de entrada e medidor de captura.
  **Penalidade = boost `shinylock`** (C: texto do boost, −70% de EXP e drops por 1 min):
  - (A) Em 4 entradas, o `boosts.until` = entrada + 60,0 s. Todo abate antes dele tem debuff e nenhum depois (7/601,
    9/23, 10/27, typhlosion). O lock atravessa a retomada `:rN`.
  - (A) Drops no lock: 15 contra 68 esperados (0,22×; P = 0,13 contra ×0,3).
  - Sim: lock por tempo (`penalidade_duracao_ms` 60000, `penalidade_fator` 0,3, `penalidade_loot` "chance", F para
    chance × quantidade). Emite `boosts {shinylock, until}` depois do field-init (A).
  - (F) O minuto conta da saída do lugar anterior (`ms_desde_saida`, hipótese do usuário; explica o S3, que não tem o
    `boosts` no arquivo).
  - Regra de quando aplicar (B-relatado: hunt diferente da última ou sessão expirada, 15 min com o jogo fechado) em
    `CenarioJogo.penalizar_entrada`. O save ganhou o campo opcional `ultima_hunt`.

  **Captura = medidor de investimento por espécie** (C: tutorial e tela used-balls; Master Ball garante; shiny à parte,
  min(1, shinyBase × catchRate), da barra de captura):
  - (A) O Rattata 1 mostra a chance subindo com as tentativas desde a última captura: 15/34, 15/18, 3/3.
  - (F) Modelo por máxima verossimilhança nas sequências de Rattata, Vulpix e Rhydon: −59,5 com 2 parâmetros, contra
    −65,6 de uma chance fixa por espécie. Fórmula: min(1, 0,68 · nível^−0,86 · investido / precoNpc · (1 + bônus)),
    com investido = bolas desde a última captura, incluindo a atual.
  - (F) Valor da bola = eficiência × 50/3, porque a Idle Ball falhou no Rattata 1 do S2, e pelo ouro dela daria chance
    1; a alternativa "ouro" fica parametrizada.
  - `captura_pontos` saiu. O medidor vive na sim (`sim.medidor`) e no save (campo opcional `captura_medidor`); o jogo
    ainda não tem a tela de Gerenciamento de Captura.
  - Reanálise: Rattata 23/37 e 12/22 (modelo 22,0 e 13,3), Rhydon 5/608 (3,9 partindo de medidor zero), Vulpix 2/37
    (1,15), Blastoise 0/193 (0,4), Idle Ball 0/1 (0,71). Não é validação independente: as mesmas sequências
    entraram no ajuste.

  **Gravador e ferramentas:**
  - Gravador v1.1 (do usuário, revisado: só `fetch` de `/api/game/*`, parâmetros com cara de credencial filtrados)
    grava `dir: "rest"`.
  - `ferramentas/gravador/rest.py` lê esse formato. `analisar_gravacao.py` mostra o lock e o used-balls do início e do
    fim. `gerar_protocolo.py` põe as respostas REST numa seção própria (as mensagens WS ficaram iguais).
    `conferir_fase3.py` compara as capturas com o modelo partindo do used-balls do início.
  - Plano (seção b revista): C3/C4 dispensados; C5 passa para o Geodude 1 na conta B (Poké/Great/Ultra separam
    eficiência × ouro); novos C7 (Geodude 1, preço 300) e C8 (Meowth 20, preço 300) separam nível de preço; C6 vira P2.

  **Testes:** regras 39/39 (captura e lock refeitos), save fase 3 12/12 (save antigo carrega, ida e volta, inválidos,
  sessão, regra), cena 22/22, ponte 11/11 (`boosts` depois do field-init), save em thread 15/15 mortes, determinismo,
  protocolo, caminho 8/8, regras do usuário 17/17, cadáveres 3/3, catálogo 12/12. A saída da sim mudou de propósito
  (lock e medidor). Diferencial: 1h 27/30, antiga 23/26 (iguais a antes).
- 10/11/2026 — Fase 3, gravações M1, M2, C1, c2 (Vulpix, extra) e C6. **Nenhuma tem linha REST**: sem used-balls,
  o medidor inicial é desconhecido, e o ajuste usa só os trechos depois da 1ª captura de cada gravação.
  - Causa provável: uma versão antiga do gravador já ativa na página; com outra versão ativa, o v1.1 saía sem avisar.
    O gravador v1.2 avisa nesse caso e marca `restHook` na linha `__open`.

  **Configuração:** bate com o plano, salvo:
  - Venusaur 140–142 (o plano previa 124);
  - C1 com 52 tentativas (o plano previa ~60);
  - M1 com ~19 min de fields espalhados em 2,5 h;
  - M2 com o `view` 27×15 do começo ao fim. O cliente calcula o view só pelo zoom (C): a pergunta da janela não se
    aplica.

  **Captura:**
  - (A) O C1 (Spearow 10, preço 100: 28/52) **derruba o fator de nível**; o modelo antigo previa 3,9.
  - (A) A chance por tentativa desde a última captura é 13/28, 7/14, 7/7 (Rattata: 15/34, 15/18, 3/3).
  - (F) Novo ajuste, por máxima verossimilhança em 6 espécies: chance = min(1, 0,735 · v/P · (1 + 1,44 ·
    investido_antes/P)). Log-verossimilhança −98,1 com 2 parâmetros, contra −126,0 do modelo de nível. Um fator de
    nível ou de raridade a mais não acrescenta nada.
  - Esperado × observado: Rattata 34,3/33, Spearow 25,4/27, Vulpix 4,0/3, Rhydon 2,7/4, Bulbasaur RARE 2,05/0
    (P = 0,13: inconclusivo), Blastoise 0,24/0.
  - Na sim, `captura_c`/`captura_k` substituem `captura_c0`/`captura_alfa`, e o investimento conta antes da bola atual.
  - Ainda não fecha: o valor de cada bola (só a Super Ball foi medida; pede o C5), a raridade, e se o investimento
    feito antes da gravação conta (pede used-balls).
  - (C) O Daily Catch (prints do usuário) é uma missão diária: `/api/game/daily-catch` traz faixas com o nível mínimo
    do treinador, a lista de espécies e o prêmio. Não é a chance de captura.

  **Penalidade:**
  - (A) Fecha a regra de −70%: XP = floor(total × 0,3) em 76/76 abates no lock; drops no lock 42 contra 153,5
    esperados (0,274×).
  - (A) O minuto contou da entrada nas 9 entradas com `boosts` (until − entrada = 60,0–61,4 s, recebido no
    `enter-hunt`). O c2 entrou 32 s depois do fim do C1 e ganhou 60,7 s. Só o S3 foge.
  - "Desde a saída da hunt anterior" não se confirma. "Desde a saída da cidade" é indistinguível da entrada. Fica F,
    parametrizado (`ms_desde_saida`).

  **Movimento:**
  - (A) A borda da perseguição é 13 nos dois eixos (zero a partir de 14), não ±13/±7. Fora dela, 100% parados.
  - H1 e H4 se explicam por isso no Kangaskhan. H3 cai: o "vaguear" era perseguição com |dy| 8–13. H2 segue sem
    retorno ao spawn observado.
  - Na sim, a meia-altura 13 melhora M1/M2 e piora o Rhydon (o diferencial perde 1 critério em cada caso), então a sim
    fica com 7 (F) até o M3. O `medir_movimento.py` mede com 13×13 (`--visao`).

  **Outros:**
  - Golpe: a escolha continua fixa por indivíduo (C1 15/15, M1 13/13, c2 15/15; C6 1 hit fora em 113).
  - Cadáveres: 9 espécies (+ Bulbasaur 2830, Spearow 2826).
  - Protocolo: 144 tipos, 50 vistos.
  - Estado inicial do Kangaskhan em `dados/testes/estado_kangaskhan_venusaur_m2.json`.

  **Testes:** regras 40/40, caminho 8/8, determinismo, regras do usuário 17/17, cadáveres 3/3, catálogo 12/12, save
  fase 3 12/12, cena 22/22, grade 7/7, protocolo OK, ponte 11/11, save em thread 15/15. Diferencial: 1h 27/30,
  antiga 23/26 (iguais a antes).
- 10/11/2026 — Fase 3, gravações C5 e M3 (gravador v1.2: as duas têm linhas `__rest`, mas **nenhuma tem used-balls**;
  o C5 tem `capture-log` e o `auto-helper` de cada troca de bola).
  - Configuração: C5 conta B, Rhydon 425, `geodude`, Poké 61 / Great 60 / Super 59 / Ultra 69 e um trecho extra de
    Idle 75 (44,7 min); M3 conta B, Golem 387 (plano 386), `rhydon`, 16,7 min (plano 20), catch ligado (5 tentativas).
  - **Captura — valor da bola = ouro (A, C5; critério fechado)**: tabela nos Fatos. A sim passa a `captura_valor_bola`
    "ouro", com c 0,814 e k 1,14 reajustados em todas as sequências (antes 0,735 e 1,44, com a eficiência; com só a
    Super Ball as duas formas eram iguais). As 5 falhas de Idle Ball de todas as gravações foram em shiny, o que tira o
    motivo antigo para a eficiência. Medidor que zera ao trocar de bola: indistinguível (logL −191,0 × −190,6).
    Investimento de antes da gravação: inconclusivo (sem used-balls).
  - `conferir_fase3.py`: modelo com o ouro, tentativas em shiny fora do modelo (marcadas "(shiny)"), C5 = `geodude`.
    Modelo × observado: C5 125,2/127, C1 28,4/28, c2 3,4/3, S4 2,5/2, C6 2,0/0.
  - **Movimento (M3)**: tabela na investigação de movimento. Nenhuma regra fechou M1, M2, M3 e rhydon-1h juntas: a sim
    continua com `visao_meia_altura` 7. Parâmetro experimental `mob_espera_apos_heroi_ticks` (0 = desligado; saída da
    sim igual com 0).
  - Penalidade: lock de 60 s desde a entrada também no C5 e no M3 (8/8 e 11/11 abates com debuff antes do until).
  - `extrair_estado_inicial.py` usa o líder do `pokes-chunk` quando a gravação não tem poke-delta do herói (M3).
  - Cadáveres: 10 espécies normais (+ Geodude), 3 shiny. Protocolo: 144 tipos, 54 vistos, 6 caminhos REST.

  **Testes:** regras 41/41, caminho 8/8, determinismo, regras do usuário 17/17, cadáveres 3/3, catálogo 12/12, save
  fase 3 12/12, cena 22/22, grade 7/7, protocolo OK, ponte 11/11, save em thread 15/15. Diferencial: 1h 27/30,
  antiga 23/26 (iguais a antes; a saída da sim muda de propósito nas capturas).
- 10/11/2026 — Fase 3, gravações T1 (transições) e C8 (Meowth 20), e **fechamento da fase 3**.
  - T1: rattata → cidade (29 s) → spearow → mapa → vulpix → cidade → vulpix (8,9 min, Venusaur, Super Ball). Lock de
    60 s **desde a entrada** nas três entradas em hunt nova (58,9–59,3 s pelo serverNow); **mesma hunt pela cidade não
    penaliza** (sem `boosts`, 0/15 abates com debuff). Fecha a regra do usuário (B-relatado → A), salvo a expiração
    de sessão (não gravada) e o S3. A sim já fazia assim (`penalizar_entrada`, `ms_desde_saida` 0); só os comentários
    mudaram.
  - C8: Meowth 20 (preço 300), 87 tentativas, 17 capturas; used-balls só no início. O print do fim, enviado à parte,
    mostra 6 tentativas no total, o que não bate com as 87 do arquivo: não usado. Meowth ausente da lista no início →
    medidor zero conhecido; o modelo esperava 18,4 (17 observados). **O nível não pesa** com o mesmo preço (Meowth 20 ×
    Geodude 1). O used-balls mostra que `goldSpent` é o ouro desde a última captura (A). c e k da sim mantidos (o
    ajuste com T1 e C8 dá 0,815 e 1,20, diferença pequena).
  - Golpe fixo por indivíduo: C8 15/15 (Solar Beam 12, Petal Blizzard 3); T1, 41 indivíduos.
  - Cadáveres: 11 espécies normais (+ Meowth), 4 shiny. Protocolo: 144 tipos, 54 vistos, 8 caminhos REST.
  - Movimento registrado como desvio conhecido (seção própria). `CALIBRACAO_FASE3.md` e `PLANO_FASE4.md` escritos.

  **Testes:** regras 41/41, caminho 8/8, determinismo, regras do usuário 17/17, cadáveres 3/3, catálogo 12/12, save
  fase 3 12/12, cena 22/22, grade 7/7, protocolo OK, ponte 11/11, save em thread 15/15. Diferencial: 1h 27/30,
  antiga 23/26 (iguais a antes).
- 10/11/2026 — **Fase 4, lote 1** (evolução, loja e economia, Nurse Joy, depot; regras e fontes em `CALIBRACAO_FASE4.md`).
  - Lógica em `sim/servico_cidade.gd` (puro, determinístico, comandos e mensagens no formato do original quando
    conhecido, C/A; o resto E). `ponte_cidade.gd` monta o estado do save, manda o comando e aplica as mensagens; o
    `EstadoJogo` (evoluir, curar, depot) passa por ela, então as telas antigas não mudaram de contrato.
  - Evolução (C, guia e janela do original): só em Cerulean; nível = `evolveLevel`; com pedras mantém o nível, sem
    pedras é grátis e volta ao Lv.1; IV/Quality mantidos e stats da base nova. **Receita das pedras é F**: tipo
    principal da origem + tipos ganhos (bate com os 2 exemplos do guia). Eevee por ramos (B/F). Janela nova
    `painel_evolucao.gd`; o botão nunca volta ao Lv.1 sem escolha.
  - Loja do Mark (`painel_loja.gd`, NPC em (22, 8) do city-npcs): bolas pelo `balls.catalog` (A), poções pelo
    `priceGold`; venda pelo `npcPrice` (C) com teto no preço de compra (E: evita ouro infinito); Pokémon da BOX pelo
    `valorVenda` (F). Ouro no save (campo `ouro`; começa em 0, E) e no canto da cidade.
  - Nurse Joy: cura o time de graça, sem recarga (C). Depot: time 6 (C), BOX 3000 (A, conta VIP), 200 pilhas de
    itens (E), "guardar tudo" (C).
  - VIP: opção em ⚙ (canto inferior direito da cidade), desligada por padrão; ligada, `cfg.vip` na simulação (+50%
    da XP base, A). Campo `vip` no save.
  - Espécies: `especies_importadas.obter_todas()` = as 212 com recurso + as do snapshot (base/tipos do gerado); usada
    pelo save, pela ponte e pela captura da cena nova (antes, captura de espécie sem `.tres` era ignorada).
    `obter_especies()` segue com as 212 (contrato dos testes do P04). Custo: +95 ms uma vez, no início.
  - Testes antigos do P04 ajustados ao comportamento novo (sem relaxar a regra): `test_evolucao_pokemon` (pedras /
    Lv.1, a janela), e `forcar_cidade = "cerulean"` no preparo de `test_hunt_larvitar`, `test_ataques_independentes`,
    `test_team_fiel` e `test_qualidade` (que curavam/depositavam fora da cidade). `testes/rodar_antigos.sh` roda os 43.

  **Testes:** serviço 40/40, ciclo de ponta a ponta 20/20 (hunt com VIP → vende loot → compra Super Ball e Small
  Potion → Nurse → Geodude → Graveler com pedra → BOX e depot → save relido), regras 41/41, caminho 8/8,
  determinismo, regras do usuário 17/17, cadáveres 3/3, catálogo 12/12, save fase 3 12/12, grade 7/7, cena 22/22,
  protocolo, ponte 11/11, save em thread 15/15. Diferencial 1h 27/30, antiga 23/26 (iguais). P04: 37/43 passam;
  4 falhavam antes também (cerco_acesso, compatibilidade_save, mapa_entre_hunts, mapa_fiel).
  (A instabilidade do `test_movimento_selvagens` foi resolvida na entrada seguinte: não era regressão.)
  **Desempenho** (mesma máquina e estado, Firefox/Discord abertos; os números absolutos da 2b exigem fechá-los):
  quadro p99 e carga iguais dentro do ruído (Rhydon 1499–1703 × 1644–1649 ms de carga, p99 13,7–14,0 × 14,1–14,3;
  elekid 1535–1554 × 1542–1557, p99 18,1–18,6 × 17,1–18,1); tick da sim p99 2,3–3,1 × 2,4–2,6 ms
  (`testes/medir_tick.gd`; `simulacao_hunt.gd` não mudou).
- 11/11/2026 — Correções antes do lote 2 (nenhuma regra de jogo nova).
  - `test_movimento_selvagens` determinístico: todas as fontes de aleatoriedade da cena antiga são semeadas (RNG
    global, que sorteia IV/Quality dos selvagens; `rng_dano`, `rng_troca`, `rng_loot`; IA de movimento), o relógio de
    troca é fixo e a cena avança por passos de 0,1 s com os timers parados. A parte unitária roda numa instância própria.
    **20/20 rodadas com a mesma impressão** (`1c0d65f2d50b`). Modo `--varrer N` (sementes 1..N).
  - **Por que a falha subiu de 2/9 para 7/13: não foi regressão.** Com as mesmas 40 sementes, a saída é idêntica byte a
    byte em `3d8abb6` (antes do lote 1) e na versão atual; nas duas, 18 de 40 sementes não matam nenhum selvagem em 60 s.
    O teste antigo usava sementes aleatórias e falhava ~45% das vezes; 2/9 e 7/13 são amostras dessa mesma taxa.
  - Preços (`dados/relatorios/precos_npc.md`, gerado por `ferramentas/importador/relatorio_precos.py`): importação
    conferida campo a campo contra o snapshot cru (`npcPrice → precoNpc`, `priceGold → precoGold`, ouro inteiro),
    **0 divergências: não era erro de importação**. As poções eram os únicos itens com `npcPrice` > preço de compra.
    O cliente (C) mostra que o Mark não compra heal/revive/stone (exceto 205 e 206). A regra de venda do lote 1 estava
    errada ao vender poções: corrigida em `sim/servico_cidade.gd`. O teto "venda ≤ compra" fica só como proteção.
    Resultado: 370 vendáveis, 0 com venda acima da compra.
  - Os 4 testes do P04 que já falhavam:
    - `test_cerco_acesso`, `test_mapa_fiel`, `test_mapa_entre_hunts`: esperavam a cena antiga "Caca"; desde a fase 2
      (decisão E) o mapa abre `caca_sim.tscn` para hunt com mapa e hunt-config no snapshot. Expectativas atualizadas
      (o de viagem entre hunts agora confere a nova instância pelo `hunt_key`).
    - `test_compatibilidade_save`: dependia da fixture que o runner antigo gravava antes; agora
      `testes/test_compatibilidade_save.sh` grava a fixture e roda o teste no mesmo user:// isolado (`rodar.sh`
      aceita `ISOLADO`). Os campos opcionais novos (medidor, última hunt, ouro, VIP) são conferidos com o padrão.
  - `cenario_teste_config.tscn` (gerado por `test_configuracao_hunts.gd`) no `.gitignore`.

  **Testes:** P04 **43/43**, serviço da cidade 41/41, ciclo 20/20, regras 41/41, caminho 8/8, determinismo, regras do
  usuário 17/17, cadáveres 3/3, catálogo 12/12, save fase 3 12/12, grade 7/7, cena 22/22, protocolo, ponte 11/11, save
  em thread 15/15. Diferencial 1h 27/30, antiga 23/26 (iguais).
- 11/11/2026 — Gravação G1 (`poke har/gravacoes/fase3/g1.jsonl`, com G1, G2 e G4 numa sessão) e ajustes (detalhe em
  `CALIBRACAO_FASE4.md`).
  - G1 (A): compra `{ok, bought, item, goldSpent, gold}` (Small Potion por 5); venda `{ok, soldKinds, soldCount,
    goldGained, gold}` (Bag of Pollen por 40 = npcPrice); `GET /shop` = `{gold, balls, items}`. A recusa de poções
    segue C (a lista de venda é do cliente).
  - G2 (A): **venda de Pokémon = `sellValue` da espécie**: 2 Blastoise Lv.1 de Quality/IV diferentes → 18000 cada;
    `sellValue` = `valorVenda` em 399/399 Pokémon (níveis 1 a 425). F → A.
  - G4 (A): `joy-heal` → `{type: "joy-healed"}` sem campos, na hora, sem custo; depot `{inventory, depot}` com itens
    `{id, name, icon, category, npcPrice, quantity}`; mover leva a pilha inteira; "guardar tudo" esvazia a BAG
    (inclusive poções); 89 pilhas sem aviso de limite. As bolas não aparecem no depot do original (o P04 guarda: não
    mudado, pendente de decisão).
  - Mensagens do serviço da cidade no formato gravado (shop, shop-bought, shop-sold, joy-healed, depot).
  - O Mark não compra Pokémon shiny (C, aplicado).
  - Item 3: a sim nova também não abate com time nível 1 (40/40 sementes, mesmo com HP cheio a cada passo); causa =
    dano no nível 1–4 (desvio conhecido acima), não alvo, perseguição nem spawn (35 golpes em 60 s, cadência cheia).
  **Testes:** serviço 46/46, P04 43/43, regressão verde, diferencial 1h 27/30 e antiga 23/26 (iguais).
- 11/11/2026 — **Fase 4, lote 2 começado** (regras e fontes em `CALIBRACAO_FASE4.md`).
  - `sim/servico_jogador.gd` (puro): **sessão** (regra do usuário: sem soneca, 15 min fechado expira; com soneca
    valendo, não, E), **Modo Soneca** (C: Zzz → a hunt roda 5 min sem bolas; voltar antes de 5 min cancela; coleta =
    XP/loot/poções da amostra + 50% da taxa de XP pelo tempo fora, teto 24 h, no treinador e no Pokémon; turbo
    recusado offline, E), **Streak Points** (C: 1 ponto/1000 abates, n-ésimo custa 25.000 × n, trilhas EXP/Loot/Shiny
    +0,1%), **Tipo do Dia** (A: formato, texto e virada às 03:00 UTC; E: rotação fixa ancorada em 09/11 Dragão e
    10/11 Inseto).
  - `simulacao_hunt.gd`: parcelas `streak` (só treinador, A), `boost` (xp/pokexp), `typeDay` (F: % da base), loot
    com boost +40%, tipo do dia ×1,2 (F) e rolagens extras do Streak Loot (C); boost de captura dobra a chance (C);
    mensagens `boosts` e `events` no formato gravado (A). **Com nada ativo, a saída é idêntica byte a byte** à de
    antes. Boosts não têm fonte offline ainda (E).
  - Cliente: `streak` e `soneca` no save (opcionais); a hunt conta abates para o Streak e passa Streak, Tipo do Dia e
    boosts para a sim; botão 💤 Zzz; janela de coleta ao abrir a cidade; janela de Streak Points.
  - **Não feito:** tarefas de NPC e Daily Kill/Catch/Gift — o cliente só traz o formato; alvos, quantidades e prêmios
    vêm do servidor (gravações G5 e G7). Também G3 (receita das pedras), G6 (soneca real) e G8 (Tipo do Dia num abate).
  **Testes:** lote 2 puro 28/28, ciclo do lote 2 na cena 14/14, P04 43/43 (compatibilidade com os campos novos),
  serviço da cidade 46/46, regressão verde, diferencial 1h 27/30 e antiga 23/26 (iguais).
- 13/11/2026 — Bolas fora do depot (A, G4): o serviço da cidade recusa `ballId`, "guardar tudo" só leva itens (inclusive
  poções), a tela do depot não lista bolas, e o save antigo com bolas no depot as devolve para a BAG ao carregar.
  Testes: `testes/test_migracao_depot_bolas.gd` 7/7 (fixture `dados/testes/save_antigo_bolas_no_depot.json`), serviço
  46/46; `test_consistencia` e `test_qualidade` (P04) ajustados à regra nova (a bola não vai para o depot).
- 13/11/2026 — Fase 4, item 1 (dano em nível baixo): ajuste com as variantes a/b/c (+ e/d) contra todos os golpes
  gravados; tabela no desvio de dano acima. **Nenhuma variante explica todas as faixas sem piorar alguma gravação: não
  aplicada.** A fórmula ganhou o parâmetro `formula_dano` (padrão "atual": saída da sim idêntica byte a byte, Rhydon
  20 min); `test_sim_diferencial.sh` aceita `PARAMS=...`; `varrer_sementes_sim.gd` aceita `--formula`, `--nivel`,
  `--encher_hp`, `--heroi`, `--slug`. 40 sementes: 0/40 abatem em 60 s com a fórmula atual (e com qualquer variante sem
  encher o HP). Limite: falta snapshot dos stats do selvagem de nível 1 (o resto do erro está nessa faixa).
- 13/11/2026 — **Fase 4, item 3** (gravações G5–G8; detalhe em `CALIBRACAO_FASE4.md`).
  - G6 (soneca, A; só a volta foi gravada): a taxa é XP da amostra ÷ 300 s nominais com **round** (xp50 139, xp100
    278, estKills 23 aos 217 s; coleta de 145 aos 227 s: batem exatamente). **Corrigido**: a coleta entrega só os
    50% do tempo fora (antes somava a amostra); a amostra entra antes, na 1ª leitura do relatório depois dos 5 min
    (E); formatos do relatório e da coleta iguais aos gravados.
  - G7 (A): Streak no formato gravado (`tracks` em pontos, `bonusPct`, `earned`, `canBuy`, `gold`, abates por
    espécie, agora no save); custo 25.000 × n e bônus 0,1% confirmados; parcela `streak` = floor (era round).
    **Daily Gift** implementado: 28 prêmios gravados, um por dia em sequência, dia VIP bloqueia sem VIP (C), boosts
    de 1 h (C; vão no save); itens direto na BAG (E: no original, Gift Center).
  - G8 (A): `typeDay` = floor(20% da base) (61/61; era round); 13/11 = Sombrio (rotação corrigida, E nos outros
    dias); loot no tipo do dia veio ×1,42 da tabela (×1,2 fica, F, com o indício registrado).
  - G5 (A): **Quests & Tasks** (124 tarefas, 43 cidades, progresso por abate/captura/entrega), **Daily Kill** (3
    opções, xp = floor(qtd × xpAbate × 8/3) em 3/3, prêmio do tier, sem reroll) e **Daily Catch** (2 slots por dia,
    faixas por nível; xp do slot F). Sorteio das opções e quantidades do Daily Kill: E (o servidor não mostra a regra).
  - Testes novos: `test_sim_diarias` 36/36, `test_ciclo_diarias` 14/14; `test_sim_lote2` 36/36 (compara com as
    respostas gravadas da G6/G7 campo a campo), `test_ciclo_lote2` 16/16. Saída padrão da sim idêntica byte a byte
    (Rhydon 20 min). Protocolo regenerado com a fase 4 (145 tipos, 57 vistos, 27 caminhos REST); cadáveres: 14
    espécies normais. Corrigido no caminho: o `test_compatibilidade_save` do P04 não esperava a migração das bolas do
    depot (item 2; commit à parte). Faltam: G3 e as gravações G6b, G9, G10, G11 (roteiros no fim do
    `CALIBRACAO_FASE4.md`).
- 15/11/2026 — Fase 4, item 1: `formula_dano` passa a "sem_piso_divisor" por padrão (E sobre a tabela F do desvio de
  dano; o parâmetro continua). Diferencial 1h 27/30 e antiga 23/26 (iguais); regras 41/41, determinismo, regras do
  usuário 17/17, lote 2 36/36, caminho 8/8. A saída da sim muda só onde a defesa contínua do alvo é < 1.
- 15/11/2026 — Fase 4, item 2 (0/40): causa = dano do aliado no nível 1 (tabela no desvio de dano). `piso_ataque_aliado`
  3 (F) na fórmula: o time da `geodude-10min` upa na sim no ritmo do real (abates/min 2,62 × 2,55; níveis/min 0,25 ×
  0,23). Rhydon 20 min idêntico byte a byte com e sem o piso (diferencial igual). Regras 43/43. Ferramentas:
  `comparar_nivel_baixo.py`, `ajustar_dano.py` com variantes de piso ("+aN", "+adN", "+AN").
- 15/11/2026 — Fase 4, item 3 (G3, G6b, G9, G10; detalhe em `CALIBRACAO_FASE4.md`).
  - G3 (A): Geodude → Graveler gastou 1 Rock Stone (só o tipo principal; hunt da origem < 40): a receita F acerta esse
    caso; mensagens de evolução com os campos gravados (`icon`; `ok`, `usedStone`, `stonesSpent`).
  - G6b (A): só o cancelamento foi gravado. Voltar antes dos 5 min **entrega a parte rodada** (`offline-notice
    {kind: cancelled, reason: reconnect, ms, kills, xp, pokeXp…}`); corrigido (antes, E: nada). A amostra guarda a linha
    do tempo; a cidade mostra o aviso.
  - G9 (A): POST /daily (`claimed {day, kind, refId, qty, label, icon, tag}`, `toGiftCenter`; offline false, E), tasks/claim
    (`{ok, taskId, xp, cash, …}`, 3/3 iguais ao tasks.json), Daily Kill (+3 opções exatas, `have` só depois do pick).
    Daily Catch: XP = floor(xpAbate × 8/3 × m) com m múltiplo de 0,5 (4/4), mas **m não é pelo slot** (Arbok 1,5 e 18):
    m sorteado em [1,5; 18] (F).
  - G10 (A): loot do tipo do dia × 1,4 (×1,2 rejeitado, z 2,8; controle na mesma hunt 1,03×); 15/11 = Veneno (rotação).
  - `dados/fase4/` regenerado com G9 (claims do Daily Catch das duas gravações). Testes: cidade 48/48, lote 2 39/39,
    diárias 40/40, ciclos 14/14, 16/16, 20/20, cena 22/22.
- 15/11/2026 — **Fase 4, lote 3 começado** (detalhe e pendências em `CALIBRACAO_FASE4.md`).
  - `sim/servico_itens.gd` (puro): **Rare Candy** (C: +1 nível, só time, nível ≤ 100, até 10 por Pokémon; A: exatamente o
    XP que falta) e **berries** (C: um Pokémon do time, 30 min, a mesma não acumula; A: efeito e % das 40 pela descrição
    do items.json — 38 de redução de dano por tipo, 2 de cura). Efeito no combate (F na aplicação): dano recebido ×
    (1 − pct), cura × (1 + pct); sem berry ativa a saída é idêntica. Save: campo opcional `itens_uso`.
  - Held items, TMs, breeding, Ditto, Pokédex, Golden Stars e Pokécards: regras do cliente (C) e o que a G9 mostrou das
    Golden Stars (A: 6 h por estrela, rolagem grátis a cada 12 h, 9 candidatos) registrados; os números ficam no servidor
    (gravações L1–L4).
  - (Corrigido em 15/11: o `itens.json` não perde acentos; era a saída do console do Windows.)
  - Testes: `test_sim_itens` 18/18, `test_ciclo_itens` 6/6. Protocolo 146 tipos, 59 vistos, 36 caminhos REST;
    cadáveres 15 espécies normais.
- 15/11/2026 — Pós-lote 3, item 1 (dispersão do dano no nível 1): causa = defesa do selvagem por indivíduo na sim; no real,
  nível 1 dá a mesma defesa para todos os indivíduos (S1, S2: 0,77). Regra não fechada (c5 e geodude-10min destoam):
  não aplicada; tabela no desvio de dano. Ferramenta `ferramentas/fase4/stat_comum.py`.
- 15/11/2026 — Pós-lote 3, item 2 (acentos): **o importador não perde acentos** — `dados/gerados/itens.json` está em UTF-8
  correto (0 caractere de substituição) e regenerar não muda nada; os "�" eram a saída do console do Windows (cp1252).
  O importador passa a imprimir em UTF-8; o código que "consertava" o `�` no Daily Gift saiu (não havia `�` nos dados).
  A única mojibake nos dados é um exemplo de chat de log antigo dentro do `protocolo.json` (texto de terceiro, sem uso).
- 15/11/2026 — **Fase 4, lote 4 começado** (detalhe em `CALIBRACAO_FASE4.md`).
  - Ginásios (C): insígnia de 48 h, +1% de XP (parcela `gym`, floor, F) e +1% de rolagem extra de drop por insígnia ativa;
    18 ginásios; 4 conhecidos pelo `gym-global` (A). Sem a luta (servidor), a insígnia ainda não se ganha offline.
  - Bosses: catálogo do snapshot (A, 87); luta não implementada. Invasão: calendário A (horas UTC ímpares, entrada até
    hh:10, fim hh:30) e as mensagens no formato gravado; a luta não foi gravada. Profissões: só o levantamento (C/A), os
    números são do servidor.
  - Teste `test_sim_mundo` 14/14; com 0 insígnias a saída da sim é idêntica. Gravações GB1, BS1, PR1, IV1.
- 15/11/2026 — Processamento automático de gravações: `python -I ferramentas/processar_gravacao.py <arquivo>` verifica
  HP (aliado/selvagem), XP base/VIP/debuff/typeDay, loot × tabela (normal, lock, tipo do dia), Auto-Potion (gatilho e
  escolha; com poção fixa no Auto-Helper a regra não se aplica), passos, cadência, pisos, fórmula de dano por faixa,
  golpe fixo por indivíduo, lock de 60 s (abates a ±1 s do until fora), soneca, Daily Kill/Catch/Gift, tarefas, Streak,
  receita de pedras e a rotação do Tipo do Dia, com as constantes lidas de `sim/*.gd`. Teste contra as conclusões
  registradas: 25/25 (G3, G6–G10, rhydon-1h, C5). Relatórios das gravações da fase 4 em `dados/relatorios/gravacoes/`.
- 15/11/2026 — Investigação "o servidor mudou entre 09/11 e 10/11?": não há sinal nas outras grandezas (tabela no desvio de
  dano). Só registrado, nenhuma regra mudou. Ferramenta `ferramentas/fase4/comparar_dias.py`.
- 15/11/2026 — Jogo novo do zero (`testes/test_jogo_novo.gd` 14/14; tabela em `CALIBRACAO_FASE4.md`): o começo do P04
  (Larvitar, inventário de teste) dava lugar ao do original (C): escolha entre Bulbasaur, Charmander e Squirtle no nível
  1, 100 Small Potions e 100 Poké Balls, Cerulean e a primeira hunt recomendada (Geodude ou Paras, vantagem ×4). No
  Geodude, o Bulbasaur faz ~50 abates em 10 min e chega ao nível 3. A validação do save aceita as três linhas novas.
  E/abertos: IV/Quality do inicial, ouro 0, padrões do Auto-Helper, tutorial do Oak e escolha do visual (gravação NJ1).
- 15/11/2026 — Sombras e iluminação portadas (seção acima). Geometria idêntica ao original em 3 mapas (73.549 sombras;
  `test_render_sombras` 11/11 em rhydon e geodude). Desempenho: um canvas item por sombra custava +1 a +5 ms de p99; com as
  estáticas em lote por chunk, o comparativo limpo (5 hunts, ligadas × desligadas em sequência) ficou igual dentro do
  ruído (ex.: raichu 18,2 × 16,6; elekid 17,8 × 19,2). A medição formal de 3 rodadas saiu contaminada (máquina em uso: 22 de
  48 corridas com a janela limitada a 15–40% dos quadros), e já sem sombra 3 das 16 medianas passavam de 16,7 ms. **Critério
  não demonstrado → desligadas por padrão.** Refazer com a máquina livre: `POKE_SOMBRAS=1 python -I testes/test_todas_hunts.py
  --velocidade 1 ...` contra a mesma lista sem a variável.
- 15/11/2026 — Segundo plano (decisão do usuário: o jogo é idle). Nas 48 corridas da medição das sombras, mesmo com a janela
  limitada pelo sistema a 5–15 quadros/s, a simulação fez 300 ticks em 60 s em todas: o progresso não depende do desenho.
  Novo: sem foco, `Engine.max_fps` = 10 e a simulação ganha 25 ms por quadro (4 ms com foco); o laço da hunt deixou de
  descartar o atraso acima de 10 s (agora recupera tudo, com teto de 1 h). Sombras ligadas por padrão (o custo com a janela
  em foco ficou dentro do ruído no comparativo limpo). Teste `testes/test_modo_fundo.gd` 5/5: 10,0 quadros/s, 100 ticks em
  20,1 s, e 80 ticks em 16 s atravessando uma trava de 12 s.
- 15/11/2026 — Revisão das capturas do jogo novo (0 em 50 Poké Balls): **sem erro**. Poké Ball vale 5 no medidor (A:
  priceGold) e o Geodude custa 300 (A: precoNpc); a chance vai de 1,36% (1ª tentativa) a 2,62% (50ª); esperado 0,99 captura
  em 50 e 37% de chance de nenhuma (o real deu 0/47 no C5). 20 sementes × 10 min na sim: 985 bolas jogadas, 17 capturas
  contra 18,0 esperadas. Teste `testes/test_captura_jogo_novo.gd` 5/5.
- 15/11/2026 — Jogo fechado numa hunt sem soneca (B-relatado: o servidor segue caçando até a sessão morrer, 15 min depois
  de fechar). Antes, ao reabrir, só se decidia se a sessão tinha expirado; a caça do tempo fechado não existia. Agora a hunt
  grava `hunt_ao_fechar` (save) e, ao abrir a cidade, `EstadoJogo.recuperar_hunt_fechada` roda até 15 min daquela caça
  (`servico_jogador.segundos_recuperar` / `rodar_recuperacao`) e aplica XP, loot, capturas, bolas, poções e HP; o resto se
  perde; com soneca vale a soneca. Fica E: reabrir dentro de 15 min volta para a cidade (o original retoma a hunt).
  A extração do save para a sim saiu da cena para `EstadoJogo.extrair_jogo_hunt` (a hunt e a recuperação usam a mesma).
  `testes/test_jogo_fechado.gd` 11/11: 5 min → 300 s (28 abates); 20 min → 900 s (81 abates); com soneca e na cidade, nada.
- 15/11/2026 — p99 em foco das 5 hunts mais pesadas com sombras: **não medido**. As 15 corridas (3 rodadas) rodaram sem
  foco — uma janela aberta por processo em segundo plano não recebe foco no Windows com o PC em uso — e o modo de fundo
  entrou (10 quadros/s, p99 100–178 ms = o intervalo do limite). Do que dá para ler sem foco (`dados/relatorios/
  sombras_custo_render_2026-11-15.md`): o render da CPU por quadro (p99) sobe de 6,9–8,5 ms sem sombra para 8,2–11,2 ms com
  sombra (+1 a +3 ms), e os draw calls de ~147 para ~170 (camada em grupo por andar + lotes por chunk); a GPU medida saiu
  contaminada pela espera da janela. Para medir em foco: `POKE_MODO_FUNDO=0 python -I testes/test_todas_hunts.py --velocidade 1
  --segundos 60 --slugs nightmare_raichu,nightmare_elekid,rapidash,ancient_pinsir,nightmare_luxray` com a janela do Godot
  na frente e o PC parado (~8 min por rodada).
- 18/11/2026 — p99 **em foco** com sombras (medição do usuário, PC parado; `dados/relatorios/p99_foco_sombras_2026-11-18.md`):
  5 hunts mais pesadas × 3 rodadas, 60 s a 1×, 163–176 quadros/s (foco conferido pela contagem). Medianas: ancient_pinsir
  10,07; nightmare_luxray 9,84; nightmare_elekid 9,56; nightmare_raichu 9,14; rapidash 7,56 → **critério cumprido 5/5**
  (pior p99 individual 12,55). Render CPU p99 3,3–4,0 ms, GPU 2,5–2,9, ~170 draw calls. Sombras seguem ligadas por padrão.
  À parte: nightmare_elekid 0 abates em 60 s em 2 das 3 rodadas (time de teste E; não afeta o quadro).
- 18/11/2026 — **Alvo do herói pelo tempo de caminho** (A). Investigando o 0 abates do nightmare_elekid na varredura:
  na sim pura, 13 de 20 sementes não abatiam nada em 60 s. O herói escolhia o selvagem mais perto em linha reta, a 23
  tiles, que no labirinto fica a mais de 60 s de caminho, e nunca chegava. Nas gravações (`ferramentas/gravador/medir_alvo.py`,
  2400 trocas de alvo), o menor tempo de caminho até encostar acerta 2295 e a linha reta 2067. Nos 457 casos em que os
  dois discordam, o caminho acerta 408 e a linha reta 180. Parâmetro `alvo_criterio` ("caminho", o padrão; "chebyshev" é a
  regra anterior). O campo de tempo cobre o mapa inteiro e ignora os outros selvagens (F). Desempate: Chebyshev, distância
  euclidiana, slot (F).
  - Na própria saída, a sim acerta 99,4% pelo caminho e 83,8% pela linha reta; no real, 95,1% e 83,3%.
  - Diferencial: 1h **28/30** (passou "hits selvagens por minuto lutando", 18,4 dentro de 17,4–27,2) e antiga 23/26 (igual).
    Seguem fora o ms/tile do herói e o do selvagem.
  - Tick da sim: p99 1,81 ms com qualquer dos dois critérios.
  - Teste novo `test_sim_alvo.gd` (nightmare_elekid e nightmare_snorunt, 20 sementes cada): 2/2. Com `--criterio=chebyshev`
    dá 0/2, com 13/20 e 12/20 sementes sem abate. Era também o "labirinto" do snorunt na varredura 2b.6.
  - A saída da sim muda de propósito (Rhydon 20 min não é mais idêntica).
  - Regressão: os 27 testes da sim e da cena, protocolo, compatibilidade 22/22, ponte 11/11, save em thread 15/15 e P04 43/43, tudo verde.
- 18/11/2026 — Escopo novo, item 1 (inicial): o jogo novo começa com o **Geodude nível 1** (E), com o mesmo kit (100 Small
  Potions e 100 Poké Balls) e ouro 0, e a primeira hunt recomendada é a Rattata (A: geodude-10min). A tela de jogo novo
  mostra o Geodude, e a caixa "Iniciais do original" troca para os três do original (C). `servico_novo_jogo.gd` ganhou os
  modos `projeto` e `original`. A validação do save aceita a linha Geodude → Graveler → Golem como inicial.
  `test_jogo_novo` 17/17.
- 18/11/2026 — Escopo novo, item 2 (acesso às hunts; `sim/regras_acesso.gd`, mapa-múndi). Regras do cliente (C, janela do
  mapa `tA` e o clique no marcador) aplicadas:
  - Região pelo nível do treinador: Kanto 0, Outland 150, Orre 500, Nightmare 2000. Johto aparece como "em
    desenvolvimento".
  - Cada hunt pede nível do treinador ≥ nível da hunt. Mensagens iguais às do original ("Você precisa ser nível N para
    caçar em X. 🔒", "Outland desbloqueia no nível 150. 🔒").
  - A aba de região bloqueada abre para ver; o bloqueio vale no clique da hunt.
  - Orre pergunta "…TMs AoE e de elemento…, deseja entrar?" (Sim/Não) e deixa entrar.
  - Nada de item, insígnia, passagem ou custo para viajar entre regiões: o clique leva direto à hunt.
  - O nível cobrado é o do treinador (`level` do field-kill). A curva de XP do treinador é a mesma do Pokémon (A: 19
    níveis gravados, de 109 a 633, todos coerentes).
  - O mapa-múndi agora cobra o nível (`acesso_hunts_sem_limite` = false). As abas mostram as 4 regiões, com os 454
    marcadores do map-markers (A) e a viagem pelo slug.
  - **E / em aberto:**
    - O servidor não foi visto recusando `enter-hunt` (F: igual ao cliente).
    - Sem TMs no jogo (lote 3 congelado), o aviso de Orre aparece sempre.
    - O snapshot não tem as imagens grandes de Outland, Orre e Nightmare: fundo liso do tamanho dos marcadores (E). O
      coletor passa a baixá-las.
    - `hunt-cooldown {ms}` (C) não aparece em gravação nenhuma e não é simulado.
    - Pokepedia (B) não consultada: não há cópia local, e o cliente não traz outro requisito.
  - Testes: `test_acesso_hunts` 13/13. P04 `test_cerco_acesso`, `test_mapa_fiel` e `test_mapa_entre_hunts` foram
    atualizados à regra do original (antes afirmavam acesso livre e "região não implementada").
- 18/11/2026 — Escopo novo, item 5 (movimento reaberto): tabela real × sim (7 e 13) em `dados/relatorios/movimento_2026-11-18.md`.
  - Diverge: adjacentes, ms por tile do selvagem em luta curta, ms por tile do herói (sinal misto) e chegadas no M1.
  - Igual: cadência por passo. Chegadas com 7 em 3 de 4 gravações.
  - Ferramentas: `comparar_movimento.py`; `medir_movimento.py` ganhou "chegadas de não-alvos por minuto";
    `testes/duracao_luta.gd` escolheu a hunt da luta média (Venusaur na `blastoise`, 11,5 s).
  - 3 gravações com roteiro (MV1–MV3). Nenhuma regra mudou.
- 18/11/2026 — Escopo novo, item 4 (placar): `PLACAR_ESCOPO.md` é o critério de pronto. Cada item do escopo foi
  quebrado nas regras que o original decide. Conta como confirmada a regra vista no original (A, ou C quando ela mora no
  cliente), feita igual pela sim e com teste ou ferramenta que confere. B, E e F não contam.
  - Total **58/84 (69%)**.
  - 100%: Auto-Potion e Nurse Joy. 80–83%: XP do Pokémon e loot. 71–75%: acesso, XP do treinador, IV/Quality.
    64–67%: combate, golpe, depot. 50–60%: dano, Auto-Catch, começo do jogo.
  - Cada linha diz o que falta.
  - Achado de passagem (A): cada `poke-xp` traz um Pokémon só, o ativo (807/807).
- 18/11/2026 — Escopo novo, item 3 (campanha do zero e jogabilidade; `dados/relatorios/campanha_2026-11-18.md`).
  - **Campanha** (`testes/campanha.gd`, sim pura, política do jogador E no cabeçalho): Geodude Lv.1 do jogo novo → 300,6 h
    jogadas → treinador e Golem **346**, 43 hunts de Kanto e Outland. Usa os comandos do serviço da cidade (Nurse,
    venda, evolução com pedra, compra de poção e bola). Evoluiu para Graveler às 21 h e para Golem às 102 h (as 4 Rock
    Stones exigem farmar pedra).
  - 29 mortes em 318 sessões e **nenhuma morte em loop** (nunca duas sessões seguidas morrendo na mesma hunt). Nenhuma
    hunt com 0 abates e nenhuma travada ≥ 60 s (o maior trecho parado foi 1,2 s).
  - Orre (500) e Nightmare (2000) não foram alcançados em 300 h.
  - **Jogabilidade** (`testes/jogabilidade_hunts.gd`, 451 hunts × 5 min): com a linha do Geodude no nível da hunt, 212
    passam e 239 morrem (dificuldade). Com o time forte, **451/451**. Nenhuma trava de mecânica e nenhum 0 abate sem
    morte. Primeiro abate mais demorado: magnemite, 173 s.
  - Ferramenta: `ferramentas/fase4/relatorio_campanha.py`.
  - Limites: a política é E (sonda de 2 min por candidata, bloqueio de +10 níveis depois de morrer, nota XP + pedras).
    Não há gravação de um time no mesmo nível da hunt para dizer se a dificuldade é a do original.
- 18/11/2026 — G11 (nível 1–4 na `rattata`; `dados/relatorios/g11_nivel1.md`, `dados/relatorios/capturado_x_selvagem.md`).
  - **Capturado** (A, todas as gravações):
    - É um sorteio novo, não o indivíduo selvagem: 12 de 57 capturas são incompatíveis com o maxHp do selvagem.
    - A Quality segue os pesos do cliente (218 capturas, χ² 2,8) e o IV é 1..32 uniforme (ivTotal 97,2 ± 21,7).
    - Os stats exibidos no nível 1 batem com a fórmula (218/218).
    - O jogo já fazia assim (`dados_pokemon.gd`); passa de E para A.
  - **Dano de nível 1** (A, não fechado e não aplicado):
    - O aliado no nível 1 só dá valores pares: Vulpix 14/16 e Geodude 6/8.
    - O Vulpix tira mais no nível 1 (14–16) que no 2 (11–12).
    - A SpD comum do Rattata nível 1 de 0,81 explica 177/177 golpes do Vulpix nos níveis 2–3.
    - O Tackle do Rattata sobe de 5 para 7 quando o Vulpix vai do nível 1 ao 2.
    - Melhor variante (`x2`): 83,7% contra 82,6% da atual. Ferramentas: `grupos_nivel_baixo.py`, `ajuste_nivel1.py`,
      `capturado_x_selvagem.py`, `nivel1_individuos.py`.
  - Tipo do Dia de 18/11 = Fantasma (A): rotação corrigida.
  - Placar: 62/89 (70%). IV e Quality 9/10; dano 4/10, com duas linhas novas de efeito A ainda sem regra.
- 18/11/2026 — Gravação livre, item 1 (`ferramentas/gravador/segmentar.py`; `processar_gravacao.py` aceita pasta ou
  vários arquivos).
  - As exportações diárias são juntadas sem repetir linha.
  - Os trechos são cortados por:
    - cidade × hunt;
    - entrada nova × retomada `:rN`, com a janela do lock (boost shinylock);
    - troca de time (heroName/looktype do field);
    - zoom (comando `view` com outro {hc, hr});
    - buraco de mais de 5 s entre fields (aba em segundo plano).
  - Cada pedaço diz para que serve: xp, loot, dano, passos/cadência (sem buraco, ≥ 60 s), movimento, resultado
    (≥ 5 min com líder conhecido), penalidade, cidade.
  - Passos, cadência e Auto-Potion rodam só nos pedaços sem buraco. O relatório vai para `dados/relatorios/gravacoes/`
    (antes caía em `dados/relatorios/`) com a tabela de trechos.
  - Achado (A): mesmo com a aba na frente, só 30–50% dos pares de fields têm Δseq = 2. "Contínuo" é ≥ 25%; o que marca
    a aba em segundo plano é o buraco.
  - Testes: `testes/test_segmentar.py` 10/10 (exportações sobrepostas, buraco, zoom e troca de time sobre T1 + G11);
    `test_processar_gravacao.py` 25/25.
- 18/11/2026 — Gravador v1.3, item 2 (`ferramentas/gravador/gravador_ws.user.js`).
  - Exporta sozinho, a cada 2 h, só o que é novo desde a última exportação: `poke_livre_<data>_<hora>.jsonl`, com a
    marca do último registro no localStorage.
  - Ao fechar ou recarregar a aba, baixa da memória o que falta (`_ao_fechar`; até ~20 MB). Se o navegador bloquear,
    ao abrir o jogo de novo o que ficou sem exportar é baixado (`_recuperado`). As repetições entre arquivos saem no
    `segmentar.py`.
  - Os registros exportados com mais de 3 dias são apagados do navegador. Trava contra duas exportações ao mesmo tempo.
  - Botão "exportar novos" no painel.
  - Teste `testes/test_gravador.js` (Node, navegador simulado, relógio falso) 9/9: 2 abas, 5 h, todas as mensagens na
    união dos arquivos.
  - Não testado num navegador de verdade: se o download no fechamento passa depende do navegador; a recuperação cobre.
- 18/11/2026 — Movimento, item 3: critério de pronto = resultado por trecho, real × sim, ±10%
  (`ferramentas/validar_resultado.py` (antes `ferramentas/fase4/resultado_trechos.py`)).
  - Cada trecho útil de qualquer gravação (≥ 5 min, líder conhecido) vira estado inicial, com VIP, inventário, bolas,
    Auto-Helper e o **time real** (o `sim/cenario.gd` usa as reservas do `pokes.list` quando existem, no lugar dos
    Geodudes inventados), e roda na sim pela mesma duração com 3 sementes.
  - A penalidade só entra quando o real teve lock no trecho.
  - Resultado: **32/55** em 11 trechos. Mortes/h 11/11, ao lado 7/11, abates 6/11, XP/h 6/11, ouro/h 2/11.
  - Quando os abates divergem, a sim sempre mata menos (−11% a −24%). Isso aponta para a perseguição e o caminho até o
    alvo.
  - Ajustes de passagem:
    - `extrair_estado_inicial.py` lê `pokes.list` (o `time`) e infere o VIP pela parcela `vip` do primeiro abate.
    - `segmentar.py` exporta o contexto e usa o líder conhecido depois, quando falta no começo.
  - Nenhuma regra de jogo mudou. O placar fica em 62/88 (70%).
- 19/11/2026 — **Ciclo 1 da estratégia nova** (`ESTRATEGIA.md`). Classes: 1 exata, 2 resultado, 3 desenhada.
  - **Placar por classe** (`PLACAR_ESCOPO.md`): classe 1 **53/53**; classe 2 **157/160** no validador; classe 3
    **22/22** decididas.
  - **Gravação livre:** 11 exportações e duas abas (contas) gravando juntas. O `segmentar.py` separa por `sessao`, lê em
    streaming sem repetir linha, corta o trecho quando o Auto-Helper muda e guarda mensagens só dos pedaços exportados.
  - **Validador da classe 2** (`ferramentas/validar_resultado.py` → `dados/relatorios/validar_resultado.md`): cinco
    métricas por trecho (abates/min, XP/h, ouro/h, mortes/h, capturas/h), real × sim, 3 sementes.
    - Passa a ±10% ou dentro do ruído da amostra: Poisson para contagens; para o ouro, a faixa de 95% sorteada da tabela
      de loot.
    - Resultado: 157/160 em 32 trechos (105/160 só com ±10%). Fora: 3 trechos de ouro com loot raro (esperado ~1,6 pelo
      acaso).
  - **Ajustes da sim:**
    - `alvo_vem_ao_encontro` true (H4; M3 e S1 voltam a ±10%);
    - filtro de nomes do Auto-Catch (C);
    - no estado das gravações: maxHp gravado por slot, Auto-Helper gravado (bola, limite, poção, nomes) e o time real nas
      reservas.
  - **Diferencial:** 1h 28/30 (igual). O antigo (9 min de 09/11) cai para 21/26 com o alvo vindo ao encontro; sem ele,
    25/26. Fica o validador, que é o critério da classe 2 e cobre 32 trechos.
  - **Classe 3 em `dados/balanceamento.json`** (23 valores com motivo, `sim/balanceamento.gd`; `test_balanceamento` 8/8).
  - **Inventário do cliente** (`INVENTARIO_CLIENTE.md`): 76 grupos de telas e textos, 16 feitos, 18 parciais e 42
    faltando, 22 deles online.
  - **Campanha com metas** (`dados/relatorios/campanha_metas_2026-11-19.md`):
    - Graveler 22 h, Golem 40–102 h (sorte das 4 Rock Stones), Outland 69–109 h.
    - Projeção (estimativa): Orre ~640 h, Nightmare ~30 mil h.
    - Achado (A): o XP base é o `experience` da espécie. Orre 510–560 e Nightmare rendem menos que a Outland.
    - 4 muros com proposta, sem aplicar.
  - **Testes novos:** `test_balanceamento` 8/8, `test_auto_catch_filtro` 3/3. Regressão verde (31 testes do Godot,
    scripts, P04 43/43).
- 19/11/2026 — **Ciclo 2** (decisões do ciclo 1 aplicadas; detalhe nos relatórios citados).
  - **Shiny (A/C):** só espécies com forma shiny (190, `dados/gerados/shiny.json` do cliente) aparecem shiny, 1/260 por
    abate nelas (42/10.914 na gravação livre; 0/3.323 nas outras), nenhum no lock. Auto-Catch Shiny ligado com a melhor
    bola; shinyBase por tier é classe 3. O capturado shiny fica shiny (save: campo opcional). `test_shiny` 7/7.
  - **Garantia de pedra (classe 3):** 3× os abates esperados; contador no save. `test_garantia_pedra` 5/5.
  - **Revisão:** o alvo não vem de fora da borda real (0 de 9.120 intervalos): regra do ciclo 1 revertida; critério formal
    da classe 2 (intervalo de 95%) em `ESTRATEGIA.md`. Validador **159/160** (antes 157/160).
  - **Ranking (A):** topo 1872, ninguém em 2000 (`dados/relatorios/ranking_2026-11-19.md`).
  - **Campanha com tudo ligado** (`dados/relatorios/campanha_ciclo2_2026-11-19.md`; soneca 8 h/dia, Streak, diárias,
    boosts, Tipo do Dia; insígnias 0): VIP — Outland 52 h, Orre **312 h** (19 dias), Nightmare ~14.700 h (projeção);
    sem VIP — Outland 66 h, Orre ~467 h, Nightmare ~25.900 h. ~20% do XP vem de soneca e diárias.
  - **Metas visíveis** (`sim/metas.gd`, classe 3): hunt recomendada (0 mortes em 46 sessões nela), próxima meta, marcos.
  - **XP por região** (`combate.xp_regiao`): implementado na parcela `event`, **em 1** até a decisão. `test_xp_regiao` 4/4.
  - **Backlog do cliente** (`INVENTARIO_CLIENTE.md`: 25 feitos, 13 parciais, 38 faltando, 23 deles online): pacote de
    textos do original, Hunt Analyzer, Gerenciamento de Captura, Log de Capturas, Perfil, Pokédex, Todos os Shinys,
    Inventário, avisos (level up, shiny, boosts), tutorial, tamanho da interface e tela cheia.
  - **Build Windows** `builds/ciclo2/` (`ferramentas/build/montar_build.sh`): exe (binário do Godot; sem templates) + pck +
    dados + snapshot; verificado com APPDATA isolado (jogo novo com Geodude, hunt, save). Save em
    `%APPDATA%\Godot\app_userdata\PokeIdle\progresso_v1.json`.
  - **Testes:** novos `test_shiny`, `test_garantia_pedra`, `test_metas` 14/14, `test_janelas_ciclo2` 26/26, `test_tutorial`
    10/10, `test_xp_regiao` 4/4; regressão verde (41 do Godot, scripts, P04 43/43); diferencial 1h 29/30, antiga 22/26.
- 20/11/2026 — **Ciclo 4, item 1 (começo de jogo como o original).**
  - Inicial: só Bulbasaur, Charmander e Squirtle (o Geodude saiu do jogo; fica só nas ferramentas de campanha).
  - IV e Quality do inicial: porte exato do sorteio do cliente semeado com "<nome>:<id>" (C). O servidor usar a mesma
    semente é F.
  - Tela de criar personagem pelo CSS e pelo vídeo.
  - Gravador v1.4: a tela de criação é `/create-character`, fora do `@match /play*`, e o site troca de página sem
    recarregar.
  - Tutorial com os 17 passos do cliente (`painel_tutorial.gd`), no estilo `.tutg-*` do CSS: véu, holofote no alvo,
    mão, anel e pontos até o NPC, balão e Oak. Os passos de ação fecham sozinhos: Nurse, Depot e Mark ao abrir a janela,
    mapa, entrada na hunt, 1º abate, bola lançada, mochila aberta e poção usada.
  - Captura manual na sim (A/C): o abate sem Auto-Catch fica 20 s em `pending`; o comando `catch {pendingId, ballId}`
    tem 4 s de recarga. O painel de captura (`painel_captura.gd`) segue o `cap-panel` do original.
  - Poção manual: `use-heal` na hunt, e na cidade direto no líder; botão "Usar" e duplo clique na mochila.
  - Lado a lado em `dados/relatorios/visual_ciclo4/` (01–04).
  - Testes: `test_tutorial` 22/22, `test_captura_manual` 8/8, `test_jogo_novo` 17/17, `test_caca_sim` 22/22.
  - Limites: o vídeo acaba no passo do mapa, então os passos da hunt não têm quadro de referência; o Mercado só se pula.
- 20/11/2026 — **Ciclo 4, item 2 (cidade).**
  - Cerulean passa a ser desenhada pelo `render/mapa_renderizador.gd` das hunts com o mapa do servidor `cerulean_novo`
    (`cenario_cidade.gd`). Antes era um recorte antigo (4.615 casas no chão, contra 28.224) com um Sprite2D por peça e
    sem animação. Agora vale a ordem do cliente, com telhados, sombras e **decorações animadas** (2.052 peças
    animadas).
  - NPCs pelo `/api/game/city-npcs` (A, igual em 20/11): Nurse, Depot, Mark, Mercado e Pescador, com os ícones e
    looktypes do catálogo `c5` do cliente e `styleNpc` (C). Treinador e seguidores entram no andar do chão com o zIndex
    de criatura.
  - Vista da cidade em 50×26 casas: o "0.5×" do vídeo (A).
  - Janela da Nurse Joy pelo CSS `.npc-dlg-*` (C). Depot com a altura do conteúdo (A: vídeo).
  - Trilha do tutorial com um ponto a cada 2 casas (A).
  - **Casa à direita da porta do Pokémon Center (−2,−4): não é erro.** A jardineira da casa (−1,−4) é desenhada com
    64 px e cobre (−2,−4). O mapa põe ali a peça invisível 8274, que está em `blocking` no `collision.json` do
    servidor (A, conferido em 20/11). O `walkable()` do cliente (C) bloqueia igual.
  - Em Cerulean, 20 casas são bloqueadas só pela 8274, todas pontas de bancos e jardineiras. A colisão da cidade bate
    casa a casa com a regra do cliente (`test_cidade_mapa` 5/5).
  - O build leva o `cerulean_novo` e o city-npcs no pacote `jogo/`.
  - Primeira carga do mapa: 7,6 s para montar o cache; depois 0,4–0,7 s.
  - Testes: `test_cidade_mapa` 5/5, `test_ciclo_cidade` 20/20, P04 `test_depot_cidade_fiel` 25/25 (âncora da Nurse
    agora pelo NPC) e `test_cidade_qualidade` 79/79.
  - Lado a lado: 04–06; colisão na porta: 07.
- 20/11/2026 — **Ciclo 4, item 3 (mochila).** `painel_inventario.gd` refeito pelo `.inv-bag` do cliente (C) e pelo vídeo
  (A):
  - mochila desenhada com `bag_top/mid/bottom.webp` em 354 px;
  - 4 abas com os ícones `tab_*.png` (Tudo, Pokémon, Pokébolas, Itens) e status "N/6 Pokémon · M itens";
  - busca, categoria e ordem (versão atual, vista no vídeo);
  - grade de 6×38 px com no mínimo 30 casas: a equipe primeiro, com Nv, ⚔ e ★; depois bolas e itens, com "9999+";
  - dica `.inv-tip` ao passar o mouse e a mensagem `.inv-flash` sobre o status;
  - duplo clique: a poção cura o líder e o Pokémon da equipe vai para o Box. Clique numa berry ou Rare Candy abre a
    janela de uso.
  - Testes: `test_mochila` 10/10, `test_janelas_ciclo2` 26/26, `test_tutorial` 22/22, `test_ciclo_itens` 6/6.
  - Lado a lado: 08.
- 20/11/2026 — **Ciclo 4, item 4 (mapa, hunts e combate).**
  - **Mapa:** as 451 hunts têm marcador e levam a uma hunt simulada (`test_mapa_hunts` 4/4). O `map-markers` do servidor
    (A, igual em 20/11) põe 3 hunts da Nightmare (togetic, togekiss, tyranitar; nível 3000) em y = −158, fora da
    imagem. A região de fundo gerado desloca a origem para elas caberem (E).
  - **Entrada na hunt** (`ferramentas/build/medir_entrada_hunt.gd`, pelo POKE_VERIFICAR):
    - build do ciclo 3: 1ª visita 2,0–8,2 s (montar o cache do mapa); depois 0,85–1,23 s;
    - agora no projeto: 0,39–0,57 s com o atlas pronto, ~1 s na 1ª da sessão.
    - O que mudou:
      - o cache de desenho e a grade da sim de cada mapa vão prontos no build (`jogo/cache/mapas`, chave pelo JSON
        descomprimido);
      - o atlas é montado em segundo plano na cidade para as hunts liberadas (`EstadoJogo.pre_aquecer_atlas`);
      - manifest, dados do jogo, espécies e cadáveres ficam em memória por sessão;
      - "Carregando mundo…" (A, vídeo) entre o clique e o 1º quadro (`tela_carregando.gd`).
  - **Dano:** nome do golpe acima do número (`.dmg-move`), com as cores e tamanhos de `.dmg-float` (C).
  - **Zoom:** opção do cliente nas Configurações (25×13, 0.75×, 0.5×), padrão 1 (C: `cameraZoom ?? 1`). Vale para a
    cidade e a hunt e vai no save (campo opcional `zoom`). O vídeo usa 0.5×.
  - **Selvagem bloqueado contorna** (A: `ferramentas/fase4/medir_contorno.py`; nas gravações, com as casas que
    aproximam ocupadas, o original dá passo lateral em vez de esperar):
    - até 4 casas do herói, o caminho conta os outros selvagens como obstáculo (`mob_contorna_bloqueio`);
    - `test_sim_contorno` 3/3; validador da classe 2 159/160 (igual).
  - **Loot na tela:** cartão de abate no tamanho do `.kc-card` (340 px), com o loot ordenado (especial, raro, comum;
    até 6 e "+N"); a pílula do debuff saía "+-6".
  - **Campanha de 20 h** (`kills_diarios`, `kill_xp`, `catch_xp` em 0):
    - Daily Kill — **defeito do jogo, corrigido**: as opções do dia eram geradas travadas (treinador < 25 na virada)
      e ficavam vazias o dia inteiro. Agora são geradas ao destravar (`test_sim_diarias` 42/42). A campanha também
      passou a tentar a escolha a cada volta à cidade.
    - Daily Catch: só paga a espécie da lista do dia. A campanha capturava pouco; agora rende 9.589 XP em 20 h.
    - A campanha não contava captura de shiny quando a bola do shiny era a mesma do Auto-Catch (corrigido).
- 20/11/2026 — **Ciclo 4, item 5 (shiny).**
  - A chance segue a regra do cliente, min(1, shinyBase(tier) × catchRate). O catchRate é A; o shinyBase é classe 3:
    A 0,4% … E 2%.
  - `test_shiny_captura` 3/3: a tabela do balanceamento está na sim, e 40.000 Poké Balls num tier C deram 393 contra
    400.
  - Por bola, sem Master: de 0,4% (Poké, tier A) a 10% (Idle, tier E).
  - Os 0 capturados da campanha são esperados: 32 shinies com Poké Ball dão 0,22–0,32 captura (P(0) 72–80%).
  - A campanha do ciclo 3 também não contava shiny capturado com a mesma bola do Auto-Catch (corrigido).
  - Tabela e contas: `dados/relatorios/shiny_captura_ciclo4.md`.
- 20/11/2026 — **Ciclo 4, item 6 (My Pokes / Equipe).** A janela já seguia o `.team-*` do cliente: 6 casas com
  pokébola, ficha com retrato, nome, Nível, Poder, tipos, selo de Quality e o tipo ao fundo, botões Ativo e Box, barras
  de HP/EXP e atributos coloridos pela razão sobre o maior (C).
  - O botão de evoluir só existia para 4 espécies (tabela do P04). Agora vem do `evolui` das espécies do snapshot:
    "⬆ Evoluir p/ X · Nv.N 🔒" ou "· só em Cerulean 🔒" (C).
  - Os textos passam a vir do pacote `window.team.*`.
  - P04 `test_team_fiel` 98/98, `test_evolucao_pokemon` 15/15.
  - Lado a lado: 10.
- 20/11/2026 — **Ciclo 4, item 7 (Perfil).** `painel_perfil.gd` refeito pelo `.pf-*` do cliente (C) e pelo vídeo (A).
  - Antes, os valores quebravam na vertical.
  - Agora:
    - janela de 440 px com a cabeça hexagonal, as joias e o título em Cinzel dourado;
    - avatar de 132 px com o outfit do treinador;
    - nome, VIP, nível e a barra de XP dourada ("atual / próximo XP");
    - fichas de Rank, Pokédex, ouro e diamantes, e os botões Personalizar Outfit e Log de Capturas;
    - seções Informações Gerais, Progressão, Rankings de Perfil e Duelo/PvP, com as linhas alternadas.
  - O que é do servidor aparece como o original mostra para quem não tem: Sem Bless, Sem clã, 0, "Em breve" (E).
  - E: o fundo dos botões (`/assets/evolution/lol-btn-frame.png`) não foi baixado; no lugar, uma moldura dourada.
  - `test_janelas_ciclo2` 26/26. Lado a lado: 11.
- 20/11/2026 — **Ciclo 4, item 8 (barra de menu e janelas).**
  - Os 33 itens do dock estão na ordem do cliente (C), e a dica de cada um é o nome do original (`hud.world.menu.*`).
  - Nenhum botão fica desligado (antes eram 18). Os sem janela própria abrem `janela_original.gd`, com a moldura do
    `.pf-window` e o ícone do item:
    - Soneca: dorme na hunt; na cidade, explica;
    - Configurações: abre o ⚙ na cidade;
    - Sair: pede confirmação, salva e fecha;
    - Novidades: mostra uma nota;
    - os recursos do servidor (ranking, clãs, guilda, troca, PvP, passe, VIP/amigos, correio, diamantes, indicação,
      lives, PiP, profissões, breeding) dizem que são do jogo online (E).
  - A HUD da hunt usava a escala da janela-base de 1152 px (dock, time e Auto-Helper 1,63× maiores que na cidade e no
    original). Agora usa pixels da janela, como a cidade.
  - Boosts e eventos em fichas `.bi-chip` (C), a 74 px do topo, com o ícone e a borda de cada classe.
  - `test_dock_menu` 6/6. Lado a lado: 09 (hunt) e 12 (janela de item online).
- 20/11/2026 — **Build do ciclo 4** (`builds/ciclo4`, 621 MB: exe 105, pck 94, `jogo/` 420 com os caches de mapa,
  `dados/` 3,3).
  - Verificação com APPDATA isolado: fases 1, 2 e 3 OK.
    - Fase 1: jogo novo com Bulbasaur, gênero e nome → tutorial → hunt Geodude → caça → salva.
    - Fase 2: reabre e continua (XP 12 → 60).
    - Fase 3: importa o save do projeto sem mexer nele.
  - Achado e corrigido no caminho: o verificador abria o mapa antes de a cidade recarregar depois de "Começar", e o exe
    caía (segfault). O jogo agora ignora a viagem pedida por um mapa fora da árvore.
  - **Entrada na hunt no build**, ciclo 3 → ciclo 4 (`ferramentas/build/medir_entrada_hunt.gd`):
    - 1ª visita: rattata 2,27 → 0,91 s; geodude 2,67 → 0,60; rhydon 2,87 → 0,55; electabuzz 1,96 → 0,50;
      nightmare_steelix 8,21 → 1,26 (sem o atlas pronto; com o pré-aquecimento da cidade, ele já existe quando a hunt
      é liberada);
    - visitas seguintes: 0,85–1,23 → 0,28–0,46 s.
  - Regressão:
    - os testes do ciclo (tutorial, captura manual, mochila, cidade, mapa, contorno, shiny, dock, diárias…) verdes;
    - sim (regras 43/43, determinismo, caminho, alvo, grade 7/7, protocolo), ponte 11/11, save em thread 15/15,
      compatibilidade 24/24, segmentar 10/10, processar gravação 25/25, gravador 9/9;
    - P04 20/20; validador da classe 2 159/160 (igual).
- 20/11/2026 — Assets do original baixados com a autorização do usuário: `/assets/evolution/lol-btn-frame.png` (o fundo
  dos botões do Perfil, agora igual ao CSS) e `/assets/maps/{outland,orre,nightmare}.png` (as imagens das regiões no
  mapa-múndi, em `assets/interface/mapa/regioes/`). Antes eram uma moldura dourada e um fundo liso (E).
  - Os 3 marcadores da Nightmare em y = −158 (A) ficam numa margem acima da imagem, que desce junto com eles.
  - `test_mapa_hunts` 4/4, `test_acesso_hunts` 13/13, P04 `test_mapa_fiel` 28/28 e `test_mapa_entre_hunts` 8/8,
    `test_janelas_ciclo2` 26/26. Lado a lado: 11 (refeito) e 13.
- 20/11/2026 — **Ciclo 4, item 8 (continuação): todas as janelas com a moldura do original.**
  - `janela_base.gd`, de que herdam Gerenciamento de Captura, Log de Capturas, Pokédex, Todos os Shinys, Ginásios,
    Bosses, Álbum, Hunt Analyzer e Visual, passa a desenhar a moldura das janelas do cliente (C; A: vídeo):
    - cabeça hexagonal com trilhos dourados e joias turquesa;
    - título centralizado em Cinzel e o × à direita;
    - corpo escuro com borda dourada e abas em pílula;
    - medidas em px da tela de 1880.
  - Pokédex refeita pelo vídeo:
    - 4 quadros de contagem (Capturados x/total, Não capturados, Bloqueados, Desbloqueados; os dois últimos são o
      bônus de +25% XP do servidor, E: 0 desbloqueados offline);
    - grade de 7 colunas de cartões com sprite, número, nome, ✓ verde e silhueta para os não capturados.
  - Gerenciamento de Captura no tamanho do original (980 px).
  - Fica uma diferença: o original tem uma coluna por bola; o medidor offline guarda só o total por espécie.
  - Testes: `test_janelas_ciclo2` 26/26, `test_dock_menu` 6/6, `test_album` 8/8, `test_bosses` 12/12,
    `test_ginasios` 12/12, `test_tutorial` 22/22, `test_ciclo_cidade` 20/20.
  - Lado a lado: 14 (Gerenciamento de Captura) e 15 (Pokédex).
- 20/11/2026 — **Rebuild final do ciclo 4** (`builds/ciclo4`, 628 MB). Verificação: fases 1, 2 e 3 OK.
  - **Entrada na hunt no build** (user:// vazio, `ferramentas/build/medir_entrada_hunt.gd`), ciclo 3 → ciclo 4:

    | Hunt | 1ª visita | Visitas seguintes |
    | --- | --- | --- |
    | rattata | 2,27 → 0,51 s | 0,89 → 0,34 s |
    | geodude | 2,67 → 0,32 s | 0,87 → 0,33 s |
    | rhydon | 2,87 → 0,32 s | 0,88 → 0,32 s |
    | electabuzz | 1,96 → 0,28 s | 0,85 → 0,30 s |
    | nightmare_steelix | 8,21 → 0,89 s | 1,23 → 0,48 s |

    Critério de no máximo 1 s cumprido em todas, inclusive na 1ª visita sem o atlas pré-aquecido.
- 20/11/2026 — **Ciclo 5, item 1 (teste do build do ciclo 4 pelo usuário).** Lado a lado e índice em
  `dados/relatorios/teste_ciclo4/LEIA.md`. Os dois vídeos da pasta de evidências são do jogo original.
  - My Pokes: a barra de cada atributo é o IV / 32; o número segue sendo o stat (E).
  - Painel de captura (canto inferior direito): aparece a cada lançamento, inclusive no Auto-Catch (C), com o link
    "Loja" e o aviso de 2,5 s.
  - Pokédex: grade de 7 colunas montada uma vez. Abre em ~200 ms na 1ª vez e em 13 ms depois; os sprites ficam dentro
    do cartão.
  - Animação da Pokébola na hunt: `render/efeito_captura.gd`, porte de spawnCatchFx/tickCatchFx (C).
  - Botão Zzz flutuante removido: a Soneca fica só no dock.
  - Casa (−2,−4), à direita da porta do Pokémon Center, liberada: E, `balanceamento.json` cidade.casas_liberadas (o
    original bloqueia com a peça 8274).
  - Troca de líder pelo time: o novo líder sobe para o 1º lugar e o antigo vai para a casa dele (A, vídeo). Depois da
    troca, 5 s de recarga com `poke-swap-cooldown` (C/A).
  - Fontes: renderização LCD, hinting normal e as medidas do CSS (.phud).
  - 98: Novo jogo em ⚙, com confirmação. O save atual é copiado para `user://backups/progresso_<data>.json` e conferido
    byte a byte; só então é apagado, e o jogo reinicia como instalação nova.
  - 99: ao reabrir, a mensagem diz quanto tempo o jogo ficou fechado, os 15 min que contaram, o que se perdeu e por quê,
    e o resultado. Com 0 abates, diz o motivo; fechado fora de uma hunt, avisa que nada acumulou. O "0 de exp" não se
    reproduziu: a recuperação rende quando o horário é coerente.
  - Testes: `test_troca_time` 4/4, `test_reabrir.sh` 4/4, `test_novo_jogo_config.sh` 12/12; `test_team_fiel`,
    `test_janelas_ciclo2`, `test_ciclo_lote2` e `test_cidade_mapa` atualizados às regras novas.
- 20/11/2026 — Decisões do ciclo 4 aplicadas.
  - Gerenciamento de Captura com uma coluna por bola, como o original (A: used-balls `balls` {ballId: tentativas}). O
    medidor ganhou o campo opcional `bolas`; saves antigos carregam e a diferença aparece na dica do total.
  - Zoom padrão 1 (25×13) já era o padrão.
  - Itens online seguem com o aviso; build de ~630 MB mantido.
- 20/11/2026 — **Ciclo 5, item 2 (validador na gravação livre de 18–20/11, duas contas):** 225/235 grandezas em 47
  trechos (`dados/relatorios/validar_resultado_livre_2026-11-20.md`). Cobertura: Kanto (hunts de nível 1, 30 e 100) e
  Outland (150), líderes do nível 4 ao 278; nada de Orre nem de Nightmare. A Rocket de Cerulean é evento e fica sem
  estado.
  - XP/h é comparado sem as parcelas que só existem online (`raid`, +20% da base; `guild`; A, conta B). Com elas o
    Gyarados saía 14% abaixo; sem elas, 47/47.
  - O medidor de captura do começo de cada trecho é reconstruído: o `segmentar.py` segue os catch-result e o
    used-balls da sessão (A); a espécie sem nada conhecido começa do investimento médio estacionário do modelo (classe 3).
  - Tentativa a tentativa, com o medidor conhecido, o modelo de captura espera 230 capturas e o real deu 239. Mesmo
    assim, o teste de sinal por trecho segue com a sim abaixo (20 × 5), sem causa achada.
  - Ouro: os 8 trechos fora são loot raro (dois Strange Pheromone de 1 M; Lizard Tail 0,518 × 0,476 da tabela).
- 20/11/2026 — **Ciclo 5, item 3 (campanha com time, `testes/campanha.gd --time 1`):**
  `dados/relatorios/campanha_ciclo5_time_2026-11-20.md`.
  - Em 600 h VIP: Orre às 520 h; reservas em ~40 com o Golem em 527 (XP só do ativo).
  - Orre no acesso (530) não é jogável: só a electrike, a 2,1 M XP/h com ×10, contra 15 M na Outland.
  - Nightmare: ~8.600 h ativas ficando na Outland, ou ~2.700 h se Orre 580 for aguentável.
- 20/11/2026 — **Build do ciclo 5** (`builds/ciclo5`, 627 MB): fases 1, 2 e 3 OK.
  - A pasta de evidências (`referencia_visual/`, 280 MB de vídeos e quadros) entrava no `.pck` (188 MB, build de 722 MB).
    Agora fica no `exclude_filter` e tem `.gdignore`.
  - O verificador espera a gravação em thread antes de conferir a cópia do save na fase 3: na troca `.tmp` → principal,
    o arquivo some por um instante (falha intermitente).
  - Regressão: 51 testes do Godot verdes, os .sh e .py verdes, P04 20/20 e diferencial 1h 28/30 (igual).
- 20/11/2026 — **Piso de XP em Orre** (decisão do usuário).
  - Regra: em Orre, o multiplicador de cada hunt é max(×10, 40.524 ÷ XP base médio das espécies da hunt)
    (`Simulacao.multiplicador_regiao`; `balanceamento.json` combate.xp_regiao_piso). Exemplos: 530 ×73,9, 560 ×18,7;
    de 580 em diante fica o ×10.
  - Medido com VIP (`testes/medir_orre.gd`): taillow e electrike (530) a 15,6 e 14,5 M XP/h, contra 15,0–16,4 M da melhor
    Outland. 5 das 14 hunts de 530 ainda derrubam o time.
  - Orre 580 com o Golem no 580: swellow e manectric a ~50 M XP/h, sem morte.
  - Nightmare ~3.200 h ativas desde o zero.
  - Testes: `test_xp_regiao` 10/10, `test_balanceamento` 8/8, regras 43/43, determinismo, cena 22/22.
- 22/11/2026 — **Ciclo 6.**
  - **Capturas por trecho** (`ferramentas/fase4/capturas_trechos.py`, `dados/relatorios/capturas_trechos_2026-11-22.md`):
    - a sim joga as mesmas bolas do real (1,00 por abate elegível, no mesmo tick);
    - o viés é da chance de uma espécie: Larvitar 116 capturas × 95,6 esperadas, z 2,1; Pupitar e Rattata batem;
    - modelo mantido.
  - **Lote 3 descongelado:** TMs e held items pelas regras do cliente (C; `dados/gerados/lote3.json` gerado por
    `ferramentas/importador/extrair_lote3.py`).
    - Serviço: TM Researcher, canLearnTm, Held Machine, equipar e destruir.
    - Simulação: efeitos dos helds, TM elemental (300, 10 s, 2+ alvos) e AoE TM (respingo, classe 3 1,0).
    - Peças de TM a 2% nos bosses. Held e TMs ficam em `itens_uso`.
    - Teste: `test_lote3` 21/21.
  - **Profissões** (`sim/servico_profissoes.gd`):
    - Botânico e Prestígio, ranks E–S, captura +3% por rank (C);
    - mentor medido (A): 0,5% da base por nível acima de 200 de diferença, teto 60%.
    - Teste: `test_profissoes` 12/12.
  - **Breeding** (`sim/servico_breeding.gd`): regras do cliente, números classe 3. Teste: `test_breeding` 9/9.
  - Crafting e Golden Stars: não começados.
  - **Campanha** com revezamento do líder, bosses, itens e profissão (`dados/relatorios/campanha_ciclo6_2026-11-22.md`):
    - Orre às 502 h; reservas 86–106 com o Golem 595.
    - Time + itens quase igualam os abates/min de Orre aos da Outland, mas sem o piso Orre 530 rende 3,5 M XP/h contra 15 M.
    - Proposta: reduzir o piso para ~16.500.
  - **Build** `builds/ciclo6` (627 MB): 3 fases OK.
  - **Regressão:** verde (diferencial 28/30, igual a antes).
- 22/11/2026 — **Piso de Orre reduzido para 16.500** (decisão do usuário; era 40.524).
  - Medido com o time e os itens do fim da campanha: electrike 10,1 M XP/h, torchic 11,9 M.
  - Sem VIP, empata com a melhor Outland; com VIP fica em ~2/3, porque o VIP soma 50% da base, que em Orre é pequena.
  - Teste: `test_xp_regiao` 10/10.
