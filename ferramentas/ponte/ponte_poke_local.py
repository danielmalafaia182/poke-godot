#!/usr/bin/env python3
"""Ponte: o cliente original (poke-local) desenha a hunt gerada pela simulação Godot (sim/).

Arquitetura (critério de pronto da fase 1):
  navegador ── HTTP/WS 127.0.0.1:8000 ── esta ponte ── TCP 127.0.0.1:8765, JSON por linha ── Godot headless
                                          │                                                  (ponte/servidor_sim.gd)
                                          └─ fixtures do poke-local/serve.py (tudo que não é hunt)

- Reaproveita o `serve.py` do poke-local SEM alterá-lo (subclasse do Handler): sessão fictícia, APIs de leitura,
  respostas WS de fixtures. Só o WebSocket é reimplementado para encaminhar enter-hunt, leave-hunt, field-get e
  view ao Godot e repassar ao navegador, sem mudar nada, as mensagens que a simulação emite.
- O poke-local só tem os recursos de Cerulean/Snorlax. Para a hunt do Rhydon a ponte serve do snapshot do servidor
  (`poke har/extraido/snapshot_2026-11-09/`): mapas, atlas de map-items (versão 06563563679b), creatures.json,
  items.json e o hunt-config. Outfits e cadáveres continuam do poke-local (o snapshot não tem as imagens).
- Decisão E (CLAUDE.md: um sprite só no offline é aceitável): se o outfit de um looktype emitido não existe nas
  páginas locais (ex.: Venusaur, 22), a ponte troca por um que existe (padrão 200, Rhydon) só na apresentação;
  a simulação e as gravações do lado do servidor guardam o valor original.
- Teste: injeta ferramentas/ponte/monitor_erros.js (window.__ponteErros) e ferramentas/gravador/gravador_ws.user.js no /play (como o Tampermonkey faria, no início da página)
  e aceita POST /__ponte/gravacao com o JSONL exportado. Também grava, do lado do servidor, tudo que passa pelo WS.
- Testes nunca tocam o save real: o Godot roda com APPDATA temporário (a sim não usa user://).

Uso:  python ferramentas/ponte/ponte_poke_local.py [--semente 1] [--estado dados/testes/estado_rhydon_venusaur.json]
Depois abra http://127.0.0.1:8000, Mapa → Rhydon.
"""
import argparse
import atexit
import base64
import hashlib
import json
import os
import re
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from urllib.parse import urlsplit, parse_qs

RAIZ = Path(__file__).resolve().parents[2]
POKE_LOCAL = RAIZ / "poke-local"
PUBLIC = POKE_LOCAL / "public"
SNAPSHOT = Path(os.environ.get("POKE_SNAPSHOT", RAIZ / "poke har" / "extraido" / "snapshot_2026-11-09"))
GRAVADOR = RAIZ / "ferramentas" / "gravador" / "gravador_ws.user.js"
SAIDA = RAIZ / "saida_testes" / "ponte"
GODOT_PADRAO = r"C:\Users\dmala\Desktop\Godot\Godot_v4.7.2-stable_win64_console.exe"
PORTA_HTTP = 8000          # o CSP do serve.py só libera ws://127.0.0.1:8000
COMANDOS_HUNT = {"enter-hunt", "leave-hunt", "field-get", "view"}

sys.path.insert(0, str(POKE_LOCAL))
import serve  # noqa: E402  (poke-local/serve.py, inalterado)

TIPOS = {".json": "application/json; charset=utf-8", ".webp": "image/webp", ".png": "image/png",
         ".js": "text/javascript; charset=utf-8", ".html": "text/html; charset=utf-8"}


def outfits_locais():
    """Looktypes cujo manifest de outfit existe no poke-local (categories/outfits-<gênero>-<id>-<hash>.json)."""
    r = set()
    for f in (PUBLIC / "game" / "asset-packs" / "categories").glob("outfits-*-*-*.json"):
        m = re.match(r"outfits-[a-z]+-(\d+)-", f.name)
        if m:
            r.add(int(m.group(1)))
    return r


