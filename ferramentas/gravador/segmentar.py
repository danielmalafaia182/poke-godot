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
        self.contexto = []      # vip, inventory, balls, autohelper e o líder no começo do pedaço (para a sim)

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


def linhas_dedup(fs):
    """(sessao, dir, msg) de cada linha, na ordem dos arquivos, sem repetir linha idêntica (exportações sobrepostas e
    arquivos baixados duas vezes, como "x(1).jsonl")."""
    vistas = set()
    for f in fs:
        for l in open(f, encoding="utf-8", errors="replace"):
            l = l.strip()
            if not l:
                continue
            h = hash(l)
            if h in vistas:
                continue
            vistas.add(h)
            try:
                o = json.loads(l)
            except Exception:
                continue
            if not isinstance(o, dict):
                continue
            m = o.get("msg")
            if isinstance(m, str):
                try:
                    m = json.loads(m)
                except Exception:
                    continue
            if "direcao" in o and "dados" in o:          # gravador antigo
                try:
                    m = json.loads(o["dados"])
                except Exception:
                    continue
                yield o.get("sessao", "antigo"), ("out" if str(o["direcao"]).startswith("envi") else "in"), m
                continue
            if isinstance(m, dict):
                yield o.get("sessao", "?"), o.get("dir", "in"), m


class _Sessao:
    """Estado de uma aba do jogo (o gravador grava as abas abertas juntas; cada uma tem a sua `sessao`)."""

    def __init__(self, nome, trechos, guardar):
        self.nome = nome
        self.trechos = trechos
        self.guardar = guardar
        self.inst = None
        self.ped = None
        self.lock = None
        self.cidade = None
        self.view = None
        self.ult_field = None
        self.pokes = {}
        self.lider_id = None
        self.ultimo = {}

    def contexto(self):
        c = [self.ultimo[k] for k in ("vip", "inventory", "balls", "autohelper") if k in self.ultimo]
        time = sorted([p for p in self.pokes.values() if p.get("team")], key=lambda p: (p.get("slot") is None, p.get("slot") or 0))
        if time:
            c.append({"type": "pokes", "list": [dict(p, leader=(p["id"] == self.lider_id)) for p in time]})
        if self.lider_id in self.pokes:
            c.append({"type": "poke-delta", "poke": dict(self.pokes[self.lider_id], team=True, leader=True)})
        return c

    def fechar_ped(self):
        ped = self.ped
        if ped is not None and ped.fields:
            r = ped.resumo(self.lock)
            r["sessao"] = self.nome
            if self.guardar is not None and (self.guardar is True or set(r["uteis"]) & self.guardar):
                r["_msgs"] = [self.inst["init"]] + ped.msgs
                r["_contexto"] = ped.contexto
                r["_pokes_final"] = self.pokes
            self.trechos.append(r)
        self.ped = None

    def abrir_cidade(self):
        self.cidade = {"tipo": "cidade", "sessao": self.nome, "t0": self.ult_field["serverNow"] if self.ult_field else 0,
                       "rest": Counter(), "comandos": Counter()}

    def fechar_cidade(self, t):
        c = self.cidade
        if c is not None:
            c["t1"] = t
            c["duracao_s"] = round(max(0, t - c["t0"]) / 1000.0, 1)
            c["uteis"] = ["cidade"] if c["rest"] else []
            c["rest"] = dict(c["rest"])
            c["comandos"] = dict(c["comandos"])
            self.trechos.append(c)
        self.cidade = None

    def guardando(self):
        return self.guardar is not None

    def msg(self, d, m):
        t = m.get("type")
        if d == "in" and t in ("vip", "inventory", "balls", "autohelper"):
            self.ultimo[t] = m
        if d == "out":
            if t == "view":
                v = [m.get("hc"), m.get("hr")]
                if self.view is not None and v != self.view and self.ped is not None:
                    tt, quem = self.ped.t1, self.ped.lider
                    self.fechar_ped()
                    self.ped = Pedaco(self.inst, "zoom", tt, quem, v)
                self.view = v
            elif t in ("leave-hunt", "set-city") and self.inst is not None:
                self.fechar_ped()
                self.inst = None
                self.abrir_cidade()
            elif self.cidade is not None:
                self.cidade["comandos"][t] += 1
            return
        if t in ("pokes", "pokes-chunk"):
            for p in m.get("list", m.get("pokes", [])):
                self.pokes[p["id"]] = p
                if p.get("leader"):
                    self.lider_id = p["id"]
            return
        if t == "poke-delta":
            p = m["poke"]
            if p["id"] in self.pokes or p.get("team"):
                self.pokes[p["id"]] = p
                if p.get("leader"):
                    self.lider_id = p["id"]
            return
        if t == "field-init":
            self.fechar_ped()
            self.fechar_cidade(0)
            hk = m.get("huntKey", "")
            nova = ":r" not in hk
            self.inst = {"slug": m.get("slug"), "huntKey": hk, "nova": nova, "init": m}
            if nova:
                self.lock = None
            self.ult_field = None
            return
        if t == "boosts" and self.inst is not None:
            for b in m.get("boosts", []):
                if b.get("key") == "shinylock":
                    self.lock = (self.ult_field["serverNow"] if self.ult_field else b["until"] - 60000, b["until"])
            return
        if t == "field-none" and self.inst is not None:
            self.fechar_ped()
            self.inst = None
            self.abrir_cidade()
            return
        if self.inst is None:
            if self.cidade is not None and d == "rest":
                self.cidade["rest"][m.get("caminho", m.get("path", "?"))] += 1
            return
        ped = self.ped
        if t == "field":
            atual = (m.get("heroName"), m.get("heroLooktype"))
            sn = m["serverNow"]
            uf = self.ult_field
            if ped is None:
                ped = self.ped = Pedaco(self.inst, "entrada" if self.inst["nova"] else "retomada", sn, atual, self.view)
            elif atual != ped.lider:
                self.fechar_ped()
                ped = self.ped = Pedaco(self.inst, "troca de time", sn, atual, self.view)
            elif uf is not None and (sn - uf["serverNow"]) / 1000.0 > BURACO_S:
                self.fechar_ped()
                ped = self.ped = Pedaco(self.inst, "buraco", sn, atual, self.view)
                ped.buraco_s = (sn - uf["serverNow"]) / 1000.0
            if uf is not None and ped.fields:
                ped.pares += 1
                ped.pares2 += int(m["seq"] - uf["seq"] == 2)
            ped.fields += 1
            ped.t1 = sn
            pk = self.pokes
            if self.lider_id not in pk or pk[self.lider_id].get("name") != m.get("heroName"):
                # troca automática ou pelo time: o líder do field é o Pokémon com esse nome no time
                cand = [p for p in pk.values() if p.get("name") == m.get("heroName") and p.get("team")]
                if cand:
                    self.lider_id = cand[0]["id"]
            if ped.fields == 1:          # 1º field do pedaço (já contado acima)
                ped.contexto = self.contexto()
            if self.lider_id in pk and pk[self.lider_id].get("name") == m.get("heroName"):
                ped.niveis.add(pk[self.lider_id].get("level"))
            if m.get("fainted") and not (uf or {}).get("fainted"):
                ped.desmaios += 1
            h = m["hero"]
            ped.adj += sum(1 for x in m["mobs"] if not x["dead"] and cheb(x, h) <= 1)
            self.ult_field = m
            if self.guardando():
                ped.msgs.append(m)
            return
        if ped is None:
            return
        if self.guardando():
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

    def fim(self):
        self.fechar_ped()
        self.fechar_cidade(self.ult_field["serverNow"] if self.ult_field else 0)


