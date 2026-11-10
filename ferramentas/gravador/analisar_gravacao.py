#!/usr/bin/env python3
"""Resume gravações de WebSocket do Poke Idle World em métricas comparáveis.

Aceita os três formatos (mensagem crua por linha, gravador antigo {direcao,dados},
gravador novo {dir,msg}). Para cada hunt (field-init) mede:
  - intervalo entre snapshots (serverNow) e passo de seq
  - hits por golpe e lado (aliado->selvagem, selvagem->aliado): n, intervalo típico, min/média/máx de dano, eff
  - abates, XP por parcela, loot por item, capturas por bola, auto-heals
  - HP máximo dos selvagens (para conferir 35 x stat)
  - penalidade de entrada (boost shinylock): until, abates antes/depois, com/sem xpParts.debuff, drops por abate
  - gravador v1.1: respostas REST por endpoint e a diferença do used-balls entre a primeira e a última (rest.py)
Uso: python3 analisar_gravacao.py gravacao.jsonl [mais.jsonl ...] [--json saida.json]
"""
import argparse, json, os, statistics, sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rest  # noqa: E402


def mensagens(caminho):
    for linha in open(caminho, encoding="utf-8", errors="replace"):
        linha = linha.strip()
        if not linha:
            continue
        try:
            o = json.loads(linha)
        except Exception:
            continue
        if isinstance(o, dict) and "direcao" in o and "dados" in o:
            if not o["direcao"].startswith("receb"):
                continue
            try:
                o = json.loads(o["dados"])
            except Exception:
                continue
        elif isinstance(o, dict) and "dir" in o and "msg" in o:
            if o["dir"] != "in":
                continue
            o = o["msg"]
        if isinstance(o, dict) and "type" in o:
            yield o


def resumo_valores(v):
    if not v:
        return None
    return {"n": len(v), "min": min(v), "media": round(statistics.fmean(v), 2), "max": max(v),
            "mediana": statistics.median(v)}


