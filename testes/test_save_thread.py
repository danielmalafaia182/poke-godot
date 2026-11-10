#!/usr/bin/env python3
"""Save em thread (fase 2b, item 1). APPDATA isolado por teste (o save real nunca é tocado).

1. Save antigo: dados/testes/save_antigo_inventario.json vira o progresso do APPDATA isolado; testes/save_thread_etapa.gd
   --modo antigo confere carga, gravação em thread, arquivo, exclusividade e custo na thread principal.
2. Jogo fechado no meio da gravação: N vezes, o Godot grava sem parar (--modo martelar) e é morto num instante aleatório;
   em seguida um processo novo carrega (--modo conferir). Exige: carrega sem bloqueio, e a XP carregada fica entre a
   última gravação confirmada (SALVO) e a última iniciada (INICIO) — nada confirmado se perde, nada inventado aparece.
Uso: python -I testes/test_save_thread.py [--vezes 15]
"""
import argparse
import os
import random
import shutil
import subprocess
import sys
import tempfile
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", r"C:\Users\dmala\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe")


def godot(appdata, modo, timeout=None, matar_em=None):
    env = dict(os.environ, APPDATA=appdata)
    cmd = [GODOT, "--headless", "--path", RAIZ, "--script", "res://testes/save_thread_etapa.gd", "--", "--modo", modo]
    p = subprocess.Popen(cmd, cwd=RAIZ, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         encoding="utf-8", errors="replace")
    if matar_em is None:
        out, _ = p.communicate(timeout=timeout)
        return p.returncode, out
    linhas = []
    inicio = time.time()
    os.set_blocking(p.stdout.fileno(), False) if hasattr(os, "set_blocking") and os.name != "nt" else None
    # lê enquanto roda; mata no instante sorteado (contado a partir do 1º INICIO, quando a gravação já começou)
    import threading
    def ler():
        for l in p.stdout:
            linhas.append(l.rstrip("\n"))
    t = threading.Thread(target=ler, daemon=True)
    t.start()
    while not any(l.startswith("INICIO") for l in linhas) and time.time() - inicio < 120:
        time.sleep(0.01)
    time.sleep(matar_em)
    p.kill()
    p.wait()
    t.join(timeout=5)
    return p.returncode, "\n".join(linhas)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vezes", type=int, default=15)
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    falhas = 0
    base = tempfile.mkdtemp(prefix="poke_save_thread_")
    pasta = os.path.join(base, "Godot", "app_userdata", "PokeIdle")
    os.makedirs(pasta)
    shutil.copy(os.path.join(RAIZ, "dados", "testes", "save_antigo_inventario.json"), os.path.join(pasta, "progresso_v1.json"))
    rc, out = godot(base, "antigo", timeout=300)
    for l in out.splitlines():
        if l.startswith(("OK", "FALHA", "RESULTADO", "SCRIPT ERROR")):
            print("[antigo]", l)
    if rc != 0 or "RESULTADO" not in out:
        falhas += 1
    random.seed(20261109)
    ok_kill = 0
    no_meio = 0
    for i in range(a.vezes):
        matar = random.uniform(0.05, 2.5)
        _, out = godot(base, "martelar", matar_em=matar)
        salvos = [int(l.split()[1]) for l in out.splitlines() if l.startswith("SALVO ")]
        iniciados = [int(l.split()[1]) for l in out.splitlines() if l.startswith("INICIO ")]
        if iniciados and (not salvos or salvos[-1] < iniciados[-1]):
            no_meio += 1                     # morreu com uma gravação em andamento
        sobras = sorted(f for f in os.listdir(pasta) if f.startswith("progresso"))
        rc, out2 = godot(base, "conferir", timeout=120)
        lin = [l for l in out2.splitlines() if l.startswith("CARREGADO")]
        if not lin:
            print("FALHA morte %d: conferência não carregou" % i, out2[-500:])
            falhas += 1
            continue
        _, xp, bloq, aviso = (lin[0].split() + ["", ""])[:4]
        xp = int(xp)
        minimo = salvos[-1] if salvos else 0
        maximo = iniciados[-1] if iniciados else xp
        ok = bloq == "false" and minimo <= xp <= maximo
        ok_kill += ok
        falhas += 0 if ok else 1
        print("%s morte %2d aos %.2f s: últ. confirmada %s, últ. iniciada %s, carregada %d, arquivos %s%s" % (
            "OK   " if ok else "FALHA", i, matar, minimo, maximo, xp, sobras, (" aviso=" + aviso) if aviso else ""))
    print("mortes com gravação em andamento: %d de %d" % (no_meio, a.vezes))
    print("RESULTADO: %s (%d/%d mortes sem perda)" % ("OK" if falhas == 0 else "FALHA", ok_kill, a.vezes))
    shutil.rmtree(base, ignore_errors=True)
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