def segmentar(entradas, guardar_msgs=False, guardar=None):
    """Trechos de todas as abas gravadas (uma `sessao` por aba). `guardar_msgs=True` guarda as mensagens de todos os
    pedaços; `guardar={"resultado", ...}` só dos pedaços úteis para esses usos (as gravações livres são grandes)."""
    fs = arquivos_de(entradas)
    trechos = []
    g = True if guardar_msgs else (set(guardar) if guardar else None)
    sessoes = {}
    for sess, d, m in linhas_dedup(fs):
        st = sessoes.get(sess)
        if st is None:
            st = sessoes[sess] = _Sessao(sess, trechos, g)
        st.msg(d, m)
    for st in sessoes.values():
        st.fim()
    # Líder desconhecido no começo do pedaço (gravação sem pokes/poke-delta antes): usa o que se soube dele depois, pelo
    # nome. IV e Quality não mudam; o XP do momento vem do 1º poke-xp do pedaço (extrair_estado_inicial.py).
    for x in trechos:
        pk = x.pop("_pokes_final", None)
        if pk is None or x["tipo"] != "hunt" or any(m.get("type") == "poke-delta" for m in x.get("_contexto", [])):
            continue
        nome = (x.get("lider") or [None])[0]
        cand = [p for p in pk.values() if p.get("name") == nome]
        if cand:
            x.setdefault("_contexto", []).append({"type": "poke-delta", "poke": dict(cand[0], team=True, leader=True)})
            x["lider_de_depois"] = True
    trechos.sort(key=lambda x: (x.get("t0") or 0))
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
        init = dict(x["_msgs"][0])
        if (x["motivo_inicio"] != "entrada" or not x.get("lock_s")) and ":r" not in init.get("huntKey", ""):
            # pedaço do meio, ou entrada sem lock no real (A: nem toda entrada penaliza): a sim não aplica a penalidade
            init["huntKey"] = init.get("huntKey", "") + ":r1"
        msgs = [init] + x.get("_contexto", []) + x["_msgs"][1:]
        with open(c, "w", encoding="utf-8", newline="\n") as f:
            for j, m in enumerate(msgs):
                f.write(json.dumps({"sessao": x["huntKey"], "t": x["t0"] + j, "dir": "in", "msg": m}, ensure_ascii=False) + "\n")
        x.pop("_msgs", None)
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
