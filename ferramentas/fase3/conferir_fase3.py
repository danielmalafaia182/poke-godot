#!/usr/bin/env python3
"""Confere as gravações da fase 3 (poke har/gravacoes/fase3/<ID>.jsonl) contra PLANO_GRAVACOES_FASE3.md.

Para cada gravação: configuração gravada (sessão, hunt, entradas e retomadas, líderes com nível, bola da auto-captura),
golpes do líder (contagem por líder e por golpe; o mesmo golpe por indivíduo?), capturas por bola, penalidade de XP de
entrada (abates com `xpParts.debuff`, instante do último e do primeiro sem) e a previsão do plano com o critério
(≥ 95% dos hits do líder no golpe previsto). Tudo aqui é observação direta (A); a previsão é a hipótese da sim (F).

Captura (gravador v1.1): o used-balls da primeira e da última resposta REST dá o medidor de cada espécie no início e no
fim; a previsão de capturas usa o modelo do medidor da sim (sim/regras.gd, F), partindo do medidor do início (sem
used-balls: parte de zero, marcado). Penalidade: until do boost shinylock e abates antes/depois.

Uso: python -I ferramentas/fase3/conferir_fase3.py [arquivos…]   (padrão: todas as de poke har/gravacoes/fase3/)
     --json saida.json grava o resumo.
"""
import argparse
import glob
import json
import os
import sys
from collections import Counter, defaultdict

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "gravador"))
import rest  # noqa: E402

# Modelo do medidor (F) — mesmos valores de sim/regras.gd PARAMETROS (captura_*)
C0, ALFA = 0.68, 0.86
EFIC = {1: 1, 2: 2, 3: 3, 4: 4, 5: 255, 6: 5, 7: 5}
PRECO_BOLA = {1: 5, 2: 20, 3: 50, 4: 130, 5: 0, 6: 400, 7: 400}


def valor_bola(b):
    return EFIC.get(b, 0) * PRECO_BOLA[3] / 3.0


def chance(b, nivel, investido, preco):
    if EFIC.get(b, 0) <= 0:
        return 0.0
    if EFIC[b] >= 255:
        return 1.0
    return max(0.0, min(1.0, C0 * max(1, nivel) ** -ALFA * investido / max(1.0, preco)))


def _carregar(nome):
    d = json.load(open(os.path.join(RAIZ, "dados", "gerados", nome), encoding="utf-8"))
    return d if isinstance(d, list) else list(d.values()) if not isinstance(next(iter(d.values())), dict) or "id" in next(iter(d.values())) else d

# Previsões do plano (F, sim/regras.gd escolher_golpe): ID → (hunt, {líder: golpe previsto})
PLANO_GOLPES = {
    "S1": ("oddish", {"Rhydon": "Stone Edge", "Golem": "Earthquake"}),
    "S2": ("rattata", {"Rhydon": "Hammer Arm"}),
    "S3": ("rhyhorn", {"Gyarados": "Hydro Pump"}),
    "S4": ("vulpix", {"Venusaur": "Double-Edge"}),
    "S5": ("hoppip", {"Gyarados": "Ice Fang"}),
    "S6": ("chansey", {"Exeggutor": "Wood Hammer"}),
    "S7": ("exeggcute", {"Rhydon": "Megahorn", "Golem": "Steamroller"}),
    "S8": ("bulbasaur", {"Venusaur": "Double-Edge"}),
}
PLANO_CAPTURA = {"C1": "spearow", "C2": "vulpix", "C3": "arbok", "C4": "pikachu", "C5": "vulpix", "C6": "bulbasaur"}
PLANO_MOVIMENTO = {"M1": "kangaskhan", "M2": "kangaskhan", "M3": "rhydon", "M4": "rattata"}


def ler(caminho):
    for linha in open(caminho, encoding="utf-8"):
        linha = linha.strip()
        if linha:
            yield json.loads(linha)


