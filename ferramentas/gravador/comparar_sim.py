#!/usr/bin/env python3
"""Teste diferencial: simulação × gravação real, para uma hunt.

Os dois lados passam pelo MESMO código: `analisar()` de analisar_gravacao.py (hits, abates, XP, loot, curas, HP máximo)
mais as métricas de ritmo abaixo, calculadas aqui. Os critérios são fixados antes de rodar e não são ajustados ao resultado.

Uso:
  python ferramentas/gravador/comparar_sim.py --slug rhydon --especie 112 \
      --real "poke har/gravacoes/gravacoes_unicas_2026-11-09.jsonl" --sim saida_testes/dif_*.jsonl [--json saida.json]
Código de saída: 0 se todos os critérios passarem.
"""
import argparse
import json
import math
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from analisar_gravacao import analisar, mensagens  # noqa: E402


def cheb(a, b):
    return max(abs(a["row"] - b["row"]), abs(a["col"] - b["col"]))


def percentil(v, p):
    v = sorted(v)
    if not v:
        return None
    k = (len(v) - 1) * p
    i = int(math.floor(k))
    j = min(i + 1, len(v) - 1)
    return v[i] + (v[j] - v[i]) * (k - i)


def coletar(caminhos, slug, especie):
    """Percorre as mensagens e junta, só dos fields cuja hunt é `slug` e cujos selvagens são todos `especie`."""
    r = defaultdict(list)
    r["kills"] = 0
    r["dur_ms"] = 0
    r["heals"] = []
    r["loot"] = Counter()
    r["loot_kills"] = 0
    for c in caminhos:
        atual = None
        anterior = None
        for m in mensagens(c):
            t = m["type"]
            if t == "field-init":
                atual = m.get("slug")
                anterior = None
                continue
            if atual != slug:
                continue
            if t == "field":
                if not m["mobs"] or any(x["speciesId"] != especie for x in m["mobs"]):
                    anterior = None
                    continue
                for h in m["hits"]:
                    if h["slot"] >= 0:
                        r["dano_aliado"].append(h["amount"])
                    else:
                        r["dano_selvagem"].append(h["amount"])
                for x in m["mobs"]:
                    r["hp_max"].append(x["maxHp"])
                if anterior is not None:
                    dt = m["serverNow"] - anterior["serverNow"]
                    if 0 < dt <= 10000:                     # fields que não chegaram (até ~4 s) contam; pausas longas não
                        r["dur_ms"] += dt
                        if m["fighting"]:
                            r["luta_ms"] += [dt]
                            r["hits_selv_luta"] += [sum(1 for h in m["hits"] if h["slot"] == -1)]
                        # velocidade do herói: andando atrás do mesmo alvo, sem lutar
                        if (not anterior["fighting"] and not m["fighting"] and anterior["targetSlot"] == m["targetSlot"]
                                and anterior["targetSlot"] is not None):
                            r["heroi_ms"] += [dt]
                            r["heroi_tiles"] += [cheb(anterior["hero"], m["hero"])]
                        # perseguição dos selvagens dentro da visão, longe do herói
                        if m["seq"] - anterior["seq"] == 2:
                            am = {x["slot"]: x for x in anterior["mobs"]}
                            for x in m["mobs"]:
                                p = am.get(x["slot"])
                                if not p or p["dead"] or x["dead"]:
                                    continue
                                h = anterior["hero"]
                                if cheb(p, h) > 2 and abs(p["col"] - h["col"]) <= 13 and abs(p["row"] - h["row"]) <= 7:
                                    r["mob_ms"] += [dt]
                                    r["mob_tiles"] += [cheb(p, x)]
                anterior = m
            elif t == "field-kill" and m.get("speciesId") == especie:
                r["kills"] += 1
                r["xp_por_abate"].append(m["xpGained"])
                r["loot_kills"] += 1
                for it in m.get("loot", []):
                    r["loot"][it["name"]] += 1
                    r["loot_qtd_" + it["name"]].append(it["qty"])
            elif t == "auto-heal":
                r["heals"].append(m["heal"])
    return r


