#!/usr/bin/env python3
"""Gravação livre → trechos (A). O jogador joga normalmente com o gravador sempre ligado e exporta uma vez por dia para
`poke har/gravacoes/livre/`. Este módulo corta tudo em trechos e diz para que regra cada um serve.

Entrada: arquivos .jsonl do gravador ({sessao, t, dir, msg}) ou uma pasta (todos os .jsonl dela). Linhas repetidas entre
exportações (mesma sessão, instante, direção e conteúdo) contam uma vez (`ler_logs`). Os arquivos são ordenados pelo
primeiro instante.

Tipos de trecho:
  cidade  do fim de uma hunt (field-none, set-city, leave-hunt) até a próxima entrada (field-init)
  hunt    de um field-init até o fim da instância, cortado em pedaços quando:
            - o líder muda (heroName/heroLooktype do field, poke-summon, switch)          → "troca de time"
            - o zoom muda (comando view com {hc, hr} diferente)                           → "zoom"
            - há um buraco nos fields (serverNow pula mais de BURACO_S: aba em segundo plano, PC dormindo,
              conexão caída)                                                             → "buraco"
          A entrada é nova (huntKey sem ":rN") ou retomada. A janela da penalidade vem do boost shinylock (A).
Para cada pedaço: duração, fields, fração de pares consecutivos (Δseq = 2), líder e nível, view, segundos dentro do lock,
abates (no lock e fora), XP, loot, curas, capturas, desmaios, selvagens ao lado do herói por field.

Usos (`uteis`):
  xp, loot           todos os abates (o lock e o Tipo do Dia são separados pelas parcelas do xpParts)
  penalidade         entradas novas com boost shinylock
  passos, cadencia   pedaços sem buraco (≥ 25% dos pares com Δseq = 2, como na aba em primeiro plano) de pelo menos 60 s
  movimento          pedaços contínuos de pelo menos 5 min fora do lock
  resultado          pedaços de pelo menos 5 min com o líder conhecido (critério de pronto do movimento: abates/min,
                     XP/h, mortes/h, ouro/h e selvagens ao lado do herói, real × sim, ±10%)
  dano               pedaços com o líder conhecido (stats exibidos no instante)
  cidade             trechos de cidade com respostas REST (loja, evolução, depot, Nurse)

Uso: python -I ferramentas/gravador/segmentar.py <arquivos ou pasta> [--json trechos.json] [--md trechos.md]
     [--exportar pasta]  (grava um .jsonl por pedaço de hunt, com o field-init da instância, para as ferramentas antigas)
"""
import argparse
import glob
import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "protocolo"))
from gerar_protocolo import ler_logs  # noqa: E402

BURACO_S = 5.0          # serverNow entre fields consecutivos acima disso = buraco (o normal é 0,4 s)
CONTINUO_MIN = 0.25    # A: com a aba na frente o cliente recebe só 30–50% dos pares com Δseq = 2 (rhydon-1h, T1); o que
                       # marca a aba em segundo plano é o buraco (> BURACO_S), que corta o pedaço
DUR_PASSOS_S = 60
DUR_RESULTADO_S = 300


def arquivos_de(entradas):
    fs = []
    for e in entradas:
        if os.path.isdir(e):
            fs += glob.glob(os.path.join(e, "**", "*.jsonl"), recursive=True)
        else:
            fs.append(e)

    def primeiro_t(f):
        for l in open(f, encoding="utf-8", errors="replace"):
            try:
                return float(json.loads(l).get("t", 0))
            except Exception:
                continue
        return 0.0
    return sorted(set(fs), key=primeiro_t)


def cheb(a, b):
    return max(abs(a["row"] - b["row"]), abs(a["col"] - b["col"]))


