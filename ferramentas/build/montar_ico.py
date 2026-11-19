#!/usr/bin/env python3
"""Monta assets/interface/icone/icone_jogo.ico com os PNGs de ferramentas/build/gerar_icone.gd (ICO com PNG embutido)."""
import os
import struct

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
P = os.path.join(RAIZ, "assets/interface/icone")
pngs = [(t, open(os.path.join(P, f"icone_{t}.png"), "rb").read()) for t in (16, 32, 48, 64, 128, 256)]
cab = struct.pack("<HHH", 0, 1, len(pngs))
off = 6 + 16 * len(pngs)
ents = b""
dados = b""
for t, b in pngs:
    ents += struct.pack("<BBBBHHII", 0 if t == 256 else t, 0 if t == 256 else t, 0, 0, 1, 32, len(b), off + len(dados))
    dados += b
open(os.path.join(P, "icone_jogo.ico"), "wb").write(cab + ents + dados)
print("ok", len(cab + ents + dados), "bytes")
