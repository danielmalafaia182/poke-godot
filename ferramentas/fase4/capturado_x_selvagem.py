#!/usr/bin/env python3
"""O capturado é o mesmo indivíduo do selvagem? (A, todas as gravações com captura) — fecha IV e Quality do capturado.

Para cada captura com sucesso: o selvagem no tile do catch-result no field anterior (maxHp, espécie, nível da hunt) e o
poke-delta do capturado que chega em seguida (nível 1, quality, ivTotal, stats exibidos).
Teste: o maxHp do selvagem é max(120, 35 × round(L/100 × (base_hp + 2·IV_hp) × Q^0,95)) (A, CLAUDE.md). Com a Quality
do CAPTURADO, existe IV_hp em 1..32 que dá o maxHp observado? Só vale para maxHp > 120 (no piso não há informação).
Comparação: com uma Quality sorteada pelos pesos do cliente (C), a fração de casos compatíveis por acaso.
Também: os stats exibidos do capturado no nível 1 batem com a fórmula (round(1/100 × (base + 2·IV) × Q^exp)) para algum
IV, com o ivTotal exibido (A + C)?

Uso: python -I ferramentas/fase4/capturado_x_selvagem.py [gravações...] [--md saida.md]
"""
import argparse
import glob
import itertools
import json
import os
import random
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402

ESP = {e["id"]: e for e in json.load(open(os.path.join(RAIZ, "dados", "gerados", "especies.json"), encoding="utf-8"))}
HUNTS = {h["slug"]: h for h in json.load(open(os.path.join(RAIZ, "dados", "gerados", "hunts.json"), encoding="utf-8"))}
# pesos de Quality do cliente (C, rollQuality; mesma tabela de sim/regras.gd)
FAIXAS_Q = [(0.8, 0.9, 5.0), (0.9, 1.0, 5.0), (1.0, 1.1, 34.03846), (1.1, 1.2, 20.0), (1.2, 1.3, 10.0), (1.3, 1.4, 10.0),
            (1.4, 1.5, 10.0), (1.5, 1.6, 5.0), (1.7, 1.8, 0.67308), (1.8, 1.8001, 0.28846)]
EXP = {"hp": 0.95, "speed": 0.95}


def js_round(x):
    import math
    return math.floor(x + 0.5)


def stat(base, iv, nivel, q, chave):
    return js_round(nivel / 100.0 * (base + 2 * iv) * q ** EXP.get(chave, 0.8))


def maxhp_compativel(esp, nivel, q, maxhp):
    base = esp["base"]["hp"]
    return [iv for iv in range(1, 33) if max(120, 35 * stat(base, iv, nivel, q, "hp")) == maxhp]


def stats_n1_compativeis(esp, q, stats, iv_total):
    """Existe um vetor de IVs (1..32) com a soma ivTotal que dá os stats exibidos no nível 1?"""
    opcoes = []
    for k in ("hp", "atk", "def", "spAtk", "spDef", "speed"):
        ivs = [iv for iv in range(1, 33) if stat(esp["base"][k], iv, 1, q, k) == stats[k]]
        if not ivs:
            return False
        opcoes.append((min(ivs), max(ivs)))
    return sum(a for a, _ in opcoes) <= iv_total <= sum(b for _, b in opcoes)


def q_aleatoria(rng):
    tot = sum(p for _, _, p in FAIXAS_Q)
    x = rng.random() * tot
    for a, b, p in FAIXAS_Q:
        if x < p:
            return a + rng.random() * (b - a)
        x -= p
    return 1.0


