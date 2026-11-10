#!/usr/bin/env python3
"""Confere as gravações da fase 3 (poke har/gravacoes/fase3/<ID>.jsonl) contra PLANO_GRAVACOES_FASE3.md.

Para cada gravação: configuração gravada (sessão, hunt, entradas e retomadas, líderes com nível, bola da auto-captura),
golpes do líder (contagem por líder e por golpe; o mesmo golpe por indivíduo?), capturas por bola, penalidade de XP de
entrada (abates com `xpParts.debuff`, instante do último e do primeiro sem) e a previsão do plano com o critério
(≥ 95% dos hits do líder no golpe previsto). Tudo aqui é observação direta (A); a previsão é a hipótese da sim (F).

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
         "capturas": Counter(), "abates": 0, "debuff": [], "sem_debuff": None, "t_entrada": None, "duracao_s": 0}
    t0 = t1 = None
    for reg in ler(caminho):
        m = reg.get("msg") or {}
        t = m.get("type")
        r["sessoes"].add(reg.get("sessao"))
        if t == "enter-hunt":
            r["entradas"].append((m.get("slug"), bool(m.get("resume"))))
            r["t_entrada"] = r["t_entrada"] or reg["t"]
        elif t == "field-init":
            r["huntKeys"].append(m.get("huntKey"))
        elif t == "pokes-chunk":
            for p in m.get("list", []):
                if p.get("team"):
                    r["niveis"][p["name"]] = p["level"]
        elif t == "field-kill":
            r["abates"] += 1
            pk = m.get("pokeXp") or {}
            deb = (m.get("xpParts") or {}).get("debuff", 0)
            dt = round((reg["t"] - (r["t_entrada"] or reg["t"])) / 1000.0, 1)
            if deb:
                r["debuff"].append(dt)
            elif r["sem_debuff"] is None:
                r["sem_debuff"] = dt
            if pk.get("level"):
                r["niveis"].setdefault("_poke_%s" % pk.get("speciesId"), pk.get("level"))
        elif t == "catch-result":
            r["capturas"][(m.get("ballName"), bool(m.get("success")))] += 1
        elif t == "field":
            t0 = t0 or m["serverNow"]
            t1 = m["serverNow"]
            nome = m.get("heroName")
            r["lideres"][nome] += 1
            for h in m.get("hits", []):
                if int(h.get("slot", -1)) >= 0:        # slot do selvagem atingido = golpe do líder
                    r["golpes"][(nome, h.get("move"))] += 1
                    r["por_slot"][(nome, h["slot"])][h.get("move")] += 1
    r["duracao_s"] = round((t1 - t0) / 1000.0) if t0 else 0
    return r


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
                      "primeiro_sem_debuff_s": r["sem_debuff"], "golpe_previsto": v})
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(saida, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
