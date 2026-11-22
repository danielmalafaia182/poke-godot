#!/usr/bin/env python3
"""Capturas por trecho, real × sim (ciclo 6): onde a sim perde capturas.

Para cada trecho exportado pelo validador (`saida_testes/validar_resultado*/livre/trecho_*.jsonl` e as saídas `.simN`),
conta: abates; abates elegíveis ao Auto-Catch (espécie passa no filtro de nomes, não shiny, com bola da cor no estoque);
bolas jogadas (catch-result); bolas por abate elegível; capturas; tentativas por captura; e o tempo do abate até o
catch-result (ms, pelo serverNow do último field antes de cada mensagem).

Uso: python -I ferramentas/fase4/capturas_trechos.py [pasta] [--md saida.md]
"""
import glob
import json
import os
import statistics
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def medir(caminho):
    ab = eleg = bolas = caps = 0
    ah = {}
    t = None
    pend = {}
    atrasos = []
    for linha in open(caminho, encoding="utf-8"):
        m = json.loads(linha)["msg"]
        tp = m.get("type")
        if tp == "autohelper":
            ah = m
        elif tp == "field":
            t = m.get("serverNow")
        elif tp == "field-kill":
            ab += 1
            nomes = str(ah.get("autoCatchNames") or "").strip()
            ok_nome = not nomes or str(m.get("speciesName", "")).lower() in [x.strip().lower() for x in nomes.split(",")]
            if not m.get("shiny") and ok_nome and ah.get("autoCatch", True):
                eleg += 1
            pend[(m.get("col"), m.get("row"))] = t
        elif tp == "catch-result":
            bolas += 1
            caps += 1 if m.get("success") else 0
            t0 = pend.pop((m.get("col"), m.get("row")), None)
            if t0 is not None and t is not None:
                atrasos.append(t - t0)
    return {"abates": ab, "eleg": eleg, "bolas": bolas, "caps": caps,
            "atraso": statistics.median(atrasos) if atrasos else None}


def main():
    pasta = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else os.path.join(RAIZ, "saida_testes", "validar_resultado_c5", "livre")
    md = sys.argv[sys.argv.index("--md") + 1] if "--md" in sys.argv else None
    sys.stdout.reconfigure(encoding="utf-8")
    linhas = ["| Trecho | Abates real · sim | Elegíveis real · sim | Bolas/elegível real · sim | Bolas real · sim | Capturas real · sim | Tentativas/captura real · sim | ms abate→bola real · sim |",
              "| --- | --- | --- | --- | --- | --- | --- | --- |"]
    tot = {"r": [0] * 4, "s": [0] * 4}
    for f in sorted(glob.glob(os.path.join(pasta, "trecho_*.jsonl"))):
        if ".sim" in f:
            continue
        sims = [medir(s) for s in sorted(glob.glob(f.replace(".jsonl", ".sim*.jsonl")))]
        if not sims:
            continue
        r = medir(f)
        if r["bolas"] == 0 and all(s["bolas"] == 0 for s in sims):
            continue
        ms = {k: statistics.mean([s[k] for s in sims]) for k in ("abates", "eleg", "bolas", "caps")}
        at = [s["atraso"] for s in sims if s["atraso"] is not None]
        for i, k in enumerate(("abates", "eleg", "bolas", "caps")):
            tot["r"][i] += r[k]
            tot["s"][i] += ms[k]
        f2 = lambda a, b: "%.2f" % (a / b) if b else "—"
        linhas.append("| %s | %d · %.0f | %d · %.0f | %s · %s | %d · %.0f | %d · %.1f | %s · %s | %s · %s |" % (
            os.path.basename(f)[7:-6], r["abates"], ms["abates"], r["eleg"], ms["eleg"], f2(r["bolas"], r["eleg"]), f2(ms["bolas"], ms["eleg"]),
            r["bolas"], ms["bolas"], r["caps"], ms["caps"], "%.0f" % (r["bolas"] / r["caps"]) if r["caps"] else "—",
            "%.0f" % (ms["bolas"] / ms["caps"]) if ms["caps"] else "—",
            "%.0f" % r["atraso"] if r["atraso"] is not None else "—", "%.0f" % statistics.mean(at) if at else "—"))
    r, s = tot["r"], tot["s"]
    linhas.append("| **total** | %d · %.0f | %d · %.0f | %.3f · %.3f | %d · %.0f | %d · %.1f | %.0f · %.0f | |" % (
        r[0], s[0], r[1], s[1], r[2] / max(1, r[1]), s[2] / max(1, s[1]), r[2], s[2], r[3], s[3], r[2] / max(1, r[3]), s[2] / max(1, s[3])))
    txt = "\n".join(linhas)
    print(txt)
    if md:
        open(md, "w", encoding="utf-8").write(txt + "\n")


if __name__ == "__main__":
    main()
