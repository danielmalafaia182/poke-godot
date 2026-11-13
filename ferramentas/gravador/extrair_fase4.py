#!/usr/bin/env python3
"""Extrai das gravações da fase 4 (A) os dados de tarefas e diárias para dados/fase4/ (gerado; não editar à mão).

  tarefas.json        GET /api/game/tasks (G5): {cidades, tarefas[{id, npc, city, goals[{pokeId, name, qty, kind}], xp, cash}]}
                      (sem o progresso da conta que gravou)
  daily_catch.json    GET /api/game/daily-catch (G5): {total, tiers[{key, label, minLevel, maxLevel, reward, rewardText,
                      species[{id, name, huntLevel}]}], claimsGravados[{slot, speciesId, xp}]}
  daily_kill.json     GET /api/game/daily-kill (G5): o dia gravado (tier, opções, prêmio, minLevel, reroll)
  daily_gift.json     GET /api/game/daily (G7): {total, rewards[{day, kind, label, qty, tag, icon}]}
  soneca.json         GET/POST /api/game/offline (G6): o relatório e a resposta da coleta gravados
  streak.json         GET /api/game/streak e POST /streak/spend (G7), sem a lista de abates por espécie

Uso: python -I ferramentas/gravador/extrair_fase4.py
"""
import glob
import json
import os
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PASTA = os.path.join(RAIZ, "poke har", "gravacoes", "fase 4")
SAIDA = os.path.join(RAIZ, "dados", "fase4")


def rest(arquivos):
    for f in arquivos:
        for l in open(f, encoding="utf-8", errors="replace"):
            try:
                o = json.loads(l)
            except Exception:
                continue
            if o.get("dir") == "rest" and isinstance(o.get("msg"), dict):
                yield os.path.basename(f), o["msg"]


def gravar(nome, dados):
    os.makedirs(SAIDA, exist_ok=True)
    with open(os.path.join(SAIDA, nome), "w", encoding="utf-8", newline="\n") as f:
        json.dump(dados, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print("ok:", nome)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    arqs = sorted(glob.glob(os.path.join(PASTA, "*.jsonl")))
    ult = {}
    soneca = []
    streak = []
    for arq, m in rest(arqs):
        c = m.get("corpo")
        if m.get("status") != 200 or not isinstance(c, dict):
            continue
        ult[m["caminho"]] = (arq, c)
        if m["caminho"] == "/api/game/offline":
            soneca.append({"arquivo": arq, "metodo": m["metodo"], "corpo": c})
        if m["caminho"].startswith("/api/game/streak"):
            streak.append({"arquivo": arq, "metodo": m["metodo"], "corpo": {k: v for k, v in c.items() if k != "kills"}})
    fonte = lambda caminho: ult[caminho][0]
    t = ult["/api/game/tasks"][1]
    gravar("tarefas.json", {"fonte": "A: %s, GET /api/game/tasks" % fonte("/api/game/tasks"), "cidades": t["cities"],
                            "tarefas": [{k: x[k] for k in ("id", "npc", "city", "goals", "xp", "cash")} for x in t["tasks"]]})
    dc = ult["/api/game/daily-catch"][1]
    gravar("daily_catch.json", {"fonte": "A: %s, GET /api/game/daily-catch" % fonte("/api/game/daily-catch"), "total": dc["total"],
                                "resetAt": dc["resetAt"],
                                "tiers": [{"key": x["key"], "label": x["label"], "minLevel": x["minLevel"], "maxLevel": x.get("maxLevel"),
                                           "reward": x["reward"], "rewardText": x["rewardText"],
                                           "species": [{"id": s["id"], "name": s["name"], "huntLevel": s["huntLevel"]} for s in x["species"]]}
                                          for x in dc["tiers"]],
                                "claimsGravados": [{k: x[k] for k in ("slot", "speciesId", "xp", "tierKey")} for x in dc["claims"]]})
    dk = ult["/api/game/daily-kill"][1]
    gravar("daily_kill.json", {"fonte": "A: %s, GET/POST /api/game/daily-kill" % fonte("/api/game/daily-kill"), "dia": dk})
    dg = ult["/api/game/daily"][1]
    gravar("daily_gift.json", {"fonte": "A: %s, GET /api/game/daily (mês %s)" % (fonte("/api/game/daily"), dg["ym"]), "total": dg["total"],
                               "rewards": [{k: x[k] for k in ("day", "kind", "label", "qty", "tag", "icon")} for x in dg["rewards"]]})
    gravar("soneca.json", {"fonte": "A: GET/POST /api/game/offline", "respostas": soneca})
    gravar("streak.json", {"fonte": "A: GET /api/game/streak e POST /api/game/streak/spend (sem a lista de abates)", "respostas": streak})


if __name__ == "__main__":
    main()
