# Inventário do cliente original (backlog do ciclo 2)

Gerado por `ferramentas/inventario/gerar_inventario.py` a partir dos textos do cliente original (C: 4187 textos em pt-BR, chunk `3vooh2axx98am.js`). Cada linha é uma janela, uma parte da HUD ou um grupo de telas, com o número de textos (botões, títulos, avisos) e exemplos. Status no nosso jogo avaliado em 19/11.

**76 grupos: 25 feitos, 13 parciais, 38 faltando** (500 / 1444 / 2243 textos). Dos que faltam, 23 dependem de outros jogadores ou de conta (ficam para a versão online).

| Grupo | Status | Textos | No nosso jogo / o que falta | Exemplos |
| --- | --- | --- | --- | --- |
| `window.breeding` | falta | 116 | breeding | Centro de Breeding · Par reprodutor · Selecione no box |
| `window.bosses` | falta | 116 | catálogo na sim, sem luta nem tela | Abandonar · Sacrifique um · Capturando… |
| `window.goldenStars` | falta | 116 | Golden Stars | Poke Slot Machine · Trocar bônus · Trocar Pokémon |
| `window.seasonPass` | falta | 102 | passe de temporada | Acelerar · Comprado · Passe Premium · {{price}} |
| `landing` | falta | 84 | página inicial do site (fora do jogo) | Direto no navegador · Também no celular · Sem download |
| `window.professions` | falta | 83 | profissões (pesca, botânico, pesquisador…) | Profissões · Fechar · Em breve |
| `window.pokeCardAlbum` | falta | 69 | álbum de Pokécards | Poke Card Album · Fechar · Voltar |
| `window.talents` | falta | 27 | talentos | Talentos do Botânico · Berry que protege do tipo {{type}} · Berry que protege dos golpes tipo Neutro |
| `window.ditto` | falta | 22 | cópia com Ditto | Espécies disponíveis · Limpar filtros · {{shown}}/{{total}} |
| `window.craft` | falta | 19 | craft | 🌿 {{n}} Fresh Herbs · 🍂 {{n}} Wild Herbs · Painel de Crafts |
| `window.gyms` | falta | 17 | insígnias existem na sim (sim/servico_ginasios.gd), sem tela nem luta | Ginásios · Ginásio · Recompensas do Ginásio |
| `window.fishing` | falta | 15 | pesca | Fechar · ⏳ Aguarde {{seconds}}s · Nv {{min}}–{{max}} |
| `window.outfit` | falta | 14 | escolha do visual do treinador | ✅ Outfit aplicada! · Aplicar · Adquirir |
| `packs` | falta | 10 | pacotes de cartas | Como você quer pagar? · PIX · QR Code · cai na hora |
| `hud.gymAnnounce` | falta | 6 | anúncio de ginásio | NOVO LÍDER DE GINÁSIO · derrotou · e assumiu a liderança do |
| `window.fishingWave` | falta | 2 | onda de pesca | Pescando… · {{value}}s |
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
| `window.news` | falta | 4 | notícias (online) | Novidades · Para mais detalhes acesse · Novo Patch Note postado |
| `hud.promo` | falta | 3 | promoções (online) | Fechar · Ver o Passe de Batalha |
| `pokepedia` | parcial | 500 | painel_pokepedia.gd (catálogo do P04); faltam os guias da Pokepedia do original | Held Items · Slot {{slot}} · Como funcionam |
| `shop` | parcial | 277 | painel_loja.gd (loja do Mark); falta a loja de diamantes | Promoção encerrada · termina em {{left}} · Promoção de lançamento |
| `modal` | parcial | 165 | confirmações de evolução, loja e Orre; faltam as outras | Volta pro Lv.1 · Fechar · Aceitar |
| `hud.world` | parcial | 155 | cidade e hunt com NPCs por clique; faltam vários avisos e ações de NPC | Combate · Pesca · Level Up |
| `window.inventory` | parcial | 140 | painel_inventario.gd (ciclo 2): abas por categoria, quantidade, preço de NPC, Usar para Rare Candy e berries; held, TMs, addons e conversões sem uso (lote 3 congelado) | Eficiência ×{{rate}} · Expira em {{left}} · Captura garantida |
| `hud.config` | parcial | 67 | ⚙ na cidade: VIP, Streak, Diárias, Itens, Metas, Tutorial, tamanho da interface e tela cheia (ciclo 2); faltam som e zoom da hunt | Efeitos de ambiente · Sombras · Notificações de batalha |
| `window.pokedex` | parcial | 49 | painel_pokedex.gd (ciclo 2): busca, capturado/não capturado, tipo, detalhe com abates, evolução e stats; falta o Bônus de Captura +25% XP (número de abates e XP são do servidor) | Todos os tipos · Voltar · Bônus disponível |
| `window.pokeTooltip` | parcial | 26 | cartão do Pokémon na HUD; faltam campos (TMs, held item, golpes com cooldown) | Pokémon · Ativo · 🎭 Addon |
| `misc` | parcial | 18 | textos soltos | Inseto · Sombrio · Dragão |
| `createCharacter` | parcial | 14 | painel_novo_jogo.gd: nome e inicial; faltam o visual e o gênero | ‹ Voltar (trocar conta) · ✓ Escolhido · CRIANDO… |
| `window.pokeball` | parcial | 14 | escolha da bola no painel Capture da hunt | Pokébola · +{{count}}× {{name}} · Loja de Diamantes |
| `window.gifts` | parcial | 6 | o Daily Gift entrega direto na BAG; falta o Gift Center | 🎁 Gift Center · Fechar · Resgatar |
| `hud.shinyAnnounce` | parcial | 13 | avisos_hud.gd (ciclo 2): shiny que apareceu e shiny capturado; o anúncio global entre jogadores é online | SHINY · capturou um · ANÚNCIO GLOBAL · TIER {{tier}} |
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
| `window.offline` | feito | 14 | painel_soneca.gd: Modo Soneca e coleta (A, G6) | Turbinar pra · (100% · {{cost}}💎) · (máx. 24h) |
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
| `hud.captureBar` | feito | 14 | painel Capture da hunt (estoque de bolas, contador) | Comprar · 🎉 {{species}} capturado com {{ball}}! · 💨 {{species}} escapou! |

A lista completa de textos por grupo (chave e texto) sai em `saida_testes/inventario_textos.md` (fora do git; gerado pelos dois comandos do cabeçalho do script).