def conferir(caminho):
    ident = os.path.splitext(os.path.basename(caminho))[0].split("_")[0].upper()
    r = {"arquivo": os.path.basename(caminho), "id": ident, "sessoes": set(), "entradas": [], "huntKeys": [],
         "niveis": {}, "lideres": Counter(), "golpes": Counter(), "por_slot": defaultdict(Counter),
         "capturas": Counter(), "tentativas": [], "lock_until": None, "abates_srv": [], "abates": 0, "debuff": [], "sem_debuff": None, "t_entrada": None, "duracao_s": 0}
    t0 = t1 = ultimo_srv = slug_atual = None
    for reg in ler(caminho):
        m = reg.get("msg") or {}
        t = m.get("type")
        r["sessoes"].add(reg.get("sessao"))
        if t == "enter-hunt":
            r["entradas"].append((m.get("slug"), bool(m.get("resume"))))
            r["t_entrada"] = r["t_entrada"] or reg["t"]
        elif t == "field-init":
            r["huntKeys"].append(m.get("huntKey"))
            slug_atual = m.get("slug")
        elif t == "pokes-chunk":
            for p in m.get("list", []):
                if p.get("team"):
                    r["niveis"][p["name"]] = p["level"]
        elif t == "field-kill":
            r["abates"] += 1
            pk = m.get("pokeXp") or {}
            deb = (m.get("xpParts") or {}).get("debuff", 0)
            dt = round((reg["t"] - (r["t_entrada"] or reg["t"])) / 1000.0, 1)
            r["abates_srv"].append((ultimo_srv, bool(deb)))
            if deb:
                r["debuff"].append(dt)
            elif r["sem_debuff"] is None:
                r["sem_debuff"] = dt
            if pk.get("level"):
                r["niveis"].setdefault("_poke_%s" % pk.get("speciesId"), pk.get("level"))
        elif t == "catch-result":
            r["capturas"][(m.get("ballName"), bool(m.get("success")))] += 1
            r["tentativas"].append((m.get("speciesName"), int(m.get("ballId", 0)), bool(m.get("success")), slug_atual))
        elif t == "boosts":
            for b in m.get("boosts") or []:
                if b.get("key") == "shinylock":
                    r["lock_until"] = int(b.get("until", 0))
        elif t == "field":
            ultimo_srv = m["serverNow"]
            t0 = t0 or m["serverNow"]
            t1 = m["serverNow"]
            nome = m.get("heroName")
            r["lideres"][nome] += 1
            for h in m.get("hits", []):
                if int(h.get("slot", -1)) >= 0:        # slot do selvagem atingido = golpe do líder
                    r["golpes"][(nome, h.get("move"))] += 1
                    r["por_slot"][(nome, h["slot"])][h.get("move")] += 1
    r["duracao_s"] = round((t1 - t0) / 1000.0) if t0 else 0
    r["used_balls"] = rest.used_balls(caminho)
    return r


def conferir_captura(r, slug):
    """Por espécie: tentativas, capturas e capturas esperadas pelo modelo do medidor (F), partindo do used-balls."""
    if not r["tentativas"]:
        return []
    esp = {e["nome"]: e for e in _carregar("especies.json")}
    hunts = json.load(open(os.path.join(RAIZ, "dados", "gerados", "hunts.json"), encoding="utf-8"))
    hunts = {h["slug"]: h for h in hunts} if isinstance(hunts, list) else hunts
    ub = r["used_balls"]
    ini = rest.medidor(ub[0]["corpo"]) if ub else {}
    fim = rest.medidor(ub[-1]["corpo"]) if len(ub) >= 2 else {}
    linhas = []
    nivel = 1
    for nome in sorted({x[0] for x in r["tentativas"]}):
        e = esp.get(nome, {})
        sid, preco = int(e.get("id", 0)), float(e.get("precoNpc", 0) or 0)
        m0 = ini.get((sid, False))
        inv = (m0["tentativas"] * valor_bola(r["tentativas"][0][1])) if m0 else 0.0   # F: medidor ≈ tentativas × bola usada
        esperado, obs, n = 0.0, 0, 0
        niveis = set()
        for nm, b, ok, sl in r["tentativas"]:
            if nm != nome:
                continue
            h_ = sl or slug
            # sem field-init no arquivo (gravação começou no meio da hunt): nível da hunt da espécie (nivelHunt)
            nivel = int(hunts[h_]["nivel"]) if h_ in hunts else int(e.get("nivelHunt") or 1)
            niveis.add((h_ if h_ in hunts else "?", nivel))
            n += 1
            inv += valor_bola(b)
            p = chance(b, nivel, inv, preco)
            esperado += p          # esperança condicionada à história observada (o medidor zera nas capturas reais)
            if ok:
                obs += 1
                inv = 0.0
        m1 = fim.get((sid, False))
        linhas.append({"especie": nome, "nivel": nivel, "hunts": sorted(niveis), "preco": preco, "tentativas": n, "capturas": obs,
                       "esperado_modelo": round(esperado, 2), "medidor_inicio": m0, "medidor_fim": m1,
                       "fonte_medidor": "used-balls" if m0 else "sem used-balls (partindo de 0)"})
    return linhas


