#!/usr/bin/env python3
"""Relatório por indivíduo selvagem: maxHp → stat de HP → faixa de IV/Quality → dano previsto × observado.

Para a fase 3 (calibração do dano). Não muda nada na simulação. Fontes de cada passo:
  - Indivíduo = (huntKey sem o sufixo ":rN", slot, espécie): o respawn traz o mesmo indivíduo e as retomadas
    (":r1", ":r2"…) da mesma hunt mantêm os 15 (A: maxHp por slot igual em r1..r8 do Rhydon).
  - HP do selvagem = max(120, 35 × stat HP) (A). stat = round(L/100 × (base + 2·IV) × Q^exp) (B+C).
    IV ∈ 1..32 (C/E), Quality nas faixas do rollQuality, em passos de 0,001, com os pesos do cliente (C).
    → conjunto de pares (IV_hp, Q) que reproduzem o maxHp; daí a faixa de Q do indivíduo.
  - Dano previsto = fórmula candidata (F, mesma de sim/regras.gd), com os stats exatos do aliado (poke-delta, A),
    o golpe, o tipo e o `eff` que vieram no próprio hit (A), e a defesa do selvagem variando sobre
    (Q compatível com o HP) × (IV de Def/SpD 1..32) × aleatório 0,85..1,00.
  - Compatibilidade: existe um valor de defesa do selvagem, permitido pelo HP, que explica TODOS os hits observados
    nele? Se sim, o relatório mostra a faixa de defesa (e de Q) que sobra. Se não, a fórmula candidata não fecha
    nesse indivíduo (sinal para a fase 3).
  - Selvagem → aliado: o hit no herói (slot −1) não diz quem bateu; só entram fields com UM selvagem vivo
    adjacente ao herói (Chebyshev ≤ 1), atribuídos a ele. Ataque do selvagem variando sobre Q × IV de Atk/SpA.
  - Hits por abate observados: hits do aliado no slot entre o respawn e o field-kill daquele slot (só vidas inteiras).

Uso: python relatorio_individuos.py gravacao.jsonl [...] --slug rhydon [--json saida.json] [--md saida.md]
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402

# --- mesmas constantes de sim/regras.gd (C/A/F conforme lá) ---
FAIXAS_QUALIDADE = [(0.8, 0.9, 5.0), (0.9, 1.0, 5.0), (1.0, 1.1, 34.03846), (1.1, 1.2, 20.0), (1.2, 1.3, 10.0),
                    (1.3, 1.4, 10.0), (1.4, 1.5, 10.0), (1.5, 1.6, 5.0), (1.7, 1.8, 0.67308), (1.8, 1.8, 0.28846)]
EXPOENTE = {"hp": 0.95, "atk": 0.8, "def": 0.8, "spAtk": 0.8, "spDef": 0.8, "speed": 0.95}
PARAM = {"stab": 1.5, "fator_selvagem": 1.8, "piso_aliado": 2, "piso_selvagem": 1, "aleatorio": (0.85, 1.0),
         "hp_selvagem_por_stat": 35, "hp_selvagem_minimo": 120}


def js_round(x):
    return math.floor(x + 0.5)


def stat(base, iv, nivel, q, chave):
    return js_round(nivel / 100.0 * (base + 2 * iv) * q ** EXPOENTE[chave])


def dano(nivel, poder, a, d, stab, eff, selvagem, r):
    piso = PARAM["piso_selvagem"] if selvagem else PARAM["piso_aliado"]
    if eff == 0:
        return piso
    v = (2.0 * nivel / 5.0 + 2.0) * poder * a / max(1.0, d) / 50.0
    if stab:
        v *= PARAM["stab"]
    v *= eff
    if selvagem:
        v *= PARAM["fator_selvagem"]
    return max(piso, js_round(v * r))


def grade_qualidade():
    """[(Q, peso)] com Q em passos de 0,001 (floor(x·1000)/1000 no cliente) e o peso da faixa dividido igualmente."""
    r = []
    for lo, hi, w in FAIXAS_QUALIDADE:
        if lo == hi:
            r.append((lo, w))
            continue
        ks = range(int(round(lo * 1000)), int(round(hi * 1000)))
        for k in ks:
            r.append((k / 1000.0, w / len(ks)))
    return r


QS = grade_qualidade()


def carregar(caminho):
    d = json.load(open(caminho, encoding="utf-8"))
    return d if isinstance(d, list) else next(v for v in d.values() if isinstance(v, list))


def pares_hp(base_hp, nivel, max_hp):
    """Pares (IV, Q, peso) que dão esse maxHp de selvagem."""
    alvo = None if max_hp <= PARAM["hp_selvagem_minimo"] else max_hp / PARAM["hp_selvagem_por_stat"]
    r = []
    for q, w in QS:
        for iv in range(1, 33):
            s = stat(base_hp, iv, nivel, q, "hp")
            if (alvo is None and PARAM["hp_selvagem_por_stat"] * s <= PARAM["hp_selvagem_minimo"]) or s == alvo:
                r.append((iv, q, w))
    return r


def valores_stat(base, nivel, qs_pesos, chave):
    """{valor do stat: peso} sobre Q (com peso do HP) × IV 1..32."""
    r = defaultdict(float)
    for q, w in qs_pesos.items():
        for iv in range(1, 33):
            r[stat(base, iv, nivel, q, chave)] += w / 32.0
    return r


def explica(amostras, k_fn, valores):
    """Valores do stat (defesa ou ataque) do selvagem para os quais todos os hits observados caem em
    [dano(0,85), dano(1,0)]. amostras = [(dano, snapshot do aliado)]: o aliado pode ter subido de nível no meio."""
    lo_r, hi_r = PARAM["aleatorio"]
    ok = []
    for v in sorted(valores):
        if all(k_fn(v, lo_r, h) <= a <= k_fn(v, hi_r, h) for a, h in amostras):
            ok.append(v)
    return ok


def faixa_continua(base, nivel, qs, chave):
    """Faixa do stat SEM arredondar (L/100 × (base + 2·IV) × Q^exp) sobre os Q compatíveis com o HP e IV 1..32."""
    e = EXPOENTE[chave]
    return (nivel / 100.0 * (base + 2) * min(qs) ** e, nivel / 100.0 * (base + 64) * max(qs) ** e)


def explica_continuo(amostras, k_lin, faixa):
    """Hipótese F (stats sem arredondar): intervalo do stat do selvagem que explica todos os hits, com o dano
    = round(K(stat) × aleatório). k_lin(h) devolve (K, sentido): sentido −1 se o stat está no divisor (defesa)."""
    lo_r, hi_r = PARAM["aleatorio"]
    lo, hi = faixa
    for a, h in amostras:
        k, sentido = k_lin(h)
        if a <= 1:
            continue                          # piso: não restringe
        if sentido < 0:                       # dano = round(k / D × r)
            lo, hi = max(lo, k * lo_r / (a + 0.5)), min(hi, k * hi_r / (a - 0.5))
        else:                                 # dano = round(k × A × r)
            lo, hi = max(lo, (a - 0.5) / (k * hi_r)), min(hi, (a + 0.5) / (k * lo_r))
    return [round(lo, 2), round(hi, 2)] if lo <= hi else None


def previsto(k_fn, valores, h):
    """min, média e máx do dano previsto (aliado no snapshot h) sobre os valores (com pesos) e aleatório uniforme."""
    lo_r, hi_r = PARAM["aleatorio"]
    rs = [lo_r + (hi_r - lo_r) * i / 15 for i in range(16)]
    tot = sum(valores.values())
    media = sum(w * sum(k_fn(v, r, h) for r in rs) / len(rs) for v, w in valores.items()) / tot
    return min(k_fn(v, lo_r, h) for v in valores), media, max(k_fn(v, hi_r, h) for v in valores)


def resumo_num(v):
    return {"n": len(v), "min": min(v), "media": round(sum(v) / len(v), 1), "max": max(v)} if v else {"n": 0}


def chave_base(hk):
    """'rhydon:1794193271335:r3' → 'rhydon:1794193271335' (as retomadas mantêm os indivíduos)."""
    partes = str(hk).split(":")
    return ":".join(partes[:-1]) if len(partes) >= 3 and partes[-1][:1] == "r" and partes[-1][1:].isdigit() else str(hk)


def coletar(caminhos, slug, especie=None):
    """Indivíduos por (huntKey, slot): maxHp, hits do aliado, hits atribuídos, vidas (hits até cada abate)."""
    ind = {}
    heroi = {}          # último poke-delta visto: {speciesId, level, stats}
    huntkey, atual = None, None
    vidas_abertas = {}  # (hk, slot) -> hits nesta vida (None = vida começou antes da gravação)
    for d, m, _ in ler_logs(caminhos):
        if d != "in":
            continue
        t = m["type"]
        if t == "poke-delta":
            p = m.get("poke", {})
            if p.get("stats"):
                heroi = {"speciesId": p.get("speciesId"), "level": p.get("level"), "stats": p["stats"],
                         "nome": p.get("name")}
        elif t == "field-init":
            huntkey, atual = chave_base(m.get("huntKey")), m.get("slug")
            vidas_abertas = {}
        elif atual != slug:
            continue
        elif t == "field":
            if not heroi or m.get("heroName") != heroi.get("nome"):
                continue
            h = m["hero"]
            vivos = [x for x in m["mobs"] if not x["dead"]]
            especies_slot = {x["slot"]: x["speciesId"] for x in m["mobs"]}
            for x in m["mobs"]:
                if especie and x["speciesId"] != especie:
                    continue
                k = (huntkey, x["slot"], x["speciesId"])
                e = ind.setdefault(k, {"huntKey": huntkey, "slot": x["slot"], "especie": x["speciesId"],
                                       "maxHp": x["maxHp"], "hits_aliado": defaultdict(list), "hits_selvagem":
                                       defaultdict(list), "hits_por_vida": [], "heroi": None})
                e["heroi"] = e["heroi"] or dict(heroi)
                if x["dead"]:
                    vidas_abertas.pop(k, None)
                elif k not in vidas_abertas:
                    # vida nova se o selvagem aparece com HP cheio; senão a vida começou fora da gravação
                    vidas_abertas[k] = 0 if x["hp"] == x["maxHp"] else None
            for hit in m["hits"]:
                if hit["slot"] >= 0:
                    k = (huntkey, hit["slot"], especies_slot.get(hit["slot"]))
                    if k in ind:
                        ind[k]["hits_aliado"][(hit["move"], hit["type"], hit["eff"])].append((hit["amount"], dict(heroi)))
                        if vidas_abertas.get(k) is not None:
                            vidas_abertas[k] += 1
            adj = [x for x in vivos if max(abs(x["row"] - h["row"]), abs(x["col"] - h["col"])) <= 1]
            if len(adj) == 1 and (huntkey, adj[0]["slot"], adj[0]["speciesId"]) in ind:
                k = (huntkey, adj[0]["slot"], adj[0]["speciesId"])
                for hit in m["hits"]:
                    if hit["slot"] == -1:
                        ind[k]["hits_selvagem"][(hit["move"], hit["type"], hit["eff"])].append((hit["amount"], dict(heroi)))
        elif t == "field-kill":
            k = (huntkey, m.get("slot"), m.get("speciesId"))
            if vidas_abertas.get(k) is not None and k in ind:
                ind[k]["hits_por_vida"].append(vidas_abertas[k])
            vidas_abertas.pop(k, None)
    return ind


def analisar(ind, especies, nivel_selvagem):
    saida = []
    for (hk, slot, _), e in sorted(ind.items(), key=lambda kv: (str(kv[0][0]), kv[0][1], kv[0][2])):
        esp = especies[e["especie"]]
        her = e["heroi"]
        if not her:
            continue
        esp_h = especies[her["speciesId"]]
        golpes_h = {g["nome"]: g for g in esp_h["golpes"]}
        golpes_s = {g["nome"]: g for g in esp["golpes"]}
        pares = pares_hp(esp["base"]["hp"], nivel_selvagem, e["maxHp"])
        qs = defaultdict(float)
        for iv, q, w in pares:
            qs[q] += w
        r = {"huntKey": hk, "slot": slot, "especie": esp["nome"], "maxHp": e["maxHp"],
             "stat_hp": e["maxHp"] // PARAM["hp_selvagem_por_stat"] if e["maxHp"] > 120 else "≤3",
             "pares_iv_q": len(pares),
             "iv_hp": [min(p[0] for p in pares), max(p[0] for p in pares)] if pares else None,
             "q": [min(qs), max(qs)] if qs else None,
             "heroi": {"nome": her["nome"], "nivel": her["level"], "stats": her["stats"]},
             "aliado_para_selvagem": [], "selvagem_para_aliado": [],
             "hits_por_abate_observado": (sum(e["hits_por_vida"]) / len(e["hits_por_vida"])) if e["hits_por_vida"] else None,
             "vidas_inteiras": len(e["hits_por_vida"])}
        if not pares:
            r["nota"] = "nenhum (IV, Q) reproduz esse maxHp"
            saida.append(r)
            continue
        tipos_s, tipos_h = esp["tipos"], esp_h["tipos"]
        media_prev_total, media_post = [], []
        for (golpe, tipo, eff), amostras in e["hits_aliado"].items():
            g = golpes_h.get(golpe)
            if not g:
                continue
            especial = g["categoria"] == "SPECIAL"
            chave_a = "spAtk" if especial else "atk"
            chave_d = "spDef" if especial else "def"
            stab = tipo in tipos_h
            vals = valores_stat(esp["base"][chave_d], nivel_selvagem, qs, chave_d)

            def k_fn(dv, rr, h, g=g, stab=stab, eff=eff, chave_a=chave_a):
                return dano(h["level"], g["poder"], h["stats"][chave_a], dv, stab, eff, False, rr)
            mn, md, mx = previsto(k_fn, vals, amostras[-1][1])
            comp = explica(amostras, k_fn, vals)
            media_prev_total.append((md, len(amostras)))
            if comp:
                _, md_post, _ = previsto(k_fn, {v: vals[v] for v in comp}, amostras[-1][1])
                media_post.append((md_post, len(amostras)))
            def k_lin(h, g=g, stab=stab, eff=eff, chave_a=chave_a):
                return ((2.0 * h["level"] / 5.0 + 2.0) * g["poder"] * h["stats"][chave_a] / 50.0
                        * (PARAM["stab"] if stab else 1.0) * eff, -1)
            cont = explica_continuo(amostras, k_lin, faixa_continua(esp["base"][chave_d], nivel_selvagem, qs, chave_d))
            r["aliado_para_selvagem"].append({
                "compativel_stat_continuo": cont,
                "golpe": golpe, "eff": eff, "stab": stab,
                "niveis_aliado": sorted({h["level"] for _, h in amostras}), "observado": resumo_num([x for x, _ in amostras]),
                "previsto": {"min": mn, "media": round(md, 1), "max": mx},
                "defesa": {"stat": chave_d, "faixa_pelo_hp": [min(vals), max(vals)],
                           "compativel_com_hits": [comp[0], comp[-1]] if comp else None},
                "compativel": bool(comp)})
        if media_prev_total:
            md = sum(m * n for m, n in media_prev_total) / sum(n for _, n in media_prev_total)
            r["hits_por_abate_previsto"] = round(e["maxHp"] / md, 2)
        if media_post:
            md = sum(m * n for m, n in media_post) / sum(n for _, n in media_post)
            r["hits_por_abate_previsto_pelos_hits"] = round(e["maxHp"] / md, 2)
        for (golpe, tipo, eff), amostras in e["hits_selvagem"].items():
            g = golpes_s.get(golpe)
            if not g:
                continue
            especial = g["categoria"] == "SPECIAL"
            chave_a = "spAtk" if especial else "atk"
            chave_dh = "spDef" if especial else "def"
            stab = tipo in tipos_s
            vals = valores_stat(esp["base"][chave_a], nivel_selvagem, qs, chave_a)

            def k_fn(av, rr, h, g=g, stab=stab, eff=eff, chave_dh=chave_dh):
                return dano(nivel_selvagem, g["poder"], av, h["stats"][chave_dh], stab, eff, True, rr)
            mn, md, mx = previsto(k_fn, vals, amostras[-1][1])
            comp = explica(amostras, k_fn, vals)
            def k_lin(h, g=g, stab=stab, eff=eff, chave_dh=chave_dh):
                return ((2.0 * nivel_selvagem / 5.0 + 2.0) * g["poder"] / max(1.0, h["stats"][chave_dh]) / 50.0
                        * (PARAM["stab"] if stab else 1.0) * eff * PARAM["fator_selvagem"], 1)
            cont = explica_continuo(amostras, k_lin, faixa_continua(esp["base"][chave_a], nivel_selvagem, qs, chave_a))
            r["selvagem_para_aliado"].append({
                "compativel_stat_continuo": cont,
                "golpe": golpe, "eff": eff, "stab": stab,
                "niveis_aliado": sorted({h["level"] for _, h in amostras}), "observado": resumo_num([x for x, _ in amostras]),
                "previsto": {"min": mn, "media": round(md, 1), "max": mx},
                "ataque": {"stat": chave_a, "faixa_pelo_hp": [min(vals), max(vals)],
                           "compativel_com_hits": [comp[0], comp[-1]] if comp else None},
                "compativel": bool(comp)})
        saida.append(r)
    return saida


def markdown(linhas, fonte):
    out = [f"# Relatório por indivíduo — {fonte}", "",
           "Fórmula de dano candidata (F). HP 35×stat, stats, IV 1..32 e Quality do rollQuality (A/B/C). "
           "ok = existe defesa/ataque permitido pelo HP que explica todos os hits observados: com stats inteiros / "
           "com o stat do selvagem sem arredondar (hipótese F).", "",
           "| instância | slot | maxHp | stat HP | IV HP | Q | golpe aliado | obs (n, mín–máx, média) | "
           "previsto (mín–máx, média) | defesa pelo HP → pelos hits | ok | hits/abate obs → prev (pelo HP / pela defesa compatível) | "
           "golpe selvagem | obs | previsto | ok |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in linhas:
        a = r["aliado_para_selvagem"][0] if r["aliado_para_selvagem"] else None
        s = max(r["selvagem_para_aliado"], key=lambda x: x["observado"]["n"]) if r["selvagem_para_aliado"] else None
        hk = str(r["huntKey"])

        def f_obs(x):
            o = x["observado"]
            return f'{o["n"]}, {o["min"]}–{o["max"]}, {o["media"]}'

        def f_prev(x):
            p = x["previsto"]
            return f'{p["min"]}–{p["max"]}, {p["media"]}'
        def ok_txt(x):
            if not x:
                return "—"
            c = x["compativel_stat_continuo"]
            return ("sim" if x["compativel"] else "**não**") + (" / sim" if c else " / **não**")
        q = r["q"]
        out.append("| " + " | ".join(str(v) for v in [
            hk, r["slot"], r["maxHp"], r["stat_hp"],
            "–".join(map(str, r["iv_hp"])) if r["iv_hp"] else "—",
            f"{q[0]:.3f}–{q[1]:.3f}" if q else "—",
            f'{a["golpe"]} (eff {a["eff"]:g})' if a else "—", f_obs(a) if a else "—", f_prev(a) if a else "—",
            (f'{a["defesa"]["faixa_pelo_hp"][0]}–{a["defesa"]["faixa_pelo_hp"][1]} → '
             + ("–".join(map(str, a["defesa"]["compativel_com_hits"])) if a["defesa"]["compativel_com_hits"] else "nenhuma"))
            if a else "—",
            ok_txt(a),
            (f'{r["hits_por_abate_observado"]:.2f}' if r["hits_por_abate_observado"] is not None else "—")
            + " → " + str(r.get("hits_por_abate_previsto", "—")) + " / " + str(r.get("hits_por_abate_previsto_pelos_hits", "—")),
            f'{s["golpe"]} (eff {s["eff"]:g})' if s else "—", f_obs(s) if s else "—", f_prev(s) if s else "—",
            ok_txt(s)]) + " |")
    ok_a = [x["compativel"] for r in linhas for x in r["aliado_para_selvagem"]]
    ok_s = [x["compativel"] for r in linhas for x in r["selvagem_para_aliado"]]
    ca = [x["compativel_stat_continuo"] is not None for r in linhas for x in r["aliado_para_selvagem"]]
    cs = [x["compativel_stat_continuo"] is not None for r in linhas for x in r["selvagem_para_aliado"]]
    out += ["", f"Indivíduos: {len(linhas)}. Golpe aliado compatível em {sum(ok_a)}/{len(ok_a)} pares "
                f"(indivíduo × golpe) com stats inteiros e {sum(ca)}/{len(ca)} sem arredondar; golpe selvagem "
                f"{sum(ok_s)}/{len(ok_s)} e {sum(cs)}/{len(cs)} (atribuição do hit ao único selvagem adjacente "
                f"tem ruído: na simulação, onde a fórmula é exata, dá ~96%)."]
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivos", nargs="+")
    ap.add_argument("--slug", default="rhydon")
    ap.add_argument("--especie", type=int, help="só indivíduos desta espécie (padrão: todas)")
    ap.add_argument("--nivel-selvagem", type=int, help="padrão: nível da hunt em dados/gerados/hunts.json")
    ap.add_argument("--json")
    ap.add_argument("--md")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    especies = {e["id"]: e for e in carregar(os.path.join(RAIZ, "dados", "gerados", "especies.json"))}
    hunts = {h["slug"]: h for h in carregar(os.path.join(RAIZ, "dados", "gerados", "hunts.json"))}
    nivel = a.nivel_selvagem or int(hunts[a.slug]["nivel"])
    linhas = analisar(coletar(a.arquivos, a.slug, a.especie), especies, nivel)
    md = markdown(linhas, ", ".join(os.path.basename(x) for x in a.arquivos))
    print(md)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(linhas, f, ensure_ascii=False, indent=1)
    if a.md:
        with open(a.md, "w", encoding="utf-8") as f:
            f.write(md)


if __name__ == "__main__":
    main()
