#!/usr/bin/env python3
"""Inventário do cliente original → INVENTARIO_CLIENTE.md (backlog do ciclo 2).

Fonte: os textos do cliente (C, chunk 3vooh2axx98am.js, extraídos por `extrair_textos.js`): cada janela (`window.*`),
parte da HUD (`hud.*`) e grupo de topo (cadastro, loja, Pokepedia, modais…), com o número de textos (botões, títulos,
avisos) e alguns exemplos. O status no nosso jogo é avaliado à mão em STATUS (feito / parcial / falta), com uma linha do
que existe ou falta. "online" marca o que depende de outros jogadores ou de conta (fica fora do jogo offline até a
versão online, mas entra no backlog).

Uso: node ferramentas/inventario/extrair_textos.js poke-local/public/_next/static/chunks/3vooh2axx98am.js saida_testes/textos_cliente.json
     python -I ferramentas/inventario/gerar_inventario.py saida_testes/textos_cliente.json
"""
import json
import os
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

# (status, onde/como no nosso jogo ou o que falta). Avaliação do projeto (19/11).
STATUS = {
    "window.autoHelper": ("feito", "painel_auto_helper.gd (poção, limite, Auto-Catch, bola)"),
    "window.depot": ("feito", "painel_depot.gd + sim/servico_cidade.gd (regras A da G4)"),
    "window.map": ("feito", "mapa_mundi.gd: 4 regiões, níveis, aviso de Orre (C)"),
    "window.team": ("feito", "painel_time.gd, troca de líder com 5 s"),
    "window.streak": ("feito", "painel_streak.gd + sim/servico_jogador.gd (A, G7)"),
    "window.dailyGift": ("feito", "painel_diarias.gd (28 prêmios gravados)"),
    "window.quests": ("feito", "painel_diarias.gd: 124 tarefas de NPC"),
    "window.questsMenu": ("feito", "painel_diarias.gd (abas)"),
    "window.offline": ("feito", "painel_soneca.gd: Modo Soneca e coleta (A, G6)"),
    "window.allPokes": ("feito", "painel_todos_shinys.gd (ciclo 2): as 190 formas shiny do cliente por tier, busca e as já capturadas"),
    "window.inventory": ("parcial", "painel_inventario.gd (ciclo 2): abas por categoria, quantidade, preço de NPC, Usar para Rare Candy e berries; held, TMs, addons e conversões sem uso (lote 3 congelado)"),
    "window.pokeTooltip": ("parcial", "cartão do Pokémon na HUD; faltam campos (TMs, held item, golpes com cooldown)"),
    "window.pokeball": ("parcial", "escolha da bola no painel Capture da hunt"),
    "window.pokedex": ("parcial", "painel_pokedex.gd (ciclo 2): busca, capturado/não capturado, tipo, detalhe com abates, evolução e stats; falta o Bônus de Captura +25% XP (número de abates e XP são do servidor)"),
    "window.vip": ("falta", "no original é a lista de amigos e mensagens (online); a chave VIP fica nas Configurações"),
    "window.gifts": ("parcial", "o Daily Gift entrega direto na BAG; falta o Gift Center"),
    "window.profile": ("feito", "painel_perfil.gd (ciclo 2): nível, XP, ouro, VIP, tempo em caça, capturas, abates, Pokédex; clã, PvP e rankings são online"),
    "window.usedBalls": ("feito", "painel_bolas_usadas.gd (ciclo 2): tentativas desde a última captura, totais, ouro gasto, aba shiny, busca"),
    "window.captureLog": ("feito", "painel_log_capturas.gd (ciclo 2): últimas 100, abas normal/shiny, 1ª captura, limpar"),
    "window.huntAnalyzer": ("feito", "painel_analyzer.gd (ciclo 2): tempo, XP/h, abates/h, capturas, loot e supply a preço de NPC, saldo, drops, zerar"),
    "window.gyms": ("feito", "painel_ginasios.gd (ciclo 3): 18 ginásios, luta automática time × time, insígnia de 48 h com +1% XP/drop, Campeão; times e luta classe 3; disputa de liderança e rateio são online"),
    "window.bosses": ("feito", "painel_bosses.gd (ciclo 3): 87 bosses (A), entrada por token, Auto Boss, Altar com Shiny Card, histórico; HP, drops e custos classe 3"),
    "window.professions": ("falta", "profissões (pesca, botânico, pesquisador…)"),
    "window.breeding": ("falta", "breeding"),
    "window.ditto": ("falta", "cópia com Ditto"),
    "window.craft": ("falta", "craft"),
    "window.talents": ("falta", "talentos"),
    "window.goldenStars": ("falta", "Golden Stars"),
    "window.pokeCardAlbum": ("feito", "painel_album.gd (ciclo 3): 430 cartas (A), abrir Poke Card Pack, filtros por set e posse; pesos e drop do pacote classe 3"),
    "window.fishing": ("falta", "pesca"),
    "window.fishingWave": ("falta", "onda de pesca"),
    "window.outfit": ("feito", "seletor_visual.gd/painel_visual.gd (ciclo 3): outfit e 4 cores pelo renderizador do cliente, na cidade e na hunt"),
    "window.tutorial": ("feito", "painel_tutorial.gd (ciclo 2): passos e textos do cliente; Mercado (online), lançar bola (captura manual adiada) e Inventário ficam fora"),
    "window.seasonPass": ("falta", "passe de temporada"),
    "window.market": ("falta", "mercado entre jogadores (online)"),
    "window.trade": ("falta", "troca entre jogadores (online)"),
    "window.tradeHub": ("falta", "central de trocas (online)"),
    "window.pvp": ("falta", "PvP (online)"),
    "window.clans": ("falta", "clãs (online)"),
    "window.guild": ("falta", "guilda, com Dailies da guild e parcela de XP `guild` (online)"),
    "window.rankings": ("falta", "rankings (online)"),
    "window.referral": ("falta", "indicação de amigos (online/conta)"),
    "window.discord": ("falta", "ligação com o Discord (online/conta)"),
    "window.emailGate": ("falta", "confirmação de e-mail (conta)"),
    "window.news": ("falta", "notícias (online)"),
    "window.streamBonus": ("falta", "bônus de live (online)"),
    "window.liveStore": ("falta", "loja de diamantes (conta)"),
    "hud.killCard": ("feito", "cartoes_derrota.gd (um por vez, até 30 por instância: regra E)"),
    "hud.captureBar": ("feito", "painel Capture da hunt (estoque de bolas, contador)"),
    "hud.combat": ("feito", "números de dano e placas (render/vista_hunt.gd)"),
    "hud.menu": ("feito", "menu_superior_original.gd"),
    "hud.party": ("feito", "painel do time na HUD da hunt"),
    "hud.levelUp": ("feito", "avisos_hud.gd (ciclo 2): aviso de subida do treinador e do Pokémon"),
    "hud.boost": ("feito", "avisos_hud.gd (ciclo 2): barra com shinylock, boosts e Tipo do Dia, efeito no tooltip"),
    "hud.config": ("parcial", "⚙ na cidade: VIP, Streak, Diárias, Itens, Metas, Tutorial, tamanho da interface e tela cheia (ciclo 2); faltam som e zoom da hunt"),
    "hud.world": ("parcial", "cidade e hunt com NPCs por clique; faltam vários avisos e ações de NPC"),
    "hud.slideNotice": ("feito", "avisos_hud.gd (ciclo 2): aviso deslizante, um por vez, com ✕"),
    "hud.shinyAnnounce": ("parcial", "avisos_hud.gd (ciclo 2): shiny que apareceu e shiny capturado; o anúncio global entre jogadores é online"),
    "hud.gymAnnounce": ("falta", "anúncio global de novo líder de ginásio (online)"),
    "hud.account": ("falta", "conta (login, senha, privacidade): fora do jogo offline"),
    "hud.chat": ("falta", "chat (online)"),
    "hud.chatLinks": ("falta", "links no chat (online)"),
    "hud.promo": ("falta", "promoções (online)"),
    "createCharacter": ("feito", "painel_novo_jogo.gd: nome, inicial e (ciclo 3) visual — Menino/Menina, outfit, cores"),
    "pokepedia": ("parcial", "painel_pokepedia.gd (catálogo do P04); faltam os guias da Pokepedia do original"),
    "shop": ("parcial", "painel_loja.gd (loja do Mark); falta a loja de diamantes"),
    "modal": ("parcial", "confirmações de evolução, loja e Orre; faltam as outras"),
    "misc": ("parcial", "textos soltos"),
    "common": ("feito", "textos comuns (OK, cancelar…)"),
    "play": ("feito", "tela de jogo"),
    "packs": ("parcial", "Poke Card Pack abre no álbum (ciclo 3); a loja de pacotes é de diamantes (online)"),
    "rules": ("falta", "regras do servidor e termos (conta)"),
    "auth": ("falta", "login e cadastro: o jogo offline não tem conta"),
    "landing": ("falta", "página inicial do site (fora do jogo)"),
    "passwordGate": ("falta", "senha de acesso (conta)"),
    "namelock": ("falta", "trava de nome (conta)"),
}


