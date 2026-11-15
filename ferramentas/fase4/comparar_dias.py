#!/usr/bin/env python3
"""Fase 4 (15/11): o servidor mudou entre 09/11 e 10/11? (hipótese levantada pela defesa do selvagem de nível 1:
geodude-10min, 09/11, pede ~0,95; S1/S2, 10/11, pedem 0,77). Só investiga: aplica as mesmas regras do processador de
gravações (ferramentas/processar_gravacao.py) a todas as gravações, separa por dia (UTC do 1º serverNow) e compara
grandezas que não dependem do time: HP do aliado/selvagem, XP base/VIP/debuff, loot × tabela, passos, cadência, pisos,
fórmula de dano por faixa, e o maxHp dos selvagens por espécie e hunt.
Uso: python -I ferramentas/fase4/comparar_dias.py [--md dados/relatorios/servidor_09x10.md]
"""
import argparse
import datetime as D
import math
import random
import re
import glob
import json
import os
import statistics
import sys
from collections import Counter, defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas"))
import processar_gravacao as P   # noqa: E402


def dia_de(caminho):
    for l in open(caminho, encoding="utf-8", errors="replace"):
        try:
            o = json.loads(l)
        except Exception:
            continue
        m = o.get("msg")
        if isinstance(m, dict) and m.get("serverNow"):
            return D.datetime.fromtimestamp(m["serverNow"] / 1000, D.timezone.utc).strftime("%Y-%m-%d")
    return None


def maxhp_por_especie(caminho):
    """(slug, espécie, nível da hunt) -> lista de maxHp distintos por indivíduo (huntKey sem :rN, slot)."""
    r = defaultdict(dict)
    slug = hk = None
    for o in P.linhas(caminho):
        m = o["msg"]
        if m.get("type") == "field-init":
            slug, hk = m.get("slug"), str(m.get("huntKey", "")).split(":r")[0]
        elif m.get("type") == "field" and slug:
            for mb in m.get("mobs", []):
                r[(slug, mb["speciesId"])][(hk, mb["slot"])] = int(mb["maxHp"])
    return {k: list(v.values()) for k, v in r.items()}


