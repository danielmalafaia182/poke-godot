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
| `ferramentas/protocolo/gerar_protocolo.py`, `regenerar.sh` | Gera `dados/protocolo.json` (`regenerar.sh` fixa as fontes: 5 chunks do jogo + todas as gravações) |
| `ferramentas/gravador/medir_passos.py`, `medir_pocao.py` | Medem nas gravações a duração dos passos (por tick exato) e o gatilho/escolha do Auto-Potion |
| `ferramentas/gravador/medir_movimento.py` | Adjacentes/perseguição por field, coleira (spawn), caminho do herói até o alvo |
| `ferramentas/gravador/relatorio_individuos.py` | Por indivíduo selvagem: maxHp → stat HP → faixa de IV/Quality → dano previsto × observado (para a fase 3) |
| `ponte/servidor_sim.gd`, `ferramentas/ponte/ponte_poke_local.py` | Ponte: o cliente original (poke-local) desenha a hunt da simulação. `python ferramentas/ponte/ponte_poke_local.py` e abrir http://127.0.0.1:8000 |
| `ferramentas/importador/importar_snapshot.py` | Snapshot → `dados/gerados/*.json` (determinístico) |
| `ferramentas/importador/diff_snapshots.py` | Diferenças entre snapshots |
| `dados/gerados/` | especies (647), golpes (407), itens (670), hunts (451), cidades (3), regras, relatório |
| `dados/protocolo.json` | 139 tipos de mensagem; 65 comandos que o cliente envia; 72 eventos que ele escuta; 28 vistos nas gravações |
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
| `field-init` anuncia heroStepMs 500, trainerStepMs 500, mobStepMs 1000. Espera real antes de cada passo = stepMs × (2 se diagonal), arredondada para cima ao tick: herói →reto 600 ms, →diagonal 1000/1200; selvagem →reto 1000/1200, →diagonal 2000. Treinador = posição do herói, sempre | `medir_passos.py`, 45 instâncias |
| Em todo `field`, stepStartAt = serverNow; walkFrom ≠ posição só no field do tick em que o passo começou | 4046 fields |
| Ritmo de ataque: aliado ~1600 ms; cada selvagem ~2000 ms (às vezes +1 tick) | 557 hits de Solar Beam, 532 selvagens, Gastly, Bulbasaur |
| HP de combate do aliado = max(24, 12 × stat de HP) | Venusaur 120→1440, 121→1452; Geodude 2→24, 3→36 |
| HP do selvagem = max(120, 35 × stat de HP) | todos os maxHp de Rhyhorn, Rhydon, Kangaskhan, Blastoise; Geodude nível 1 no piso |
| Stat = round(L/100 × (base + 2·IV) × Quality^exp); exp 0,95 HP/vel, 0,8 demais; Power = round(Σstats × Quality) | (B)+(C), paridade testada antes |
| Fator aleatório 0,85–1,00 por golpe | máx/mín ≤ 1,17 dentro do mesmo indivíduo (72 indivíduos) |
| Efetividade amplificada: ×1,5→1,75; ×2→2,5; ×4→5,5; resistência ÷1,5 (×½ → 0,333); ×0 e ×1 iguais | (B) + `eff` nos hits |
| **Piso de dano: 2 para o aliado, 1 para o selvagem — inclusive com eff 0 ou resistido** | Gastly×Rattata (eff 0: 2 e 1); Rattata→Geodude resistido: 1 em 880 hits |
| XP base por abate = `experience` da espécie; VIP soma +50% em parcela separada (`xpParts`) | 200+ abates |
| Ao entrar numa hunt (não na retomada `:rN`) os abates de ~1 min saem com `xpParts.debuff` = −70% (5772 → 1731) | rhydon-1h: os 7 primeiros abates; mecanismo exato em aberto (F) |
| Os hits do `field` que o cliente não recebe não se perdem: vão no próximo field entregue; o `field-kill` sai no tick do abate, antes do field com o golpe final | rhydon-1h: hits/field 0,18 com Δseq 2, 0,91 com Δseq 10 |
| XP acumulada = round(50/3 × (L³ − 6L² + 17L − 12)) → 100/200/400/800 para níveis 2–5 | (B) + Geodude subiu com 102, 210; nível 4 com 714 |
| Loot: tabela de `creatures.json`, chance em 1/100.000, quantidade min–max | Rhydon 60 abates: Horn 83,3% vs 83,32% |
| Hyper Potion cura até 1000, limitado ao HP que falta | 60+ auto-heals |
| Auto-Potion dispara no mesmo tick em que o HP fica ≤ 50% (sem recarga observada); usa a menor poção do inventário que cobre o que falta, ou a maior se nenhuma cobre | `medir_pocao.py`: 42/42 cruzamentos; 208/208 escolhas |
| Golpes: o mesmo nome tem cooldown diferente por espécie (234 de 407 variam) | catálogo; por isso golpes ficam dentro de cada espécie |
| Captura com Super Ball: 59% em Rattata nível 1 (35/59); no Rhydon 80, 0 em 167 (gravações antigas) e 5 em 608 na rhydon-1h (~0,8%); o Rhydon capturado chega como poke-delta de nível 1 | gravações; `hunt-config.catchChance` é 0 em todas |
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
Em aberto: no nível 1 o Geodude (Atk exibido 1) tira 6–8 em Rattata — sugere stats sem arredondar ou piso interno de stat.
Teste de calibração disponível: 680 hits do Geodude níveis 1–4 (`gravacoes/geodude-*.jsonl`).

