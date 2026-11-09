# Poke Idle em Godot — instruções para o Claude Code

Leia este arquivo inteiro antes de qualquer mudança. Ele é o ponto de entrada do projeto.
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
| `ferramentas/protocolo/gerar_protocolo.py` | Gera `dados/protocolo.json` |
| `ferramentas/importador/importar_snapshot.py` | Snapshot → `dados/gerados/*.json` (determinístico) |
| `ferramentas/importador/diff_snapshots.py` | Diferenças entre snapshots |
| `dados/gerados/` | especies (647), golpes (407), itens (670), hunts (451), cidades (3), regras, relatório |
| `dados/protocolo.json` | 136 tipos de mensagem; 65 comandos que o cliente envia; 72 eventos que ele escuta |
| `dados/correcoes.json` | Correções sobre o publicado (IV até 32) |
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

- Troca automática após KO: **aleatória** entre membros vivos e válidos do TIME (não do box), sem curar;
  depois dela, 5 s de cooldown para troca manual. Volta à cidade só quando não há reserva viva.
- Interações da cidade por **clique** (NPCs/depot); nada de tecla obrigatória. HUD responsivo, referência 1920×1080.
- **IV de 1 a 32 por atributo** (total 192). A Pokepedia cita 31 em parte do texto; vale 32.
- Mostrar IV individual exato no depot é melhoria deliberada (o original mostra total/faixas).
- Um cartão de derrota por vez, sem fila, no máximo 30 exibições por instância (limita apresentação, não prêmios).
- Contador "Capture" reinicia a cada nova instância de hunt; sem mensagem "X captured...".
- Captura manual e efeito de Speed na cadência: adiados.
- Outfits (sprites de todos os Pokémon) ficaram fora do snapshot por ora; usar um sprite só no offline é aceitável.

## Fatos confirmados (fonte A, salvo indicação)

| Regra | Evidência |
| --- | --- |
| Servidor em ticks de 200 ms; snapshot `field` a cada 2 ticks (400 ms); `seq` conta ticks | todos os logs |
| Passo: herói e treinador 500 ms; selvagem 1000 ms (`field-init`: heroStepMs, trainerStepMs, mobStepMs) | todos os logs |
| Ritmo de ataque: aliado ~1600 ms; cada selvagem ~2000 ms (às vezes +1 tick) | 557 hits de Solar Beam, 532 selvagens, Gastly, Bulbasaur |
| HP de combate do aliado = max(24, 12 × stat de HP) | Venusaur 120→1440, 121→1452; Geodude 2→24, 3→36 |
| HP do selvagem = max(120, 35 × stat de HP) | todos os maxHp de Rhyhorn, Rhydon, Kangaskhan, Blastoise; Geodude nível 1 no piso |
| Stat = round(L/100 × (base + 2·IV) × Quality^exp); exp 0,95 HP/vel, 0,8 demais; Power = round(Σstats × Quality) | (B)+(C), paridade testada antes |
| Fator aleatório 0,85–1,00 por golpe | máx/mín ≤ 1,17 dentro do mesmo indivíduo (72 indivíduos) |
| Efetividade amplificada: ×1,5→1,75; ×2→2,5; ×4→5,5; resistência ÷1,5 (×½ → 0,333); ×0 e ×1 iguais | (B) + `eff` nos hits |
| **Piso de dano: 2 para o aliado, 1 para o selvagem — inclusive com eff 0 ou resistido** | Gastly×Rattata (eff 0: 2 e 1); Rattata→Geodude resistido: 1 em 880 hits |
| XP base por abate = `experience` da espécie; VIP soma +50% em parcela separada (`xpParts`) | 200+ abates |
| XP acumulada = round(50/3 × (L³ − 6L² + 17L − 12)) → 100/200/400/800 para níveis 2–5 | (B) + Geodude subiu com 102, 210; nível 4 com 714 |
| Loot: tabela de `creatures.json`, chance em 1/100.000, quantidade min–max | Rhydon 60 abates: Horn 83,3% vs 83,32% |
| Hyper Potion cura até 1000, limitado ao HP que falta | 60+ auto-heals |
| Golpes: o mesmo nome tem cooldown diferente por espécie (234 de 407 variam) | catálogo; por isso golpes ficam dentro de cada espécie |
| Captura com Super Ball: 59% em Rattata nível 1 (35/59); 0% em 167 tentativas no nível 80+ | gravações; `hunt-config.catchChance` é 0 em todas |
| 15 spawns por hunt em Kanto/Outland, 16 em Orre, até 56 em Nightmare | `hunt-config` |

### Fórmula de dano candidata (F, coerente com todos os casos medidos)

```
dano = max(piso, (2·L/5 + 2) · Poder · A/D / 50 · STAB(1,5) · eff_amplificada · (1,8 se selvagem) · aleatório(0,85..1,00))
A/D = SpA/SpD (golpe especial) ou Atk/Def (físico); piso = 2 aliado / 1 selvagem
```

Envelopes previstos contêm os observados em: Venusaur 109 Solar Beam → Rhydon 80 (910–2282) e → Kangaskhan 80 (128–230);
Rhydon Stone Edge → Venusaur (241–432); Kangaskhan Mega Punch → Venusaur (136–207).
Em aberto: no nível 1 o Geodude (Atk exibido 1) tira 6–8 em Rattata — sugere stats sem arredondar ou piso interno de stat.
Teste de calibração disponível: 680 hits do Geodude níveis 1–4 (`gravacoes/geodude-*.jsonl`).

### Em aberto (não invente; deixe parametrizado e marcado)

Seleção de golpe (hipótese: maior dano esperado, empate → menor cooldown; o Venusaur usa só Solar Beam),
IA de movimento dos selvagens, fórmula de captura, parcela extra de XP vista na conta B (×1,554 em vez de ×1,5),
efeitos de status, regras de respawn (tempo exato).

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

## Fase 1 — simulação mínima de hunt (próximo trabalho)

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
