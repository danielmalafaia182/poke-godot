# Inventário do cliente original (backlog do ciclo 2)

Gerado por `ferramentas/inventario/gerar_inventario.py` a partir dos textos do cliente original (C: 4187 textos em pt-BR, chunk `3vooh2axx98am.js`). Cada linha é uma janela, uma parte da HUD ou um grupo de telas, com o número de textos (botões, títulos, avisos) e exemplos. Status no nosso jogo avaliado em 19/11; revisto nos ciclos 7 e 8 (22/11).

**76 grupos: 38 feitos, 13 parciais, 25 faltando** (1154 / 1416 / 1617 textos). Dos que faltam, 24 dependem de outros jogadores ou de conta (ficam para a versão online).

| Grupo | Status | Textos | No nosso jogo / o que falta | Exemplos |
| --- | --- | --- | --- | --- |
| `window.breeding` | feito | 116 | painel_breeding.gd (ciclo 8): escolher os pais, caminho, dobro de pedras, incubadora (C; números classe 3). Comprar slot e chocar na hora são de diamantes (online) | Centro de Breeding · Par reprodutor · Selecione no box |
| `window.goldenStars` | feito | 116 | painel_golden_stars.gd (ciclo 8): slots, desbloqueios, Roll, escolha direta, sorteio, trocar bônus (A/C; custos classe 3) | Poke Slot Machine · Trocar bônus · Trocar Pokémon |
| `window.seasonPass` | falta | 102 | passe de temporada | Acelerar · Comprado · Passe Premium · {{price}} |
| `landing` | falta | 84 | página inicial do site (fora do jogo) | Direto no navegador · Também no celular · Sem download |
| `window.professions` | feito | 83 | painel_profissoes.gd (ciclo 8): abas das carreiras, rank, requisitos, bônus, troca, crafting e pictures | Profissões · Fechar · Em breve |
| `window.talents` | feito | 27 | árvore do Botânico na janela de Profissões (liberação por rank, classe 3) | Talentos do Botânico · Berry que protege do tipo {{type}} · Berry que protege dos golpes tipo Neutro |
| `window.ditto` | feito | 22 | sim/servico_ditto.gd (ciclo 8): transformação de 12 h, −25%, restrições do cliente; fonte offline no treinador 100 (classe 3). O Shiny Ditto é da loja de diamantes (online) | Espécies disponíveis · Limpar filtros · {{shown}}/{{total}} |
| `window.craft` | feito | 19 | crafting na janela de Profissões: Craftar N, fila, Coletar (C; números classe 3) | 🌿 {{n}} Fresh Herbs · 🍂 {{n}} Wild Herbs · Painel de Crafts |
| `window.fishing` | feito | 15 | painel_pesca.gd + sim/servico_pesca.gd (ciclo 8): Pescador na cidade, faixas, skill, progresso, recarga (C; A: 12 peixes no nível 4; faixas classe 3) | Fechar · ⏳ Aguarde {{seconds}}s · Nv {{min}}–{{max}} |
| `window.fishingWave` | parcial | 2 | a onda de pesca é abstrata (E): espera e recarga, sem luta na água | Pescando… · {{value}}s |
| `window.pvp` | falta | 212 | PvP (online) | PvP — Batalhas · Jogadores Online · Histórico |
| `window.guild` | falta | 204 | guilda, com Dailies da guild e parcela de XP `guild` (online) | Guild · Fechar · Carregando… |
| `window.market` | falta | 202 | mercado entre jogadores (online) | Adicionar · Nenhum jogador ignorado. · Ignorar jogador (bloqueia ofertas dele) |
| `rules` | falta | 184 | regras do servidor e termos (conta) | Regras do Servidor · Voltar · Documentos Disponíveis |
| `window.liveStore` | falta | 147 | loja de diamantes (conta) | Fechar · Loja · Início |
| `hud.account` | falta | 84 | conta (login, senha, privacidade): fora do jogo offline | Data de nascimento · Cancelar · Aceitar e continuar |
| `auth` | falta | 57 | login e cadastro: o jogo offline não tem conta | Autenticando… · Falha ao autenticar com o Google. · ACESSE NOSSO DISCORD |
| `window.streamBonus` | falta | 48 | bônus de live (online) | Bônus {{platform}} · Fechar · Carregando… |
| `window.vip` | falta | 38 | no original é a lista de amigos e mensagens (online); a chave VIP fica nas Configurações | Adicionar amigo · Adicionar por nome… · Nenhuma mensagem ainda. Diga oi! 👋 |
| `window.clans` | falta | 37 | clãs (online) | Trocar (Rank {{rank}}) · 💎{{price}} · Fechar · Confirmar filiação |
| `window.trade` | falta | 36 | troca entre jogadores (online) | Troca com {{name}} · Fechar · Sua oferta |
| `window.rankings` | falta | 35 | rankings (online) | Fechar · Voltar · — fim do ranking — |
| `hud.chat` | falta | 30 | chat (online) | ⬇ Voltar ao fim · Guild · Dúvidas |
| `window.referral` | falta | 24 | indicação de amigos (online/conta) | Código: · Confirmar · ✓ Copiado |
| `window.discord` | falta | 21 | ligação com o Discord (online/conta) | ✅ Conectado · Não conectado · Cancelar |
| `window.emailGate` | falta | 16 | confirmação de e-mail (conta) | Confirme seu email para usar o Mercado · Seu email: · Enviar email de verificação |
| `passwordGate` | falta | 12 | senha de acesso (conta) | ‹ Sair (trocar conta) · Carregando… · DEFINA SUA SENHA |
| `namelock` | falta | 11 | trava de nome (conta) | ‹ Sair (trocar conta) · Carregando… · Novo nome do treinador |
| `hud.chatLinks` | falta | 10 | links no chat (online) | Pokébola · Energia · Cura |
| `window.tradeHub` | falta | 10 | central de trocas (online) | Troca com Jogador · Nome do jogador · Digite o nome exato |
| `hud.gymAnnounce` | falta | 6 | anúncio global de novo líder de ginásio (online) | NOVO LÍDER DE GINÁSIO · derrotou · e assumiu a liderança do |
| `window.news` | falta | 4 | notícias (online) | Novidades · Para mais detalhes acesse · Novo Patch Note postado |
| `hud.promo` | falta | 3 | promoções (online) | Fechar · Ver o Passe de Batalha |
| `pokepedia` | parcial | 500 | painel_pokepedia.gd (catálogo do P04); faltam os guias da Pokepedia do original | Held Items · Slot {{slot}} · Como funcionam |
| `shop` | parcial | 277 | painel_loja.gd (loja do Mark); falta a loja de diamantes | Promoção encerrada · termina em {{left}} · Promoção de lançamento |
| `modal` | parcial | 165 | confirmações de evolução, loja e Orre; faltam as outras | Volta pro Lv.1 · Fechar · Aceitar |
| `hud.world` | parcial | 155 | cidade e hunt com NPCs por clique; faltam vários avisos e ações de NPC | Combate · Pesca · Level Up |
| `window.inventory` | parcial | 140 | painel_inventario.gd (ciclo 2) e ⚙ → Usar itens: Rare Candy, berries, TMs (TM Researcher), held items (Held Machine, equipar) — ciclo 6 | Eficiência ×{{rate}} · Expira em {{left}} · Captura garantida |
| `hud.config` | parcial | 67 | ⚙ na cidade: VIP, Streak, Diárias, Itens, Metas, Tutorial, tamanho da interface e tela cheia (ciclo 2); faltam som e zoom da hunt | Efeitos de ambiente · Sombras · Notificações de batalha |
| `window.pokedex` | parcial | 49 | painel_pokedex.gd (ciclo 2): busca, capturado/não capturado, tipo, detalhe com abates, evolução e stats; falta o Bônus de Captura +25% XP (número de abates e XP são do servidor) | Todos os tipos · Voltar · Bônus disponível |
| `window.pokeTooltip` | feito | 26 | cartão do Pokémon com TMs, held e Ditto (ciclo 8) | Pokémon · Ativo · 🎭 Addon |
| `misc` | parcial | 18 | textos soltos | Inseto · Sombrio · Dragão |
| `window.pokeball` | parcial | 14 | escolha da bola no painel Capture da hunt | Pokébola · +{{count}}× {{name}} · Loja de Diamantes |
| `window.gifts` | parcial | 6 | o Daily Gift entrega direto na BAG; falta o Gift Center | 🎁 Gift Center · Fechar · Resgatar |
| `hud.shinyAnnounce` | parcial | 13 | avisos_hud.gd (ciclo 2): shiny que apareceu e shiny capturado; o anúncio global entre jogadores é online | SHINY · capturou um · ANÚNCIO GLOBAL · TIER {{tier}} |
| `packs` | parcial | 10 | Poke Card Pack abre no álbum (ciclo 3); a loja de pacotes é de diamantes (online) | Como você quer pagar? · PIX · QR Code · cai na hora |
| `window.bosses` | feito | 116 | painel_bosses.gd (ciclo 3): 87 bosses (A), entrada por token, Auto Boss, Altar com Shiny Card, histórico; HP, drops e custos classe 3 | Abandonar · Sacrifique um · Capturando… |
| `window.pokeCardAlbum` | feito | 69 | painel_album.gd (ciclo 3): 430 cartas (A), abrir Poke Card Pack, filtros por set e posse; pesos e drop do pacote classe 3 | Poke Card Album · Fechar · Voltar |
| `window.map` | feito | 51 | mapa_mundi.gd: 4 regiões, níveis, aviso de Orre (C) | — por nome — · Fechar · 🗺️ Editor de Marcadores |
| `window.depot` | feito | 44 | painel_depot.gd + sim/servico_cidade.gd (regras A da G4) | Todas as categorias · 📦 Tudo guardado. · Todos os tipos |
| `window.streak` | feito | 28 | painel_streak.gd + sim/servico_jogador.gd (A, G7) | Pontos disponíveis · Fechar · Bônus: {{from}}% → {{to}}% |
| `hud.boost` | feito | 27 | avisos_hud.gd (ciclo 2): barra com shinylock, boosts e Tipo do Dia, efeito no tooltip | Aumenta muito a chance de aparecer shiny · Dobra a chance de captura · +{{pct}}% de chance de captura |
| `window.team` | feito | 27 | painel_time.gd, troca de líder com 5 s | Ativo · Ativo — é o Pokémon que caça · Equipado |
| `hud.killCard` | feito | 25 | cartoes_derrota.gd (um por vez, até 30 por instância: regra E) | derrotado · {{count}} abate · {{count}} abates |
| `window.autoHelper` | feito | 25 | painel_auto_helper.gd (poção, limite, Auto-Catch, bola) | Auto-Catch · Auto-Catch Shiny ·  — clique pra assinar. |
| `window.huntAnalyzer` | feito | 23 | painel_analyzer.gd (ciclo 2): tempo, XP/h, abates/h, capturas, loot e supply a preço de NPC, saldo, drops, zerar | Saldo (Loot + Capturas − Supply) · Capturados · Capturados (+${{gold}}) |
| `window.captureLog` | feito | 20 | painel_log_capturas.gd (ciclo 2): últimas 100, abas normal/shiny, 1ª captura, limpar | 🗑 Limpar histórico · Confirmar? Apaga TUDO · Fechar |
| `window.usedBalls` | feito | 17 | painel_bolas_usadas.gd (ciclo 2): tentativas desde a última captura, totais, ouro gasto, aba shiny, busca | Você já capturou · Fechar · Nome |
| `window.dailyGift` | feito | 15 | painel_diarias.gd (28 prêmios gravados) | Calendário concluído · 🎁 Resgatar · Resgatar |
| `createCharacter` | feito | 14 | painel_novo_jogo.gd: nome, inicial e (ciclo 3) visual — Menino/Menina, outfit, cores | ‹ Voltar (trocar conta) · ✓ Escolhido · CRIANDO… |
| `window.offline` | feito | 14 | painel_soneca.gd: Modo Soneca e coleta (A, G6) | Turbinar pra · (100% · {{cost}}💎) · (máx. 24h) |
| `window.outfit` | feito | 14 | seletor_visual.gd/painel_visual.gd (ciclo 3): outfit e 4 cores pelo renderizador do cliente, na cidade e na hunt | ✅ Outfit aplicada! · Aplicar · Adquirir |
| `window.quests` | feito | 10 | painel_diarias.gd: 124 tarefas de NPC | Capturado · Resgatar · Resgatada |
| `hud.party` | feito | 9 | painel do time na HUD da hunt | Evoluir · ⬆ Evoluir · Evoluir em {{dest}} |
| `window.allPokes` | feito | 8 | painel_todos_shinys.gd (ciclo 2): as 190 formas shiny do cliente por tier, busca e as já capturadas | Nenhum shiny encontrado. · Falha ao carregar. · Carregando… |
| `window.questsMenu` | feito | 8 | painel_diarias.gd (abas) | Daily Catch · Missões diárias de captura. · Daily Kill |
| `hud.levelUp` | feito | 7 | avisos_hud.gd (ciclo 2): aviso de subida do treinador e do Pokémon | Seu Pokémon · Sua habilidade de Pesca subiu! · Nv. {{level}} |
| `hud.combat` | feito | 6 | números de dano e placas (render/vista_hunt.gd) | Modo carta · EXP · Procurando Pokémon selvagem… |
| `hud.menu` | feito | 5 | menu_superior_original.gd | Minha Conta · Nosso Discord · Sair da Conta |
| `common` | feito | 4 | textos comuns (OK, cancelar…) | Idioma · Carregando… · Carregando mundo… |
| `play` | feito | 2 | tela de jogo | Carregando… · Carregando mundo… |
| `hud.slideNotice` | feito | 1 | avisos_hud.gd (ciclo 2): aviso deslizante, um por vez, com ✕ | Fechar |
| `window.tutorial` | feito | 59 | painel_tutorial.gd (ciclo 2): passos e textos do cliente; Mercado (online), lançar bola (captura manual adiada) e Inventário ficam fora | CLIQUE PARA CONTINUAR · 👆 Agora <b>clique</b> em {{npcName}}! · o Depot |
| `window.profile` | feito | 51 | painel_perfil.gd (ciclo 2): nível, XP, ouro, VIP, tempo em caça, capturas, abates, Pokédex; clã, PvP e rankings são online | Perfil · ← Voltar ao Perfil · Log de Capturas |
| `window.gyms` | feito | 17 | painel_ginasios.gd (ciclo 3): 18 ginásios, luta automática time × time, insígnia de 48 h com +1% XP/drop, Campeão; times e luta classe 3; disputa de liderança e rateio são online | Ginásios · Ginásio · Recompensas do Ginásio |
| `hud.captureBar` | feito | 14 | painel Capture da hunt (estoque de bolas, contador) | Comprar · 🎉 {{species}} capturado com {{ball}}! · 💨 {{species}} escapou! |

