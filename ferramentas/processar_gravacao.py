#!/usr/bin/env python3
"""Processa uma gravação do original (gravador v1.x) contra as regras da simulação registradas em CALIBRACAO_FASE3.md e
CALIBRACAO_FASE4.md. Para cada regra que a gravação cobre, diz se CONFIRMOU, CONTRADISSE (com os números) ou se ficou
INCONCLUSIVA; no fim, as regras que a gravação não cobre. Grava dados/relatorios/gravacao_<nome>.md.

As regras verificadas usam as mesmas constantes da sim (lidas de sim/*.gd quando é possível, para não divergir):
  HP do aliado e do selvagem, XP base / VIP / debuff / typeDay / streak, loot × tabela (normal, lock, tipo do dia),
  Auto-Potion (gatilho e escolha), passos do herói e do selvagem, cadência do aliado, pisos de dano, fórmula de dano
  (fração de golpes explicados, ferramentas/fase4/ajustar_dano.py), golpe fixo por indivíduo selvagem, penalidade de
  entrada (60 s), soneca (GET/POST /offline), Daily Kill, Daily Catch, tarefas, Streak, Daily Gift, receita de pedras
  (/evolve) e o Tipo do Dia (nome e rotação).

Gravação livre (18/11): aceita vários arquivos ou uma pasta (ex.: `poke har/gravacoes/livre/`). As exportações diárias
são juntadas sem repetir linha (sessão, instante, direção, conteúdo) e cortadas em trechos por
`ferramentas/gravador/segmentar.py`: cidade × hunt, entrada nova × retomada e janela da penalidade, troca de time, mudança
de zoom e buracos (aba em segundo plano). Passos, cadência e Auto-Potion rodam só nos pedaços sem buraco; o resto, na
gravação inteira (as regras já separam lock, Tipo do Dia e líder). O relatório ganha a tabela de trechos.

Uso: python -I ferramentas/processar_gravacao.py <arquivo.jsonl | pasta> [...] [--nome N] [--saida dados/relatorios/gravacoes]
     [--sem-dano]
"""
import argparse
import glob
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "gravador"))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "fase4"))

CONFIRMOU, CONTRADISSE, INCONCLUSIVO = "confirmou", "contradisse", "inconclusivo"


def carregar(nome):
    return json.load(open(os.path.join(RAIZ, "dados", "gerados", nome), encoding="utf-8"))


def gd_const(arquivo, chave):
    """Valor de PARAMETROS["chave"] num .gd da sim (número, string ou lista simples de strings)."""
    s = open(os.path.join(RAIZ, arquivo), encoding="utf-8").read()
    m = re.search(r'"%s":\s*(\[[^\]]*\]|"[^"]*"|[-0-9.]+)' % re.escape(chave), s, re.S)
    if not m:
        raise KeyError(chave)
    v = m.group(1)
    if v.startswith("["):
        return re.findall(r'"([^"]+)"', v)
    if v.startswith('"'):
        return v.strip('"')
    return float(v)


def linhas(caminho):
    for l in open(caminho, encoding="utf-8", errors="replace"):
        try:
            o = json.loads(l)
        except Exception:
            continue
        if isinstance(o, dict) and isinstance(o.get("msg"), dict):
            yield o


class Relatorio:
    def __init__(self):
        self.itens = []          # (regra, fonte da regra, status, detalhe)

    def add(self, regra, fonte, status, detalhe):
        self.itens.append((regra, fonte, status, detalhe))

    def status(self, prefixo):
        return [s for r, _, s, _ in self.itens if r.startswith(prefixo)]


def binom_z(obs, esp, n_eventos):
    var = max(esp * (1.0 - min(0.999, esp / max(1, n_eventos))), 1e-9)
    return (obs - esp) / math.sqrt(var)


# ------------------------------------------------------------------------------------------------ regras da hunt

