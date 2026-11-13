#!/usr/bin/env python3
"""Ajuste da fórmula de dano contra TODOS os golpes gravados (fase 4, item 1). Não muda a simulação.

Para cada gravação e cada hunt nela: indivíduos selvagens (huntKey, slot) com os golpes do aliado neles e os golpes
deles no aliado (só quando há UM selvagem adjacente), com os stats exatos do aliado no instante (poke-delta, pokes,
pokes-chunk; A). O stat do selvagem é desconhecido: varre o intervalo contínuo que o maxHp permite (Q compatível com o
HP × IV 1..32, sem arredondar, como a sim) e escolhe, por indivíduo × golpe, o valor que explica mais golpes.
Um golpe é explicado se dano(aleatório 0,85) ≤ observado ≤ dano(aleatório 1,00).

Variantes (F, todas com o piso 2/1 e eff 0 = piso):
  c  atual (a da sim): round(K · mods · r), com D = max(1, D) no divisor   K = (2L/5+2)·P·A/D/50
  a  clássica:    round((K + 2) · mods · r)                   +2 depois de /50, antes dos modificadores
  b  +2 no fim:   round(K · mods · r) + 2                     +2 depois de todos os modificadores
  e  atual SEM o piso 1 no divisor (D < 1 entra como é: stats contínuos do selvagem no nível 1–4 ficam em 0,3–1,0)
  d  e com o stat do ALIADO sem arredondar (desconhecido em [exibido − 0,5; exibido + 0,5), varrido por golpe)
Indivíduo: (huntKey, slot) e a "geração" do slot — um selvagem CAPTURADO volta como outro indivíduo (A: no C5 o
mesmo slot do Geodude 1 recebe Earthquakes de 0,93 a 2,07 milhões, 2,2×, mais que o 1,17× do aleatório).
mods = STAB 1,5 × eff amplificada × 1,8 (se selvagem).

Uso: python -I ferramentas/fase4/ajustar_dano.py [--json saida.json] [--md saida.md]
"""
import argparse
import glob
import json
import math
import os
import sys
from collections import defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "gravador"))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
import relatorio_individuos as R  # noqa: E402
from gerar_protocolo import ler_logs  # noqa: E402

FAIXAS = [(1, 4), (5, 19), (20, 79), (80, 199), (200, 99999)]
PASSOS = 240


def faixa_de(n):
    for lo, hi in FAIXAS:
        if lo <= n <= hi:
            return "%d–%s" % (lo, hi if hi < 99999 else "+")
    return "?"


def dano_variante(var, nivel, poder, a, d, stab, eff, selvagem, r):
    piso = 1 if selvagem else 2
    if eff == 0:
        return piso
    divisor = max(1e-9, d) if var in ("e", "d") else max(1.0, d)
    k = (2.0 * nivel / 5.0 + 2.0) * poder * a / divisor / 50.0
    mods = (1.5 if stab else 1.0) * eff * (1.8 if selvagem else 1.0)
    if var in ("c", "d", "e"):
        v = R.js_round(k * mods * r)
    elif var == "a":
        v = R.js_round((k + 2.0) * mods * r)
    elif var == "b":
        v = R.js_round(k * mods * r) + 2
    else:
        raise ValueError(var)
    return max(piso, v)