def resumo(r):
    min_ = r["dur_ms"] / 60000 if r["dur_ms"] else 0
    s = {
        "minutos": round(min_, 1),
        "abates": r["kills"],
        "abates_min": r["kills"] / min_ if min_ else 0,
        "hits_aliado_por_abate": len(r["dano_aliado"]) / r["kills"] if r["kills"] else 0,
        "curas_min": len(r["heals"]) / min_ if min_ else 0,
        "cura_media": statistics.fmean(r["heals"]) if r["heals"] else 0,
        "heroi_ms_tile": sum(r["heroi_ms"]) / max(1, sum(r["heroi_tiles"])),
        "mob_ms_tile": sum(r["mob_ms"]) / max(1, sum(r["mob_tiles"])),
        "hits_selvagem_por_min_lutando": sum(r["hits_selv_luta"]) / (sum(r["luta_ms"]) / 60000) if r["luta_ms"] else 0,
    }
    for k in ("dano_aliado", "dano_selvagem"):
        v = r[k]
        s[k] = {"n": len(v), "min": min(v) if v else None, "p01": percentil(v, .01), "media": statistics.fmean(v) if v else None,
                "p99": percentil(v, .99), "max": max(v) if v else None}
    hp = sorted(set(r["hp_max"]))
    s["hp_max_distintos"] = hp
    s["xp_por_abate"] = sorted(set(r["xp_por_abate"]))
    s["loot_taxa"] = {k: v / r["loot_kills"] for k, v in r["loot"].items()} if r["loot_kills"] else {}
    s["loot_qtd_media"] = {k[len("loot_qtd_"):]: statistics.fmean(v) for k, v in r.items() if k.startswith("loot_qtd_")}
    return s