def analisar(caminhos):
    hunts = []
    atual = None
    for c in caminhos:
        ultimo_lock = 0
        for m in mensagens(c):
            t = m["type"]
            if t == "field-init":
                atual = {"slug": m.get("slug"), "huntKey": m.get("huntKey"), "fonte": c.split("/")[-1],
                         "init": {k: m.get(k) for k in ("rows", "cols", "tickMs", "heroStepMs", "mobStepMs", "trainerStepMs")},
                         "fields": [], "kills": [], "catches": [], "heals": [], "locks": []}
                if ultimo_lock:   # o lock é do jogador, não da instância: vale também nas retomadas (:rN)
                    atual["locks"].append(ultimo_lock)
                hunts.append(atual)
                continue
            if atual is None:
                if t == "field":   # gravação começou no meio da hunt
                    atual = {"slug": "?", "huntKey": None, "fonte": c.split("/")[-1], "init": {},
                             "fields": [], "kills": [], "catches": [], "heals": [], "locks": []}
                    hunts.append(atual)
                else:
                    continue
            if t == "field":
                atual["fields"].append(m)
            elif t == "field-kill":
                # instante do abate no relógio do servidor ≈ serverNow do último field (o field-kill sai antes do field
                # do tick do abate, então fica no máximo um intervalo de field atrás)
                atual["kills"].append(dict(m, _srv=atual["fields"][-1]["serverNow"] if atual["fields"] else None))
            elif t == "boosts":
                for b in m.get("boosts") or []:
                    if b.get("key") == "shinylock":
                        ultimo_lock = int(b.get("until", 0))
                        atual["locks"].append(ultimo_lock)
            elif t == "catch-result":
                atual["catches"].append(m)
            elif t == "auto-heal":
                atual["heals"].append(m)
            elif t in ("field-none", "leave-hunt"):
                atual = None
    saida = []
    for h in hunts:
        fs = h["fields"]
        r = {"slug": h["slug"], "fonte": h["fonte"], "init": h["init"], "snapshots": len(fs)}
        if len(fs) > 1:
            dt = [b["serverNow"] - a["serverNow"] for a, b in zip(fs, fs[1:]) if "serverNow" in a and "serverNow" in b]
            dseq = [b["seq"] - a["seq"] for a, b in zip(fs, fs[1:]) if "seq" in a and "seq" in b]
            r["intervaloMs"] = Counter(dt).most_common(5)
            r["passoSeq"] = Counter(dseq).most_common(5)
            r["duracaoS"] = round((fs[-1]["serverNow"] - fs[0]["serverNow"]) / 1000, 1)
        if fs:
            r["heroi"] = {"nome": fs[0].get("heroName"), "looktype": fs[0].get("heroLooktype"),
                          "hpMax": fs[0].get("heroMaxHp")}
            hp = defaultdict(set)
            for f in fs:
                for mob in f.get("mobs", []):
                    hp[mob["speciesId"]].add(mob["maxHp"])
            r["hpMaxSelvagens"] = {str(k): sorted(v) for k, v in hp.items()}
            r["hpMultiplo35"] = all(x % 35 == 0 or x == 120 for v in hp.values() for x in v)
        # hits: um hit pode aparecer agrupado; usa serverNow do snapshot
        por = defaultdict(lambda: {"t": [], "dano": [], "eff": Counter()})
        for f in fs:
            for hit in f.get("hits", []):
                lado = "selvagem->aliado" if hit.get("slot") == -1 else "aliado->selvagem"
                k = f"{lado} | {hit.get('move')} ({hit.get('type')})"
                por[k]["t"].append(f["serverNow"]); por[k]["dano"].append(hit.get("amount", 0)); por[k]["eff"][hit.get("eff")] += 1
                for extra in ("crit", "blocked"):
                    if hit.get(extra):
                        por[k].setdefault(extra, 0); por[k][extra] += 1
        r["hits"] = {}
        for k, v in sorted(por.items()):
            gaps = [b - a for a, b in zip(v["t"], v["t"][1:])]
            r["hits"][k] = {"dano": resumo_valores(v["dano"]), "eff": dict(v["eff"]),
                            "intervalos": Counter(gaps).most_common(5),
                            **{x: v[x] for x in ("crit", "blocked") if x in v}}
        xp = Counter(); loot = Counter()
        for kmsg in h["kills"]:
            for parte, val in (kmsg.get("xpParts") or {}).items():
                xp[parte] += val
            for l in kmsg.get("loot", []):
                loot[l["name"]] += l.get("qty", 1)
        r["abates"] = len(h["kills"]); r["xpPorParte"] = dict(xp); r["loot"] = dict(loot)
        r["capturas"] = Counter((c.get("ballName"), bool(c.get("success"))) for c in h["catches"]).most_common()
        r["capturas"] = [[b, s, n] for (b, s), n in r["capturas"]]
        r["autoHeal"] = Counter((x.get("name"), x.get("heal")) for x in h["heals"]).most_common()
        pen = {"until": h["locks"][-1] if h["locks"] else None,
               "comDebuff": sum(1 for k in h["kills"] if "debuff" in (k.get("xpParts") or {}))}
        if pen["until"]:
            antes = [k for k in h["kills"] if k["_srv"] is not None and k["_srv"] < pen["until"]]
            depois = [k for k in h["kills"] if k["_srv"] is not None and k["_srv"] >= pen["until"]]
            pen.update({"abatesAntes": len(antes), "abatesDepois": len(depois),
                        "debuffAntes": sum(1 for k in antes if "debuff" in (k.get("xpParts") or {})),
                        "debuffDepois": sum(1 for k in depois if "debuff" in (k.get("xpParts") or {})),
                        "dropsPorAbateAntes": round(sum(len(k.get("loot") or []) for k in antes) / max(1, len(antes)), 3),
                        "dropsPorAbateDepois": round(sum(len(k.get("loot") or []) for k in depois) / max(1, len(depois)), 3)})
        r["penalidade"] = pen
        saida.append(r)
    return saida


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+")
    ap.add_argument("--json")
    a = ap.parse_args()
    res = analisar(a.arquivos)
    for r in res:
        print(f"\n== {r['slug']} ({r['fonte']}) snapshots={r['snapshots']} duração={r.get('duracaoS')} s")
        print("   init:", r["init"])
        print("   intervalo ms:", r.get("intervaloMs"), " passo seq:", r.get("passoSeq"))
        if "heroi" in r: print("   herói:", r["heroi"], " HP selvagem múltiplo de 35:", r.get("hpMultiplo35"))
        for k, v in r["hits"].items():
            print(f"   {k}: dano={v['dano']} eff={v['eff']} intervalos={v['intervalos']}")
        print("   abates:", r["abates"], " xp:", r["xpPorParte"], " loot:", r["loot"])
        if r["capturas"]: print("   capturas:", r["capturas"])
        if r["autoHeal"]: print("   auto-heal:", r["autoHeal"])
        if r["penalidade"]["until"] or r["penalidade"]["comDebuff"]: print("   penalidade de entrada:", r["penalidade"])
    for c in a.arquivos:
        rs = rest.ler_rest(c)
        if not rs:
            continue
        print(f"\n== REST ({c.split('/')[-1]}): {len(rs)} respostas:",
              dict(Counter(f"{x['metodo']} {x['caminho']}" for x in rs).most_common()))
        ub = rest.used_balls(c)
        if len(ub) >= 2:
            print("   used-balls (primeira → última):")
            for k, d in rest.diferenca(ub[0]["corpo"], ub[-1]["corpo"]).items():
                print("     ", k, json.dumps(d, ensure_ascii=False))
        elif ub:
            print("   used-balls: só 1 resposta (abra a tela Gerenciamento de Captura no início E no fim)")
    if a.json:
        json.dump(res, open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    sys.exit(main())