def coletar(caminho):
    """{(arquivo, huntKey, slot, espécie): {maxHp, slug, aliado: [(golpe, tipo, eff, dano, heroi)], selvagem: [...]}}"""
    ind = {}
    deltas = {}
    huntkey, slug = None, None
    geracao = defaultdict(int)       # (huntKey, slot) -> nº de capturas no slot
    ultimo_field = None
    ultimo_abate = {}
    for d, m, _ in ler_logs([caminho]):
        if d != "in":
            continue
        t = m.get("type")
        if t == "poke-delta":
            p = m.get("poke", {})
            if p.get("stats"):
                deltas[p.get("name")] = {"speciesId": p.get("speciesId"), "level": p.get("level"), "stats": p["stats"]}
        elif t in ("pokes-chunk", "pokes"):
            for p in m.get("list", []):
                if p.get("team") and p.get("stats"):
                    deltas.setdefault(p.get("name"), {"speciesId": p.get("speciesId"), "level": p.get("level"), "stats": p["stats"]})
                    if p.get("leader"):
                        deltas[p.get("name")] = {"speciesId": p.get("speciesId"), "level": p.get("level"), "stats": p["stats"]}
        elif t == "field-init":
            huntkey, slug = R.chave_base(m.get("huntKey")), m.get("slug")
        elif t == "field-kill":
            ultimo_abate[(m.get("row"), m.get("col"))] = m.get("slot")
            if os.environ.get("DANO_VIDA_POR_ABATE") == "1":
                geracao[(huntkey, m.get("slot"))] += 1      # diagnóstico: cada vida é um indivíduo
        elif t == "catch-result" and m.get("success"):
            # o field-kill do mesmo tile traz o slot (A); o capturado volta como outro indivíduo
            sl = ultimo_abate.get((m.get("row"), m.get("col")))
            if sl is not None:
                geracao[(huntkey, sl)] += 1
        elif t == "field" and slug:
            ultimo_field = m
            heroi = deltas.get(m.get("heroName"))
            if not heroi:
                continue
            h = m["hero"]
            esp_slot = {x["slot"]: x["speciesId"] for x in m["mobs"]}
            for x in m["mobs"]:
                k = (os.path.basename(caminho), huntkey, (x["slot"], geracao[(huntkey, x["slot"])]), x["speciesId"])
                ind.setdefault(k, {"maxHp": x["maxHp"], "slug": slug, "aliado": [], "selvagem": []})
            for hit in m.get("hits", []):
                if hit["slot"] >= 0:
                    k = (os.path.basename(caminho), huntkey, (hit["slot"], geracao[(huntkey, hit["slot"])]), esp_slot.get(hit["slot"]))
                    if k in ind:
                        ind[k]["aliado"].append((hit["move"], hit["type"], hit["eff"], hit["amount"], dict(heroi)))
            vivos = [x for x in m["mobs"] if not x["dead"]]
            adj = [x for x in vivos if max(abs(x["row"] - h["row"]), abs(x["col"] - h["col"])) <= 1]
            if len(adj) == 1:
                k = (os.path.basename(caminho), huntkey, (adj[0]["slot"], geracao[(huntkey, adj[0]["slot"])]), adj[0]["speciesId"])
                if k in ind:
                    for hit in m.get("hits", []):
                        if hit["slot"] == -1:
                            ind[k]["selvagem"].append((hit["move"], hit["type"], hit["eff"], hit["amount"], dict(heroi)))
    return ind


