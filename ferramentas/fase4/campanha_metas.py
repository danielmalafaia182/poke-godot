#!/usr/bin/env python3
"""Campanha com metas (testes/campanha.gd): tempo até Graveler, Golem, Outland (150), Orre (500) e Nightmare (2000), e os
muros de progressão (trechos longos sem subir de nível), com proposta de solução (sem aplicar).

Lê a linha do tempo da campanha (o .json do fim ou, se a campanha ainda roda, as linhas SESSAO do .log). Metas não
alcançadas são projetadas pela curva de XP (A, a mesma do Pokémon e do treinador) com o XP/h das últimas 20 h: estimativa,
marcada como tal.

Uso: python -I ferramentas/fase4/campanha_metas.py saida_testes/campanha_longa.log [--md dados/relatorios/campanha_metas_<data>.md]
"""
import argparse
import json
import math
import sys


def cub(n):
    return 0 if n <= 1 else round(50 / 3 * (n ** 3 - 6 * n ** 2 + 17 * n - 12))


def xp(n):
    if n <= 150:
        return cub(n)
    t = n - 150
    if t <= 100:
        tri = t * (t + 1) / 2
        return round(cub(150) + 0.5 * tri ** 2 + t * (t + 1) * (2 * t + 1) / 6 * 197.5 + tri * 25629.0 + 1087900.0 * t)
    return round(xp(250) + 2.0 * (cub(n) - cub(250)))


def ler(caminho):
    if caminho.endswith(".json"):
        return json.load(open(caminho, encoding="utf-8"))["linha_tempo"]
    lt = []
    for l in open(caminho, encoding="utf-8", errors="replace"):
        if l.startswith("SESSAO "):
            lt.append(json.loads(l[7:]))
    return lt


def nivel_de(s, i):
    a, b = s.split("→")
    return int(a if i == 0 else b)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("entrada")
    ap.add_argument("--md")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    lt = ler(a.entrada)
    metas = {}
    for x in lt:
        t = nivel_de(x["treinador"], 1)
        if x.get("evoluiu") and x["evoluiu"] not in metas:
            metas[x["evoluiu"]] = x["h"]
        for alvo, nome in ((150, "Outland (treinador 150)"), (500, "Orre (treinador 500)"), (2000, "Nightmare (treinador 2000)")):
            if t >= alvo and nome not in metas:
                metas[nome] = x["h"]
    h_fim = lt[-1]["h"]
    t_fim = nivel_de(lt[-1]["treinador"], 1)
    # XP/h do treinador nas últimas 20 h (pela curva)
    ini = next((x for x in lt if x["h"] >= h_fim - 20), lt[0])
    t_ini = nivel_de(ini["treinador"], 0)
    xp_h = (xp(t_fim) - xp(t_ini)) / max(1e-9, h_fim - (ini["h"] - 1))
    proj = {}
    for alvo, nome in ((500, "Orre (treinador 500)"), (2000, "Nightmare (treinador 2000)")):
        if nome not in metas and xp_h > 0:
            proj[nome] = h_fim + (xp(alvo) - xp(t_fim)) / xp_h
    # muros: janelas de 10 h com no máximo 1 nível de treinador, a partir do nível 20; e sessões repetidas com morte
    muros = []
    i = 0
    while i < len(lt):
        j = i
        while j + 1 < len(lt) and lt[j + 1]["h"] - lt[i]["h"] <= 10:
            j += 1
        ganho = nivel_de(lt[j]["treinador"], 1) - nivel_de(lt[i]["treinador"], 0)
        if lt[j]["h"] - lt[i]["h"] >= 8 and ganho <= 1 and nivel_de(lt[i]["treinador"], 0) >= 20:
            k = j
            while k + 1 < len(lt) and nivel_de(lt[k + 1]["treinador"], 1) - nivel_de(lt[i]["treinador"], 0) <= max(1, ganho):
                k += 1
            muros.append((lt[i], lt[k]))
            i = k + 1
        else:
            i += 1
    linhas = ["# Campanha com metas e muros", "",
              f"Fonte: `testes/campanha.gd` (Geodude Lv.1 do jogo novo, política do jogador E no cabeçalho do script), {len(lt)} sessões, "
              f"{h_fim:.0f} h simuladas; no fim, treinador {t_fim} e líder {lt[-1]['lider'].split(' ')[0]} {nivel_de(lt[-1]['lider'].split(' ')[1], 1)}.", "",
              "## Metas", "", "| Meta | Tempo de jogo |", "| --- | --- |"]
    for nome in ("Graveler", "Golem", "Outland (treinador 150)", "Orre (treinador 500)", "Nightmare (treinador 2000)"):
        if nome in metas:
            linhas.append(f"| {nome} | **{metas[nome]:.0f} h** |")
        elif nome in proj:
            linhas.append(f"| {nome} | não alcançado em {h_fim:.0f} h; projeção pela curva de XP com o ritmo das últimas 20 h "
                          f"({xp_h / 1e6:.1f} M XP/h): **~{proj[nome]:,.0f} h** (estimativa) |".replace(",", "."))
        else:
            linhas.append(f"| {nome} | não alcançado |")
    linhas += ["", "XP total pedida (curva A): treinador 150 = %s, 500 = %s, 2000 = %s." % tuple(f"{xp(n):,}".replace(",", ".") for n in (150, 500, 2000)), "",
               "## Muros (janelas de ~10 h com no máximo 1 nível de treinador)", "",
               "| De (h) | Até (h) | Duração | Treinador | Líder | Onde |", "| --- | --- | --- | --- | --- | --- |"]
    for x, y in muros:
        hunts = sorted({z["slug"] for z in lt if x["h"] <= z["h"] <= y["h"]})
        linhas.append(f"| {x['h'] - 1:.0f} | {y['h']:.0f} | {y['h'] - x['h'] + 1:.0f} h | {x['treinador'].split('→')[0]}→{y['treinador'].split('→')[1]} | "
                      f"{x['lider'].split('→')[0]}→{y['lider'].split('→')[1]} | {', '.join(hunts[:5])} |")
    txt = "\n".join(linhas) + "\n"
    print(txt)
    if a.md:
        open(a.md, "w", encoding="utf-8", newline="\n").write(txt)


if __name__ == "__main__":
    main()
