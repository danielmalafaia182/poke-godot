#!/usr/bin/env python3
"""GIF animado → folha de sprites PNG (quadros lado a lado) + duração de cada quadro. Só biblioteca padrão.

O Godot não lê GIF. O cliente original mostra os ícones de item com <img src={icon}>, e o navegador anima GIF (C), então
os quadros são preservados: o jogo anima a folha (regras_loot.gd, AnimatedTexture). Decodificação conforme GIF89a:
tabela de cores global/local, LZW, entrelaçamento, transparência e descarte (0/1 mantém, 2 limpa a área, 3 restaura o
anterior) do Graphic Control Extension. Determinístico (mesma entrada → mesmos bytes).

Uso como módulo: folha, info = converter(bytes_do_gif); como script: python -I gif_para_folha.py entrada.gif saida.png
"""
import struct
import sys
import zlib


def _lzw(dados, tam_min, total):
    tam = tam_min + 1
    limpar = 1 << tam_min
    fim = limpar + 1
    tabela = [bytes([i]) for i in range(limpar)] + [b"", b""]
    saida = bytearray()
    bits = 0
    nbits = 0
    anterior = None
    pos = 0
    while pos < len(dados) or nbits >= tam:
        while nbits < tam and pos < len(dados):
            bits |= dados[pos] << nbits
            nbits += 8
            pos += 1
        if nbits < tam:
            break
        cod = bits & ((1 << tam) - 1)
        bits >>= tam
        nbits -= tam
        if cod == limpar:
            tam = tam_min + 1
            tabela = tabela[:limpar + 2]
            anterior = None
            continue
        if cod == fim:
            break
        if cod < len(tabela):
            entrada = tabela[cod]
            if anterior is not None:
                tabela.append(anterior + entrada[:1])
        elif anterior is not None:
            entrada = anterior + anterior[:1]
            tabela.append(entrada)
        else:
            break
        saida += entrada
        anterior = entrada
        if len(tabela) == (1 << tam) and tam < 12:
            tam += 1
        if len(saida) >= total:
            break
    return bytes(saida[:total]).ljust(total, b"\0")


def _blocos(b, pos):
    out = bytearray()
    while True:
        n = b[pos]
        pos += 1
        if n == 0:
            return bytes(out), pos
        out += b[pos:pos + n]
        pos += n


def converter(b):
    """Devolve (png_bytes, {"quadros", "largura", "altura", "duracoesMs"})."""
    if b[:6] not in (b"GIF87a", b"GIF89a"):
        raise ValueError("não é GIF")
    w, h, flags, _bg, _asp = struct.unpack("<HHBBB", b[6:13])
    pos = 13
    global_ct = None
    if flags & 0x80:
        n = 3 * (2 << (flags & 7))
        global_ct = b[pos:pos + n]
        pos += n
    canvas = bytearray(w * h * 4)          # RGBA, começa transparente
    quadros, duracoes = [], []
    gce = {"atraso": 0, "transp": None, "descarte": 0}
    while pos < len(b):
        sep = b[pos]
        pos += 1
        if sep == 0x3B:
            break
        if sep == 0x21:
            rotulo = b[pos]
            pos += 1
            dados, pos = _blocos(b, pos)
            if rotulo == 0xF9 and len(dados) >= 4:
                pk, atraso, ti = dados[0], struct.unpack("<H", dados[1:3])[0], dados[3]
                gce = {"atraso": atraso, "transp": ti if pk & 1 else None, "descarte": (pk >> 2) & 7}
            continue
        if sep != 0x2C:
            break
        x, y, iw, ih, f2 = struct.unpack("<HHHHB", b[pos:pos + 9])
        pos += 9
        ct = global_ct
        if f2 & 0x80:
            n = 3 * (2 << (f2 & 7))
            ct = b[pos:pos + n]
            pos += n
        tam_min = b[pos]
        pos += 1
        dados, pos = _blocos(b, pos)
        idx = _lzw(dados, tam_min, iw * ih)
        linhas = list(range(ih))
        if f2 & 0x40:                       # entrelaçado
            linhas = list(range(0, ih, 8)) + list(range(4, ih, 8)) + list(range(2, ih, 4)) + list(range(1, ih, 2))
        anterior = bytes(canvas) if gce["descarte"] == 3 else None
        for i, ly in enumerate(linhas):
            cy = y + ly
            if cy >= h:
                continue
            for lx in range(iw):
                cx = x + lx
                if cx >= w:
                    continue
                c = idx[i * iw + lx]
                if c == gce["transp"] or ct is None or 3 * c + 2 >= len(ct):
                    continue
                o = 4 * (cy * w + cx)
                canvas[o:o + 4] = bytes((ct[3 * c], ct[3 * c + 1], ct[3 * c + 2], 255))
        quadros.append(bytes(canvas))
        duracoes.append(max(20, gce["atraso"] * 10) if gce["atraso"] > 0 else 100)   # 0 → 100 ms (como os navegadores)
        if gce["descarte"] == 2:
            for ly in range(ih):
                cy = y + ly
                if cy < h:
                    o = 4 * (cy * w + x)
                    n = 4 * min(iw, w - x)
                    canvas[o:o + n] = bytes(n)
        elif gce["descarte"] == 3 and anterior is not None:
            canvas = bytearray(anterior)
        gce = {"atraso": 0, "transp": None, "descarte": 0}
    n = len(quadros)
    lw = w * n
    cru = bytearray()
    for yy in range(h):
        cru.append(0)
        for q in quadros:
            cru += q[4 * yy * w:4 * (yy + 1) * w]

    def bloco(tipo, conteudo):
        return struct.pack(">I", len(conteudo)) + tipo + conteudo + struct.pack(">I", zlib.crc32(tipo + conteudo) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", lw, h, 8, 6, 0, 0, 0)) + \
        bloco(b"IDAT", zlib.compress(bytes(cru), 9)) + bloco(b"IEND", b"")
    return png, {"quadros": n, "largura": w, "altura": h, "duracoesMs": duracoes}


if __name__ == "__main__":
    png, info = converter(open(sys.argv[1], "rb").read())
    open(sys.argv[2], "wb").write(png)
    print(info)
