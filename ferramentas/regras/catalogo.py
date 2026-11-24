#!/usr/bin/env python3
"""Game Master, passo 2: catálogo de TODAS as regras e parâmetros (dados/regras/catalogo.json) e o REGRAS.md.

Entrada: saida_testes/regras_valores.json (ferramentas/regras/exportar_valores.gd: valor em execução, tipo e literal de
cada parâmetro), os comentários do código (sim/regras.gd e o `p` de cada serviço), os motivos de dados/balanceamento.json
(enquanto existir) e as tabelas de regras do PLACAR_ESCOPO.md (fórmulas e regras que não são parâmetro).
Saída: dados/regras/catalogo.json (lido pelo gerador dos Resources e pelo dock do Game Master) e REGRAS.md.
Uso: python -I ferramentas/regras/catalogo.py [valores.json]
"""
import json
import os
import re
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

# fonte → (arquivo do código, nome do Resource para as chaves da fonte; "sim" é dividido por sistema abaixo)
FONTES = {
    "sim": ("sim/regras.gd", None), "cidade": ("sim/servico_cidade.gd", "RegrasEconomia"), "diarias": ("sim/servico_diarias.gd", "RegrasDiarias"),
    "jogador": ("sim/servico_jogador.gd", "RegrasJogador"), "ginasios": ("sim/servico_ginasios.gd", "RegrasGinasios"),
    "bosses": ("sim/servico_bosses.gd", "RegrasBosses"), "cards": ("sim/servico_cards.gd", "RegrasCards"), "itens": ("sim/servico_itens.gd", "RegrasItens"),
    "profissoes": ("sim/servico_profissoes.gd", "RegrasProfissoes"), "breeding": ("sim/servico_breeding.gd", "RegrasBreeding"),
    "golden_stars": ("sim/servico_golden_stars.gd", "RegrasGoldenStars"), "pesca": ("sim/servico_pesca.gd", "RegrasPesca"),
    "ditto": ("sim/servico_ditto.gd", "RegrasDitto"), "metas": ("sim/metas.gd", "RegrasInterface"),
    "jogo_novo": ("sim/servico_novo_jogo.gd", "RegrasJogoNovo"), "apresentacao": ("sim/regras_apresentacao.gd", "RegrasInterface"),
}
# Resource → sistema (o nome da seção do REGRAS.md)
SISTEMA = {
    "RegrasCombate": "combate e dano", "RegrasMovimento": "movimento", "RegrasXP": "XP e níveis", "RegrasCaptura": "captura e shiny",
    "RegrasLoot": "loot e economia", "RegrasSessao": "penalidade e sessão", "RegrasEventos": "Streak, boosts e Tipo do Dia",
    "RegrasVIP": "VIP", "RegrasEconomia": "loja, Nurse Joy, depot e evolução", "RegrasDiarias": "diárias e tarefas",
    "RegrasJogador": "soneca, Streak e sessão", "RegrasGinasios": "ginásios", "RegrasBosses": "bosses", "RegrasCards": "cards",
    "RegrasItens": "TMs, held items, Rare Candy e berries", "RegrasProfissoes": "profissões, mentor e crafting", "RegrasBreeding": "breeding",
    "RegrasGoldenStars": "Golden Stars", "RegrasPesca": "pesca", "RegrasDitto": "Ditto", "RegrasInterface": "interface e metas",
    "RegrasJogoNovo": "começo de jogo",
}
# seção do Balanceamento → Resources (a "combate" é a união dos da sim)
SECOES = {"combate": ["RegrasCombate", "RegrasMovimento", "RegrasXP", "RegrasCaptura", "RegrasLoot", "RegrasSessao", "RegrasEventos", "RegrasVIP"]}
for _f, (_a, _r) in FONTES.items():
    if _r:
        SECOES.setdefault(_f, []).append(_r)


