#!/usr/bin/env python3
"""Critério de pronto do movimento (decisão do usuário, 18/11): resultado por trecho de hunt, real × sim, ±10%.

Em vez de igualar cada grandeza do movimento (ms/tile, chegadas, borda), compara o que o jogador sente em cada trecho:
abates/min, XP/h, mortes/h, ouro/h (venda do loot ao Mark) e selvagens ao lado do herói por field.

Para cada gravação (ou pasta de gravação livre): `segmentar.py` corta os trechos; os úteis para "resultado" (≥ 5 min, líder
conhecido) são exportados com o contexto (vip, inventário, bolas, Auto-Helper, time), viram um estado inicial
(`extrair_estado_inicial.py`) e rodam na sim pela mesma duração (`testes/rodar_sim.gd`, N sementes). As mesmas contas dos
dois lados. Uma grandeza passa se a média da sim fica a ±10% do real; mortes/h também passam se as duas ficam abaixo de
0,5 por hora, e "ao lado/field" se a diferença for de até 0,05 (perto de zero, ±10% é ruído; E).

Uso: python -I ferramentas/fase4/resultado_trechos.py [gravações ou pastas...] [--sementes 3] [--md saida.md] [--json saida.json]
     (sem argumentos: todas as gravações de poke har/gravacoes, inclusive livre/)
"""
import argparse
import glob
import json
import os
import statistics
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "gravador"))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
import segmentar as SG  # noqa: E402
from gerar_protocolo import ler_logs  # noqa: E402

ITENS = {i["id"]: i for i in json.load(open(os.path.join(RAIZ, "dados", "gerados", "itens.json"), encoding="utf-8"))}
TOL = 0.10
GRANDEZAS = [("abates_min", "Abates/min"), ("xp_h", "XP/h"), ("mortes_h", "Mortes/h"), ("ouro_h", "Ouro/h"), ("adj", "Ao lado/field")]


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
    abates = xp = ouro = mortes = 0
    adj = nf = 0
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
            f = bool(m.get("fainted"))
            mortes += int(f and not ant_fainted)
            ant_fainted = f
        elif t == "field-kill":
            abates += 1
            xp += int(m.get("xpGained", 0))
            for it in m.get("loot") or []:
                ouro += preco_venda(it.get("itemId", 0)) * int(it.get("qty", 0))
        elif t == "field-none" and m.get("motivo") == "sem-reserva":
            mortes += 1
    mins = max(1e-9, ((t1 or 0) - (t0 or 0)) / 60000.0)
    return {"min": round(mins, 2), "abates_min": abates / mins, "xp_h": xp / mins * 60, "mortes_h": mortes / mins * 60,
            "ouro_h": ouro / mins * 60, "adj": adj / nf if nf else 0.0}


def rodar_sim(estado, segundos, semente, saida):
    barra = lambda c: c.replace(os.sep, "/")      # o bash do Git come as barras invertidas do Windows
    bash = os.environ.get("BASH_GIT", "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else "bash")   # o de bin/ monta /c (o de usr/bin não)
    cmd = [bash, "testes/rodar.sh", "res://testes/rodar_sim.gd", "--estado", barra(estado), "--segundos", str(int(segundos)),
           "--semente", str(semente), "--saida", barra(saida)]
    env = dict(os.environ, TEMPO_MAX="1800")
    subprocess.run(cmd, cwd=RAIZ, capture_output=True, text=True, env=env, encoding="utf-8", errors="replace")
    return saida if os.path.exists(saida) else None


def passa(k, real, sims):
    if not sims:
        return False
    m = statistics.mean(sims)
    if k == "mortes_h" and real < 0.5 and m < 0.5:
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
    ap.add_argument("--pasta", default=os.path.join(RAIZ, "saida_testes", "resultado_trechos"))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    entradas = a.entradas or [x for x in sorted(glob.glob(os.path.join(RAIZ, "poke har", "gravacoes", "**", "*.jsonl"), recursive=True))
                              if "gravacoes_unicas" not in x and "poke_ws_todas" not in x]
    trabalhos = []
    for e in entradas:
        nome = os.path.splitext(os.path.basename(os.path.normpath(e)))[0]
        tr = SG.segmentar([e], guardar_msgs=True)
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
    tot_ok = tot = 0
    por_grandeza = {k: [0, 0] for k, _ in GRANDEZAS}
    for w in trabalhos:
        x = w["trecho"]
        real = medir(x["arquivo"])
        ss = sims.get(id(w), [])
        cel = []
        oks = 0
        for k, _ in GRANDEZAS:
            vals = [s[k] for s in ss]
            ok = passa(k, real[k], vals)
            oks += ok
            if ss:
                por_grandeza[k][0] += ok
                por_grandeza[k][1] += 1
            fmt = (lambda v: f"{v:.2f}") if k in ("abates_min", "adj", "mortes_h") else (lambda v: f"{v:,.0f}".replace(",", "."))
            cel.append(f"{fmt(real[k])} · {fmt(statistics.mean(vals)) if vals else '—'}{' ✅' if ok else (' ❌' if vals else '')}")
        if ss:
            tot_ok += oks
            tot += len(GRANDEZAS)
        lider = (x["lider"] or ["?"])[0]
        linhas.append(f"| {w['gravacao']} | {x['slug']} | {lider} {x['niveis_lider']} | {real['min']:.1f} | " + " | ".join(cel) +
                      f" | {oks}/{len(GRANDEZAS) if ss else 0}{'' if ss else ' (sem estado)'} |")
        saida.append({"gravacao": w["gravacao"], "slug": x["slug"], "lider": x["lider"], "real": real, "sim": ss})
    resumo = ["", f"**{tot_ok}/{tot} grandezas dentro de ±10%** em {sum(1 for w in trabalhos if sims.get(id(w)))} trechos "
              f"({a.sementes} sementes cada). Por grandeza: " + ", ".join(f"{n} {por_grandeza[k][0]}/{por_grandeza[k][1]}" for k, n in GRANDEZAS) + "."]
    txt = "\n".join(linhas + resumo)
    print(txt)
    if a.md:
        open(a.md, "w", encoding="utf-8", newline="\n").write(txt + "\n")
    if a.json:
        json.dump(saida, open(a.json, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
