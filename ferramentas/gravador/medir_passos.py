#!/usr/bin/env python3
"""Mede a duração dos passos (herói, treinador, selvagens) nas gravações reais (fonte A).

Semântica observada (A, 4046 fields): stepStartAt == serverNow em todos os fields; walkFrom ≠ posição só no
field do tick em que o passo começou (no field seguinte já volta a ser a posição). O field sai a cada 2 ticks,
então um passo que começa num tick ímpar não aparece com walkFrom: aparece só como mudança de posição.
Encadear walkFrom de fields diferentes mede errado (perde os passos dos ticks ímpares).

Reconstrução (entre dois fields recebidos A → B, Δseq = gap):
  - walkFrom_B ≠ pos_B → passo no tick seq_B (exato). Se pos_A ≠ walkFrom_B, houve outro passo antes, no
    intervalo (seq_A, seq_B − 1]: exato só se gap = 2 (tick seq_B − 1).
  - walkFrom_B == pos_B ≠ pos_A → um passo em (seq_A, seq_B − 1]: exato só se gap = 2.
  - pos_B == pos_A e walkFrom_B == pos_B → nenhum passo, desde que gap ≤ 4 (dois passos em ≤ 4 ticks que voltem
    ao mesmo tile exigiriam intervalo < 3 ticks, que nunca aparece nos trechos sem field perdido).
  Qualquer outro caso (passo com tick incerto, gap maior, salto > 1 tile por respawn/teleporte) corta a cadeia.
Intervalo de um passo = tick do passo seguinte − tick dele, quando os dois têm tick exato e há certeza de que não
houve passo entre eles. Pausas aparecem como intervalos maiores: o resumo dá a moda e a distribuição.
Reto: |Δrow|+|Δcol| = 1; diagonal: 2. O treinador é conferido à parte (sempre na posição do herói).

Uso: python medir_passos.py gravacao.jsonl [...] [--slug rhydon] [--json saida.json]
"""
import argparse
import json
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402  (mesma leitura e deduplicação do gerador do protocolo)

GAP_SEM_PASSO = 4      # maior Δseq em que "mesma posição e walkFrom = posição" garante que não houve passo