### Em aberto (não invente; deixe parametrizado e marcado)

Seleção de golpe (hipótese: maior dano esperado, empate → menor cooldown; o Venusaur usa só Solar Beam),
IA de movimento dos selvagens (ver investigação abaixo), forma da curva de captura (só 2 pontos), parcela extra de XP
vista na conta B (×1,554 em vez de ×1,5), mecanismo da penalidade de entrada (abates ou tempo), efeitos de status,
regras de respawn (tempo exato).

### Investigação de movimento (aberta; não bloqueia a fase 2)

Medido com `ferramentas/gravador/medir_movimento.py` (A = rhydon-1h, 6613 fields; sim = 2 instâncias de 60 min):

| Métrica | Real 1h | Real antiga | Sim |
| --- | --- | --- | --- |
| Selvagens adjacentes ao herói por field (média; % com 2+) | 0,40; 1,9% | 0,75; 15,6% | 0,44; 4,0% |
| Selvagens vivos na visão (±13, ±7) por field | 1,27 | 1,65 | 1,33 |
| Selvagens na visão se aproximando do herói por field (Δseq 2) | 0,48 | 0,41 | 0,35 |
| Fora da visão: parado / se afasta do spawn / se aproxima do spawn | 97,9% / 1,9% / 0 | 99,0% / 1,0% / 0 | 99,3% / 0,7% / 0 |
| Distância ao spawn fora da visão (mediana; p90) | 0; 0 | 0; 1 | 0; 0 |
| Caminho do herói até o alvo: tiles ÷ Chebyshev inicial (mediana; p90) | 0,62; 0,78 | 0,58; 0,78 | 0,67; 0,96 |
| ms por tile no caminho do herói (mediana) | 800 | 800 | 800 |

Hipóteses (F), para testar quando a fase 3 chegar ao movimento:
- H1: na visão, o selvagem real persegue mais (0,48 × 0,35 por field; P(mover) 0,35 × 0,31). Candidatos: ele não
  espera "progresso" para andar (a sim fica parada quando bloqueada) ou começa a perseguir assim que entra na visão.
- H2: não há coleira observável: quem está fora da visão fica no spawn (mediana 0) e nunca foi visto voltando a ele;
  como quase todos já estão no spawn, a coleira (se existir) não aparece nestes dados.
- H3: fora da visão há um pequeno vaguear (1–2% dos intervalos se afastando do spawn); a sim quase não tem.
- H4: o alvo vem ao encontro do herói mais no real (razão p90 0,78 × 0,96): mesma causa de H1.
- O "ms por tile" do diferencial (754–758 real × 809–866 sim) mede deslocamento entre fields; no caminho até o alvo os
  dois lados dão 800 ms/tile, então a diferença vem do encontro com o alvo (H1/H4), não da velocidade do passo.

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