def cadencia_aliado(analises, filtro_eff):
    """Intervalo mais frequente entre hits do aliado, pelo analisar_gravacao.py (mesmo código nos dois lados)."""
    c = Counter()
    for h in analises:
        for k, v in h["hits"].items():
            if k.startswith("aliado->selvagem") and filtro_eff in v["eff"]:
                for intervalo, n in v["intervalos"]:
                    c[round(intervalo / 200) * 200] += n
    return c.most_common(1)[0][0] if c else None, dict(c.most_common(6))


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True)
    ap.add_argument("--especie", type=int, required=True)
    ap.add_argument("--real", nargs="+", required=True)
    ap.add_argument("--sim", nargs="+", required=True)
    ap.add_argument("--eff-aliado", type=float, default=5.5, help="eff dos hits do aliado na espécie (filtra a cadência)")
    ap.add_argument("--json")
    ap.add_argument("--por-instancia", action="store_true", help="métricas de ritmo/dano por instância (um arquivo = uma instância)")
    a = ap.parse_args()

    real = resumo(coletar(a.real, a.slug, a.especie))
    sim = resumo(coletar(a.sim, a.slug, a.especie))
    cad_real = cadencia_aliado([h for h in analisar(a.real) if h["slug"] in (a.slug, "?")], a.eff_aliado)
    cad_sim = cadencia_aliado([h for h in analisar(a.sim) if h["slug"] == a.slug], a.eff_aliado)

    linhas = []

    def crit(nome, ok, v_real, v_sim, regra, origem):
        linhas.append({"metrica": nome, "real": v_real, "sim": v_sim, "criterio": regra, "ok": bool(ok), "origem": origem})

    def perto(x, y, tol):
        return y and abs(x - y) / abs(y) <= tol

    crit("XP por abate", sim["xp_por_abate"] == real["xp_por_abate"], real["xp_por_abate"], sim["xp_por_abate"], "igual", "A")
    crit("cadência do aliado (moda, ms)", cad_sim[0] == cad_real[0], cad_real, cad_sim, "mesma moda", "A")
    for k, nome in (("dano_aliado", "dano aliado→selvagem"), ("dano_selvagem", "dano selvagem→aliado")):
        r, s = real[k], sim[k]
        if not a.por_instancia:  # no modo por instância a média é comparada contra a distribuição das instâncias
            crit(nome + " (média)", perto(s["media"], r["media"], 0.10), round(r["media"], 1), round(s["media"], 1), "±10%", "F (fórmula candidata)")
        crit(nome + " (faixa real dentro do envelope p01–p99 da sim)", s["p01"] <= r["min"] * 1.05 and r["max"] <= s["p99"] * 1.05 + 1,
             [r["min"], r["max"]], [round(s["p01"]), round(s["p99"])], "real ⊂ [p01, p99] da sim (5% de folga)", "F")
    hr, hs = real["hp_max_distintos"], sim["hp_max_distintos"]
    crit("HP máximo dos selvagens (faixa)", min(hs) <= min(hr) and max(hr) <= max(hs), [min(hr), max(hr)], [min(hs), max(hs)],
         "faixa real ⊂ faixa da sim", "A (35×stat) + C (rollQuality/IV)")
    crit("HP máximo dos selvagens (todos múltiplos de 35)", all(x % 35 == 0 or x == 120 for x in hs), True,
         all(x % 35 == 0 or x == 120 for x in hs), "sim", "A")
    mr, ms_ = statistics.fmean(hr), statistics.fmean(hs)
    if not a.por_instancia:
        crit("HP máximo dos selvagens (média dos distintos)", perto(ms_, mr, 0.10), round(mr), round(ms_), "±10%", "C")
    for item, taxa in sorted(real["loot_taxa"].items()):
        n = real["abates"]
        st = sim["loot_taxa"].get(item, 0.0)
        sigma = math.sqrt(max(st * (1 - st), 1e-9) / max(n, 1))
        crit(f"loot {item} (taxa por abate)", abs(taxa - st) <= 3 * sigma + 1e-9, round(taxa, 3), round(st, 3), "|Δ| ≤ 3σ binomial (n real)", "A")
    for item, q in sorted(real["loot_qtd_media"].items()):
        qs = sim["loot_qtd_media"].get(item, 0)
        crit(f"loot {item} (quantidade média)", perto(qs, q, 0.20), round(q, 2), round(qs, 2), "±20%", "A")
    ritmo = [
        ("abates por minuto", "abates_min", 0.20, "derivado"),
        ("hits do aliado por abate", "hits_aliado_por_abate", 0.15, "derivado"),
        ("hits selvagens por minuto lutando", "hits_selvagem_por_min_lutando", 0.20, "F (aggro/ritmo)"),
        ("curas por minuto", "curas_min", 0.30, "F (limiar/recarga)"),
        ("cura média", "cura_media", 0.15, "A+F"),
        ("herói: ms por tile andando", "heroi_ms_tile", 0.15, "F"),
        ("selvagem: ms por tile perseguindo", "mob_ms_tile", 0.15, "A+F"),
    ]
    if a.por_instancia and len(a.sim) >= 5:
        # Cada arquivo de simulação = uma instância (15 indivíduos sorteados uma vez, como no original);
        # a gravação real também é uma instância só. Critério: valor real entre p05 e p95 das instâncias simuladas.
        por = [resumo(coletar([f], a.slug, a.especie)) for f in a.sim]
        dist = {
            "dano aliado→selvagem (média por instância)": ([p["dano_aliado"]["media"] for p in por], real["dano_aliado"]["media"]),
            "dano selvagem→aliado (média por instância)": ([p["dano_selvagem"]["media"] for p in por], real["dano_selvagem"]["media"]),
            "HP máximo dos selvagens (média por instância)": ([statistics.fmean(p["hp_max_distintos"]) for p in por], mr),
        }
        for nome, chave, _, origem in ritmo:
            dist[nome + " (por instância)"] = ([p[chave] for p in por], real[chave])
        for nome, (v, r) in dist.items():
            lo, hi = percentil(v, 0.05), percentil(v, 0.95)
            crit(nome, lo <= r <= hi, round(r, 2), [round(lo, 2), round(hi, 2)], f"real ∈ [p05, p95] de {len(v)} instâncias", "distribuição")
    else:
        for nome, chave, tol, origem in ritmo:
            crit(nome, perto(sim[chave], real[chave], tol), round(real[chave], 2), round(sim[chave], 2), f"±{int(tol * 100)}%", origem)

    print(f"real: {real['minutos']} min, {real['abates']} abates | sim: {sim['minutos']} min, {sim['abates']} abates")
    print(f"{'métrica':58} {'real':>22} {'sim':>22}  critério")
    for l in linhas:
        rv = json.dumps(l["real"], ensure_ascii=False)[:22]
        sv = json.dumps(l["sim"], ensure_ascii=False)[:22]
        print(f"{'OK   ' if l['ok'] else 'FALHA'} {l['metrica'][:52]:52} {rv:>22} {sv:>22}  {l['criterio']} [{l['origem']}]")
    falhas = [l for l in linhas if not l["ok"]]
    print(f"RESULTADO: {len(linhas) - len(falhas)}/{len(linhas)} critérios dentro da faixa")
    if a.json:
        json.dump({"real": real, "sim": sim, "criterios": linhas}, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=str)
    return 0 if not falhas else 1


if __name__ == "__main__":
    sys.exit(main())