def regras_hunt(msgs, R, esp, rel_cobertas):
    vip_frac = gd_const("sim/regras.gd", "vip_fracao")
    pen_fator = gd_const("sim/regras.gd", "penalidade_fator")
    td_pct = gd_const("sim/regras.gd", "tipo_do_dia_pct")
    td_loot = gd_const("sim/regras.gd", "tipo_do_dia_loot")
    kills = [m for _, m in msgs if m.get("type") == "field-kill"]
    if not kills:
        return
    rel_cobertas.add("hunt")
    # XP base = experience da espécie
    ok = sum(1 for k in kills if int((k.get("xpParts") or {}).get("base", -1)) == int(esp.get(k.get("speciesId"), {}).get("xpAbate", -2)))
    R.add("XP base por abate = experience da espécie", "CALIBRACAO_FASE3 (A)", CONFIRMOU if ok == len(kills) else CONTRADISSE, "%d/%d abates" % (ok, len(kills)))
    # VIP = round(base × 0,5)
    vk = [k for k in kills if int((k.get("xpParts") or {}).get("vip", 0)) > 0]
    if vk:
        ok = sum(1 for k in vk if int(k["xpParts"]["vip"]) == int(math.floor(k["xpParts"]["base"] * vip_frac + 0.5)))
        R.add("VIP = +50% da base (parcela vip)", "CLAUDE.md Fatos (A)", CONFIRMOU if ok == len(vk) else CONTRADISSE, "%d/%d abates com VIP" % (ok, len(vk)))
    # debuff = floor(total × 0,3)
    dk = [k for k in kills if "debuff" in (k.get("xpParts") or {})]
    if dk:
        ok = 0
        for k in dk:
            p = k["xpParts"]
            bruto = sum(int(v) for c, v in p.items() if c != "debuff")
            ok += int(int(k["xpGained"]) == int(math.floor(bruto * pen_fator + 1e-9)))
        R.add("Penalidade de entrada: XP = floor(total × 0,3)", "CLAUDE.md Fatos (A)", CONFIRMOU if ok == len(dk) else CONTRADISSE, "%d/%d abates no lock" % (ok, len(dk)))
    # typeDay = floor(base × 20%)
    tk = [k for k in kills if int((k.get("xpParts") or {}).get("typeDay", 0)) > 0]
    if tk:
        ok = sum(1 for k in tk if int(k["xpParts"]["typeDay"]) == int(math.floor(k["xpParts"]["base"] * td_pct / 100.0 + 1e-9)))
        R.add("Tipo do Dia: typeDay = floor(20% da base)", "CALIBRACAO_FASE4 (A, G8)", CONFIRMOU if ok == len(tk) else CONTRADISSE, "%d/%d abates" % (ok, len(tk)))
    # loot × tabela, por grupo
    grupos = {"normal": [], "lock": [], "tipo do dia": []}
    for k in kills:
        if k.get("shiny"):
            continue
        p = k.get("xpParts") or {}
        g = "lock" if "debuff" in p else ("tipo do dia" if int(p.get("typeDay", 0)) > 0 else "normal")
        grupos[g].append(k)
    fator = {"normal": 1.0, "lock": pen_fator, "tipo do dia": td_loot}
    fonte = {"normal": "CLAUDE.md Fatos (A: tabela)", "lock": "CLAUDE.md Fatos (A: ~0,27×; sim: chance × 0,3, F)",
             "tipo do dia": "CALIBRACAO_FASE4 (A, G8 × G10: × 1,4)"}
    for g, ks in grupos.items():
        if len(ks) < 15:
            continue
        obs = sum(len(k.get("loot") or []) for k in ks)
        esp_n = 0.0
        eventos = 0
        for k in ks:
            for li in esp.get(k["speciesId"], {}).get("loot", []):
                esp_n += min(1.0, float(li["chance"]) * fator[g])
                eventos += 1
        z = binom_z(obs, esp_n, eventos)
        st = CONFIRMOU if abs(z) <= 2.0 else CONTRADISSE
        R.add("Loot × tabela (%s, chance × %.2f)" % (g, fator[g]), fonte[g], st,
              "%d drops em %d abates; esperado %.1f (z = %.2f; razão à tabela %.2f)" % (obs, len(ks), esp_n, z, obs / max(1e-9, esp_n / fator[g])))