def coletar(arqs):
    casos = []
    for arq in arqs:
        slug = None
        ultimo = None
        pend = []
        for d, m, _ in ler_logs([arq]):
            if d != "in":
                continue
            t = m.get("type")
            if t == "field-init":
                slug = m.get("slug")
            elif t == "field":
                ultimo = m
            elif t == "catch-result" and m.get("success") and ultimo and slug in HUNTS:
                x = next((y for y in ultimo["mobs"] if y["row"] == m.get("row") and y["col"] == m.get("col")), None)
                if x:
                    pend.append({"gravacao": os.path.basename(arq), "slug": slug, "nivel": int(HUNTS[slug]["nivel"]),
                                 "speciesId": x["speciesId"], "maxHp": x["maxHp"], "shiny": bool(x.get("shiny"))})
            elif t == "poke-delta" and pend:
                p = m["poke"]
                if p.get("level") == 1 and not p.get("team") and p.get("speciesId") == pend[0]["speciesId"]:
                    c = pend.pop(0)
                    c.update({"quality": p.get("quality"), "ivTotal": p.get("ivTotal"), "stats": p.get("stats")})
                    casos.append(c)
    return casos


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="*")
    ap.add_argument("--md")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    arqs = a.arquivos or sorted(glob.glob(os.path.join(RAIZ, "poke har", "gravacoes", "**", "*.jsonl"), recursive=True))
    arqs = [x for x in arqs if "gravacoes_unicas" not in x]
    casos = coletar(arqs)
    rng = random.Random(1)
    info = [c for c in casos if c["maxHp"] > 120]
    ok = sum(1 for c in info if maxhp_compativel(ESP[c["speciesId"]], c["nivel"], c["quality"], c["maxHp"]))
    acaso = []
    for c in info:
        n = sum(1 for _ in range(400) if maxhp_compativel(ESP[c["speciesId"]], c["nivel"], q_aleatoria(rng), c["maxHp"]))
        acaso.append(n / 400.0)
    n1 = [c for c in casos if c.get("stats")]
    n1_ok = sum(1 for c in n1 if stats_n1_compativeis(ESP[c["speciesId"]], c["quality"], c["stats"], c["ivTotal"]))
    linhas = ["# Capturado × selvagem (A)\n",
              f"{len(casos)} capturas casadas com o poke-delta do capturado; {len(info)} com maxHp do selvagem acima do piso de 120.\n",
              "| Teste | Resultado |", "| --- | --- |",
              f"| maxHp do selvagem explicado com a Quality do capturado (algum IV_hp 1..32) | **{ok}/{len(info)}** |",
              f"| O mesmo com uma Quality sorteada pelos pesos do cliente (esperado por acaso) | {sum(acaso):.1f}/{len(info)} ({100 * sum(acaso) / max(1, len(info)):.0f}%) |",
              f"| Stats exibidos do capturado no nível 1 coerentes com quality + ivTotal (IV 1..32, fórmula C) | **{n1_ok}/{len(n1)}** |", ""]
    # distribuição da Quality e do ivTotal dos capturados × sorteio do cliente (C: rollQuality, IV 1..32 uniforme)
    tot = sum(p for _, _, p in FAIXAS_Q)
    qs = [c["quality"] for c in casos]
    ivt = [c["ivTotal"] for c in casos]
    linhas += ["| Faixa de Quality | Capturados | Esperado pelo cliente |", "| --- | --- | --- |"]
    chi = 0.0
    for lo, hi, p in FAIXAS_Q:
        n = sum(1 for q in qs if lo <= q < hi)
        e = len(qs) * p / tot
        chi += (n - e) ** 2 / e if e > 1 else 0.0
        linhas.append(f"| {lo:.1f}–{hi:.1f} | {n} | {e:.1f} |")
    import statistics
    linhas += [f"| fora das faixas (a 1,6–1,7 não existe) | {sum(1 for q in qs if not any(lo <= q < hi for lo, hi, _ in FAIXAS_Q))} | 0 |", "",
               f"χ² = {chi:.1f} (faixas com esperado > 1; {sum(1 for _, _, p in FAIXAS_Q if len(qs) * p / tot > 1) - 1} graus de liberdade). "
               f"ivTotal: média {statistics.mean(ivt):.1f}, dp {statistics.pstdev(ivt):.1f}, de {min(ivt)} a {max(ivt)} "
               f"(seis IV uniformes 1..32: média 99, dp 22,6).", ""]
    linhas.append("| Gravação | Hunt (nível) | Espécie | maxHp do selvagem | Quality do capturado | ivTotal | IV_hp compatíveis | Por acaso |")
    linhas.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for c, pa in zip(info, acaso):
        ivs = maxhp_compativel(ESP[c["speciesId"]], c["nivel"], c["quality"], c["maxHp"])
        linhas.append(f"| {c['gravacao']} | {c['slug']} ({c['nivel']}) | {ESP[c['speciesId']]['nome']}{' ✨' if c['shiny'] else ''} | {c['maxHp']} | "
                      f"{c['quality']} | {c['ivTotal']} | {(str(min(ivs)) + '–' + str(max(ivs))) if ivs else 'nenhum'} | {100 * pa:.0f}% |")
    txt = "\n".join(linhas)
    print(txt)
    if a.md:
        open(a.md, "w", encoding="utf-8", newline="\n").write(txt + "\n")


if __name__ == "__main__":
    main()
