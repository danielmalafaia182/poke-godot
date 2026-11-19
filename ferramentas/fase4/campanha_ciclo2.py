#!/usr/bin/env python3
"""Campanha do ciclo 2 (testes/campanha.gd --completo 1): tudo que o offline tem ligado, VIP numa rodada sim e noutra não.

Metas de tempo (horas de jogo ativo e dias de calendário, com 16 h ativas + soneca por dia), parcelas extras (soneca,
tarefas, Daily Kill/Catch, Streak), shinies, as metas visíveis no trecho 150–500 (hunt recomendada, próxima meta, marcos)
e se a hunt recomendada matou. Metas não alcançadas: projeção pela curva de XP (A) com o XP/h das últimas 40 h (estimativa).
O multiplicador de XP por região (classe 3, proposta) é aplicado por cima da projeção: o tempo de 500 → 2000 divide pelo
multiplicador de Orre (de 500 a 2000 o jogador caça em Orre; a Nightmare só abre no 2000).

Uso: python -I ferramentas/fase4/campanha_ciclo2.py saida_testes/campanha_c2_vip.json saida_testes/campanha_c2_semvip.json
     [--anterior saida_testes/campanha.json] [--md dados/relatorios/campanha_ciclo2_<data>.md]
"""
import argparse
import json
import sys

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from campanha_metas import xp, nivel_de  # noqa: E402


def metas(d):
    lt = d["linha_tempo"]
    m = {}
    for x in lt:
        t = nivel_de(x["treinador"], 1)
        if x.get("evoluiu") and x["evoluiu"] not in m:
            m[x["evoluiu"]] = (x["h"], x.get("dias"))
        for alvo, nome in ((150, "Outland (150)"), (500, "Orre (500)"), (2000, "Nightmare (2000)")):
            if t >= alvo and nome not in m:
                m[nome] = (x["h"], x.get("dias"))
    h_fim = lt[-1]["h"]
    d_fim = lt[-1].get("dias") or h_fim / 24
    t_fim = nivel_de(lt[-1]["treinador"], 1)
    ini = next((x for x in lt if x["h"] >= h_fim - 40), lt[0])
    xp_h = (xp(t_fim) - xp(nivel_de(ini["treinador"], 0))) / max(1e-9, h_fim - ini["h"] + 1)
    dias_por_h = d_fim / h_fim if h_fim else 1 / 16
    proj = {}
    for alvo, nome in ((500, "Orre (500)"), (2000, "Nightmare (2000)")):
        if nome not in m and xp_h > 0:
            h = h_fim + (xp(alvo) - xp(t_fim)) / xp_h
            proj[nome] = (h, h * dias_por_h)
    return m, proj, xp_h, h_fim, t_fim, dias_por_h