def recurso_sim(k):
    if k.startswith(("captura_", "shiny_", "chance_shiny")) or k in ("boost_captura_bonus", "pendente_vida_ms"):
        return "RegrasCaptura"
    if k.startswith(("alvo_", "desempate_", "visao_", "passo_extra", "mob_contorna", "mob_espera", "inicio_")) or k in (
            "caminho_margem", "fator_diagonal_passo", "hero_step_ms", "mob_step_ms", "trainer_step_ms"):
        return "RegrasMovimento"
    if k.startswith("xp_regiao"):
        return "RegrasXP"
    if k in ("vip_fracao",):
        return "RegrasVIP"
    if k.startswith(("penalidade_",)):
        return "RegrasSessao"
    if k.startswith(("tipo_do_dia", "streak_", "insignia_")):
        return "RegrasEventos"
    if k in ("card_chance_shiny", "pack_chance_abate", "pedra_garantia_fator"):
        return "RegrasLoot"
    return "RegrasCombate"


# o valor no jogo original quando o nosso é diferente (o resto: igual ou sem dado)
ORIGINAL = {
    ("sim", "xp_regiao"): "sem multiplicador por região (×1 em toda parte)",
    ("sim", "xp_regiao_piso"): "sem piso (a base da espécie vale)",
    ("sim", "visao_meia_altura"): "13 (A: borda da perseguição 13 × 13)",
    ("cidade", "casas_liberadas"): "a casa (−2,−4) bloqueada pela peça 8274 (A/C)",
    ("sim", "piso_ataque_aliado"): "não medido (F): o dano no nível 1 pede ~3",
    ("ditto", "nivel_recebe"): "o Ditto vem da loja de diamantes (online)",
}


# Constantes que o jogo nunca deve mudar: ficam fora dos Resources (não aparecem no Game Master), com o motivo.
FIXOS = {
    ("sim", "tick_ms"): "protocolo do servidor: tick de 200 ms (A); o cliente interpola por ele e o `seq` conta ticks",
    ("sim", "ticks_por_field"): "protocolo: um `field` a cada 2 ticks (A); muda o que o cliente recebe",
}
FIXOS_CODIGO = [
    ("Tabela de tipos (efetividade bruta)", "sim/regras.gd TABELA_TIPOS", "B/C: a tabela dos jogos; muda a identidade do jogo"),
    ("Atributos (hp, atk, def, spAtk, spDef, speed)", "sim/regras.gd CHAVES_STATS", "C: o formato do Pokémon no protocolo"),
    ("Faixas e pesos do rollQuality", "sim/regras.gd FAIXAS_QUALIDADE", "C: porte exato do cliente; é classe 1"),
    ("Curva de XP por nível (50/3 × (L³ − 6L² + 17L − 12))", "sim/regras.gd xp_total_para_nivel", "A/B: classe 1, conferida em 19 níveis"),
    ("Fórmula de stat e de Power", "sim/regras.gd calcular_stats/power", "B/C: classe 1"),
    ("Chance de loot em 1/100.000", "sim/simulacao_hunt.gd _rolar_loot", "A: formato do creatures.json"),
]


def comentarios(arquivo):
    """{chave: comentário}: o da própria linha (`"chave": valor,  # …`) ou o bloco de comentário logo acima da chave."""
    r = {}
    caminho = os.path.join(RAIZ, arquivo)
    if not os.path.exists(caminho):
        return r
    bloco = []
    for linha in open(caminho, encoding="utf-8"):
        st = linha.strip()
        if st.startswith("#") and not st.startswith("##"):
            bloco.append(st.lstrip("#").strip())
            continue
        m = re.match(r'\s*"([a-z_0-9]+)"\s*:\s*(.*)$', linha)
        if m and m.group(1) not in r:
            resto = m.group(2)
            i = resto.find("#")
            while i >= 0 and resto[:i].count('"') % 2 == 1:
                i = resto.find("#", i + 1)
            proprio = resto[i + 1:].strip() if i >= 0 else ""
            texto = " ".join(([proprio] if proprio else []) + bloco).strip()
            if texto:
                r[m.group(1)] = texto
        if not st.startswith("#"):
            bloco = []
    return r


