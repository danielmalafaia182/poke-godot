#!/usr/bin/env python3
"""Validador da classe 2 (ESTRATEGIA.md): resultado por trecho de hunt, real × sim, ±10%.

Em vez de igualar cada grandeza do movimento (ms/tile, chegadas, borda), compara o que o jogador sente em cada trecho:
abates/min, XP/h, ouro/h (venda do loot ao Mark), mortes/h e capturas/h. Também mostra (não conta) selvagens ao lado do
herói por field e um diagnóstico de onde vem a diferença: fração do tempo lutando, golpes do aliado por abate e segundos
andando por abate.

Para cada gravação (ou pasta de gravação livre): `segmentar.py` corta os trechos; os úteis para "resultado" (≥ 5 min, líder
conhecido) são exportados com o contexto (vip, inventário, bolas, Auto-Helper, time), viram um estado inicial
(`extrair_estado_inicial.py`) e rodam na sim pela mesma duração (`testes/rodar_sim.gd`, N sementes). As mesmas contas dos
dois lados. Abates/min, XP/h e mortes/h também passam se a diferença couber em 2 desvios de Poisson da contagem do trecho
(um trecho de 6 min tem ~50 abates: o acaso sozinho varia 14%). Ouro/h também passa se a diferença couber em 2 desvios do
ruído do loot: o ouro real cabe entre os percentis 2,5 e
97,5 do que a tabela de loot (A) dá para os abates da sim, sorteando o trecho 2000 vezes (E: o loot raro e caro faz um
trecho curto variar 30–40%, e assimétrico). Uma grandeza passa se a média da sim fica a ±10% do
real; mortes/h também passam se as duas ficam abaixo de
0,5 por hora, e "ao lado/field" se a diferença for de até 0,05 (perto de zero, ±10% é ruído; E).

Uso: python -I ferramentas/validar_resultado.py [gravações ou pastas...] [--sementes 3] [--params chave=valor,...]
     [--md dados/relatorios/validar_resultado.md] [--json saida.json]
     (sem argumentos: todas as gravações de poke har/gravacoes, com a pasta livre/ como uma gravação só)
"""
import argparse
import glob
import math
import json
import os
import statistics
import subprocess
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import random

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "gravador"))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
import segmentar as SG  # noqa: E402
from gerar_protocolo import ler_logs  # noqa: E402

ITENS = {i["id"]: i for i in json.load(open(os.path.join(RAIZ, "dados", "gerados", "itens.json"), encoding="utf-8"))}
ESPECIES = {e["id"]: e for e in json.load(open(os.path.join(RAIZ, "dados", "gerados", "especies.json"), encoding="utf-8"))}
_VAR_OURO = {}


def var_ouro_abate(sid):
    """Variância do ouro de venda de um abate da espécie, pela tabela de loot (A). O loot raro e caro faz o ouro de um
    trecho curto variar 30–40% só por sorte (larvitar: média 18,6, desvio 66,7 por abate)."""
    if sid not in _VAR_OURO:
        v = 0.0
        for l in ESPECIES.get(sid, {}).get("loot", []):
            p = min(1.0, float(l.get("chance", 0)))
            lo, hi = int(l.get("min", 1)), int(l.get("max", 1))
            preco = preco_venda(l.get("itemId", 0))
            e1 = preco * (lo + hi) / 2.0
            e2 = preco * preco * sum(q * q for q in range(lo, hi + 1)) / (hi - lo + 1)
            v += p * e2 - (p * e1) ** 2
        _VAR_OURO[sid] = max(0.0, v)
    return _VAR_OURO[sid]
TOL = 0.10
Z95 = 1.96   # intervalo de 95% (ESTRATEGIA.md, critério formal da classe 2)
GRANDEZAS = [("abates_min", "Abates/min"), ("xp_h", "XP/h"), ("ouro_h", "Ouro/h"), ("mortes_h", "Mortes/h"), ("capturas_h", "Capturas/h")]
EXTRAS = [("adj", "Ao lado/field"), ("luta", "Lutando"), ("golpes_abate", "Golpes/abate"), ("andando_s", "s andando/abate")]


def preco_venda(item_id):
    """Regra do Mark (C/A, sim/servico_cidade.gd preco_venda): npcPrice; não compra cura, revive e pedra (exceto 205/206);
    nunca acima do preço de compra."""
    it = ITENS.get(int(item_id))
    if not it:
        return 0
    if it.get("categoria") in ("heal", "revive", "stone") and int(item_id) not in (205, 206):
        return 0
    p = int(it.get("precoNpc", 0) or 0)
    if int(it.get("precoGold", 0) or 0) > 0:
        p = min(p, int(it["precoGold"]))
    return p