def fmt(v):
    return f"{v:,.0f}".replace(",", ".")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("vip")
    ap.add_argument("semvip")
    ap.add_argument("--anterior")
    ap.add_argument("--md")
    ap.add_argument("--mult_orre", type=float, default=0)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    rod = {"VIP": json.load(open(a.vip, encoding="utf-8")), "sem VIP": json.load(open(a.semvip, encoding="utf-8"))}
    res = {k: metas(v) for k, v in rod.items()}
    L = ["# Campanha do ciclo 2: tudo ligado, VIP e sem VIP", "",
         "Fonte: `testes/campanha.gd --completo 1` (sim pura, Geodude Lv.1 do jogo novo, política do jogador E no cabeçalho do "
         "script). Cada dia de calendário = 16 h de jogo ativo + 8 h de Modo Soneca. Ligado: soneca, Streak (trilha EXP), "
         "Daily Gift/Kill/Catch, Quests & Tasks, boosts do Gift, Tipo do Dia, Auto-Catch Shiny, garantia de pedra (3×). "
         "Insígnias: 0 (sem luta de ginásio offline).", ""]
    for k, (m, proj, xp_h, h_fim, t_fim, _) in res.items():
        d = rod[k]
        L.append(f"- **{k}**: {h_fim:.0f} h ativas ({d['linha_tempo'][-1].get('dias', 0):.1f} dias), treinador {t_fim}, "
                 f"{d['especie_final']} {d['lider_final']}, {len(d['linha_tempo'])} sessões, {d['segundos_reais'] / 60:.0f} min reais.")
    L += ["", "## Metas de tempo", "", "| Meta | VIP: horas ativas · dias | Sem VIP: horas ativas · dias |", "| --- | --- | --- |"]
    ant = None
    if a.anterior:
        am = metas(json.load(open(a.anterior, encoding="utf-8")))
        ant = am
    for nome in ("Graveler", "Golem", "Outland (150)", "Orre (500)", "Nightmare (2000)"):
        cel = []
        for k in rod:
            m, proj = res[k][0], res[k][1]
            if nome in m:
                h, dd = m[nome]
                cel.append(f"**{h:.0f} h** · {dd:.1f} d" if dd is not None else f"**{h:.0f} h**")
            elif nome in proj:
                h, dd = proj[nome]
                cel.append(f"~{fmt(h)} h · ~{fmt(dd)} d (projeção)")
            else:
                cel.append("—")
        L.append(f"| {nome} | {cel[0]} | {cel[1]} |")
    if ant:
        L += ["", "Ciclo 1 (sem nada disso, sessões de 60 min, mesma política): "
              + ", ".join(f"{n} {ant[0][n][0]:.0f} h" for n in ("Graveler", "Golem", "Outland (150)") if n in ant[0])
              + "; Orre e Nightmare só por projeção."]
    L += ["", "## De onde veio o XP do treinador (parcelas fora da caça normal)", "",
          "| Parcela | VIP | Sem VIP |", "| --- | --- | --- |"]
    for chave, nome in (("soneca_xp", "Modo Soneca (50% da taxa, 8 h/dia)"), ("tarefas_xp", "Quests & Tasks"), ("kill_xp", "Daily Kill"),
                        ("catch_xp", "Daily Catch"), ("streak_pontos", "Pontos de Streak comprados (EXP)"), ("streak_ouro", "Ouro gasto no Streak"),
                        ("gift", "Daily Gift coletados"), ("tarefas", "Tarefas entregues"), ("kills_diarios", "Daily Kill completas"),
                        ("shiny_vistos", "Shinies abatidos"), ("shiny_capturados", "Shinies capturados (aprox.)")):
        L.append(f"| {nome} | {fmt(rod['VIP']['extras'].get(chave, 0))} | {fmt(rod['sem VIP']['extras'].get(chave, 0))} |")
    for k in rod:
        tot = xp(res[k][4])
        e = rod[k]["extras"]
        fora = e.get("soneca_xp", 0) + e.get("tarefas_xp", 0) + e.get("kill_xp", 0) + e.get("catch_xp", 0)
        L.append(f"\n{k}: {100 * fora / max(1, tot):.1f}% do XP total veio dessas parcelas.")
    # metas visíveis 150–500
    L += ["", "## Metas visíveis no trecho 150–500 (sim/metas.gd)", "",
          "O que a cidade mostrava como próxima meta, cada vez que mudou (rodada VIP):", "",
          "| Hora | Treinador | Líder | Hunt recomendada | Próxima meta |", "| --- | --- | --- | --- | --- |"]
    ult = None
    mortes_rec = 0
    sess_rec = 0
    for x in rod["VIP"]["linha_tempo"]:
        mt = x.get("metas", {})
        if not mt:
            continue
        if x["slug"] == mt.get("rec"):
            sess_rec += 1
            mortes_rec += 1 if x["morte"] else 0
        t = nivel_de(x["treinador"], 1)
        chave = (mt.get("rec"), mt.get("prox"), mt.get("prox_lv"), mt.get("marco"))
        if t >= 140 and chave != ult:
            ult = chave
            if mt.get("prox"):
                pm = f"líder {mt['prox_lv']}: " + ("golpe a menos" if mt.get("prox_salto") else f"trocar para {mt['prox']}") + f" (+{mt['prox_ganho']}%)"
            else:
                pm = f"marco do treinador {mt.get('marco')}"
            L.append(f"| {x['h']:.0f} | {t} | {x['lider']} | {mt.get('rec')} | {pm} |")
    L += ["", f"Sessões na hunt recomendada: {sess_rec}, com {mortes_rec} mortes (o critério de Power da recomendação não manda o jogador morrer).", "",
          "Marcos (hora de jogo ativo em que cada um foi visto, rodada VIP): "
          + ", ".join(f"{k.replace('nivel_', 'treinador ').replace('colecao_', 'coleção ')} {v:.0f} h" for k, v in sorted(rod["VIP"]["marcos"].items(), key=lambda kv: kv[1])), ""]
    # multiplicador
    m, proj, xp_h, h_fim, t_fim, dph = res["VIP"]
    if "Orre (500)" in m:
        h500 = m["Orre (500)"][0]
    else:
        h500 = proj.get("Orre (500)", (0, 0))[0]
    h2000 = proj.get("Nightmare (2000)", (0, 0))[0]
    if h2000:
        trecho = h2000 - h500
        L += ["## Multiplicador de XP por região (classe 3, proposta; `xp_regiao` em balanceamento.json, padrão 1)", "",
              f"Rodada VIP: 500 → 2000 leva ~{fmt(trecho)} h ativas pela projeção (~{fmt(trecho * dph)} dias). De 500 a 2000 o jogador caça em "
              "Orre (a Nightmare só abre no 2000), então o tempo desse trecho divide pelo multiplicador de Orre:", "",
              "| Multiplicador de Orre | 500 → 2000 (h ativas) | dias de calendário | Nightmare no total |", "| --- | --- | --- | --- |"]
        for mult in (1, 2, 5, 10, 20, 40):
            L.append(f"| ×{mult} | {fmt(trecho / mult)} | {fmt(trecho / mult * dph)} | ~{fmt(h500 + trecho / mult)} h · ~{fmt((h500 + trecho / mult) * dph)} d |")
    txt = "\n".join(L) + "\n"
    print(txt)
    if a.md:
        open(a.md, "w", encoding="utf-8", newline="\n").write(txt)


if __name__ == "__main__":
    main()