class Pedaco:
    def __init__(self, inst, motivo, t0, lider, view):
        self.inst = inst
        self.motivo_inicio = motivo
        self.t0 = t0
        self.t1 = t0
        self.lider = lider
        self.view = view
        self.fields = 0
        self.pares = 0
        self.pares2 = 0
        self.abates = 0
        self.abates_lock = 0
        self.xp = 0
        self.loot = Counter()
        self.curas = 0
        self.capturas = 0
        self.tentativas = 0
        self.desmaios = 0
        self.adj = 0
        self.niveis = set()
        self.msgs = []

    def resumo(self, lock):
        dur = max(0.0, (self.t1 - self.t0) / 1000.0)
        lock_s = 0.0
        if lock:
            lock_s = max(0.0, (min(self.t1, lock[1]) - max(self.t0, lock[0])) / 1000.0)
        cont = self.pares2 / self.pares if self.pares else 0.0
        r = {"tipo": "hunt", "slug": self.inst["slug"], "huntKey": self.inst["huntKey"], "entrada_nova": self.inst["nova"],
             "motivo_inicio": self.motivo_inicio, "t0": self.t0, "t1": self.t1, "duracao_s": round(dur, 1), "fields": self.fields,
             "continuo": round(cont, 3), "lider": self.lider, "niveis_lider": sorted(self.niveis), "view": self.view,
             "lock_s": round(lock_s, 1), "abates": self.abates, "abates_lock": self.abates_lock, "xp": self.xp,
             "loot": dict(self.loot), "curas": self.curas, "capturas": self.capturas, "tentativas": self.tentativas,
             "desmaios": self.desmaios, "adjacentes_por_field": round(self.adj / self.fields, 3) if self.fields else None}
        u = ["xp", "loot"] if self.abates else []
        if self.lider:
            u.append("dano")
        if cont >= CONTINUO_MIN and dur >= DUR_PASSOS_S:
            u += ["passos", "cadencia"]
        if cont >= CONTINUO_MIN and dur - lock_s >= DUR_RESULTADO_S:
            u.append("movimento")
        if self.lider and dur >= DUR_RESULTADO_S:
            u.append("resultado")
        if self.inst["nova"] and lock and self.motivo_inicio == "entrada":
            u.append("penalidade")
        r["uteis"] = u
        return r


def segmentar(entradas, guardar_msgs=False):
    fs = arquivos_de(entradas)
    trechos = []
    inst = None             # instância de hunt atual
    ped = None
    lock = None
    cidade = None
    nivel = {}
    view = None
    ult_field = None
    pokes = {}
    lider_id = None

    def fechar_ped():
        nonlocal ped
        if ped is not None and ped.fields:
            r = ped.resumo(lock)
            if guardar_msgs:
                r["_msgs"] = [inst["init"]] + ped.msgs
            trechos.append(r)
        ped = None

    def fechar_cidade(t):
        nonlocal cidade
        if cidade is not None:
            cidade["t1"] = t
            cidade["duracao_s"] = round(max(0, t - cidade["t0"]) / 1000.0, 1)
            cidade["uteis"] = ["cidade"] if cidade["rest"] else []
            cidade["rest"] = dict(cidade["rest"])
            cidade["comandos"] = dict(cidade["comandos"])
            trechos.append(cidade)
        cidade = None

    for d, m, _ in ler_logs(fs, rest=False):
        t = m.get("type")
        if d == "out":
            if t == "view":
                v = [m.get("hc"), m.get("hr")]
                if view is not None and v != view and ped is not None:
                    tt, quem = ped.t1, ped.lider
                    fechar_ped()
                    ped = Pedaco(inst, "zoom", tt, quem, v)
                view = v
            elif t in ("leave-hunt", "set-city") and inst is not None:
                fechar_ped()
                inst = None
                cidade = {"tipo": "cidade", "t0": ult_field["serverNow"] if ult_field else 0, "rest": Counter(), "comandos": Counter()}
            elif cidade is not None:
                cidade["comandos"][t] += 1
            continue
        if t in ("pokes", "pokes-chunk"):
            for p in m.get("list", m.get("pokes", [])):
                pokes[p["id"]] = p
                if p.get("leader"):
                    lider_id = p["id"]
            continue
        if t == "poke-delta":
            p = m["poke"]
            if p["id"] in pokes or p.get("team"):
                pokes[p["id"]] = p
                if p.get("leader"):
                    lider_id = p["id"]
            continue
        if t == "field-init":
            fechar_ped()
            fechar_cidade(0)
            hk = m.get("huntKey", "")
            nova = ":r" not in hk
            inst = {"slug": m.get("slug"), "huntKey": hk, "nova": nova, "init": m}
            if nova:
                lock = None
            ult_field = None
            continue
        if t == "boosts" and inst is not None:
            for b in m.get("boosts", []):
                if b.get("key") == "shinylock":
                    lock = (ult_field["serverNow"] if ult_field else b["until"] - 60000, b["until"])
            continue
        if t == "field-none" and inst is not None:
            fechar_ped()
            inst = None
            cidade = {"tipo": "cidade", "t0": ult_field["serverNow"] if ult_field else 0, "rest": Counter(), "comandos": Counter()}
            continue
        if inst is None:
            if cidade is not None and d == "rest":
                cidade["rest"][m.get("path", "?")] += 1
            continue
        if t == "field":
            atual = (m.get("heroName"), m.get("heroLooktype"))
            sn = m["serverNow"]
            if ped is None:
                ped = Pedaco(inst, "entrada" if inst["nova"] else "retomada", sn, atual, view)
            elif atual != ped.lider:
                fechar_ped()
                ped = Pedaco(inst, "troca de time", sn, atual, view)
            elif ult_field is not None and (sn - ult_field["serverNow"]) / 1000.0 > BURACO_S:
                fechar_ped()
                ped = Pedaco(inst, "buraco", sn, atual, view)
                ped.buraco_s = (sn - ult_field["serverNow"]) / 1000.0
            if ult_field is not None and ped.fields:
                ped.pares += 1
                ped.pares2 += int(m["seq"] - ult_field["seq"] == 2)
            ped.fields += 1
            ped.t1 = sn
            if lider_id not in pokes or pokes[lider_id].get("name") != m.get("heroName"):
                # troca automática ou pelo time: o líder do field é o Pokémon com esse nome no time
                cand = [p for p in pokes.values() if p.get("name") == m.get("heroName") and p.get("team")]
                if cand:
                    lider_id = cand[0]["id"]
            if lider_id in pokes and pokes[lider_id].get("name") == m.get("heroName"):
                ped.niveis.add(pokes[lider_id].get("level"))
            if m.get("fainted") and not (ult_field or {}).get("fainted"):
                ped.desmaios += 1
            h = m["hero"]
            ped.adj += sum(1 for x in m["mobs"] if not x["dead"] and cheb(x, h) <= 1)
            ult_field = m
            if guardar_msgs:
                ped.msgs.append(m)
            continue
        if ped is None:
            continue
        if guardar_msgs:
            ped.msgs.append(m)
        if t == "field-kill":
            ped.abates += 1
            if "debuff" in (m.get("xpParts") or {}):
                ped.abates_lock += 1
            ped.xp += int(m.get("xpGained", 0))
            for it in m.get("loot") or []:
                ped.loot[str(it.get("itemId"))] += int(it.get("qty", 0))
        elif t == "auto-heal":
            ped.curas += 1
        elif t == "catch-result":
            ped.tentativas += 1
            ped.capturas += int(bool(m.get("success")))
    fechar_ped()
    fechar_cidade(ult_field["serverNow"] if ult_field else 0)
    return trechos


