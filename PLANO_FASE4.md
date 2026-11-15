# Fase 4 — amplitude (proposta de 10/11/2026)

**Situação:** lote 1 (itens 1 a 4: evolução, loja e economia, Nurse Joy, depot) implementado em 10/11/2026. Lote 2 começado em 11/11/2026: sessão, Modo Soneca, Streak Points, boosts e Tipo do Dia implementados; tarefas e diárias esperam as gravações G5/G7 (o servidor manda alvos e prêmios). Regras, fontes
e o que pede gravação em `CALIBRACAO_FASE4.md`. VIP virou opção do jogador (desligada por padrão). Lote 3 começado em 15/11/2026:
Rare Candy e berries implementados; held, TM, breeding, Pokédex, Golden Stars e Pokécards documentados com o que falta
gravar (`CALIBRACAO_FASE4.md`). Lote 4 começado em 15/11/2026: insígnias de ginásio (bônus na hunt), catálogo de bosses e
calendário da invasão; as lutas e as profissões esperam as gravações GB1, BS1, PR1, IV1. Item 14: não começado.

Objetivo: o jogo offline ter os sistemas do original que dão progressão fora da hunt, na mesma arquitetura: a regra
mora na simulação ou num módulo de regras puro (`RefCounted`, sem cena), com as mensagens/respostas do original, e a
cena só desenha.

## Como foi levantado o que existe

- **Protocolo WS** (`dados/protocolo.json`, C + A): 144 tipos de mensagem.
- **Endpoints `/api/game/*`** citados no cliente (`poke-local/public/_next/static/chunks/*.js`, C): ~110 caminhos.
- **Snapshot** (`poke har/extraido/snapshot_2026-11-09/`):
  - `creatures.json`: tem `evolvesToId` e `evolveLevel`.
  - `items.json`: 670 itens. Categorias: loot 387, held 64, card 52, berry 40, misc 34, addon 27, stone 20, tm 19,
    clan 17, heal 7, revive 2.
  - `bossCatalog.json` (87), `pokecards.json` (sets e cartas), `city-npcs` e outfits.
- **O que o P04 já tem** (`*.gd` na raiz):
  - `painel_nurse_joy.gd` (fluxo Talk → Heal Team);
  - `painel_depot.gd` e `inventario_jogo.gd` (BAG/DEPOT);
  - `regras_evolucao.gd`, que é só um esboço de 4 linhas;
  - `perfil_treinador.gd`, com uma curva provisória.

O gravador v1.2 já grava as respostas REST. Para cada sistema, **abrir a tela no jogo com o gravador ligado** dá o
formato real das respostas (A) sem coleta especial.

## Ordem proposta (valor para o jogo offline primeiro)