def veredicto_golpes(r):
    plano = PLANO_GOLPES.get(r["id"])
    if not plano:
        return None
    hunt, prev = plano
    linhas = []
    for lider, golpe in prev.items():
        tot = sum(n for (l, _g), n in r["golpes"].items() if l == lider)
        ok = r["golpes"].get((lider, golpe), 0)
        slots = [c for (l, _s), c in r["por_slot"].items() if l == lider]
        fixos = sum(1 for c in slots if len(c) == 1)
        frac = ok / tot if tot else 0.0
        v = "inconclusivo (sem hits)" if not tot else ("confirma" if frac >= 0.95 else "não atinge 95%")
        linhas.append({"lider": lider, "previsto": golpe, "hits": tot, "no_previsto": ok, "fracao": round(frac, 3),
                       "individuos": len(slots), "individuos_com_um_golpe": fixos, "veredicto": v})
    return {"hunt_plano": hunt, "linhas": linhas}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="*")
    ap.add_argument("--json")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    arqs = a.arquivos or sorted(glob.glob(os.path.join(RAIZ, "poke har", "gravacoes", "fase3", "*.jsonl")))
    saida = []
    for c in arqs:
        r = conferir(c)
        slug = r["entradas"][0][0] if r["entradas"] else None
        esperado = (PLANO_GOLPES.get(r["id"], (None,))[0] or PLANO_CAPTURA.get(r["id"]) or PLANO_MOVIMENTO.get(r["id"]))
        print("== %s  sessões %d  hunt %s (plano: %s)  entradas %s  retomadas %d  %d s  %d abates" % (
            r["arquivo"], len(r["sessoes"]), slug, esperado, r["entradas"],
            sum(1 for k in r["huntKeys"] if ":r" in str(k)), r["duracao_s"], r["abates"]))
        print("   líderes (fields):", dict(r["lideres"]), " níveis do time:", {k: v for k, v in r["niveis"].items() if not k.startswith("_")})
        print("   golpes do líder:", {"%s/%s" % k: n for k, n in r["golpes"].items()})
        print("   capturas:", {"%s %s" % (b, "ok" if s else "falha"): n for (b, s), n in r["capturas"].items()})
        print("   penalidade de entrada: %d abates (último em %s s; 1º sem em %s s)" % (
            len(r["debuff"]), r["debuff"][-1] if r["debuff"] else "-", r["sem_debuff"]))
        if r["lock_until"]:
            antes = [d for s_, d in r["abates_srv"] if s_ is not None and s_ < r["lock_until"]]
            depois = [d for s_, d in r["abates_srv"] if s_ is not None and s_ >= r["lock_until"]]
            print("   shinylock until %d: %d abates antes (%d com debuff), %d depois (%d com debuff)" % (
                r["lock_until"], len(antes), sum(antes), len(depois), sum(depois)))
        if r["used_balls"]:
            print("   used-balls: %d respostas REST" % len(r["used_balls"]))
        cap = conferir_captura(r, slug)
        for c_ in cap:
            print("   captura %(especie)s (%(hunts)s, preço %(preco).0f): %(capturas)d/%(tentativas)d; o modelo do medidor"
                  " esperava %(esperado_modelo).2f (%(fonte_medidor)s)" % c_)
        v = veredicto_golpes(r)
        if v:
            for ln in v["linhas"]:
                print("   %(lider)s: previsto %(previsto)s em %(no_previsto)d/%(hits)d hits (%(fracao).3f) → %(veredicto)s;"
                      " %(individuos_com_um_golpe)d/%(individuos)d indivíduos sempre com o mesmo golpe" % ln)
        saida.append({"arquivo": r["arquivo"], "id": r["id"], "hunt": slug, "hunt_plano": esperado,
                      "sessoes": sorted(r["sessoes"]), "entradas": r["entradas"], "huntKeys": r["huntKeys"],
                      "duracao_s": r["duracao_s"], "abates": r["abates"], "lideres": dict(r["lideres"]),
                      "niveis": r["niveis"], "golpes": {"%s/%s" % k: n for k, n in r["golpes"].items()},
                      "capturas": {"%s|%s" % k: n for k, n in r["capturas"].items()},
                      "debuff_abates": len(r["debuff"]), "debuff_ultimo_s": r["debuff"][-1] if r["debuff"] else None,
                      "primeiro_sem_debuff_s": r["sem_debuff"], "golpe_previsto": v,
                      "shinylock_until": r["lock_until"], "captura": cap})
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(saida, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
