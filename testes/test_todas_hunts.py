#!/usr/bin/env python3
"""Roda testes/test_todas_hunts.gd (Godot com janela, save isolado) e transforma o log num relatório por hunt.

Erros: toda linha "SCRIPT ERROR" / "ERROR:" / "WARNING:" entre HUNT_INICIO e HUNT_RESULTADO de uma hunt é dela
(ruídos conhecidos de saída do Godot são ignorados). Falha = sem HUNT_RESULTADO, erro no log, carga ≥ 2000 ms, tempo
esgotado, ou (só com --velocidade 1) p99 do quadro ≥ 16,7 ms. Em modo acelerado o quadro é só informativo: a 10× os
abates (e o trabalho de HUD de cada um) são 10× mais frequentes que no jogo — é teste de estresse, não o critério.
Uso: python testes/test_todas_hunts.py [--segundos 60] [--velocidade 30] [--slugs a,b] [--saida saida_testes/todas_hunts.json]
"""
import argparse
import json
import os
import re
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUIDO = re.compile(r"Unreferenced static string|RID allocations|Pages in use exist|leaked at exit|ObjectDB instances leaked|"
                   r"resources still in use at exit|^\s*at:|GDScript backtrace|^\s*\[\d+\]")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--segundos", default="60")
    ap.add_argument("--velocidade", default="30")
    ap.add_argument("--slugs", default="")
    ap.add_argument("--inicio", default="0")
    ap.add_argument("--quantos", default="100000")
    ap.add_argument("--saida", default=os.path.join(RAIZ, "saida_testes", "todas_hunts.json"))
    ap.add_argument("--log", default=os.path.join(RAIZ, "saida_testes", "todas_hunts.log"))
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    bash = os.environ.get("BASH_GIT", "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else "bash")   # não o bash do WSL
    cmd = [bash, "testes/rodar_janela.sh", "res://testes/test_todas_hunts.gd", "--segundos", a.segundos,
           "--velocidade", a.velocidade, "--inicio", a.inicio, "--quantos", a.quantos]
    if a.slugs:
        cmd += ["--slugs", a.slugs]
    env = dict(os.environ, TEMPO_MAX=os.environ.get("TEMPO_MAX", "14400"))
    with open(a.log, "w", encoding="utf-8") as log:
        subprocess.run(cmd, cwd=RAIZ, stdout=log, stderr=subprocess.STDOUT, env=env)
    hunts, atual = {}, None
    total = None
    for linha in open(a.log, encoding="utf-8", errors="replace"):
        linha = linha.rstrip("\n")
        if linha.startswith("HUNTS_TOTAL"):
            total = int(linha.split()[1])
        elif linha.startswith("HUNT_INICIO "):
            atual = linha.split(" ", 1)[1].strip()
            hunts[atual] = {"slug": atual, "erros": []}
        elif linha.startswith("HUNT_RESULTADO "):
            r = json.loads(linha.split(" ", 1)[1])
            hunts.setdefault(r["slug"], {"slug": r["slug"], "erros": []}).update(r)
            atual = None
        elif atual and re.search(r"SCRIPT ERROR|^ERROR:|^WARNING:", linha) and not RUIDO.search(linha):
            hunts[atual]["erros"].append(linha.strip()[:300])
    falhas = []
    for s, h in hunts.items():
        motivos = []
        if "carga_ms" not in h:
            motivos.append("não terminou (sem HUNT_RESULTADO)")
        if h["erros"]:
            motivos.append("%d erro(s) no log: %s" % (len(h["erros"]), h["erros"][0]))
        if h.get("carga_ms", 0) >= 2000:
            motivos.append("carga %d ms" % h["carga_ms"])
        if float(a.velocidade) == 1.0 and h.get("p99_ms", 0) >= 16.7:
            motivos.append("p99 do quadro %.1f ms (1×)" % h["p99_ms"])
        if h.get("obs") in ("cena sem simulação", "cena liberada", "tempo esgotado (120 s)"):
            motivos.append(h["obs"])
        h["falhas"] = motivos
        if motivos:
            falhas.append(s)
    res = {"total_pedido": total, "rodadas": len(hunts), "falhas": len(falhas), "hunts": hunts,
           "lista_falhas": {s: hunts[s]["falhas"] for s in falhas}}
    vals = [h for h in hunts.values() if "carga_ms" in h]
    if vals:
        res["resumo"] = {"carga_max_ms": max(h["carga_ms"] for h in vals), "carga_media_ms": sum(h["carga_ms"] for h in vals) / len(vals),
                         "pior_quadro_max_ms": max(h["pior_ms"] for h in vals), "p99_max_ms": max(h["p99_ms"] for h in vals),
                         "sem_abate": sorted(h["slug"] for h in vals if h.get("abates", 0) == 0),
                         "time_derrotado": sorted(h["slug"] for h in vals if h.get("motivo_fim") == "sem-reserva")}
    with open(a.saida, "w", encoding="utf-8", newline="\n") as f:
        json.dump(res, f, ensure_ascii=False, indent=1)
    print(json.dumps({k: res[k] for k in ("total_pedido", "rodadas", "falhas")}, ensure_ascii=False))
    if vals:
        r = res["resumo"]
        print("carga máx %d ms (média %.0f) | pior quadro máx %.1f ms | p99 máx %.1f ms | sem abate: %d | time derrotado: %d" % (
            r["carga_max_ms"], r["carga_media_ms"], r["pior_quadro_max_ms"], r["p99_max_ms"], len(r["sem_abate"]), len(r["time_derrotado"])))
    for s in falhas[:40]:
        print("FALHA", s, "—", "; ".join(hunts[s]["falhas"]))
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