def regra_hp(msgs, R, esp):
    """HP de combate do aliado = max(24, 12 × stat HP) e do selvagem múltiplo de 35 (ou o piso 120)."""
    stats = {}
    ok = tot = 0
    sel = Counter()
    for _, m in msgs:
        t = m.get("type")
        if t == "poke-delta" and m.get("poke", {}).get("stats"):
            p = m["poke"]
            stats[p.get("name")] = int(p["stats"]["hp"])
        elif t in ("pokes", "pokes-chunk"):
            for p in m.get("list", []):
                if p.get("team") and p.get("stats"):
                    stats.setdefault(p.get("name"), int(p["stats"]["hp"]))
        elif t == "field":
            h = m.get("heroName")
            if h in stats:
                tot += 1
                ok += int(int(m.get("heroMaxHp", 0)) == max(24, 12 * stats[h]))
            for mb in m.get("mobs", []):
                mx = int(mb.get("maxHp", 0))
                sel[mx == 120 or mx % 35 == 0] += 1
    if tot:
        R.add("HP de combate do aliado = max(24, 12 × stat HP)", "CLAUDE.md Fatos (A)", CONFIRMOU if ok >= 0.98 * tot else CONTRADISSE,
              "%d/%d fields com stats conhecidos (o stat muda no level-up até o próximo poke-delta)" % (ok, tot))
    if sel:
        R.add("HP do selvagem = max(120, 35 × stat HP)", "CLAUDE.md Fatos (A)", CONFIRMOU if sel[False] == 0 else CONTRADISSE,
              "%d de %d mobs/field com maxHp múltiplo de 35 ou 120" % (sel[True], sel[True] + sel[False]))


def regra_pocao(caminho, R):
    import medir_pocao as MP
    sim_, nao, _ = MP.cruzamentos([caminho])
    if sim_ + nao >= 3:
        R.add("Auto-Potion dispara no mesmo tick em que o HP fica ≤ 50%", "CLAUDE.md Fatos (A)", CONFIRMOU if nao == 0 else (INCONCLUSIVO if nao <= 1 else CONTRADISSE),
              "%d de %d cruzamentos curados no mesmo tick" % (sim_, sim_ + nao))
    curas, cat = MP.coletar([caminho])
    fixa = None
    for o in linhas(caminho):
        if o["msg"].get("type") == "autohelper" and o["msg"].get("autoPotionItemId"):
            fixa = o["msg"]["autoPotionItemId"]
    if fixa and curas:
        R.add("Auto-Potion com poção fixa no Auto-Helper (item %s): a regra 'menor que cobre' não se aplica" % fixa,
              "sim/cenario_jogo.gd (pocao_fixa, E)", INCONCLUSIVO, "%d curas" % len(curas))
        return
    if len(curas) >= 5:
        cura = {i["nome"]: i["cura"] for i in cat.values()}
        ok = tot = 0
        for c in curas:
            falta = c["max"] - c.get("hp_exato", c["hp_antes"])
            inv = sorted((cura[n], n) for n in c["inventario"] if n in cura) + [(cura.get(c["pocao"], 0), c["pocao"])]
            inv = sorted(set(inv))
            cobre = [n for v, n in inv if v >= falta]
            esperado = cobre[0] if cobre else (inv[-1][1] if inv else None)
            tot += 1
            ok += int(esperado == c["pocao"])
        R.add("Auto-Potion usa a menor poção que cobre o que falta (senão a maior)", "CLAUDE.md Fatos (A)",
              CONFIRMOU if ok >= 0.95 * tot else CONTRADISSE, "%d/%d curas (o HP antes da cura vem do field anterior)" % (ok, tot))


