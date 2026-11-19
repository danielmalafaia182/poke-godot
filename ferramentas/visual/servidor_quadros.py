#!/usr/bin/env python3
"""Extrai quadros dos vídeos de referência (referencia_visual/*.mp4) pelo navegador, sem ffmpeg.

Serve os vídeos (com Range, para o <video> poder buscar) e uma página (/) que toca cada vídeo, desenha 1 quadro por
segundo num canvas, descarta os repetidos (diferença média de pixels numa miniatura 96×54 abaixo do limite) e manda o
PNG por POST /quadro, que grava em referencia_visual/quadros/brutos/<n do vídeo>_<segundo>.png.
Uso: python -u ferramentas/visual/servidor_quadros.py [porta]   (abrir http://127.0.0.1:<porta>/)
"""
import json
import os
import re
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REF = os.path.join(RAIZ, "referencia_visual")
SAIDA = os.path.join(REF, "quadros", "brutos")
VIDEOS = sorted(f for f in os.listdir(REF) if f.lower().endswith(".mp4"))

PAGINA = """<!doctype html><meta charset=utf-8><title>quadros</title>
<body style="font:14px sans-serif"><div id=st>iniciando…</div><video id=v muted playsinline style="width:480px"></video>
<canvas id=c style="display:none"></canvas><script>
const VIDEOS = %s;
const st = document.getElementById('st'), v = document.getElementById('v'), c = document.getElementById('c');
const mini = document.createElement('canvas'); mini.width = 96; mini.height = 54;
function busca(t) { return new Promise(r => { v.onseeked = () => r(); v.currentTime = t; }); }
async function um(idx, nome) {
  v.src = '/video/' + encodeURIComponent(nome);
  await new Promise(r => v.onloadedmetadata = r);
  c.width = v.videoWidth; c.height = v.videoHeight;
  const ctx = c.getContext('2d'), mctx = mini.getContext('2d');
  let ant = null, salvos = 0;
  for (let t = 0; t < v.duration; t += 1) {
    await busca(t);
    ctx.drawImage(v, 0, 0);
    mctx.drawImage(v, 0, 0, 96, 54);
    const px = mctx.getImageData(0, 0, 96, 54).data;
    let dif = 0;
    if (ant) { for (let i = 0; i < px.length; i += 4) dif += Math.abs(px[i] - ant[i]) + Math.abs(px[i+1] - ant[i+1]) + Math.abs(px[i+2] - ant[i+2]); dif /= (px.length / 4) * 3; }
    if (!ant || dif > 1.5) {
      const blob = await new Promise(r => c.toBlob(r, 'image/png'));
      await fetch('/quadro?v=' + idx + '&t=' + t, { method: 'POST', body: blob });
      ant = px; salvos++;
    }
    st.textContent = nome + ': ' + t + '/' + Math.floor(v.duration) + ' s, ' + salvos + ' quadros';
  }
  return salvos;
}
(async () => { let tot = 0; for (let i = 0; i < VIDEOS.length; i++) tot += await um(i + 1, VIDEOS[i]);
  st.textContent = 'FIM ' + tot + ' quadros'; await fetch('/fim?n=' + tot, { method: 'POST' }); })();
</script>"""


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == "/":
            b = (PAGINA % json.dumps(VIDEOS)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)
            return
        if u.path.startswith("/video/"):
            nome = urllib.parse.unquote(u.path[7:])
            if nome not in VIDEOS:
                self.send_error(404)
                return
            p = os.path.join(REF, nome)
            tam = os.path.getsize(p)
            ini, fim = 0, tam - 1
            rng = self.headers.get("Range")
            m = re.match(r"bytes=(\d*)-(\d*)", rng or "")
            if m:
                ini = int(m.group(1) or 0)
                fim = int(m.group(2)) if m.group(2) else min(tam - 1, ini + 8 * 1024 * 1024)
                self.send_response(206)
                self.send_header("Content-Range", f"bytes {ini}-{fim}/{tam}")
            else:
                self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Length", str(fim - ini + 1))
            self.end_headers()
            with open(p, "rb") as f:
                f.seek(ini)
                resto = fim - ini + 1
                while resto > 0:
                    pedaco = f.read(min(resto, 1 << 20))
                    if not pedaco:
                        break
                    try:
                        self.wfile.write(pedaco)
                    except (ConnectionResetError, BrokenPipeError):
                        return
                    resto -= len(pedaco)
            return
        self.send_error(404)

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        n = int(self.headers.get("Content-Length", 0))
        corpo = self.rfile.read(n) if n else b""
        if u.path == "/quadro":
            os.makedirs(SAIDA, exist_ok=True)
            nome = "v%s_%05d.png" % (q["v"][0], int(q["t"][0]))
            with open(os.path.join(SAIDA, nome), "wb") as f:
                f.write(corpo)
            print("quadro", nome, flush=True)
        elif u.path == "/fim":
            print("FIM", q.get("n", ["?"])[0], flush=True)
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    porta = int(sys.argv[1]) if len(sys.argv) > 1 else 8770
    print("servindo", VIDEOS, "em", porta, flush=True)
    ThreadingHTTPServer(("127.0.0.1", porta), H).serve_forever()
