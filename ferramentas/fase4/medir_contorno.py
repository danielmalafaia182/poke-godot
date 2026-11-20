"""Selvagem bloqueado: o original contorna? (ciclo 4, item 4)

Para cada passo de selvagem (posição muda entre fields consecutivos com Δseq = 2), na perseguição (não adjacente antes,
dentro da caixa 13×13 do herói), classifica o passo pela distância de Chebyshev até o herói:
  - "aproxima" (d diminui), "lateral" (d igual), "afasta" (d aumenta);
e marca se, antes do passo, TODOS os vizinhos que aproximavam estavam ocupados por outro selvagem vivo ou pelo herói
("bloqueado"). Se o original contorna, aparecem passos laterais/afastando quando bloqueado; se só espera, quase nenhum.

Uso: python -I ferramentas/fase4/medir_contorno.py <gravação.jsonl> [...]
"""
import json
import sys
from collections import Counter


def fields(caminho):
    with open(caminho, encoding="utf-8") as f:
        for linha in f:
            try:
                r = json.loads(linha)
            except Exception:
                continue
            m = r.get("msg") if isinstance(r, dict) else None
            if isinstance(m, dict) and m.get("type") == "field":
                yield m


def cheb(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def analisar(caminho, cont):
    ant = None
    for f in fields(caminho):
        if ant is not None and f.get("seq", 0) - ant.get("seq", 0) == 2 and f.get("hero") and ant.get("hero"):
            h0 = (ant["hero"]["col"], ant["hero"]["row"])
            vivos0 = {m["slot"]: (m["col"], m["row"]) for m in ant.get("mobs", []) if not m.get("dead") and not m.get("respawning")}
            vivos1 = {m["slot"]: (m["col"], m["row"]) for m in f.get("mobs", []) if not m.get("dead") and not m.get("respawning")}
            for slot, p0 in vivos0.items():
                p1 = vivos1.get(slot)
                if p1 is None:
                    continue
                if p1 == p0:
                    d0 = cheb(p0, h0)
                    if 1 < d0 and abs(p0[0] - h0[0]) <= 13 and abs(p0[1] - h0[1]) <= 13:
                        ocup = set(v for s, v in vivos0.items() if s != slot) | {h0}
                        melhores = [(p0[0] + dx, p0[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                                    if (dx or dy) and cheb((p0[0] + dx, p0[1] + dy), h0) < d0]
                        if melhores and all(c in ocup for c in melhores):
                            cont[("parado", "bloqueado")] += 1
                    continue
                if cheb(p0, p1) != 1:
                    continue   # dois passos no intervalo: descarta
                d0 = cheb(p0, h0)
                if d0 <= 1 or abs(p0[0] - h0[0]) > 13 or abs(p0[1] - h0[1]) > 13:
                    continue
                d1 = cheb(p1, h0)
                tipo = "aproxima" if d1 < d0 else ("lateral" if d1 == d0 else "afasta")
                ocup = set(v for s, v in vivos0.items() if s != slot) | {h0}
                melhores = [(p0[0] + dx, p0[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                            if (dx or dy) and cheb((p0[0] + dx, p0[1] + dy), h0) < d0]
                bloq = all(c in ocup for c in melhores)
                cont[(tipo, "bloqueado" if bloq else "livre")] += 1
        ant = f


def main():
    cont = Counter()
    for c in sys.argv[1:]:
        analisar(c, cont)
    tot = sum(cont.values())
    print("passos de perseguição:", tot)
    for k in sorted(cont):
        print("  %-9s %-10s %6d" % (k[0], k[1], cont[k]))
    bl = sum(v for k, v in cont.items() if k[1] == "bloqueado")
    contorno = sum(v for k, v in cont.items() if k[1] == "bloqueado" and k[0] in ("lateral", "afasta"))
    print("com o caminho que aproxima ocupado: %d intervalos; %d passos contornando (lateral/afasta), %d parado" % (bl, contorno, cont[("parado", "bloqueado")]))


if __name__ == "__main__":
    main()