def avaliar(ind, especies, hunts, variantes):
    """Resultados por variante × lado × faixa: golpes, explicados, erro absoluto médio fora do envelope."""
    res = {v: {"aliado": defaultdict(lambda: [0, 0, 0.0]), "selvagem": defaultdict(lambda: [0, 0, 0.0])} for v in variantes}
    por_gravacao = {v: defaultdict(lambda: [0, 0]) for v in variantes}
    for k, e in ind.items():
        arq, hk, slot, sid = k
        esp = especies.get(sid)
        hunt = hunts.get(e["slug"])
        if not esp or not hunt:
            continue
        nivel_s = int(hunt["nivel"])
        pares = R.pares_hp(esp["base"]["hp"], nivel_s, e["maxHp"])
        if not pares:
            continue
        qs = sorted({q for _, q, _ in pares})
        for lado in ("aliado", "selvagem"):
            grupos = defaultdict(list)
            for golpe, tipo, eff, amt, h in e[lado]:
                grupos[(golpe, tipo, eff)].append((amt, h))
            for (golpe, tipo, eff), am in grupos.items():
                h0 = am[0][1]
                esp_h = especies.get(h0["speciesId"])
                if not esp_h:
                    continue
                atacante = esp_h if lado == "aliado" else esp
                g = next((x for x in atacante["golpes"] if x["nome"] == golpe), None)
                if not g or int(g.get("poder", 0)) <= 0:
                    continue
                especial = g["categoria"] == "SPECIAL"
                if lado == "aliado":
                    chave = "spDef" if especial else "def"          # stat do selvagem desconhecido = defesa
                    stab = tipo in esp_h["tipos"]
                else:
                    chave = "spAtk" if especial else "atk"          # stat do selvagem desconhecido = ataque
                    stab = tipo in esp["tipos"]
                lo, hi = R.faixa_continua(esp["base"][chave], nivel_s, qs, chave)
                candidatos = [lo + (hi - lo) * i / PASSOS for i in range(PASSOS + 1)]
                for var in variantes:
                    melhor = None
                    deltas_aliado = [-0.5 + i / 10.0 for i in range(10)] if var == "d" else [0.0]
                    for s, da in [(s0, d0) for s0 in candidatos for d0 in deltas_aliado]:
                        ok = 0
                        err = 0.0
                        for amt, h in am:
                            if lado == "aliado":
                                lvl = h["level"]
                                a = max(0.0, h["stats"]["spAtk" if especial else "atk"] + da)
                                d_lo = dano_variante(var, lvl, g["poder"], a, s, stab, eff, False, 0.85)
                                d_hi = dano_variante(var, lvl, g["poder"], a, s, stab, eff, False, 1.0)
                            else:
                                lvl = nivel_s
                                dd = max(0.01, h["stats"]["spDef" if especial else "def"] + da)
                                d_lo = dano_variante(var, lvl, g["poder"], s, dd, stab, eff, True, 0.85)
                                d_hi = dano_variante(var, lvl, g["poder"], s, dd, stab, eff, True, 1.0)
                            if d_lo <= amt <= d_hi:
                                ok += 1
                            else:
                                err += min(abs(amt - d_lo), abs(amt - d_hi))
                        if melhor is None or (ok, -err) > (melhor[0], -melhor[1]):
                            melhor = (ok, err)
                    nivel_faixa = am[0][1]["level"] if lado == "aliado" else nivel_s
                    cel = res[var][lado][faixa_de(nivel_faixa)]
                    cel[0] += len(am)
                    cel[1] += melhor[0]
                    cel[2] += melhor[1]
                    pg = por_gravacao[var][arq]
                    pg[0] += len(am)
                    pg[1] += melhor[0]
    return res, por_gravacao


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    ap.add_argument("--md")
    ap.add_argument("--variantes", default="c,a,b,e,d")
    a = ap.parse_args()
    variantes = a.variantes.split(",")
    especies = {e["id"]: e for e in R.carregar(os.path.join(RAIZ, "dados", "gerados", "especies.json"))}
    hunts = {h["slug"]: h for h in R.carregar(os.path.join(RAIZ, "dados", "gerados", "hunts.json"))}
    base = os.path.join(RAIZ, "poke har", "gravacoes")
    arquivos = sorted(set(glob.glob(os.path.join(base, "*.jsonl")) + glob.glob(os.path.join(base, "fase3", "*.jsonl"))
                          + glob.glob(os.path.join(base, "fase 4", "*.jsonl"))))
    arquivos = [x for x in arquivos if "gravacoes_unicas" not in x]   # agregado de outras gravações (duplicaria)
    ind = {}
    for f in arquivos:
        ind.update(coletar(f))
    res, por_g = avaliar(ind, especies, hunts, variantes)
    linhas = ["# Ajuste da fórmula de dano (fase 4, item 1)", "",
              "Gerado por `ferramentas/fase4/ajustar_dano.py` sobre %d gravações. Golpe explicado = cabe no envelope "
              "[aleatório 0,85; 1,00] com o melhor valor do stat desconhecido do selvagem (um por indivíduo × golpe). "
              "Erro = soma, nos não explicados, da distância ao envelope, dividida pelo nº de golpes." % len(arquivos), ""]
    for lado in ("aliado", "selvagem"):
        linhas += ["## %s → %s (faixa = nível do atacante)" % (("Aliado", "selvagem") if lado == "aliado" else ("Selvagem", "aliado")), "",
                   "| faixa | golpes | " + " | ".join("%s: explicados · erro médio" % v for v in variantes) + " |",
                   "|---|---|" + "---|" * len(variantes)]
        faixas = sorted({f for v in variantes for f in res[v][lado]}, key=lambda s: int(s.split("–")[0]))
        for fx in faixas:
            n = res[variantes[0]][lado][fx][0]
            cel = []
            for v in variantes:
                t, ok, err = res[v][lado][fx]
                cel.append("%.1f%% · %.2f" % (100.0 * ok / max(1, t), err / max(1, t)))
            linhas.append("| %s | %d | %s |" % (fx, n, " | ".join(cel)))
        linhas.append("")
    linhas += ["## Por gravação (os dois lados)", "", "| gravação | golpes | " + " | ".join(variantes) + " |", "|---|---|" + "---|" * len(variantes)]
    for arq in sorted(por_g[variantes[0]]):
        n = por_g[variantes[0]][arq][0]
        if n == 0:
            continue
        linhas.append("| %s | %d | %s |" % (arq, n, " | ".join("%.1f%%" % (100.0 * por_g[v][arq][1] / n) for v in variantes)))
    md = "\n".join(linhas) + "\n"
    print(md)
    if a.md:
        os.makedirs(os.path.dirname(a.md), exist_ok=True)
        open(a.md, "w", encoding="utf-8", newline="\n").write(md)
    if a.json:
        json.dump({v: {l: dict(res[v][l]) for l in res[v]} for v in variantes}, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