# Anotações dos parâmetros de serviço declarados em dicionários de uma linha (origem, descrição), registradas quando cada
# um foi escrito (ver o cabeçalho de cada serviço).
ANOTA = {
    ("profissoes", "captura_pct_rank"): ("C", "bônus de captura direta por rank, cumulativo desde o E (C: até ×1,18 no S)"),
    ("profissoes", "mentor_gap"): ("A", "diferença treinador − Pokémon a partir da qual o mentor vale (A: conta B, gravações livres)"),
    ("profissoes", "mentor_pct_nivel"): ("A", "% da base por nível acima do gap (A: 212 → 6%, 262 → 31%)"),
    ("profissoes", "mentor_teto_rank"): ("E", "teto do mentor por rank (A: 60% observado na conta B; os outros ranks classe 3)"),
    ("profissoes", "req_abates_tipo"): ("E", "abates por tipagem para cada rank (classe 3; C: o requisito existe)"),
    ("profissoes", "req_especies"): ("E", "espécies diferentes capturadas por rank (classe 3; C: o requisito existe)"),
    ("profissoes", "req_craft_pictures"): ("E", "berries criadas (Botânico) ou pictures entregues (Prestígio) por rank (classe 3)"),
    ("profissoes", "erva_chance_abate"): ("E", "chance de Fresh Herbs por abate do Botânico (classe 3; C: arbustos brotam na hunt)"),
    ("profissoes", "erva_wild_fora_kanto"): ("E", "fração de Wild Herbs fora de Kanto (classe 3; C: 🍂 Wild Herbs)"),
    ("profissoes", "foto_chance_shiny"): ("E", "chance da foto do Prestígio num shiny (A: 2 de 5 no c5; classe 3)"),
    ("profissoes", "craft_ervas"): ("E", "Fresh Herbs por berry de tipo (classe 3)"), ("profissoes", "craft_wild"): ("E", "Wild Herbs por berry neutra ou de cura (classe 3)"),
    ("profissoes", "craft_ouro"): ("E", "ouro por berry (classe 3)"), ("profissoes", "craft_s_unidade"): ("E", "segundos por unidade na fila (classe 3; C: unidades uma a uma)"),
    ("profissoes", "craft_tipos_rank"): ("E", "berries de tipo liberadas na árvore por rank (classe 3; C: árvore de talentos)"),
    ("profissoes", "craft_neutra_rank"): ("E", "rank que libera a berry neutra (classe 3)"), ("profissoes", "craft_cura_rank"): ("E", "rank que libera a berry de cura (classe 3)"),
    ("profissoes", "berry_bonus_rank"): ("E", "Toque de Herbalista: % a mais nas berries por rank (classe 3; C: cresce a cada rank)"),
    ("breeding", "delta"): ("C", "Δ de Quality no caminho com feromônio (C: +0,15 a +0,30)"), ("breeding", "delta_livre_div"): ("C", "o caminho livre divide o Δ (C: ~20× menor)"),
    ("breeding", "iv_mais1_pct"): ("C", "pedras em dobro: chance de +1 num IV (C: 5%)"), ("breeding", "quality_max"): ("C", "Quality máxima do filho (C: maior faixa do rollQuality)"),
    ("breeding", "herdar_pct"): ("E", "chance de cada IV copiar o melhor pai (classe 3; C: N% copia, senão re-rola)"),
    ("breeding", "abates_chocar"): ("E", "derrotas nas hunts para o ovo chocar (classe 3; C: chocam com derrotas)"),
    ("breeding", "slots"): ("E", "slots da incubadora (classe 3; mais slots são de diamantes no original)"),
    ("breeding", "pedras_por_ovo"): ("E", "pedras do tipo principal por ovo (classe 3; C: gasta pedras)"), ("breeding", "feromonio_id"): ("E", "item do caminho cheio: Strange Pheromone (A: existe no catálogo)"),
    ("jogador", "dia_virada_utc_s"): ("A", "virada do dia às 03:00 UTC (A)"), ("jogador", "nomes_tipos"): ("A", "nomes dos tipos do Tipo do Dia (A: formato gravado)"),
    ("jogador", "rotacao_tipos"): ("E", "rotação do Tipo do Dia (A nos dias gravados; E nos outros)"), ("jogador", "sessao_expira_s"): ("B", "sessão expira 15 min depois de fechar (B-relatado)"),
    ("jogador", "streak_abates_por_ponto"): ("C", "1 ponto de Streak por 1000 abates (C)"), ("jogador", "streak_custo_base"): ("A", "o n-ésimo ponto custa 25.000 × n (C/A G7)"),
    ("jogador", "streak_trilhas"): ("C", "trilhas EXP, Loot e Shiny (C)"),
    ("cidade", "pedra_por_tipo"): ("F", "pedra de evolução por tipo (F: receita das pedras; A em 1 caso, G3)"), ("cidade", "ramos_eevee"): ("F", "ramos do Eevee (B/F)"),
    ("cidade", "venda_categorias_excluidas"): ("C", "o Mark não compra heal/revive/stone (C)"), ("cidade", "venda_excecoes_ids"): ("C", "exceções da regra acima, itens 205 e 206 (C)"),
    ("cidade", "venda_pokemon"): ("A", "venda de Pokémon = sellValue da espécie (A: G2, 399/399)"), ("cidade", "venda_teto_preco_compra"): ("E", "revenda nunca acima do preço de compra (E: evita ouro infinito)"),
    ("diarias", "kill_xp_fator"): ("A", "Daily Kill: XP = qtd × xpAbate × 8/3 (A: 3/3)"), ("diarias", "kill_min_nivel"): ("C", "nível mínimo do Daily Kill (C)"),
    ("diarias", "kill_itens_mult"): ("E", "multiplicador dos itens do prêmio do Daily Kill (classe 3)"), ("diarias", "catch_total"): ("A", "slots do Daily Catch por dia (A: 2)"),
    ("pesca", "faixas"): ("E", "faixas da pesca: skill mínima, níveis e espécies (classe 3; C: a forma das faixas)"), ("pesca", "onda_s"): ("E", "duração da onda de pesca (classe 3)"),
    ("pesca", "recarga_s"): ("E", "recarga entre pescas (classe 3; C: ⏳ Aguarde Ns)"), ("pesca", "skill_max"): ("E", "nível máximo da pesca (classe 3)"),
    ("ditto", "debuff"): ("C", "−25% de HP, Atk, Def, SpA e SpD ao transformar (C)"), ("ditto", "duracao_s"): ("C", "a transformação dura 12 h (C)"),
    ("ditto", "nivel_recebe"): ("E", "fonte offline: um Ditto no treinador 100 (classe 3)"),
    ("bosses", "historico_max"): ("E", "lutas guardadas no histórico de bosses"), ("ginasios", "ginasios_conhecidos"): ("A", "ginásios vistos no gym-global (A)"),
    ("golden_stars", "roll_pago_ouro"): ("E", "custo da rolagem antes das 12 h (classe 3)"), ("itens", "tipos_berry"): ("A", "nome do tipo na descrição da berry → tipo do jogo (A: items.json)"),
    ("sim", "chance_shiny"): ("A", "chance de shiny (nome antigo; ver shiny_chance)"),
    ("sim", "captura_k"): ("F", "peso do investimento desde a última captura no medidor (forma F; c e k por máxima verossimilhança)"),
    ("sim", "desempate_mob"): ("A", "desempate do passo do selvagem pelas frequências medidas (A)"),
    ("sim", "penalidade_fator"): ("A", "XP e drops × 0,3 durante o lock de entrada (A: 76/76 abates)"),
    ("sim", "stats_dano_aliado"): ("F", "stats do aliado no dano: os exibidos, arredondados (F forte: 15/15 indivíduos)"),
}


