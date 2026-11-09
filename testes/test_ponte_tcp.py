#!/usr/bin/env python3
"""Teste do servidor headless da simulação (ponte/servidor_sim.gd) pelo TCP, sem navegador.

Sobe o Godot com APPDATA temporário (o save real nunca é tocado), conecta como a ponte e confere:
  - enter-hunt rhydon → field-init + field (tick 0), depois ~2,5 fields/s em tempo real;
  - serverNow acompanha o relógio (desvio < 500 ms) e seq conta ticks;
  - a mensagem sai crua (sem o envelope {t, msg} da simulação) e passa no validador do protocolo;
  - enter-hunt com resume → field-init + field da MESMA instância (mesmo huntKey);
  - field-get → field; leave-hunt → field-none; field-get sem hunt → field-none; slug sem estado → error.
Uso: python testes/test_ponte_tcp.py
"""
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", r"C:\Users\dmala\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe")
PORTA = 8791
sys.path.insert(0, str(RAIZ / "ferramentas" / "protocolo"))
import validar_jsonl  # noqa: E402

falhas = 0
total = 0


def checar(ok, nome, detalhe=""):
    global falhas, total
    total += 1
    falhas += not ok
    print(("OK    " if ok else "FALHA ") + nome + (f"  ({detalhe})" if detalhe else ""), flush=True)


class Cliente:
    def __init__(self):
        self.s = socket.create_connection(("127.0.0.1", PORTA))
        self.s.settimeout(0.2)
        self.buf = b""

    def enviar(self, msg):
        self.s.sendall((json.dumps(msg) + "\n").encode())

    def ler(self, segundos):
        r, fim = [], time.time() + segundos
        while time.time() < fim:
            try:
                b = self.s.recv(1 << 20)
            except socket.timeout:
                continue
            if not b:
                break
            self.buf += b
            while b"\n" in self.buf:
                linha, self.buf = self.buf.split(b"\n", 1)
                if linha.strip():
                    r.append((time.time() * 1000, json.loads(linha)))
        return r


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    isolado = tempfile.mkdtemp(prefix="poke_teste_ponte_")
    env = dict(os.environ, APPDATA=isolado, XDG_DATA_HOME=isolado)
    proc = subprocess.Popen([GODOT, "--headless", "--path", str(RAIZ), "--script", "res://ponte/servidor_sim.gd",
                             "--", "--porta", str(PORTA)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        fim = time.time() + 60
        while True:
            try:
                socket.create_connection(("127.0.0.1", PORTA), timeout=1).close()
                break
            except OSError:
                if time.time() > fim or proc.poll() is not None:
                    checar(False, "servidor abriu a porta")
                    return 1
                time.sleep(0.3)
        time.sleep(0.5)
        c = Cliente()
        c.enviar({"type": "enter-hunt", "slug": "rhydon", "resume": False})
        msgs = c.ler(6.0)
        tipos = [m["type"] for _, m in msgs]
        checar(tipos[:2] == ["field-init", "field"], "enter-hunt → field-init e field", str(tipos[:2]))
        checar(all("msg" not in m and "type" in m for _, m in msgs), "mensagens cruas (sem envelope {t, msg})")
        fields = [(t, m) for t, m in msgs if m["type"] == "field"]
        taxa = (len(fields) - 1) / ((fields[-1][0] - fields[0][0]) / 1000) if len(fields) > 2 else 0
        checar(2.2 <= taxa <= 2.8, "~2,5 fields por segundo em tempo real", f"{taxa:.2f}")
        desvio = max(abs(m["serverNow"] - t) for t, m in fields)
        checar(desvio < 500, "serverNow acompanha o relógio", f"desvio máx {desvio:.0f} ms")
        seqs = [m["seq"] for _, m in fields]
        checar(all(b - a == 2 for a, b in zip(seqs, seqs[1:])), "seq avança 2 por field", str(seqs[:6]))
        hk = msgs[0][1].get("huntKey")
        with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8") as f:
            for t, m in msgs:
                f.write(json.dumps({"sessao": "teste", "t": int(t), "dir": "in", "msg": m}) + "\n")
            caminho = f.name
        proto = json.load(open(RAIZ / "dados" / "protocolo.json", encoding="utf-8"))
        r = validar_jsonl.validar(caminho, proto)
        os.unlink(caminho)
        checar(not r["erros"], "mensagens passam no protocolo.json", "; ".join(r["erros"][:3]))

        c.enviar({"type": "enter-hunt", "slug": "rhydon", "resume": True})
        m = [x for _, x in c.ler(0.6)]
        checar(m and m[0]["type"] == "field-init" and m[0]["huntKey"] == hk and m[1]["type"] == "field",
               "resume devolve field-init + field da mesma instância")
        c.ler(0.5)
        c.enviar({"type": "field-get"})
        m = [x["type"] for _, x in c.ler(0.3)]
        checar("field" in m, "field-get → field", str(m))
        c.enviar({"type": "leave-hunt"})
        m = [x["type"] for _, x in c.ler(0.5)]
        checar(m == ["field-none"], "leave-hunt → field-none e para de emitir", str(m))
        c.enviar({"type": "field-get"})
        m = [x["type"] for _, x in c.ler(0.3)]
        checar(m == ["field-none"], "field-get sem hunt → field-none", str(m))
        c.enviar({"type": "enter-hunt", "slug": "snorlax", "resume": False})
        m = [x["type"] for _, x in c.ler(0.3)]
        checar(m == ["error"], "hunt sem estado inicial → error", str(m))
    finally:
        proc.terminate()
        try:
            proc.wait(5)
        except subprocess.TimeoutExpired:
            proc.kill()
    print(f"RESULTADO: {total - falhas}/{total}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
