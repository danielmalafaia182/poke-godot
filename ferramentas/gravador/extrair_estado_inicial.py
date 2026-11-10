#!/usr/bin/env python3
"""Extrai de uma gravação real o estado inicial de uma hunt, para alimentar a simulação (fase 1).

Tudo aqui é fonte A (observado nas mensagens do servidor). Nada é inventado: campo que não aparece
na gravação fica ausente e a simulação decide (e documenta) o que fazer.

Uso:
  python ferramentas/gravador/extrair_estado_inicial.py "poke har/gravacoes/gravacoes_unicas_2026-11-09.jsonl" \
      rhydon dados/testes/estado_rhydon_venusaur.json

Saída (JSON determinístico, chaves ordenadas):
  slug, huntKey (primeiro field-init), sessao, fieldInit (sem a grade), primeiroField (resumo),
  pokeDelta (primeiro poke-delta do herói do primeiro field), primeiroPokeXp, primeiroFieldKill (resumo),
  inventario (primeiro inventory), balls (primeiro balls), vip, cadaveres {speciesId: corpse}.
"""
import json
import sys


def linhas(caminho):
    for linha in open(caminho, encoding="utf-8"):
        linha = linha.strip()
        if not linha:
            continue
        try:
            o = json.loads(linha)
        except Exception:
            continue
        if isinstance(o, dict) and "msg" in o and "dir" in o:
            yield o


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    origem, slug, destino = sys.argv[1], sys.argv[2], sys.argv[3]
    est = {"formato": "poke-estado-inicial-v1", "fonte": origem.replace("\\", "/").split("/")[-1], "slug": slug}
    sessao = None
    dentro = False
    ultimo_field = None
    cadaveres = {}
    mortos_pendentes = {}
    deltas = []
    chunk = []
    for o in linhas(origem):
        if o["dir"] != "in":
            continue
        m = o["msg"]
        t = m.get("type")
        if t == "field-init":
            dentro = m.get("slug") == slug
            if dentro and "huntKey" not in est:
                sessao = o.get("sessao")
                est["sessao"] = sessao
                est["huntKey"] = m["huntKey"]
                est["fieldInit"] = {k: v for k, v in m.items() if k != "grid"}
            continue
        if sessao is not None and o.get("sessao") != sessao:
            continue
        if t == "vip" and "vip" not in est:
            est["vip"] = m
        if t == "poke-delta":
            deltas.append(m["poke"])
        if t == "pokes-chunk":
            # lista do time (A): serve de poke-delta quando a gravação não tem um do herói (ex.: M3)
            chunk.extend(x for x in m.get("list", []) if x.get("team"))
        if not dentro:
            continue
        if t == "field":
            if "primeiroField" not in est:
                est["primeiroField"] = {k: m[k] for k in ("seq", "serverNow", "heroLooktype", "heroName", "bossTeam",
                                                           "bossActiveIdx", "heroHp", "heroMaxHp")}
                est["primeiroField"]["mobsMaxHp"] = [x["maxHp"] for x in m["mobs"]]
            # cadáver: aparece na posição de um selvagem morto
            vivos = {x["slot"]: x for x in m["mobs"]}
            for x in m["mobs"]:
                if x["dead"]:
                    mortos_pendentes[(x["row"], x["col"])] = x["speciesId"]
            for c in m.get("corpses", []):
                sp = mortos_pendentes.get((c["row"], c["col"]))
                if sp is not None:
                    cadaveres.setdefault(str(sp), c["corpse"])
            ultimo_field = m
        elif t == "poke-xp" and "primeiroPokeXp" not in est:
            est["primeiroPokeXp"] = m
        elif t == "field-kill" and "primeiroFieldKill" not in est:
            est["primeiroFieldKill"] = {k: m[k] for k in ("xpGained", "totalXp", "level", "speciesId", "xpParts", "pokeXp")}
        elif t == "catch-result" and "primeiroCatchResult" not in est:
            # a bola da auto-captura não é balls.selected (A: selected=1, mas as tentativas gastam a bola 3)
            est["primeiroCatchResult"] = {k: v for k, v in m.items() if k != "type"}
        elif t == "inventory" and "inventario" not in est:
            est["inventario"] = m["items"]
        elif t == "balls" and "balls" not in est:
            est["balls"] = {k: v for k, v in m.items() if k != "type"}
    est["cadaveres"] = cadaveres
    # poke-delta do herói: o primeiro com o nome do herói do primeiro field (A: na gravação de 1 h o primeiro
    # poke-delta é de um Pokémon nível 1 vindo de pacote de cartas, não do Venusaur)
    heroi = est.get("primeiroField", {}).get("heroName")
    escolhido = next((d for d in deltas if d.get("name") == heroi and d.get("team")), None)         or next((d for d in deltas if d.get("name") == heroi), None) or (deltas[0] if deltas else None)
    if escolhido is None or escolhido.get("name") != heroi:
        escolhido = next((d for d in chunk if d.get("name") == heroi and d.get("leader")), None) or escolhido
    if escolhido is not None:
        est["pokeDelta"] = escolhido
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        json.dump(est, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print("ok:", destino, "campos:", sorted(est))
    return 0


if __name__ == "__main__":
    sys.exit(main())