def origem_de(texto, padrao):
    t = texto or ""
    if re.search(r"classe 3", t):
        return "E"
    # Um bloco pode citar A/C como contexto e F para a fórmula. Não promover a hipótese.
    if re.search(r"\bF\s*[:,)]|\bhipótese\b|\bfórmula candidata\b", t, re.I):
        return "F"
    m = re.search(r"(?<![A-Za-zÀ-ú])([ABCDEF])(?=\s*[:(,)/]|\s+[\(\[]|\s*$|\s+\()", t)
    if m:
        return m.group(1)
    for letra in "ACBEFD":
        if re.search(r"\(%s[\s:,)]" % letra, t) or t.startswith(letra + ":") or t.startswith(letra + " "):
            return letra
    return padrao


STATUS = {"A": "observada (referência declarada, não auditada pelo catálogo)",
          "B": "documentada na Pokepedia (não confirma o servidor)",
          "C": "replicada do cliente sem confirmação no servidor",
          "D": "verificada localmente (não confirma o original)",
          "E": "desenhada por nós", "F": "em aberto"}


def revisar_metadados(cat):
    """Origem não é grau de comprovação. Nunca altera literais nem dados de balanceamento."""
    for entrada in cat["parametros"]:
        candidata = origem_de(entrada["descricao"], entrada["origem"])
        # Contexto A/B/C não promove automaticamente uma decisão ou hipótese anterior.
        if candidata in ("E", "F"):
            entrada["origem"] = candidata
        if entrada["fonte"] == "sim" and entrada["chave"] in ("captura_c", "captura_k"):
            entrada["origem"] = "F"
            entrada["descricao"] = "F: coeficiente da fórmula candidata de captura, ajustado às sequências observadas (A); não é fórmula revelada pelo servidor."
            entrada["evidencia"] = "sim/regras.gd: bloco da fórmula de captura; CALIBRACAO_FASE3.md; CALIBRACAO_FASE4.md"
        entrada["status"] = STATUS[entrada["origem"]]
    for regra in cat["regras"]:
        if regra["status"].startswith("comprovada contra o original (no resultado"):
            regra["status"] = "resultado registrado no placar (não revalidado pelo catálogo)"
        elif regra["status"] != "em aberto":
            regra["status"] = STATUS[regra["origem"]]
    return cat