| # | Sistema | Por que vale | Já existe | Dados necessários | Gravação/coleta |
|---|---|---|---|---|---|
| 1 | **Evolução** (`/api/game/evolve`; `evolveNeedLevel`, `evolvesToName`, `hasEvolution` no poke) | Progressão central do time; sem ela o nível não vira nada | esboço | snapshot: `evolvesToId`/`evolveLevel` (A/C); pedras em `items` (stone 20); cliente: tela e confirmação (C); stats depois de evoluir (recalcula com a base nova? mantém IV/Q?) | evoluir 1 Pokémon com o gravador (resposta do `/evolve` + `poke-delta`) e 1 por pedra, se houver |
| 2 | **Loja e economia** (`/shop`, `/shop/buy`, `/shop/sell`, `/balls/buy`, `/pokemon/sell`, `currency`) | Sem comprar bolas e poções o loop idle trava; ouro vem dos abates/vendas | parcial (venda de loot no P04) | snapshot: `priceGold` das bolas, `sellValue`/`priceNpc` das espécies, preços dos itens (A/C); cliente: telas | abrir a loja e comprar 1 de cada tipo; vender 1 Pokémon e 1 loot |
| 3 | **Nurse Joy** (`joy-heal`) | Cura fora da hunt; hoje é local | painel | cliente (C): custo, cooldown, mensagem | 1 cura com o gravador |
| 4 | **Depot, bag e box** (`/depot`, `/depot/move`, `poke-store`, `poke-withdraw`, `/pokemon/lock`, `/item/lock`, `pokeCapacity` 3000) | Gestão do que se acumula; já é usado | painel e inventário | cliente (C) e respostas REST (A); limites (3000 do auto-helper, A) | mover 1 item e 1 Pokémon, travar 1 |
| 5 | **Modo soneca / progresso offline** (`sleep-mode`, `sleep-ok`, `/api/game/offline`, `offline-notice`, `restart-*`) | É o coração de um jogo idle offline: ganhos com o jogo fechado | não | cliente (C): regras da tela; **fórmula dos ganhos só por gravação (A)**: entrar em soneca, sair depois de X min, gravar o `offline-notice` | 2–3 sonecas de durações diferentes na mesma hunt |
| 6 | **Tarefas e diárias** (`/tasks`, `/tasks/claim`, `/daily`, `/daily-kill` + pick/reroll/claim, `/daily-catch`, `/dailys-summary`, `/pokedex` + claim) | Metas curtas; muito valor de retenção, pouco risco | não | respostas REST (A): faixas, metas, prêmios (o Daily Catch já está entendido, C); cliente (C) | abrir cada tela e resgatar 1 prêmio |
| 7 | **Boosts, eventos, dia do tipo e Streak Points** (`boosts`, `boosts-refresh`, `events`, `/streak`, `/streak/spend`; `xpParts` streak/boost/event/typeDay/gym) | A XP de cada abate já tem essas parcelas (A); hoje só base, vip e debuff | parcelas no `field-kill` | gravações com cada parcela ≠ 0 (A); `/streak` (A); cliente: catálogo de boosts (C) | ativar 1 boost; gastar Streak Points; gravar um dia de tipo |
| 8 | **Itens de uso** (`use-candy`, `use-berry`, `use-borage`, `use-held`, `use-random-held`, `use-tm`, `/held-machine`, `/tm-researcher`, `held-replace-confirm`, `tm-replace-confirm`) | Personalização do time; usa itens que já caem no loot | itens no catálogo | snapshot: categorias held/berry/tm (A/C); **efeitos**: cliente (C) e Pokepedia (B); efeito no combate exige gravação (A) | usar 1 de cada categoria; 1 hunt curta com held equipado |
| 9 | **Breeding e Ditto** (`/breeding`, `/ditto`, `family`) | Fonte de IV/Quality altos; sistema longo | não | cliente (C), Pokepedia (B), respostas REST (A); a herança de IV/Q só por amostras (A) | 3–5 crias com os pais conhecidos |
| 10 | **Pokédex, Golden Stars e Pokécards** (`/pokedex`, `/golden-stars/*`, `use-pokecard-pack`, `/pokecard-album`, `pokecards.json`) | Coleção; dados já no snapshot | não | snapshot `pokecards.json` (A); sorteios: chances só por amostra ou pelo cliente | abrir pacotes; 1 rolagem de Golden Stars |
| 11 | **Ginásios, bosses e altar** (`/gyms` + challenge/bonus/abandon, `boss`, `auto-boss*`, `/boss/*`, `/altar`; `bossCatalog.json`) | Conteúdo PvE de fim; a sim de hunt serve de base | não | snapshot `bossCatalog.json` (A); regras de luta: gravação (A) | 1 ginásio e 1 boss completos |
| 12 | **Profissões e pesca** (`/professions/*`, `profession-gather`, `profession-photo`, `fishing*`) | Sistema paralelo grande | não | cliente (C); taxas por gravação (A) | 20 min de pesca; 1 craft |
| 13 | **Invasão** (`invasion-*`) | Evento periódico | não | gravações (há `invasion-state` no C5, A) | 1 invasão inteira |
| 14 | **Outfits e addons** (`/outfits`, `/outfits/equip`, `set-addon`, `use-addon`) | Cosmético; os sprites já estão no snapshot | desenho dos outfits | snapshot (A); regras de desbloqueio: cliente (C) | equipar 1 outfit/addon |

Pendências do projeto que entram junto (decisões E já registradas):
- Captura manual.
- Efeito de Speed na cadência.
- Sombras e iluminação do cliente.

**Fora do offline (ficam para a versão online):**
- Comércio entre jogadores: troca (`trade-*`), mercado (`/market*`).
- Combate entre jogadores: PvP (`pvp-*`, `/pvp/*`).
- Social: chat e DM, amigos e bloqueios, guild e clãs (`/clans/*`).
- Competição global: rankings, `gym-global`, `shiny-global`.
- Monetização e conta: diamantes, `/packs/order`, referral, `/gifts`.
- Season pass (`pass-progress`): depende de servidor.

## Como cada item seria feito (mesmo processo das fases 1–3)

1. Ler a tela e a chamada no cliente (C). Abrir a tela no original com o gravador v1.2 (A).
2. Importar o que for dado para `dados/gerados/` (importador, nunca à mão).
3. Regra pura com `PARAMETROS` e a fonte de cada um.
4. Teste headless com save isolado.
5. Painel na cidade por clique (decisão E).
6. Linha no Estado.

**Ordem de entrega sugerida:**
- **Primeiro lote**: 1 a 4. Fecham o loop "hunt → ouro → bolas/poções → time evolui" com dados que quase todos já
  existem.
- **Segundo lote**: 5 a 7. O que torna o jogo idle de verdade e as parcelas de XP.
- **Depois**: 8 a 14, conforme o interesse.

Precisa de decisão sua antes de começar:
- **Soneca offline:** replicar a fórmula do original (exige gravação), ou simular a hunt em velocidade acelerada pelo
  tempo fora (a sim já roda 1 h em ~10 s)? A segunda é exata em relação à sim, mas pode divergir do original.
- **VIP:** continua desligado no offline? Isso afeta XP, Auto-Helper e capacidade.