A lista completa de textos por grupo (chave e texto) sai em `saida_testes/inventario_textos.md` (fora do git; gerado pelos dois comandos do cabeçalho do script).


## Depois do ciclo 7: o que falta offline (para o ciclo 8 e a versão 1.0)

Dos grupos que faltam, os que dependem de outros jogadores, de conta ou de loja de diamantes ficam para a versão online:
PvP, guilda, mercado, clãs, troca e central de trocas, rankings, chat, links do chat, amigos (window.vip), lives,
indicação, Discord, loja de diamantes, passe de temporada, regras/termos, conta, login, e-mail, senha, trava de nome,
anúncio global de ginásio, notícias, promoções e a página inicial do site.

**Ainda faltam offline (sem servidor):**

| Grupo | O que falta |
| --- | --- |
| `window.fishing`, `window.fishingWave` | pesca (habilidade por nível, faixas, onda); os números são do servidor (classe 3) |
| `window.ditto` | cópia com Ditto |

**Parciais que o ciclo 8 pode fechar (polimento):** telas próprias de breeding (escolher os pais), Golden Stars (escolha
direta, trocar bônus/Pokémon), profissões (tela completa), talentos e crafting (painéis próprios); cartão do Pokémon com
TMs e held (`window.pokeTooltip`); guias da Pokepedia; avisos e ações de NPC que faltam (`hud.world`, `modal`); Gift
Center (`window.gifts`); escolha de bola (`window.pokeball`).

## Depois do ciclo 8 (versão 1.0 offline)

Pesca e Ditto feitos; breeding, Golden Stars, profissões, talentos, crafting e o cartão do Pokémon passam a feitos. **Offline
não falta nenhum grupo inteiro.** Os parciais que ficam são detalhes ou dependem do servidor: guias da Pokepedia, loja de
diamantes (`shop`), avisos e ações de NPC (`hud.world`, `modal`), Gift Center (o prêmio vai direto para a BAG, E), escolha
de bola com itens de diamante (`window.pokeball`), a onda de pesca abstrata, os anúncios globais e os pacotes da loja.