def evidencia_de(texto, arquivo):
    t = texto or ""
    achados = re.findall(r"(?:test_[a-z_0-9]+|[A-Z]{1,2}\d{1,2}\b|rhydon-1h|geodude-10min|G\d+|c5|C\d|S\d|M\d|T1|[a-z_/]+\.(?:gd|py|json|md))", t)
    vistos = []
    for a in achados:
        if a not in vistos:
            vistos.append(a)
    return ", ".join(vistos[:4]) if vistos else "comentário em `%s`" % arquivo


def main():
    valores = json.load(open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "saida_testes", "regras_valores.json"), encoding="utf-8"))
    bal_path = os.path.join(RAIZ, "dados", "balanceamento.json")
    bal = json.load(open(bal_path, encoding="utf-8")) if os.path.exists(bal_path) else {}
    # sem o balanceamento.json (migrado para os Resources), os motivos vêm do catálogo anterior
    anterior = {}
    cat_path = os.path.join(RAIZ, "dados", "regras", "catalogo.json")
    if not bal and os.path.exists(cat_path):
        for e in json.load(open(cat_path, encoding="utf-8")).get("parametros", []):
            anterior[(e["fonte"], e["chave"])] = e
    entradas = []
    for fonte, chaves in valores.items():
        arquivo, rec_fixo = FONTES[fonte]
        com = comentarios(arquivo)
        if fonte == "sim":
            com.update({k: v for k, v in comentarios("sim/regras.gd").items()})
        sec_bal = bal.get("combate" if fonte == "sim" else fonte, {})
        for k, v in sorted(chaves.items()):
            if (fonte, k) in FIXOS:
                continue
            rec = rec_fixo or recurso_sim(k)
            motivo = sec_bal.get(k, {}).get("motivo", "") if isinstance(sec_bal.get(k), dict) else ""
            texto = motivo or com.get(k, "")
            no_bal = bool(motivo)
            origem = "E" if no_bal and not re.search(r"\b[AC]:", motivo or "") else origem_de(texto, "E")
            if (fonte, k) in ANOTA and not texto:
                origem, texto = ANOTA[(fonte, k)]
            if (fonte, k) in anterior:
                ant = anterior[(fonte, k)]
                # o texto anterior guarda os motivos do balanceamento.json removido; se o comentário do código é o mesmo
                # texto estendido (contém o começo do anterior), o comentário vale (registro novo de evidência no código)
                if not (texto and ant["descricao"][:25] in texto and len(texto) > len(ant["descricao"])):
                    origem, texto = ant["origem"], ant["descricao"]
            entradas.append({
                "id": "%s.%s" % (rec, k), "recurso": rec, "sistema": SISTEMA[rec], "fonte": fonte, "chave": k, "literal": v["literal"],
                "tipo": v["tipo"], "descricao": texto, "origem": origem, "status": STATUS[origem],
                "evidencia": evidencia_de(texto, arquivo) if texto else "padrão do código em `%s`" % arquivo,
                "original_jogo": ORIGINAL.get((fonte, k), ""), "controle": "dados/regras/<perfil>/%s.tres → %s" % (rec, k),
            })
    # regras que não são parâmetro: as tabelas do PLACAR_ESCOPO.md (classe 1, 2 e 3)
    regras = []
    placar = os.path.join(RAIZ, "PLACAR_ESCOPO.md")
    classe = ""
    for linha in open(placar, encoding="utf-8"):
        if linha.startswith("## Classe"):
            classe = linha[10:11]
        if not linha.startswith("| ") or linha.startswith("| ---") or classe == "":
            continue
        cols = [c.strip() for c in linha.strip().strip("|").split("|")]
        if cols[0] in ("Área", "Regra", "Classe") or len(cols) < 3:
            continue
        if classe == "1":
            area, regra, sit, ev = (cols + ["", "", "", ""])[:4]
            ori = "A" if re.search(r"\bA\b", ev) else ("C" if "C" in ev else "B")
            regras.append({"sistema": area, "regra": regra, "origem": ori, "status": STATUS[ori] if "✅" in sit else "em aberto", "evidencia": ev})
        elif classe == "2":
            regras.append({"sistema": cols[0], "regra": " · ".join(cols[1:3]), "origem": "A", "status": "comprovada contra o original (no resultado, classe 2)", "evidencia": cols[-1]})
        elif classe == "3":
            regras.append({"sistema": "decisões (classe 3)", "regra": cols[0] + ": " + cols[1], "origem": "E", "status": "desenhada por nós", "evidencia": cols[2] if len(cols) > 2 else ""})
    AREA = {"Começo": "começo de jogo", "Acesso": "acesso às hunts e regiões", "XP": "XP e níveis", "XP do treinador": "XP e níveis",
            "XP do Pokémon": "XP e níveis", "Combate": "combate e dano", "Dano": "combate e dano", "Golpe": "combate e dano",
            "Loot": "loot e economia", "IV": "IV e Quality", "Quality": "IV e Quality", "IV/Quality": "IV e Quality", "Auto-Potion": "combate e dano",
            "Auto-Catch": "captura e shiny", "Captura": "captura e shiny", "Nurse": "loja, Nurse Joy, depot e evolução",
            "Nurse Joy": "loja, Nurse Joy, depot e evolução", "Depot": "loja, Nurse Joy, depot e evolução", "Movimento": "movimento"}
    for r in regras:
        r["sistema"] = AREA.get(r["sistema"], r["sistema"])
    regras += [
        {"sistema": "interface e desempenho", "regra": "Quadro p99 ≤ 16,7 ms com a janela em foco (5 hunts mais pesadas)", "origem": "E", "status": "desenhada por nós",
         "evidencia": "test_todas_hunts.py --velocidade 1; v1.0: medianas 7,45–10,73 ms"},
        {"sistema": "interface e desempenho", "regra": "Sem foco, desenho a 10 quadros/s e a sim segue o relógio (atraso recuperado até 1 h)", "origem": "E",
         "status": "desenhada por nós", "evidencia": "test_modo_fundo; EstadoJogo.definir_modo_fundo"},
        {"sistema": "interface e desempenho", "regra": "Entrada na hunt em no máximo 1 s (cache e atlas prontos)", "origem": "E", "status": "desenhada por nós",
         "evidencia": "ferramentas/build/medir_entrada_hunt.gd"},
        {"sistema": "interface e desempenho", "regra": "Save em thread, atômico (.tmp, conferência byte a byte, .bak)", "origem": "E", "status": "desenhada por nós",
         "evidencia": "test_save_thread.py (15/15 mortes sem perda)"},
        {"sistema": "interface e desempenho", "regra": "HUD na referência 1880 px do original; zoom 25×13 (1), 0.75 e 0.5", "origem": "C",
         "status": "replicada do cliente sem confirmação no servidor", "evidencia": "C: cameraZoom; janela_base.gd"},
    ]
    os.makedirs(os.path.join(RAIZ, "dados", "regras"), exist_ok=True)
    cat = {"_fonte": "ferramentas/regras/catalogo.py (valores de ferramentas/regras/exportar_valores.gd); não edite à mão",
           "secoes": SECOES, "sistemas": SISTEMA, "parametros": entradas, "regras": regras}
    revisar_metadados(cat)
    json.dump(cat, open(os.path.join(RAIZ, "dados", "regras", "catalogo.json"), "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
    escrever_md(cat)
    print("catálogo: %d parâmetros em %d Resources; %d regras de fórmula" % (len(entradas), len({e["recurso"] for e in entradas}), len(regras)))


def escrever_md(cat):
    from collections import Counter
    ps, rs = cat["parametros"], cat["regras"]
    cont = Counter(e["status"] for e in ps) + Counter(r["status"] for r in rs)
    L = ["# REGRAS — mapa completo das regras e parâmetros do jogo", "",
         "Gerado por `ferramentas/regras/catalogo.py` a partir do código (valores em execução, comentários de origem), dos motivos",
         "de classe 3 e das tabelas do `PLACAR_ESCOPO.md`. Não edite à mão: mude o código ou os Resources e gere de novo.",
         "Origem: A observado no original · B Pokepedia · C cliente · D teste · E decisão nossa · F hipótese.", "",
         "O catálogo organiza referências declaradas; não executa o validador nem audita gravações. Uma letra A ou um teste local não comprova uma fórmula do servidor.",
         "O perfil chamado `original` é a referência local para restauração; inclui decisões E e hipóteses F. A fidelidade deve ser conferida nos relatórios vinculados e no placar.", "",
         "| Status | Parâmetros e regras |", "| --- | --- |"]
    for st, n in sorted(cont.items(), key=lambda x: -x[1]):
        L.append("| %s | %d |" % (st, n))
    L.append("| **total** | **%d** (%d parâmetros editáveis no Game Master + %d regras de fórmula) |" % (len(ps) + len(rs), len(ps), len(rs)))
    por_sis = {}
    for e in ps:
        por_sis.setdefault(e["sistema"], []).append(e)
    for r in rs:
        por_sis.setdefault(r["sistema"], []).append(r)
    esc = lambda s: str(s).replace("|", "\\|").replace("\n", " ")
    for sis in sorted(por_sis):
        L += ["", "## " + sis, "", "| Regra | Valor atual | Origem | Status | Evidência | Valor original (se diferente) | Controle |",
              "| --- | --- | --- | --- | --- | --- | --- |"]
        for e in por_sis[sis]:
            if "chave" in e:
                val = e["literal"] if len(e["literal"]) <= 60 else e["literal"][:57] + "…"
                L.append("| `%s` — %s | `%s` | %s | %s | %s | %s | `%s` |" % (e["chave"], esc(e["descricao"][:160]), esc(val), e["origem"], e["status"],
                                                                       esc(e["evidencia"]), esc(e["original_jogo"]), e["controle"]))
            else:
                L.append("| %s | (regra no código) | %s | %s | %s | | código da sim |" % (esc(e["regra"]), e["origem"], e["status"], esc(e["evidencia"])))
    L += ["", "## Constantes fixas (fora do Game Master)", "", "| Constante | Onde | Por que não muda |", "| --- | --- | --- |"]
    for (f, k), motivo in FIXOS.items():
        L.append("| `%s` | `%s` | %s |" % (k, FONTES[f][0], motivo))
    for nome, onde, motivo in FIXOS_CODIGO:
        L.append("| %s | `%s` | %s |" % (nome, onde, motivo))
    L += ["", "## Em aberto e o que fecharia cada ponto", ""]
    # o que fecha cada parâmetro quando já se sabe (23/11: as gravações existentes conferidas antes)
    FECHAR_PARAM = {
        "pedra_por_tipo": "abrir, com o gravador ligado, a janela de evolução (GET /api/game/evolve traz a receita sem evoluir) do "
                          "Magikarp (a sim prevê Water + Feather) e do Pupitar (2 Rock + 2 Darkness): falta só o tipo ganho",
        "alvo_so_alcancavel": "15–20 min numa hunt com spawn isolado (togepi, horsea ou goldeen) com um Pokémon forte; "
                              "medir_alvo_ilhas.py lê o targetSlot quando só sobram inalcançáveis (nenhuma gravação tem o caso)",
        "arredondamento_dano": "aliado nível 5–15 na hunt rattata ou geodude por ~30 min (dano 5–20); arredondamento_dano.py "
                               "(41.896 golpes de nível ≥ 20 dão empate)",
    }
    fechar = {"movimento": "gravação de luta média (MV1–MV3) ou mais trechos da gravação livre no validador",
              "combate e dano": "gravação de nível 1–4 com captura (G11 estendida) para separar o piso de ataque dos stats do nível 2",
              "captura e shiny": "gravações de captura de outras espécies EPIC (viés do Larvitar) e o shinyBase por tier",
              "XP e níveis": "gravação de Orre (não há)", "profissões, mentor e crafting": "gravação PR1 (profissões e pesca)"}
    for e in ps + rs:
        if e["status"] == "em aberto":
            sis = e["sistema"]
            L.append("- **%s** (%s): %s — fecha com: %s" % (e.get("chave", e.get("regra", ""))[:80], sis, esc((e.get("descricao") or e.get("evidencia", ""))[:140]),
                                                         FECHAR_PARAM.get(e.get("chave", ""), fechar.get(sis, "gravação do original que mostre esse valor"))))
    L += ["- **Orre** (hipótese F): a dificuldade depende do dano dos selvagens de nível alto na sim — fecha com gravação de Orre.",
          "- **Viés do Larvitar** na captura (z 2,1) — fecha com gravações de captura de outras espécies EPIC.", ""]
    open(os.path.join(RAIZ, "REGRAS.md"), "w", encoding="utf-8", newline="\n").write("\n".join(L))


if __name__ == "__main__":
    main()
