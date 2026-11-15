#!/usr/bin/env python3
"""Fase 4, item 2: compara por minuto de hunt uma gravação real de time de nível baixo com instâncias da sim.

Mede, só nos fields em que o herói é a espécie pedida (padrão Geodude): abates/min, desmaios do aliado/min
(heroHp chega a 0), HP médio do aliado (fração), dano recebido por golpe, dano dado por golpe (por nível do aliado),
HP máximo dos selvagens, níveis ganhos/min e curas/min. O tempo é a soma dos intervalos entre fields consecutivos
(intervalos > 5 s não contam: troca de hunt, pausa).

Uso: python -I ferramentas/fase4/comparar_nivel_baixo.py --real "poke har/gravacoes/geodude-10min.jsonl" ... \
        --sim saida_testes/geo_s*.jsonl [--heroi Geodude] [--md saida.md]
"""
import argparse
import glob
import json
import statistics
import sys


def ler(caminho):
    for l in open(caminho, encoding="utf-8", errors="replace"):
        try:
            o = json.loads(l)
        except Exception:
            continue
        m = o.get("msg") if isinstance(o, dict) else None
        if isinstance(m, dict):
            yield m


def medir(arquivos, heroi, slug=None):
    r = {"ms": 0, "abates": 0, "desmaios": 0, "hp": [], "rec": [], "dado": {}, "mxhp": [], "niveis": 0, "curas": 0}
    for arq in arquivos:
        ult = None
        dentro = False
        nivel = None
        hp_ant = None
        slug_atual = None
        for m in ler(arq):
            t = m.get("type")
            if t == "field-init":
                slug_atual = m.get("slug")
            if t == "field":
                dentro = m.get("heroName") == heroi and (slug is None or slug_atual in (None, slug))
                if not dentro:
                    ult = None
                    continue
                agora = int(m.get("serverNow", 0))
                if ult is not None and 0 < agora - ult <= 5000:
                    r["ms"] += agora - ult
                ult = agora
                hp, mx = int(m.get("heroHp", 0)), max(1, int(m.get("heroMaxHp", 1)))
                r["hp"].append(hp / mx)
                if hp <= 0 and (hp_ant is None or hp_ant > 0):
                    r["desmaios"] += 1
                hp_ant = hp
                for h in m.get("hits", []):
                    if int(h.get("slot", 0)) < 0:
                        r["rec"].append(int(h["amount"]))
                    elif nivel is not None:
                        r["dado"].setdefault(nivel, []).append(int(h["amount"]))
                for mb in m.get("mobs", []):
                    r["mxhp"].append(int(mb.get("maxHp", 0)))
            elif not dentro:
                continue
            elif t == "field-kill":
                r["abates"] += 1
                px = m.get("pokeXp", {})
                if isinstance(px, dict) and px.get("level") is not None:
                    nivel = int(px["level"])
            elif t == "poke-xp":
                if m.get("leveledUp"):
                    r["niveis"] += 1
                nivel = int(m.get("level", nivel or 1))
            elif t == "auto-heal":
                r["curas"] += 1
    return r


def resumo(r):
    mn = r["ms"] / 60000.0 or 1e-9
    return {"min": round(mn, 2), "abates/min": round(r["abates"] / mn, 2), "desmaios/min": round(r["desmaios"] / mn, 3),
            "HP médio do aliado": round(statistics.mean(r["hp"]), 3) if r["hp"] else None,
            "dano recebido/golpe": round(statistics.mean(r["rec"]), 2) if r["rec"] else None,
            "golpes recebidos/min": round(len(r["rec"]) / mn, 1),
            "HP máx. selvagem": round(statistics.mean(r["mxhp"]), 1) if r["mxhp"] else None,
            "níveis/min": round(r["niveis"] / mn, 3), "curas/min": round(r["curas"] / mn, 2),
            "dano dado por nível": {k: (min(v), round(statistics.mean(v), 2), max(v), len(v)) for k, v in sorted(r["dado"].items())}}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--real", nargs="+", required=True)
    ap.add_argument("--sim", nargs="+", required=True)
    ap.add_argument("--heroi", default="Geodude")
    ap.add_argument("--slug", default=None, help="só fields depois de um field-init desta hunt")
    a = ap.parse_args()
    sims = sorted({f for p in a.sim for f in glob.glob(p)})
    real = resumo(medir(a.real, a.heroi, a.slug))
    por = [resumo(medir([f], a.heroi, a.slug)) for f in sims]
    print("REAL:", json.dumps(real, ensure_ascii=False))
    for k in real:
        if k == "dano dado por nível":
            continue
        vals = sorted(x[k] for x in por if x[k] is not None)
        if vals:
            print("%-22s real %-8s sim p05 %-8s mediana %-8s p95 %s" % (k, real[k], vals[int(0.05 * (len(vals) - 1))],
                  vals[len(vals) // 2], vals[int(0.95 * (len(vals) - 1))]))
    agg = medir(sims, a.heroi, a.slug)
    print("dano dado por nível (sim, todas):", resumo(agg)["dano dado por nível"])


if __name__ == "__main__":
    main()