def folhas(o, pref=""):
    if isinstance(o, dict):
        for k, v in o.items():
            yield from folhas(v, f"{pref}.{k}" if pref else k)
    else:
        yield pref, o


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    pt = d.get("pt") or next(iter(d.values()))
    grupos = []
    for k, v in pt.items():
        if k in ("window", "hud") and isinstance(v, dict):
            for k2, v2 in v.items():
                grupos.append((f"{k}.{k2}", v2))
        else:
            grupos.append((k, v))
    linhas = []
    cont = {"feito": 0, "parcial": 0, "falta": 0}
    textos = {"feito": 0, "parcial": 0, "falta": 0}
    for nome, v in grupos:
        fs = list(folhas(v))
        st, nota = STATUS.get(nome, ("falta", "sem avaliação"))
        cont[st] += 1
        textos[st] += len(fs)
        ex = [str(t) for _, t in fs if isinstance(t, str) and 3 <= len(t) <= 40][:3]
        linhas.append((nome, st, len(fs), nota, ex))
    ordem = {"falta": 0, "parcial": 1, "feito": 2}
    linhas.sort(key=lambda x: (ordem[x[1]], "online" in x[3] or "conta" in x[3], -x[2]))
    total = len(grupos)
    md = ["# Inventário do cliente original (backlog do ciclo 2)", "",
          f"Gerado por `ferramentas/inventario/gerar_inventario.py` a partir dos textos do cliente original (C: {sum(textos.values())} "
          f"textos em pt-BR, chunk `3vooh2axx98am.js`). Cada linha é uma janela, uma parte da HUD ou um grupo de telas, com o "
          "número de textos (botões, títulos, avisos) e exemplos. Status no nosso jogo avaliado em 19/11.", "",
          f"**{total} grupos: {cont['feito']} feitos, {cont['parcial']} parciais, {cont['falta']} faltando** "
          f"({textos['feito']} / {textos['parcial']} / {textos['falta']} textos). Dos que faltam, "
          f"{sum(1 for x in linhas if x[1] == 'falta' and ('online' in x[3] or 'conta' in x[3] or 'fora' in x[3]))} dependem de outros "
          "jogadores ou de conta (ficam para a versão online).", "",
          "| Grupo | Status | Textos | No nosso jogo / o que falta | Exemplos |", "| --- | --- | --- | --- | --- |"]
    for nome, st, n, nota, ex in linhas:
        md.append(f"| `{nome}` | {st} | {n} | {nota} | {' · '.join(ex).replace('|', '/')} |")
    md += ["", "A lista completa de textos por grupo (chave e texto) sai em `saida_testes/inventario_textos.md` (fora do git; gerado pelos dois comandos do cabeçalho do script)."]
    open(os.path.join(RAIZ, "INVENTARIO_CLIENTE.md"), "w", encoding="utf-8", newline="\n").write("\n".join(md) + "\n")
    det = ["# Textos do cliente original por grupo (pt-BR)", ""]
    for nome, v in grupos:
        det += [f"## `{nome}`", ""]
        det += [f"- `{k}`: {str(t)[:160]}" for k, t in folhas(v)]
        det.append("")
    open(os.path.join(RAIZ, "saida_testes", "inventario_textos.md"), "w", encoding="utf-8", newline="\n").write("\n".join(det) + "\n")
    print("\n".join(md[:8]))


if __name__ == "__main__":
    main()
