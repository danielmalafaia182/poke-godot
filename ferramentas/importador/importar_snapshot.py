#!/usr/bin/env python3
"""Importa um snapshot do Poke Idle World para dados normalizados do projeto Godot.

Entrada : pasta snapshot_AAAA-MM-DD/ gerada pelo coletor (com manifest.json)
Saída   : pasta com especies.json, golpes.json, itens.json, hunts.json, cidades.json,
          regras.json e relatorio_importacao.json. Nada aqui deve ser editado à mão:
          correções entram por correcoes.json e são reaplicadas a cada importação.

Uso:
  python3 importar_snapshot.py SNAPSHOT --correcoes correcoes.json --saida res_dados_gerados/
Somente biblioteca padrão. Determinístico: a mesma entrada gera os mesmos bytes.
"""
import argparse, hashlib, json, os, sys
from collections import defaultdict

ALIAS_MAPA = {"cerulean": "cerulean_novo", "pesca": "cerulean_novo", "aero_boss": "golem"}
CHANCE_ESCALA = 100000.0   # creatures.json guarda a chance de loot em 1/100.000 (61026.73 = 61%)


def ler(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def gravar(pasta, nome, dados):
    os.makedirs(pasta, exist_ok=True)
    texto = json.dumps(dados, ensure_ascii=False, indent=1, sort_keys=False) + "\n"
    with open(os.path.join(pasta, nome), "w", encoding="utf-8", newline="\n") as f:
        f.write(texto)
    return hashlib.sha256(texto.encode()).hexdigest()


def norm_especie(c, itens_por_nome, rel):
    tipos = [c["type1"]] + ([c["type2"]] if c.get("type2") else [])
    # golpes ficam por espécie: o mesmo nome pode ter cooldown diferente em cada uma
    golpes = sorted(
        ({"nome": a["name"], "nivel": a.get("learnLevel", 1), "tipo": a.get("type"),
          "categoria": a.get("category"), "poder": a.get("power", 0), "cooldownMs": a.get("cooldownMs")}
         for a in c.get("attacks", [])),
        key=lambda g: (g["nivel"], g["nome"]))
    loot = []
    for l in c.get("loot", []):
        item = itens_por_nome.get(l["name"])
        if item is None:
            # F: o loot cita o item por nome; "Pile Of Seeds" (Skiddo) só existe como "Pile of Seeds" (5303).
            # Sem caixa, e só se o nome for único no catálogo. Fica registrado no relatório.
            item = itens_por_nome.get(("sem_caixa", l["name"].lower()))
            if item is not None:
                rel["loot_por_nome_sem_caixa"][l["name"]] = item["id"]
        if item is None:
            rel["loot_sem_item"][l["name"]].append(c["pokeId"])
        loot.append({
            "item": l["name"],
            "itemId": item["id"] if item else None,
            "chance": round(l.get("chance", 0) / CHANCE_ESCALA, 7),
            "chanceBruta": l.get("chance", 0),
            "min": l.get("minCount", 1),
            "max": l.get("maxCount", 1),
        })
    e = {
        "id": c["pokeId"],
        "nome": c["name"],
        "looktype": c.get("looktype"),
        "descricao": c.get("description", ""),
        "tipos": tipos,
        "raridade": c.get("rarity"),
        "base": {"hp": c["baseHp"], "atk": c["baseAtk"], "def": c["baseDef"],
                 "spAtk": c["baseSpAtk"], "spDef": c["baseSpDef"], "speed": c["baseSpeed"]},
        "nivelHunt": c.get("huntLevel"),
        "xpAbate": c.get("experience"),
        "evolui": ({"para": c["evolvesToId"], "nivel": c.get("evolveLevel")} if c.get("evolvesToId") else None),
        "precoNpc": c.get("priceNpc"),
        "valorVenda": c.get("sellValue"),
        "golpes": golpes,
        "loot": loot,
    }
    for k_src, k_dst in (("area", "area"), ("captureBase", "capturaBase")):
        if k_src in c:
            e[k_dst] = c[k_src]
    return e


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("snapshot")
    ap.add_argument("--correcoes", required=True)
    ap.add_argument("--saida", required=True)
    a = ap.parse_args()
    S = a.snapshot
    p = lambda *x: os.path.join(S, *x)

    manifest = ler(p("manifest.json")) if os.path.exists(p("manifest.json")) else {}
    creatures = ler(p("game", "creatures.json"))["creatures"]
    items = ler(p("game", "items.json"))["items"]
    marcadores = ler(p("api", "game", "map-markers"))["hunts"] if os.path.exists(p("api", "game", "map-markers")) \
        else ler(p("api", "game", "map-markers.json"))["hunts"]
    correcoes = ler(a.correcoes)

    rel = {"loot_sem_item": defaultdict(list), "loot_por_nome_sem_caixa": {}, "golpes_variam_por_especie": {}, "spawns_sem_especie": defaultdict(list),
           "hunts_sem_config": [], "hunts_sem_mapa": [], "ids_duplicados": []}

    # ---------- itens ----------
    itens_por_nome = {}
    itens = []
    for i in sorted(items, key=lambda x: x["id"]):
        itens_por_nome.setdefault(i["name"], i)
        sc = ("sem_caixa", i["name"].lower())
        itens_por_nome[sc] = None if sc in itens_por_nome else i     # None = nome ambíguo sem caixa
        d = {"id": i["id"], "nome": i["name"], "icone": i.get("icon"), "categoria": i.get("category"),
             "raro": bool(i.get("rare", False)), "precoNpc": i.get("npcPrice", 0)}
        for k_src, k_dst in (("description", "descricao"), ("healAmount", "cura"), ("priceGold", "precoGold"),
                             ("revivePct", "revivePct")):
            if k_src in i:
                d[k_dst] = i[k_src]
        itens.append(d)

    # ---------- espécies e golpes ----------
    especies, vistos = [], set()
    golpes = {}        # catálogo por nome: valores mais comuns + variações
    variantes = defaultdict(lambda: defaultdict(list))
    for c in sorted(creatures, key=lambda x: x["pokeId"]):
        if c["pokeId"] in vistos:
            rel["ids_duplicados"].append(c["pokeId"])
            continue
        vistos.add(c["pokeId"])
        especies.append(norm_especie(c, itens_por_nome, rel))
        for at in c.get("attacks", []):
            chave = (at.get("type"), at.get("category"), at.get("power", 0), at.get("cooldownMs"))
            variantes[at["name"]][chave].append(c["pokeId"])
    for nome, por_val in variantes.items():
        ordem = sorted(por_val.items(), key=lambda kv: (-len(kv[1]), str(kv[0])))
        (tipo, cat, poder, cd), _ = ordem[0]
        golpes[nome] = {"nome": nome, "tipo": tipo, "categoria": cat, "poder": poder, "cooldownMsComum": cd,
                        "especies": sum(len(v) for v in por_val.values())}
        if len(ordem) > 1:
            golpes[nome]["variacoes"] = [{"tipo": k[0], "categoria": k[1], "poder": k[2], "cooldownMs": k[3],
                                          "especies": sorted(v)} for k, v in ordem]
            rel["golpes_variam_por_especie"][nome] = len(ordem)
    ids_especie = {e["id"] for e in especies}

    # ---------- hunts / cidades ----------
    hunts, cidades = [], []
    for m in marcadores:
        slug = m["slug"]
        cfg_p = p("api", "hunt-config", slug + ".json")
        cfg = ler(cfg_p) if os.path.exists(cfg_p) else None
        if cfg is None:
            rel["hunts_sem_config"].append(slug)
        nome_mapa = ALIAS_MAPA.get(slug, slug)
        mapa_p = p("game", "maps", nome_mapa + ".json")
        meta_mapa = None
        if os.path.exists(mapa_p):
            try:
                mj = ler(mapa_p)
                meta = mj.get("_meta", {}) if isinstance(mj, dict) else {}
                meta_mapa = {"arquivo": f"game/maps/{nome_mapa}.json", "formato": mj.get("format"),
                             "tiles": len(mj.get("tiles", [])), "meta": meta}
            except Exception as ex:
                meta_mapa = {"arquivo": f"game/maps/{nome_mapa}.json", "erro": str(ex)}
        else:
            rel["hunts_sem_mapa"].append(slug)
        spawns = (cfg or {}).get("spawns", [])
        for s in spawns:
            if s.get("pokeId") not in ids_especie:
                rel["spawns_sem_especie"][s.get("pokeId")].append(slug)
        npcs_p = p("api", "city-npcs", slug + ".json")
        npcs = ler(npcs_p) if os.path.exists(npcs_p) else []
        h = {"slug": slug, "nome": m.get("name"), "area": m.get("area"), "nivel": m.get("level"),
             "looktype": m.get("looktype"), "pixel": m.get("pixel"), "range": m.get("range"),
             "inicio": (cfg or {}).get("start"), "spawns": spawns,
             "lures": (cfg or {}).get("lures", []), "catchChance": (cfg or {}).get("catchChance"),
             "mapa": meta_mapa, "npcs": npcs}
        # cidade = tem NPCs ou não tem spawns (Cerulean, Viridian e 'pewter', exibida como Lavender)
        (cidades if (npcs or not spawns) else hunts).append(h)

    # ---------- regras + correções ----------
    regras = {"iv": {"min": 1, "max": 31, "total_max": 186, "fonte": "publicado"},
              "selvagem": {"hpPorStat": 35, "hpMinimo": 120, "fonte": "observado nos logs (Rhyhorn, Geodude)"},
              "tickMs": 200, "snapshotACadaTicks": 2,
              "efetividadeAmplificada": {"1.5": 1.75, "2": 2.5, "4": 5.5, "fonte": "Pokepedia: combat"}}
    aplicadas = []
    for c in correcoes.get("correcoes", []):
        if c["alvo"] == "regras.iv":
            regras["iv"] = {**c["valor"], "fonte": f"correcao:{c['id']}"}
            aplicadas.append(c["id"])

    # ---------- saída ----------
    out = a.saida
    hashes = {
        "especies.json": gravar(out, "especies.json", especies),
        "golpes.json": gravar(out, "golpes.json", sorted(golpes.values(), key=lambda g: g["nome"])),
        "itens.json": gravar(out, "itens.json", itens),
        "hunts.json": gravar(out, "hunts.json", hunts),
        "cidades.json": gravar(out, "cidades.json", cidades),
        "regras.json": gravar(out, "regras.json", regras),
    }
    relatorio = {
        "formato": "poke-importacao-v1",
        "snapshot": os.path.basename(os.path.normpath(S)),
        "coletadoEm": manifest.get("coletadoEm"),
        "contagens": {"especies": len(especies), "golpes": len(golpes), "itens": len(itens),
                      "hunts": len(hunts), "cidades": len(cidades),
                      "hunts_com_mapa": sum(1 for h in hunts if h["mapa"] and "erro" not in h["mapa"])},
        "correcoesAplicadas": aplicadas,
        "hashesSaida": hashes,
        "pendencias": {k: (dict(v) if isinstance(v, defaultdict) else v) for k, v in rel.items()},
    }
    gravar(out, "relatorio_importacao.json", relatorio)
    print(json.dumps(relatorio["contagens"], ensure_ascii=False))
    print("pendências:", {k: len(v) for k, v in relatorio["pendencias"].items()})


if __name__ == "__main__":
    sys.exit(main())