def prevista(esp, sid, nivel, n=40000):
    """maxHp previsto pela fórmula da sim (IV 1..32, Quality pelos pesos de sim/regras.gd): média e desvio."""
    s = open(os.path.join(RAIZ, "sim", "regras.gd"), encoding="utf-8").read()
    i = s.index("[0.8, 0.9, 5.0]")
    faixas = [tuple(map(float, m)) for m in re.findall(r"\[([0-9.]+), ([0-9.]+), ([0-9.]+)\]", s[i - 300:i + 600])]
    tot = sum(w for _, _, w in faixas)
    rnd = random.Random(sid * 1000 + nivel)
    v = []
    b = esp[sid]["base"]["hp"]
    for _ in range(n):
        r = rnd.random() * tot
        q = faixas[-1][1]
        for lo, hi, w in faixas:
            if r < w:
                q = lo + rnd.random() * (hi - lo)
                break
            r -= w
        iv = 1 + int(32 * rnd.random())
        v.append(max(120, 35 * round(nivel / 100 * (b + 2 * iv) * q ** 0.95)))
    return statistics.mean(v), statistics.pstdev(v)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", default=os.path.join(RAIZ, "dados", "relatorios", "servidor_09x10.md"))
    a = ap.parse_args()
    base = os.path.join(RAIZ, "poke har", "gravacoes")
    arqs = sorted(set(glob.glob(os.path.join(base, "*.jsonl")) + glob.glob(os.path.join(base, "fase3", "*.jsonl"))
                      + glob.glob(os.path.join(base, "fase 4", "*.jsonl"))))
    arqs = [x for x in arqs if "gravacoes_unicas" not in x and "poke_ws_todas" not in x]   # agregados/duplicatas
    por_regra = defaultdict(lambda: defaultdict(Counter))   # regra -> dia -> status
    detalhes = defaultdict(list)
    hp = defaultdict(lambda: defaultdict(list))              # (slug, espécie) -> dia -> maxHp
    for c in arqs:
        d = dia_de(c)
        if not d:
            continue
        R, _ = P.processar(c, sem_dano=False)
        for regra, _, st, det in R.itens:
            chave = regra.split(" (")[0] if "Fórmula de dano" not in regra and "Loot" not in regra else regra
            por_regra[chave][d][st] += 1
            if st == P.CONTRADISSE:
                detalhes[chave].append("%s (%s): %s" % (os.path.basename(c), d, det))
        for k, v in maxhp_por_especie(c).items():
            hp[k][d] += v
    dias = sorted({d for r in por_regra.values() for d in r})
    l = ["# O servidor mudou entre 09/11 e 10/11? (fase 4, 15/11)", "",
         "Gerado por `ferramentas/fase4/comparar_dias.py`: as regras do processador de gravações aplicadas a todas as gravações,",
         "por dia (UTC). Cada célula: confirmou / contradisse / inconclusivo (nº de verificações).", "",
         "| Regra | " + " | ".join(dias) + " |", "|---|" + "---|" * len(dias)]
    for regra in sorted(por_regra):
        cel = []
        for d in dias:
            c = por_regra[regra].get(d)
            cel.append("%d/%d/%d" % (c[P.CONFIRMOU], c[P.CONTRADISSE], c[P.INCONCLUSIVO]) if c else "—")
        l.append("| %s | %s |" % (regra, " | ".join(cel)))
    l += ["", "## Contradições", ""]
    for regra, ds in sorted(detalhes.items()):
        for x in ds:
            l.append("- %s — %s" % (regra, x))
    l += ["", "## maxHp dos selvagens por espécie e hunt (indivíduos) em mais de um dia", "",
          "| Hunt, espécie | Dia: n, mín–média–máx, múltiplos de 35 |", "|---|---|"]
    for k, porDia in sorted(hp.items()):
        if len(porDia) < 2:
            continue
        cel = []
        for d, v in sorted(porDia.items()):
            cel.append("%s: %d, %d–%.0f–%d, %d%%" % (d, len(v), min(v), statistics.mean(v), max(v), 100 * sum(1 for x in v if x % 35 == 0 or x == 120) // len(v)))
        l.append("| %s, %s | %s |" % (k[0], k[1], " · ".join(cel)))
    esp = {e["id"]: e for e in json.load(open(os.path.join(RAIZ, "dados", "gerados", "especies.json"), encoding="utf-8"))}
    hunts = {h["slug"]: h for h in json.load(open(os.path.join(RAIZ, "dados", "gerados", "hunts.json"), encoding="utf-8"))}
    l += ["", "## maxHp dos selvagens × o previsto pela fórmula da sim (grupos com 10+ indivíduos)", "",
          "Se o servidor tivesse mudado a forma de sortear os stats dos selvagens, os dias depois de 09/11 sairiam deslocados.", "",
          "| Dia | Hunt | Espécie | Nível | Indivíduos | Média obs. | Média prevista | z |", "|---|---|---|---|---|---|---|---|"]
    zs = defaultdict(list)
    for (slug, sid), porDia in sorted(hp.items()):
        h = hunts.get(slug)
        if not h or sid not in esp:
            continue
        for d, v in sorted(porDia.items()):
            if len(v) < 10:
                continue
            m, sd = prevista(esp, sid, int(h["nivel"]))
            if sd <= 0:
                l.append("| %s | %s | %s | %d | %d | %.0f | 120 | sem informação: o piso de 120 cobre todos (previsto) |" % (d, slug, esp[sid]["nome"], h["nivel"], len(v), statistics.mean(v)))
                continue
            if max(v) == 120 and m > 240:
                l.append("| %s | %s | %s | %d | %d | %.0f | %.0f | fora: todos no piso 120, o nível do selvagem não é o da hunt |" % (d, slug, esp[sid]["nome"], h["nivel"], len(v), statistics.mean(v), m))
                continue
            z = (statistics.mean(v) - m) / (sd / math.sqrt(len(v)))
            zs[d].append(z)
            l.append("| %s | %s | %s | %d | %d | %.0f | %.0f | %.2f |" % (d, slug, esp[sid]["nome"], h["nivel"], len(v), statistics.mean(v), m, z))
    l += ["", "z médio por dia: " + ", ".join("%s %.2f (%d grupos)" % (d, statistics.mean(v), len(v)) for d, v in sorted(zs.items()))]
    md = "\n".join(l) + "\n"
    os.makedirs(os.path.dirname(a.md), exist_ok=True)
    open(a.md, "w", encoding="utf-8", newline="\n").write(md)
    print(md)


if __name__ == "__main__":
    main()