def _cheb(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def _forma(de, para):
    return "diagonal" if de[0] != para[0] and de[1] != para[1] else "reto"


class Cadeia:
    """Estado de um ator: último passo com tick exato, se ainda há certeza de continuidade desde ele."""

    def __init__(self):
        self.ultimo = None        # (tick, de, para) do último passo com tick exato
        self.intervalos = []      # (forma do passo, intervalo em ticks, forma do passo seguinte)
        self.passos = Counter()   # forma -> passos com tick exato
        self.todos = Counter()    # forma -> todos os passos vistos (com ou sem tick exato)

    def cortar(self):
        self.ultimo = None

    def passo(self, tick, de, para, exato):
        f = _forma(de, para)
        self.todos[f] += 1
        if not exato:
            self.ultimo = None
            return
        self.passos[f] += 1
        if self.ultimo is not None and self.ultimo[2] == de:
            self.intervalos.append((_forma(self.ultimo[1], self.ultimo[2]), tick - self.ultimo[0], f))
        self.ultimo = (tick, de, para)


def _avancar(cad, a, b, seq_a, seq_b):
    gap = seq_b - seq_a
    pa, pb = (a["row"], a["col"]), (b["row"], b["col"])
    w = b.get("walkFrom") or {"row": b["row"], "col": b["col"]}
    pw = (w["row"], w["col"])
    if pw != pb:
        if _cheb(pw, pb) != 1:
            return cad.cortar()
        if pa != pw:
            if _cheb(pa, pw) != 1:
                return cad.cortar()
            cad.passo(seq_b - 1, pa, pw, gap == 2)
        elif gap > GAP_SEM_PASSO:
            cad.cortar()
        cad.passo(seq_b, pw, pb, True)
    elif pa != pb:
        if _cheb(pa, pb) != 1:
            return cad.cortar()
        cad.passo(seq_b - 1, pa, pb, gap == 2)
    elif gap > GAP_SEM_PASSO:
        cad.cortar()


def medir_instancias(msgs, slug=None):
    """Devolve {tipo_ator: [Cadeia, ...]} com uma cadeia por ator e instância (huntKey)."""
    cadeias = defaultdict(list)
    atual, ant, slug_atual = None, None, None
    for d, m, _ in msgs:
        if d != "in":
            continue
        t = m["type"]
        if t == "field-init":
            slug_atual, ant = m.get("slug"), None
            atual = {} if not slug or slug_atual == slug else None
            continue
        if t != "field" or atual is None:
            continue
        estado = {"heroi": m.get("hero")}
        for x in m.get("mobs", []):
            if not x.get("dead") and not x.get("respawning"):
                estado["mob%d" % x["slot"]] = x
        for nome, b in estado.items():
            if not b:
                continue
            if nome not in atual:
                atual[nome] = Cadeia()
                cadeias["selvagem" if nome.startswith("mob") else nome].append(atual[nome])
            cad = atual[nome]
            a = ant[1].get(nome) if ant else None
            if a is None:
                cad.cortar()
                continue
            _avancar(cad, a, b, ant[0], m["seq"])
        if ant:
            for nome in ant[1]:
                if nome not in estado and nome in atual:
                    atual[nome].cortar()     # morreu/respawn: o próximo passo não encadeia
        ant = (m["seq"], estado)
    return cadeias


def treinador_igual_heroi(msgs):
    """(fields com treinador na posição do herói, fields, fields com walkFrom do treinador ≠ posição dele)."""
    iguais = total = andando = 0
    for d, m, _ in msgs:
        if d != "in" or m["type"] != "field":
            continue
        h, t = m.get("hero"), m.get("trainer")
        if not h or not t:
            continue
        total += 1
        iguais += (h["row"], h["col"]) == (t["row"], t["col"])
        w = t.get("walkFrom")
        andando += bool(w) and (w["row"], w["col"]) != (t["row"], t["col"])
    return iguais, total, andando


def resumo(c, tick_ms=200, limite_ms=3000):
    vals = sorted(v * tick_ms for v, n in c.items() for _ in range(n) if v * tick_ms <= limite_ms)
    if not vals:
        return {"n": 0}
    moda = max(c, key=lambda k: (c[k], -k)) * tick_ms
    return {"n": len(vals), "moda": moda, "min": vals[0], "mediana": vals[len(vals) // 2],
            "frac_moda": round(c[moda // tick_ms] / len(vals), 3),
            "top": [(k * tick_ms, n) for k, n in c.most_common(6)]}


def medir(arquivos, slug=None, tick_ms=200):
    cadeias = medir_instancias(ler_logs(arquivos), slug)
    saida = {}
    for tipo, cs in sorted(cadeias.items()):
        por = defaultdict(Counter)
        todos, exatos = Counter(), Counter()
        for c in cs:
            todos.update(c.todos)
            exatos.update(c.passos)
            for f, k, f2 in c.intervalos:
                por[f][k] += 1
                por[f + "→" + f2][k] += 1
        total = sum(todos.values())
        saida[tipo] = {"passos": dict(todos), "passos_tick_exato": dict(exatos),
                       "frac_diagonal": round(todos["diagonal"] / total, 3) if total else None,
                       "intervalo_ms": {f: resumo(por[f], tick_ms) for f in sorted(por)}}
    return saida


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+")
    ap.add_argument("--slug")
    ap.add_argument("--json")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    iguais, total, andando = treinador_igual_heroi(ler_logs(a.arquivos))
    print(f"treinador na posição do herói: {iguais}/{total} fields; walkFrom do treinador ≠ posição: {andando}")
    saida = medir(a.arquivos, a.slug)
    for tipo, r in saida.items():
        print(f"{tipo}: passos {r['passos']} (tick exato {r['passos_tick_exato']}), fração diagonal {r['frac_diagonal']}")
        for f, s in r["intervalo_ms"].items():
            if s["n"]:
                print(f"   {f:18s} n={s['n']:5d} moda={s['moda']} min={s['min']} mediana={s['mediana']} "
                      f"frac_moda={s['frac_moda']} top={s['top']}")
    saida["treinador"] = {"igual_heroi": [iguais, total], "andando": andando}
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(saida, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