def markdown(trechos):
    hunts = [x for x in trechos if x["tipo"] == "hunt"]
    cid = [x for x in trechos if x["tipo"] == "cidade"]
    usos = Counter(u for x in trechos for u in x["uteis"])
    mot = Counter(x["motivo_inicio"] for x in hunts)
    l = ["# Trechos da gravação livre", "",
         f"{len(hunts)} pedaços de hunt ({sum(x['duracao_s'] for x in hunts) / 60:.0f} min) e {len(cid)} trechos de cidade.",
         "Cortes: " + ", ".join(f"{k} {v}" for k, v in mot.most_common()) + ".",
         "Pedaços úteis por regra: " + ", ".join(f"{k} {v}" for k, v in sorted(usos.items())) + ".", "",
         "| # | Hunt | Entrada | Começa por | Líder (níveis) | min | Contínuo | Lock (s) | Abates | XP | Curas | Capturas | Desmaios | Ao lado/field | View | Útil para |",
         "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for i, x in enumerate(hunts, 1):
        nome = (x["lider"] or ["?"])[0]
        l.append(f"| {i} | {x['slug']} | {'nova' if x['entrada_nova'] else 'retomada'} | {x['motivo_inicio']} | {nome} {x['niveis_lider']} | "
                 f"{x['duracao_s'] / 60:.1f} | {x['continuo']:.2f} | {x['lock_s']:.0f} | {x['abates']} | {x['xp']} | {x['curas']} | "
                 f"{x['capturas']}/{x['tentativas']} | {x['desmaios']} | {x['adjacentes_por_field']} | {x['view']} | {', '.join(x['uteis'])} |")
    return "\n".join(l) + "\n"


def exportar(trechos, pasta):
    os.makedirs(pasta, exist_ok=True)
    feitos = []
    for i, x in enumerate(trechos, 1):
        if x["tipo"] != "hunt" or "_msgs" not in x:
            continue
        c = os.path.join(pasta, "trecho_%03d_%s.jsonl" % (i, x["slug"]))
        with open(c, "w", encoding="utf-8", newline="\n") as f:
            for j, m in enumerate(x["_msgs"]):
                f.write(json.dumps({"sessao": x["huntKey"], "t": x["t0"] + j, "dir": "in", "msg": m}, ensure_ascii=False) + "\n")
        x["arquivo"] = c
        feitos.append(c)
    return feitos


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("entradas", nargs="+")
    ap.add_argument("--json")
    ap.add_argument("--md")
    ap.add_argument("--exportar")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    tr = segmentar(a.entradas, guardar_msgs=bool(a.exportar))
    if a.exportar:
        exportar(tr, a.exportar)
    md = markdown(tr)
    print(md)
    if a.md:
        open(a.md, "w", encoding="utf-8", newline="\n").write(md)
    if a.json:
        json.dump([{k: v for k, v in x.items() if k != "_msgs"} for x in tr], open(a.json, "w", encoding="utf-8", newline="\n"),
                  ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