def regra_passos(caminho, R):
    import medir_passos as MPa
    m = MPa.medir([caminho])
    h = m.get("heroi", {}).get("intervalo_ms", {}).get("reto", {})
    s = m.get("selvagem", {}).get("intervalo_ms", {}).get("reto", {})
    if h.get("n", 0) >= 10:
        R.add("Passo do herói em reta: 600 ms", "CLAUDE.md Fatos (A)", CONFIRMOU if h["moda"] == 600 else CONTRADISSE, "moda %s ms (%d passos)" % (h["moda"], h["n"]))
    if s.get("n", 0) >= 10:
        R.add("Passo do selvagem em reta: 1000/1200 ms", "CLAUDE.md Fatos (A)", CONFIRMOU if s["moda"] in (1000, 1200) else CONTRADISSE, "moda %s ms (%d passos)" % (s["moda"], s["n"]))


def regra_dano(caminho, R, esp):
    """Pisos, golpe fixo por indivíduo e a fração de golpes explicados pela fórmula da sim (e + piso 3 no ataque)."""
    import ajustar_dano as AD
    ind = AD.coletar(caminho)
    if not ind:
        return
    aliado = [a for e in ind.values() for a in e["aliado"]]
    selv = [a for e in ind.values() for a in e["selvagem"]]
    if aliado:
        R.add("Piso de dano do aliado = 2", "CLAUDE.md Fatos (A)", CONFIRMOU if min(a[3] for a in aliado) >= 2 else CONTRADISSE, "mínimo %d em %d golpes" % (min(a[3] for a in aliado), len(aliado)))
    if selv:
        R.add("Piso de dano do selvagem = 1", "CLAUDE.md Fatos (A)", CONFIRMOU if min(a[3] for a in selv) >= 1 else CONTRADISSE, "mínimo %d em %d golpes" % (min(a[3] for a in selv), len(selv)))
    varios = sum(1 for e in ind.values() if len({a[0] for a in e["selvagem"]}) > 1)
    com = sum(1 for e in ind.values() if e["selvagem"])
    if com >= 3:
        R.add("Golpe do selvagem: sempre o mesmo por indivíduo", "CLAUDE.md Fatos (A)", CONFIRMOU if varios <= max(1, com // 20) else CONTRADISSE,
              "%d de %d indivíduos com mais de um golpe (atribuição só com 1 selvagem encostado)" % (varios, com))
    hunts = {h["slug"]: h for h in AD.R.carregar(os.path.join(RAIZ, "dados", "gerados", "hunts.json"))}
    res, _ = AD.avaliar(ind, esp, hunts, ["e+A3"])
    for lado in ("aliado", "selvagem"):
        for faixa, (n, ok, err) in sorted(res["e+A3"][lado].items()):
            if n < 20:
                continue
            frac = ok / n
            R.add("Fórmula de dano da sim (%s, atacante nível %s)" % (lado, faixa), "CLAUDE.md, fórmula candidata (F) + item 2 de 15/11",
                  CONFIRMOU if frac >= 0.95 else (INCONCLUSIVO if frac >= 0.85 else CONTRADISSE), "%.1f%% de %d golpes explicados" % (100 * frac, n))


def regra_cadencia(caminho, R):
    inter = Counter()
    # cadência do aliado pelos hits do herói (slot ≥ 0) com Δseq exato entre fields consecutivos
    ult_seq = None
    ultimo_hit = None
    for o in linhas(caminho):
        m = o["msg"]
        if m.get("type") == "field-init":
            ultimo_hit = None
        if m.get("type") != "field":
            continue
        hs = [h for h in m.get("hits", []) if int(h.get("slot", -1)) >= 0]
        if len(hs) == 1 and ult_seq is not None and m["seq"] - ult_seq == 2:
            if ultimo_hit is not None:
                inter[(m["seq"] - ultimo_hit) * 200] += 1
            ultimo_hit = m["seq"]
        ult_seq = m["seq"]
    if sum(inter.values()) >= 20:
        moda = inter.most_common(1)[0][0]
        R.add("Ritmo de ataque do aliado: 1600 ms", "CLAUDE.md Fatos (A)", CONFIRMOU if moda == 1600 else INCONCLUSIVO,
              "moda %d ms (%s)" % (moda, inter.most_common(3)))


def regra_penalidade(caminho, R):
    """Lock de 60 s (boost shinylock): abates antes do until com debuff, depois sem. O horário do abate é o serverNow do
    último field (atraso de até centenas de ms): abates a menos de 1 s do until não contam."""
    until = None
    entrada = None
    ultimo = None
    slug = None
    antes = depois = deb_antes = deb_depois = 0
    for o in linhas(caminho):
        m = o["msg"]
        t = m.get("type")
        if t == "field-init":
            if until is not None and (antes or depois):
                _penalidade(R, slug, antes, deb_antes, depois, deb_depois, until, entrada)
            slug, until, entrada, antes, depois, deb_antes, deb_depois = m.get("slug"), None, None, 0, 0, 0, 0
        elif t == "boosts":
            for b in m.get("boosts", []):
                if b.get("key") == "shinylock":
                    until = int(b["until"])
        elif t == "field":
            ultimo = int(m.get("serverNow", 0))
            entrada = entrada or ultimo
        elif t == "field-kill" and until is not None and ultimo:
            d = "debuff" in (m.get("xpParts") or {})
            if ultimo < until - 1000:
                antes += 1
                deb_antes += int(d)
            elif ultimo > until + 1000:
                depois += 1
                deb_depois += int(d)
    if until is not None and (antes or depois):
        _penalidade(R, slug, antes, deb_antes, depois, deb_depois, until, entrada)


def _penalidade(R, slug, antes, deb_antes, depois, deb_depois, until, entrada):
    ok = deb_antes == antes and deb_depois == 0
    R.add("Penalidade = lock de 60 s: debuff em todo abate antes do until e em nenhum depois (%s)" % slug,
          "CLAUDE.md Fatos (A)", CONFIRMOU if ok else CONTRADISSE,
          "antes %d/%d com debuff, depois %d/%d (abates a ±1 s do until fora)" % (deb_antes, antes, deb_depois, depois))


# ------------------------------------------------------------------------------------------------ REST e eventos

def regras_rest(msgs, R, esp, cobertas):
    rest = [(o, o["msg"]) for o, _ in msgs if o.get("dir") == "rest"]
    for o, m in rest:
        c = m.get("corpo")
        cam = m.get("caminho", "")
        if m.get("status") != 200 or not isinstance(c, dict):
            continue
        if cam == "/api/game/offline" and m.get("metodo") == "GET" and c.get("report"):
            cobertas.add("soneca")
            r = c["report"]
            s = r["sample"]
            seg = int(r["seconds"])
            esp50 = round(s["xpSample"] / 300.0 * seg * 0.5 + 1e-9)
            espk = round(s["kills"] / 300.0 * seg + 1e-9)
            ok = int(r["xp50"]) == esp50 and int(r["estKills"]) == espk
            R.add("Soneca: xp50 = round(xpSample/300 × s × 0,5), estKills = round(kills/300 × s)", "CALIBRACAO_FASE4 (A, G6)",
                  CONFIRMOU if ok else CONTRADISSE, "xp50 %s × %s; estKills %s × %s" % (r["xp50"], esp50, r["estKills"], espk))
        if cam == "/api/game/daily-kill" and c.get("options"):
            cobertas.add("daily-kill")
            ok = sum(1 for x in c["options"] if int(x["xp"]) == int(math.floor(int(x["qty"]) * esp.get(x["speciesId"], {}).get("xpAbate", 0) * 8 / 3 + 1e-6)))
            R.add("Daily Kill: xp = floor(qtd × xpAbate × 8/3)", "CALIBRACAO_FASE4 (A, G5/G9)", CONFIRMOU if ok == len(c["options"]) else CONTRADISSE,
                  "%d/%d opções" % (ok, len(c["options"])))
        if cam == "/api/game/daily-catch" and c.get("claims"):
            cobertas.add("daily-catch")
            ms = []
            for x in c["claims"]:
                base = esp.get(x["speciesId"], {}).get("xpAbate", 0) * 8 / 3
                mm = x["xp"] / base if base else 0
                ms.append(round(mm * 2) / 2 if abs(mm * 2 - round(mm * 2)) < 0.01 else None)
            ok = all(v is not None and 1.5 <= v <= 18 for v in ms)
            R.add("Daily Catch: xp = floor(xpAbate × 8/3 × m), m múltiplo de 0,5 em [1,5; 18]", "CALIBRACAO_FASE4 (A forma; F faixa)",
                  CONFIRMOU if ok else CONTRADISSE, "m = %s" % ms)
        if cam == "/api/game/tasks/claim" and m.get("metodo") == "POST":
            cobertas.add("tarefas")
            tar = {t["id"]: t for t in json.load(open(os.path.join(RAIZ, "dados", "fase4", "tarefas.json"), encoding="utf-8"))["tarefas"]}
            t = tar.get(c.get("taskId"), {})
            ok = int(c.get("xp", -1)) == int(t.get("xp", -2)) and int(c.get("cash", -1)) == int(t.get("cash", -2))
            R.add("Tarefa entregue paga o xp/cash da tabela (%s)" % c.get("taskId"), "CALIBRACAO_FASE4 (A, G9)", CONFIRMOU if ok else CONTRADISSE,
                  "xp %s/%s, cash %s/%s" % (c.get("xp"), t.get("xp"), c.get("cash"), t.get("cash")))
        if cam == "/api/game/streak" and "nextCost" in c:
            cobertas.add("streak")
            ok = int(c["nextCost"]) == 25000 * (int(c["spent"]) + 1) and all(abs(float(c["bonusPct"][k]) - 0.1 * int(c["tracks"][k])) < 1e-6 for k in c["tracks"])
            R.add("Streak: n-ésimo ponto custa 25.000 × n; bônus 0,1% por ponto", "CALIBRACAO_FASE4 (C/A, G7)", CONFIRMOU if ok else CONTRADISSE,
                  "spent %s → nextCost %s" % (c["spent"], c["nextCost"]))
        if cam == "/api/game/daily" and m.get("metodo") == "GET" and "nextDay" in c:
            cobertas.add("daily-gift")
            gift = json.load(open(os.path.join(RAIZ, "dados", "fase4", "daily_gift.json"), encoding="utf-8"))["rewards"]
            igual = [(r["day"], r["kind"], r["qty"]) for r in c["rewards"]] == [(r["day"], r["kind"], r["qty"]) for r in gift]
            sequencia = int(c["nextDay"]) == 1 + sum(1 for r in c["rewards"] if r["claimed"])
            R.add("Daily Gift: o mesmo calendário de 28 e nextDay = coletados + 1", "CALIBRACAO_FASE4 (A, G7/G9)",
                  CONFIRMOU if igual and sequencia else CONTRADISSE, "calendário igual: %s; nextDay %s" % (igual, c["nextDay"]))
        if cam == "/api/game/evolve" and m.get("metodo") == "GET" and c.get("stones") is not None:
            cobertas.add("evolucao")
            orig = next((e for e in esp.values() if e["nome"] == c.get("name")), None)
            dest = esp.get(c.get("destId"))
            if orig and dest:
                tabela = {"ROCK": "Rock Stone", "GROUND": "Earth Stone", "GRASS": "Leaf Stone", "FIRE": "Fire Stone", "WATER": "Water Stone"}
                nomes = [tabela.get(orig["tipos"][0])] + [tabela.get(t) for t in dest["tipos"] if t not in orig["tipos"]]
                cada = math.ceil(4 / len(nomes)) if int(orig.get("nivelHunt", 0)) >= 40 else 1
                prev = sorted((n, cada) for n in nomes if n)
                real = sorted((s["name"], int(s["need"])) for s in c["stones"])
                R.add("Receita de pedras: tipo principal da origem + tipos ganhos; 1 de cada (hunt < 40) ou 4 divididas (F)",
                      "CALIBRACAO_FASE4 (F; A num caso, G3)", CONFIRMOU if prev == real else CONTRADISSE, "previsto %s × real %s (%s)" % (prev, real, c.get("name")))


def regra_tipo_do_dia(msgs, R, cobertas):
    rot = gd_const("sim/servico_jogador.gd", "rotacao_tipos")
    ancora = int(gd_const("sim/servico_jogador.gd", "dia_ancora"))
    virada = int(gd_const("sim/servico_jogador.gd", "dia_virada_utc_s"))
    pt = {"Dragão": "DRAGON", "Inseto": "BUG", "Fogo": "FIRE", "Água": "WATER", "Sombrio": "DARK", "Planta": "GRASS", "Veneno": "POISON",
          "Elétrico": "ELECTRIC", "Gelo": "ICE", "Lutador": "FIGHTING", "Terra": "GROUND", "Voador": "FLYING", "Psíquico": "PSYCHIC",
          "Pedra": "ROCK", "Fantasma": "GHOST", "Aço": "STEEL", "Fada": "FAIRY", "Normal": "NORMAL"}
    vistos = {}
    for _, m in msgs:
        if m.get("type") == "events":
            for e in m.get("events", []):
                if e.get("key") == "type-of-day":
                    dia = (int(e["until"]) // 1000 - virada) // 86400 - 1
                    vistos[dia] = e["name"].split(":")[-1].strip()
    for dia, nome in sorted(vistos.items()):
        cobertas.add("tipo-do-dia")
        esperado = rot[(dia - ancora) % len(rot)]
        st = CONFIRMOU if pt.get(nome) == esperado else CONTRADISSE
        R.add("Tipo do Dia (rotação da sim) no dia %d" % dia, "CALIBRACAO_FASE4 (E com âncoras A)", st, "original %s × sim %s" % (nome, esperado))


# ------------------------------------------------------------------------------------------------ principal

REGRAS_CONHECIDAS = ["hunt", "soneca", "daily-kill", "daily-catch", "tarefas", "streak", "daily-gift", "evolucao", "tipo-do-dia"]


def juntar(entradas, destino):
    """Junta exportações (arquivos ou pastas) num só .jsonl, na ordem do primeiro instante de cada arquivo, sem repetir
    linha (sessão, instante, direção, conteúdo)."""
    import segmentar as SG
    vistas = set()
    n = 0
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        for arq in SG.arquivos_de(entradas):
            for l in open(arq, encoding="utf-8", errors="replace"):
                l = l.strip()
                if not l:
                    continue
                try:
                    o = json.loads(l)
                except Exception:
                    continue
                if not isinstance(o, dict):
                    continue
                k = (o.get("sessao"), o.get("t"), o.get("dir"), json.dumps(o.get("msg"), sort_keys=True))
                if k in vistas:
                    continue
                vistas.add(k)
                f.write(l + "\n")
                n += 1
    return n


def processar(caminho, sem_dano=False):
    import segmentar as SG
    import tempfile
    esp = {e["id"]: e for e in carregar("especies.json")}
    msgs = [(o, o["msg"]) for o in linhas(caminho)]
    R = Relatorio()
    cobertas = set()
    trechos = SG.segmentar([caminho], guardar_msgs=True)
    hunts = [x for x in trechos if x["tipo"] == "hunt"]
    cortes = sum(1 for x in hunts if x["motivo_inicio"] in ("buraco", "troca de time", "zoom"))
    # passos, cadência e Auto-Potion: só nos pedaços sem buraco, quando a gravação tem cortes ou várias instâncias
    limpo = caminho
    if cortes or len({x["huntKey"] for x in hunts}) > 1:
        tmp = tempfile.mkdtemp(prefix="trechos_")
        SG.exportar([x for x in trechos if "passos" in x.get("uteis", [])], tmp)
        limpo = os.path.join(tmp, "continuos.jsonl")
        with open(limpo, "w", encoding="utf-8", newline="\n") as f:
            for c in sorted(glob.glob(os.path.join(tmp, "trecho_*.jsonl"))):
                f.write(open(c, encoding="utf-8").read())
    regras_hunt(msgs, R, esp, cobertas)
    if "hunt" in cobertas:
        regra_hp(msgs, R, esp)
        regra_pocao(limpo, R)
        regra_passos(limpo, R)
        regra_cadencia(limpo, R)
        regra_penalidade(caminho, R)
        if not sem_dano:
            regra_dano(caminho, R, esp)
    regras_rest(msgs, R, esp, cobertas)
    regra_tipo_do_dia(msgs, R, cobertas)
    R.trechos = [{k: v for k, v in x.items() if k != "_msgs"} for x in trechos]
    return R, cobertas


def markdown(nome, R, cobertas):
    linhas_md = ["# Gravação %s × regras da simulação" % nome, "",
                 "Gerado por `ferramentas/processar_gravacao.py`. Status: confirmou / contradisse (com os números) / inconclusivo.", ""]
    for st, titulo in ((CONTRADISSE, "Contradisse"), (CONFIRMOU, "Confirmou"), (INCONCLUSIVO, "Inconclusivo")):
        itens = [x for x in R.itens if x[2] == st]
        if not itens:
            continue
        linhas_md += ["## %s (%d)" % (titulo, len(itens)), "", "| Regra | Fonte da regra | Números |", "| --- | --- | --- |"]
        linhas_md += ["| %s | %s | %s |" % (r, f, d) for r, f, _, d in itens]
        linhas_md.append("")
    faltam = [r for r in REGRAS_CONHECIDAS if r not in cobertas]
    linhas_md += ["## Não coberto por esta gravação", "", ", ".join(faltam) if faltam else "—", ""]
    if getattr(R, "trechos", None):
        import segmentar as SG
        linhas_md += ["## Trechos", "", SG.markdown(R.trechos).split("\n", 2)[2]]
    return "\n".join(linhas_md)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+", help="um .jsonl, vários, ou uma pasta (gravação livre)")
    ap.add_argument("--nome", help="nome do relatório (padrão: o do arquivo, ou o da pasta)")
    ap.add_argument("--saida", default=os.path.join(RAIZ, "dados", "relatorios", "gravacoes"))
    ap.add_argument("--sem-dano", action="store_true", help="pula o ajuste da fórmula de dano (o passo mais lento)")
    a = ap.parse_args()
    import tempfile
    if len(a.arquivos) == 1 and os.path.isfile(a.arquivos[0]):
        caminho = a.arquivos[0]
        nome = a.nome or os.path.splitext(os.path.basename(caminho))[0]
    else:
        caminho = os.path.join(tempfile.mkdtemp(prefix="livre_"), "juntado.jsonl")
        n = juntar(a.arquivos, caminho)
        nome = a.nome or os.path.basename(os.path.normpath(a.arquivos[0]))
        print("juntadas %d linhas de %s" % (n, ", ".join(a.arquivos)))
    R, cobertas = processar(caminho, a.sem_dano)
    md = markdown(nome, R, cobertas)
    os.makedirs(a.saida, exist_ok=True)
    destino = os.path.join(a.saida, "gravacao_%s.md" % re.sub(r"[^A-Za-z0-9_.-]+", "_", nome))
    open(destino, "w", encoding="utf-8", newline="\n").write(md)
    print(md)
    print("→", destino)


if __name__ == "__main__":
    main()