def cheb(a, b):
    return max(abs(a["row"] - b["row"]), abs(a["col"] - b["col"]))


def medir(caminho):
    t0 = t1 = None
    abates = xp = ouro = mortes = capturas = golpes = 0
    var_ouro = 0.0
    especies = Counter()
    adj = nf = luta = 0
    ant_fainted = False
    for d, m, _ in ler_logs([caminho]):
        if d != "in":
            continue
        t = m.get("type")
        if t == "field":
            t0 = m["serverNow"] if t0 is None else t0
            t1 = m["serverNow"]
            h = m["hero"]
            adj += sum(1 for x in m["mobs"] if not x["dead"] and cheb(x, h) <= 1)
            nf += 1
            luta += int(bool(m.get("fighting")))
            golpes += sum(1 for h in m.get("hits", []) if h.get("slot", -1) >= 0)
            f = bool(m.get("fainted"))
            mortes += int(f and not ant_fainted)
            ant_fainted = f
        elif t == "field-kill":
            abates += 1
            especies[m.get("speciesId")] += 1
            var_ouro += var_ouro_abate(m.get("speciesId"))
            xp += int(m.get("xpGained", 0))
            for it in m.get("loot") or []:
                ouro += preco_venda(it.get("itemId", 0)) * int(it.get("qty", 0))
        elif t == "field-none" and m.get("motivo") == "sem-reserva":
            mortes += 1
        elif t == "catch-result" and m.get("success"):
            capturas += 1
    mins = max(1e-9, ((t1 or 0) - (t0 or 0)) / 60000.0)
    frac_luta = luta / nf if nf else 0.0
    return {"min": round(mins, 2), "abates_min": abates / mins, "xp_h": xp / mins * 60, "mortes_h": mortes / mins * 60,
            "ouro_h": ouro / mins * 60, "capturas_h": capturas / mins * 60, "adj": adj / nf if nf else 0.0,
            "luta": frac_luta, "sd_ouro_h": math.sqrt(var_ouro) / mins * 60, "especies": dict(especies), "golpes_abate": golpes / abates if abates else 0.0,
            "andando_s": (1 - frac_luta) * mins * 60 / abates if abates else 0.0}


PARAMS = ""


