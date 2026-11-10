#!/usr/bin/env python3
"""Respostas REST de /api/game/* gravadas pelo gravador v1.1 (linhas {sessao, t, dir: "rest", msg: {type: "__rest",
metodo, caminho, consulta, status, corpo}}). Só biblioteca padrão.

Uso como módulo:
  ler_rest(caminho)            → [{t, sessao, metodo, caminho, consulta, status, corpo}, …] na ordem do arquivo
  used_balls(caminho)          → as respostas de /api/game/used-balls (200, corpo dict), na ordem
  medidor(corpo)               → {(speciesId, shiny): {nome, preco, gasto, tentativas, total, bolas, capturada}}
  diferenca(antes, depois)     → por espécie: Δtotal, Δtentativas, Δgasto, Δbolas, capturada antes/depois

Formato de used-balls (C, componente "Gerenciamento de Captura" do chunk 0gx72gz9qjk5j.js): {pokemons: [{speciesId,
dexId, name, shiny, price (preço de NPC), goldSpent (total gasto em ouro), balls {bolaId: n}, attempts (desde a última
captura; zera ao capturar), total (nunca zera)}], caught: [dexId…], ballTypes: [{id, name, iconUrl…}]}.
Como script: python -I rest.py gravacao.jsonl  (resume os endpoints e o used-balls do início e do fim)
"""
import json
import sys
from collections import Counter


def ler_rest(caminho):
    r = []
    for linha in open(caminho, encoding="utf-8", errors="replace"):
        linha = linha.strip()
        if not linha:
            continue
        try:
            o = json.loads(linha)
        except Exception:
            continue
        if not isinstance(o, dict) or o.get("dir") != "rest" or not isinstance(o.get("msg"), dict):
            continue
        m = o["msg"]
        r.append({"t": o.get("t"), "sessao": o.get("sessao"), "metodo": m.get("metodo"), "caminho": m.get("caminho"),
                  "consulta": m.get("consulta") or {}, "status": m.get("status"), "corpo": m.get("corpo")})
    return r


def used_balls(caminho):
    return [x for x in ler_rest(caminho)
            if x["caminho"] == "/api/game/used-balls" and x["status"] == 200 and isinstance(x["corpo"], dict)]


def medidor(corpo):
    capt = set(corpo.get("caught") or [])
    r = {}
    for p in corpo.get("pokemons") or []:
        chave = (int(p.get("speciesId", 0)), bool(p.get("shiny")))
        r[chave] = {"nome": p.get("name"), "dex": p.get("dexId"), "preco": p.get("price"), "gasto": p.get("goldSpent", 0),
                    "tentativas": p.get("attempts", 0), "total": p.get("total", 0),
                    "bolas": {str(k): v for k, v in (p.get("balls") or {}).items()},
                    "capturada": (p.get("dexId") in capt) and not p.get("shiny")}
    return r


def diferenca(antes, depois):
    a, b = medidor(antes), medidor(depois)
    r = {}
    for k in sorted(set(a) | set(b)):
        x, y = a.get(k, {}), b.get(k, {})
        bolas = Counter({kk: int(v) for kk, v in (y.get("bolas") or {}).items()})
        bolas.subtract({kk: int(v) for kk, v in (x.get("bolas") or {}).items()})
        d = {"nome": y.get("nome") or x.get("nome"), "shiny": k[1], "preco": y.get("preco") or x.get("preco"),
             "d_total": int(y.get("total", 0)) - int(x.get("total", 0)),
             "d_gasto": int(y.get("gasto", 0)) - int(x.get("gasto", 0)),
             "tentativas_antes": x.get("tentativas", 0), "tentativas_depois": y.get("tentativas", 0),
             "d_bolas": {kk: v for kk, v in bolas.items() if v},
             "capturada_antes": bool(x.get("capturada")), "capturada_depois": bool(y.get("capturada"))}
        if d["d_total"] or d["d_gasto"] or d["tentativas_antes"] != d["tentativas_depois"]:
            r["%d%s" % (k[0], "s" if k[1] else "")] = d
    return r


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    for c in sys.argv[1:]:
        rs = ler_rest(c)
        print("==", c, "respostas REST:", len(rs))
        for (met, cam), n in Counter((x["metodo"], x["caminho"]) for x in rs).most_common():
            print("   %s %s: %d" % (met, cam, n))
        ub = used_balls(c)
        if len(ub) >= 2:
            print("   used-balls: %d respostas; diferença entre a primeira e a última:" % len(ub))
            for k, d in diferenca(ub[0]["corpo"], ub[-1]["corpo"]).items():
                print("     ", k, json.dumps(d, ensure_ascii=False))
        elif ub:
            print("   used-balls: só 1 resposta (abra a tela Gerenciamento de Captura no início E no fim)")


if __name__ == "__main__":
    main()