class Godot:
    """Processo Godot headless com o servidor da simulação."""

    def __init__(self, a):
        self.a = a
        self.proc = None

    def iniciar(self):
        exe = self.a.godot
        isolado = tempfile.mkdtemp(prefix="poke_ponte_")
        env = dict(os.environ, APPDATA=isolado, XDG_DATA_HOME=isolado)
        cmd = [exe, "--headless", "--path", str(RAIZ), "--script", "res://ponte/servidor_sim.gd", "--",
               "--porta", str(self.a.porta_sim), "--estado", self.a.estado, "--semente", str(self.a.semente)]
        self.proc = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     text=True, encoding="utf-8", errors="replace")
        atexit.register(self.parar)
        threading.Thread(target=self._eco, daemon=True).start()
        fim = time.time() + 60
        while time.time() < fim:
            try:
                socket.create_connection(("127.0.0.1", self.a.porta_sim), timeout=1).close()
                return
            except OSError:
                if self.proc.poll() is not None:
                    raise SystemExit("Godot saiu antes de abrir a porta da simulação")
                time.sleep(0.3)
        raise SystemExit("Godot não abriu a porta da simulação em 60 s")

    def _eco(self):
        ruido = ("autoload", "Resource file not found: res://", "Unreferenced static string", "RID allocations",
                 "Pages in use exist", "BUG:")
        for linha in self.proc.stdout:
            if not any(r in linha for r in ruido):
                print("[godot]", linha.rstrip(), flush=True)

    def parar(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                self.proc.kill()


class GravadorServidor:
    """Grava o tráfego WS do lado do servidor, no formato do gravador ({sessao,t,dir,msg})."""

    def __init__(self):
        SAIDA.mkdir(parents=True, exist_ok=True)
        self.sessao = "ponte-" + time.strftime("%Y-%m-%dT%H-%M-%S")
        self.caminho = SAIDA / f"servidor_{self.sessao}.jsonl"
        self.lock = threading.Lock()
        self.f = open(self.caminho, "a", encoding="utf-8")

    def registrar(self, direcao, msg):
        linha = json.dumps({"sessao": self.sessao, "t": int(time.time() * 1000), "dir": direcao, "msg": msg},
                           ensure_ascii=False)
        with self.lock:
            self.f.write(linha + "\n")
            self.f.flush()


def criar_handler(a):
    disponiveis = outfits_locais()
    trocas = {}
    trocas_img = set()

    def apresentar(msg):
        """Decisão E: troca looktypes sem outfit local (só a cópia que vai para o navegador)."""
        def ajustar(o):
            if isinstance(o, dict):
                for k, v in list(o.items()):
                    if k in ("heroLooktype", "looktype", "barLooktype") and isinstance(v, int) and v not in disponiveis:
                        if v not in trocas:
                            trocas[v] = a.looktype_substituto
                            print(f"[ponte] looktype {v} sem outfit local → {a.looktype_substituto} (só na tela)",
                                  flush=True)
                        o[k] = a.looktype_substituto
                    else:
                        ajustar(v)
            elif isinstance(o, list):
                for x in o:
                    ajustar(x)
            return o
        return ajustar(json.loads(json.dumps(msg)))

    class PonteHandler(serve.Handler):
        def log_message(self, fmt, *args):
            if a.verboso:
                super().log_message(fmt, *args)

        def arquivo(self, caminho: Path, tipo=None, corpo=None):
            if corpo is None:
                if not caminho.is_file():
                    return self.reply({"message": "não encontrado", "local": True}, 404)
                corpo = caminho.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", tipo or TIPOS.get(caminho.suffix, "application/octet-stream"))
            self.send_header("Content-Length", str(len(corpo)))
            self.end_headers()
            self.wfile.write(corpo)

        def do_GET(self):
            u = urlsplit(self.path)
            path, q = u.path, parse_qs(u.query)
            if path in ("/", "/play") and not (path == "/ws"):
                html = (PUBLIC / "play.html").read_text(encoding="utf-8")
                # O poke-local trocou o beacon da Cloudflare por /local-noop.js mas manteve o integrity do original:
                # o navegador bloqueia e acusa erro no console. Sem o atributo, o script vazio carrega (nada muda).
                html = re.sub(r'(<script[^>]*src="/local-noop\.js"[^>]*?)\s+integrity="[^"]*"', r"\1", html)
                injetar = '<script src="/__ponte/monitor.js"></script>'
                if a.gravar:
                    injetar += '<script src="/__ponte/gravador.js"></script>'
                html = html.replace("<head>", "<head>" + injetar, 1)
                return self.arquivo(PUBLIC / "play.html", TIPOS[".html"], html.encode("utf-8"))
            if path == "/__ponte/gravador.js":
                return self.arquivo(GRAVADOR, TIPOS[".js"])
            if path == "/__ponte/monitor.js":
                return self.arquivo(Path(__file__).with_name("monitor_erros.js"), TIPOS[".js"])
            if path == "/api/game/map-markers":
                markers = dict(serve.FIXTURES["static"][path])
                markers["hunts"] = [m for m in markers["hunts"] if m["slug"] in ("cerulean", a.slug)]
                return self.reply(markers)
            if path == "/api/game/hunt-config" and q.get("slug", [""])[0] == a.slug:
                return self.arquivo(SNAPSHOT / "api" / "hunt-config" / f"{a.slug}.json")
            if path.startswith("/game/maps/"):
                nome = Path(path).name
                for base in (SNAPSHOT / "game" / "maps", PUBLIC / "game" / "maps"):
                    if (base / nome).is_file():
                        return self.arquivo(base / nome)
            if path.startswith("/assets/") and not (PUBLIC / path.lstrip("/")).is_file():
                alvo = SNAPSHOT / path.lstrip("/")          # ícones de itens/golpes do snapshot (fonte A)
                if alvo.is_file():
                    return self.arquivo(alvo)
                m = re.fullmatch(r"/assets/pokemon/outfit_(\d+)_\.png", path)
                if m:
                    # Decisão E: sem imagens de outfit no snapshot; usa a única local (Snorlax) só na tela.
                    if m.group(1) not in trocas_img:
                        trocas_img.add(m.group(1))
                        print(f"[ponte] outfit_{m.group(1)}_.png sem imagem local → outfit_{a.outfit_substituto}_.png",
                              flush=True)
                    return self.arquivo(PUBLIC / "assets" / "pokemon" / f"outfit_{a.outfit_substituto}_.png")
            if path in ("/game/creatures.json", "/game/items.json"):
                return self.arquivo(SNAPSHOT / "game" / Path(path).name)
            if path.startswith("/game/asset-packs/") and "outfits" not in path:
                rel = path[len("/game/asset-packs/"):]
                alvo = SNAPSHOT / "game" / "asset-packs" / rel
                if alvo.is_file():
                    return self.arquivo(alvo)
            return super().do_GET()

        def do_POST(self):
            if urlsplit(self.path).path != "/__ponte/gravacao":
                return super().do_POST()
            n = int(self.headers.get("Content-Length", "0"))
            if n > 512 * 1024 * 1024:
                return self.reply({"message": "grande demais"}, 413)
            corpo = self.rfile.read(n)
            SAIDA.mkdir(parents=True, exist_ok=True)
            destino = SAIDA / f"navegador_{time.strftime('%Y-%m-%dT%H-%M-%S')}.jsonl"
            destino.write_bytes(corpo)
            linhas = corpo.count(b"\n")
            print(f"[ponte] gravação do navegador salva: {destino} ({linhas} linhas)", flush=True)
            return self.reply({"ok": True, "arquivo": str(destino), "linhas": linhas})

        def websocket(self):
            # Mesmo handshake e enquadramento do serve.py; muda só o destino dos comandos da hunt.
            key = self.headers.get("Sec-WebSocket-Key", "")
            try:
                if len(base64.b64decode(key, validate=True)) != 16:
                    raise ValueError()
            except ValueError:
                return self.reply({"message": "Handshake inválido"}, 400)
            self.send_response(101)
            self.send_header("Upgrade", "websocket")
            self.send_header("Connection", "Upgrade")
            self.send_header("Sec-WebSocket-Accept", base64.b64encode(
                hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode())
            self.end_headers()
            self.close_connection = True
            demo = serve.HuntSession(serve.FIXTURES)       # só para pokes-get/inv-get, como no serve.py
            grav = GravadorServidor()
            lock_envio = threading.Lock()
            parado = threading.Event()

            def enviar(dados, opcode=1):
                if opcode == 1:
                    payload = json.dumps(dados, ensure_ascii=False).encode()
                else:
                    payload = dados
                n = len(payload)
                if n < 126:
                    cab = bytes([128 | opcode, n])
                elif n < 65536:
                    cab = bytes([128 | opcode, 126]) + struct.pack("!H", n)
                else:
                    cab = bytes([128 | opcode, 127]) + struct.pack("!Q", n)
                with lock_envio:
                    self.wfile.write(cab + payload)
                    self.wfile.flush()

            def para_cliente(msg):
                grav.registrar("in", msg)
                enviar(apresentar(msg))

            sim = socket.create_connection(("127.0.0.1", a.porta_sim))
            sim.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            lock_sim = threading.Lock()

            def ao_sim(msg):
                with lock_sim:
                    sim.sendall((json.dumps(msg, ensure_ascii=False) + "\n").encode("utf-8"))

            def leitor():
                buf = b""
                try:
                    while not parado.is_set():
                        bloco = sim.recv(65536)
                        if not bloco:
                            break
                        buf += bloco
                        while b"\n" in buf:
                            linha, buf = buf.split(b"\n", 1)
                            if linha.strip():
                                para_cliente(json.loads(linha))
                except (OSError, ValueError) as e:
                    if not parado.is_set():
                        print("[ponte] leitura da simulação falhou:", e, flush=True)
                finally:
                    parado.set()
                    try:
                        self.connection.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass

            threading.Thread(target=leitor, daemon=True).start()
            print(f"[ponte] cliente conectado; tráfego em {grav.caminho}", flush=True)

            def exato(n):
                d = self.rfile.read(n)
                if len(d) != n:
                    raise EOFError()
                return d
            try:
                while True:
                    cab = exato(2)
                    opcode, mascarado, n = cab[0] & 15, bool(cab[1] & 128), cab[1] & 127
                    if not mascarado or not cab[0] & 128:
                        break
                    if n == 126:
                        n = struct.unpack("!H", exato(2))[0]
                    elif n == 127:
                        n = struct.unpack("!Q", exato(8))[0]
                    if n > 65536:
                        break
                    mascara = exato(4)
                    payload = bytes(b ^ mascara[i % 4] for i, b in enumerate(exato(n)))
                    if opcode == 8:
                        parado.set()
                        enviar(payload, 8)
                        break
                    if opcode == 9:
                        enviar(payload, 10)
                        continue
                    if opcode != 1:
                        continue
                    dados = json.loads(payload)
                    tipo = dados.get("type", "")
                    grav.registrar("out", dados)
                    if a.verboso:
                        print("WS:", tipo, flush=True)
                    if tipo in COMANDOS_HUNT:
                        ao_sim(dados)
                        continue
                    # Demais mensagens: mesmas respostas de fixtures do serve.py.
                    respostas = []
                    if tipo == "pokes-get":
                        respostas = [{"type": "pokes", "list": [demo.poke]}]
                    elif tipo == "inv-get":
                        respostas = [demo.inventory()]
                    elif tipo == "ping":
                        respostas = [{"type": "pong"}]
                    elif tipo == "balls-get":
                        respostas = [serve.BALLS]
                    elif tipo == "pending-get":
                        respostas = [{"type": "pending", "list": []}]
                    elif tipo in ("autohelper-get", "autohelper-refresh"):
                        respostas = [dict(serve.AUTO, type="autohelper")]
                    elif tipo == "pvp-state":
                        respostas = [{"type": "pvp-state", "incoming": [], "outgoing": [], "battle": None,
                                      "ranked": {"queued": False, "tickets": 0}}]
                    elif tipo == "badge-refresh":
                        respostas = [{"type": "mail-badge", "unread": 0, "gifts": 0}]
                    elif tipo in ("set-city", "boosts-refresh", "events-get"):
                        respostas = []
                    else:
                        respostas = [{"type": "error", "message": "Ação local ainda não implementada: " + tipo}]
                    for r in respostas:
                        grav.registrar("in", r)
                        enviar(r)
            except (OSError, EOFError, ValueError):
                pass
            finally:
                parado.set()
                try:
                    sim.close()
                except OSError:
                    pass
                print("[ponte] cliente desconectou", flush=True)

    return PonteHandler


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--estado", default="dados/testes/estado_rhydon_venusaur.json")
    ap.add_argument("--slug", default="rhydon")
    ap.add_argument("--semente", type=int, default=1)
    ap.add_argument("--porta-sim", type=int, default=8765)
    ap.add_argument("--godot", default=os.environ.get("GODOT", GODOT_PADRAO))
    ap.add_argument("--sem-godot", action="store_true", help="não inicia o Godot (já está rodando na porta-sim)")
    ap.add_argument("--looktype-substituto", type=int, default=200)
    ap.add_argument("--outfit-substituto", type=int, default=143, help="imagem /assets/pokemon/outfit_N_.png local")
    ap.add_argument("--sem-gravador", dest="gravar", action="store_false")
    ap.add_argument("--verboso", action="store_true")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    if not (SNAPSHOT / "game" / "maps" / f"{a.slug}.json").is_file():
        raise SystemExit(f"mapa {a.slug} não encontrado no snapshot: {SNAPSHOT}")
    if not a.sem_godot:
        Godot(a).iniciar()
    os.chdir(PUBLIC)            # o SimpleHTTPRequestHandler do serve.py serve a partir daqui
    print(f"[ponte] abra http://127.0.0.1:{PORTA_HTTP}  (Mapa → {a.slug}); Ctrl+C encerra", flush=True)
    servidor = serve.ThreadingHTTPServer(("127.0.0.1", PORTA_HTTP), criar_handler(a))
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