def rodar_sim(estado, segundos, semente, saida):
    barra = lambda c: c.replace(os.sep, "/")      # o bash do Git come as barras invertidas do Windows
    bash = os.environ.get("BASH_GIT", "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else "bash")   # o de bin/ monta /c (o de usr/bin não)
    cmd = [bash, "testes/rodar.sh", "res://testes/rodar_sim.gd", "--estado", barra(estado), "--segundos", str(int(segundos)),
           "--semente", str(semente), "--saida", barra(saida)] + (["--params", PARAMS] if PARAMS else [])
    env = dict(os.environ, TEMPO_MAX="1800")
    subprocess.run(cmd, cwd=RAIZ, capture_output=True, text=True, env=env, encoding="utf-8", errors="replace")
    return saida if os.path.exists(saida) else None


def faixa_ouro(especies, minutos, n=2000, semente=1):
    """Percentis 2,5 e 97,5 do ouro/h que a tabela de loot (A) dá para esses abates (espécie → quantidade), sorteando o
    trecho n vezes. O loot raro e caro deixa a distribuição assimétrica: a maioria dos trechos curtos fica abaixo da média."""
    rng = random.Random(semente)
    itens = []
    for sid, q in especies.items():
        for l in ESPECIES.get(sid, {}).get("loot", []):
            preco = preco_venda(l.get("itemId", 0))
            p = min(1.0, float(l.get("chance", 0)))
            if preco > 0 and p > 0:
                itens.append((int(q), p, preco * (int(l.get("min", 1)) + int(l.get("max", 1))) / 2.0))
    amostras = []
    for _ in range(n):
        g = 0.0
        for q, p, v in itens:
            g += rng.binomialvariate(q, p) * v
        amostras.append(g / max(1e-9, minutos) * 60)
    amostras.sort()
    return amostras[int(0.025 * n)], amostras[int(0.975 * n) - 1]


def passa_estrito(k, real, sims):
    """Só ±10% (com os pisos de perto de zero)."""
    if not sims:
        return False
    m = statistics.mean(sims)
    if k in ("mortes_h", "capturas_h") and real < 0.5 and m < 0.5:
        return True
    if real == 0:
        return abs(m) < 1e-9
    return abs(m - real) <= TOL * abs(real)


def passa(k, real, sims, minutos=60.0, sd=0.0, n=0, faixa=None):
    """±10%; mortes/h e capturas/h também passam se as duas forem < 0,5/h; capturas/h, se a diferença em contagem no
    trecho couber em 2 desvios de Poisson (poucas capturas por trecho: ±10% seria ruído); ao lado/field, até 0,05."""
    if not sims:
        return False
    m = statistics.mean(sims)
    if k in ("mortes_h", "capturas_h") and real < 0.5 and m < 0.5:
        return True
    if k == "capturas_h":
        nr, ns = real * minutos / 60.0, m * minutos / 60.0
        if abs(ns - nr) <= Z95 * math.sqrt(max(nr, 1.0)) * math.sqrt(1.0 + 1.0 / len(sims)):
            return True
    if k == "ouro_h" and faixa and faixa[0] <= real <= faixa[1]:
        return True                                    # o ouro real cabe no que a tabela dá para os abates da sim (95%)
    if k in ("abates_min", "xp_h", "mortes_h") and n > 0:
        # contagem de Poisson: o desvio da taxa é taxa/√n (abates e XP: n = abates; mortes: n = mortes)
        if abs(m - real) <= Z95 * abs(real) / math.sqrt(n) * math.sqrt(1.0 + 1.0 / len(sims)):
            return True
    if k == "adj" and abs(m - real) <= 0.05:          # E: perto de zero, ±10% é ruído (M3: 0,03 × 0,06)
        return True
    if real == 0:
        return abs(m) < 1e-9
    return abs(m - real) <= TOL * abs(real)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("entradas", nargs="*")
    ap.add_argument("--sementes", type=int, default=3)
    ap.add_argument("--md")
    ap.add_argument("--json")
    ap.add_argument("--pasta", default=os.path.join(RAIZ, "saida_testes", "validar_resultado"))
    ap.add_argument("--params", default="", help="parâmetros da sim para experimentar (chave=valor,...)")
    a = ap.parse_args()
    global PARAMS
    PARAMS = a.params
    sys.stdout.reconfigure(encoding="utf-8")
    livre = os.path.join(RAIZ, "poke har", "gravacoes", "livre")
    entradas = a.entradas or ([x for x in sorted(glob.glob(os.path.join(RAIZ, "poke har", "gravacoes", "**", "*.jsonl"), recursive=True))
                               if "gravacoes_unicas" not in x and "poke_ws_todas" not in x and os.sep + "livre" + os.sep not in x]
                              + ([livre] if os.path.isdir(livre) else []))
    trabalhos = []
    for e in entradas:
        nome = os.path.splitext(os.path.basename(os.path.normpath(e)))[0]
        tr = SG.segmentar([e], guardar={"resultado"})
        uteis = [x for x in tr if "resultado" in x.get("uteis", [])]
        if not uteis:
            continue
        pasta = os.path.join(a.pasta, nome)
        SG.exportar(uteis, pasta)
        for x in uteis:
            est = x["arquivo"].replace(".jsonl", ".estado.json")
            r = subprocess.run([sys.executable, "-I", os.path.join(RAIZ, "ferramentas", "gravador", "extrair_estado_inicial.py"), x["arquivo"], x["slug"], est],
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
            ok_est = r.returncode == 0 and "pokeDelta" in json.load(open(est, encoding="utf-8")) and "primeiroPokeXp" in json.load(open(est, encoding="utf-8"))
            trabalhos.append({"gravacao": nome, "trecho": x, "estado": est if ok_est else None})
    jobs = []
    for w in trabalhos:
        if not w["estado"]:
            continue
        for s in range(1, a.sementes + 1):
            jobs.append((w, s, w["trecho"]["arquivo"].replace(".jsonl", ".sim%d.jsonl" % s)))
    with ThreadPoolExecutor(max_workers=max(1, (os.cpu_count() or 4) - 1)) as ex:
        res = list(ex.map(lambda j: (j, rodar_sim(j[0]["estado"], j[0]["trecho"]["duracao_s"], j[1], j[2])), jobs))
    sims = {}
    for (w, s, _), out in res:
        if out:
            sims.setdefault(id(w), []).append(medir(out))
    linhas = ["| Gravação | Hunt | Líder (níveis) | min | " + " | ".join(n + " real · sim" for _, n in GRANDEZAS) + " | Passa |",
              "| --- | --- | --- | --- | " + " | ".join("---" for _ in GRANDEZAS) + " | --- |"]
    saida = []
    diag = ["", "Diagnóstico (não conta): real · sim", "", "| Gravação | Hunt | " + " | ".join(n for _, n in EXTRAS) + " |",
            "| --- | --- | " + " | ".join("---" for _ in EXTRAS) + " |"]
    tot_ok = tot = 0
    est_ok = 0
    por_grandeza = {k: [0, 0] for k, _ in GRANDEZAS}
    for w in trabalhos:
        x = w["trecho"]
        real = medir(x["arquivo"])
        ss = sims.get(id(w), [])
        cel = []
        oks = 0
        for k, _ in GRANDEZAS:
            vals = [s[k] for s in ss]
            n = real["abates_min"] * real["min"] if k in ("abates_min", "xp_h") else (real["mortes_h"] * real["min"] / 60.0 if k == "mortes_h" else 0)
            fx = None
            if k == "ouro_h" and ss and real["abates_min"] > 0:
                # abates da sim (média das sementes), com a mistura de espécies do real
                fator = statistics.mean([s["abates_min"] for s in ss]) / real["abates_min"]
                fx = faixa_ouro({sid: max(1, round(q * fator)) for sid, q in real["especies"].items()}, real["min"])
            ok = passa(k, real[k], vals, real["min"], real.get("sd_ouro_h", 0.0), n, fx)
            est_ok += passa_estrito(k, real[k], vals) if ss else 0
            oks += ok
            if ss:
                por_grandeza[k][0] += ok
                por_grandeza[k][1] += 1
            fmt = (lambda v: f"{v:.2f}") if k in ("abates_min", "adj", "mortes_h", "capturas_h") else (lambda v: f"{v:,.0f}".replace(",", "."))
            cel.append(f"{fmt(real[k])} · {fmt(statistics.mean(vals)) if vals else '—'}{' ✅' if ok else (' ❌' if vals else '')}")
        if ss:
            tot_ok += oks
            tot += len(GRANDEZAS)
        lider = (x["lider"] or ["?"])[0]
        linhas.append(f"| {w['gravacao']} | {x['slug']} | {lider} {x['niveis_lider']} | {real['min']:.1f} | " + " | ".join(cel) +
                      f" | {oks}/{len(GRANDEZAS) if ss else 0}{'' if ss else ' (sem estado)'} |")
        diag.append(f"| {w['gravacao']} | {x['slug']} | " + " | ".join(
            f"{real[k]:.2f} · {statistics.mean([s[k] for s in ss]):.2f}" if ss else f"{real[k]:.2f} · —" for k, _ in EXTRAS) + " |")
        saida.append({"gravacao": w["gravacao"], "slug": x["slug"], "lider": x["lider"], "real": real, "sim": ss})
    resumo = ["", f"**{tot_ok}/{tot} grandezas dentro de ±10% ou do ruído da amostra** ({est_ok}/{tot} só com ±10%) em {sum(1 for w in trabalhos if sims.get(id(w)))} trechos "
              f"({a.sementes} sementes cada). Por grandeza: " + ", ".join(f"{n} {por_grandeza[k][0]}/{por_grandeza[k][1]}" for k, n in GRANDEZAS) + "."]
    # teste de sinal: um desvio sistemático aparece como muitos trechos fora de ±10% no mesmo sentido
    sinal = []
    for k, nome in GRANDEZAS:
        acima = abaixo = 0
        for w in trabalhos:
            ss = sims.get(id(w), [])
            if not ss:
                continue
            rv = medir(w["trecho"]["arquivo"])[k]
            sv = statistics.mean([x[k] for x in ss])
            if rv > 0 and sv > rv * (1 + TOL):
                acima += 1
            elif rv > 0 and sv < rv * (1 - TOL):
                abaixo += 1
        n = acima + abaixo
        p = min(1.0, 2.0 * sum(math.comb(n, i) for i in range(min(acima, abaixo) + 1)) / 2 ** n) if n else 1.0
        sinal.append(f"{nome}: {acima} acima, {abaixo} abaixo (p = {p:.2f})")
    resumo.append("Teste de sinal dos trechos fora de ±10% (sim acima × abaixo do real; p < 0,05 = desvio sistemático): " + "; ".join(sinal) + ".")
    txt = "\n".join(linhas + resumo + diag)
    print(txt)
    if a.md:
        open(a.md, "w", encoding="utf-8", newline="\n").write(txt + "\n")
    if a.json:
        json.dump(saida, open(a.json, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
