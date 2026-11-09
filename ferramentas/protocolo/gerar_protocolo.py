#!/usr/bin/env python3
"""Gera protocolo.json: catálogo das mensagens do Poke Idle World.

Fontes:
  --cliente  chunks JS do cliente original (comandos enviados e eventos assinados)
  --logs     gravações (3 formatos aceitos: linha = mensagem JSON; formato antigo
             {"direcao","dados"}; formato do gravador novo {"dir","msg"})

Saída: para cada tipo, direção, quantas vezes foi visto, em quais fontes, e o
esquema dos campos (tipos observados, exemplo curto, aninhamento de objetos e listas).
Uso: python3 gerar_protocolo.py --cliente chunk1.js chunk2.js --logs a.txt b.jsonl --saida protocolo.json
"""
import argparse, glob, json, os, re, sys
from collections import defaultdict

TIPOS_HTML = {"button", "number", "checkbox", "password", "submit", "range", "text",
              "email", "female", "male", "radio", "file", "search", "hidden", "tel", "url",
              # literais {type:"..."} do bundle que não são mensagens (DOM, WebGL, React)
              "script", "style", "stylesheet", "uniform", "void", "filtering", "send"}
# nomes assinados que são eventos do navegador/DOM, não do servidor
EVENTOS_DOM = {"beforetoggle", "cancel", "change", "close", "load", "scroll", "scrollend", "toggle",
               "type", "sort", "cursor", "new", "old", "image-pair", "history", "invalid", "input",
               "keydown", "resize", "message", "open", "group"}


def tipo_json(v):
    if v is None: return "null"
    if isinstance(v, bool): return "bool"
    if isinstance(v, int): return "int"
    if isinstance(v, float): return "float"
    if isinstance(v, str): return "str"
    if isinstance(v, list): return "list"
    return "object"


class Esquema:
    """Acumula a forma de valores JSON vistos para um mesmo campo."""
    def __init__(self):
        self.tipos = defaultdict(int)
        self.campos = {}          # para objetos
        self.itens = None         # para listas
        self.exemplo = None
        self.vistos = 0

    def ver(self, v):
        self.vistos += 1
        t = tipo_json(v)
        self.tipos[t] += 1
        if t == "object":
            for k, x in v.items():
                self.campos.setdefault(k, Esquema()).ver(x)
        elif t == "list":
            self.itens = self.itens or Esquema()
            for x in v[:50]:
                self.itens.ver(x)
        elif self.exemplo is None:
            self.exemplo = v if not isinstance(v, str) else v[:60]

    def dump(self, total_pai=None):
        d = {"tipos": sorted(self.tipos)}
        if total_pai is not None and self.vistos < total_pai:
            d["opcional"] = True
        if self.exemplo is not None:
            d["exemplo"] = self.exemplo
        if self.campos:
            d["campos"] = {k: e.dump(self.tipos.get("object", 0)) for k, e in sorted(self.campos.items())}
        if self.itens is not None:
            d["itens"] = self.itens.dump()
        return d


def ler_logs(caminhos, deduplicar=True):
    """Devolve (direcao, mensagem, fonte) para cada mensagem reconhecida.

    Com deduplicar, uma linha do gravador novo ({sessao,t,dir,msg}) que já apareceu em outro arquivo
    (mesma sessão, instante, direção e conteúdo) é contada uma vez só: as gravações exportadas se sobrepõem."""
    vistas = set()
    for c in caminhos:
        with open(c, encoding="utf-8", errors="replace") as f:
            for linha in f:
                linha = linha.strip()
                if not linha:
                    continue
                try:
                    o = json.loads(linha)
                except Exception:
                    continue
                if not isinstance(o, dict):
                    continue
                if "direcao" in o and "dados" in o:          # gravador antigo
                    try:
                        m = json.loads(o["dados"])
                    except Exception:
                        continue
                    d = "out" if o["direcao"].startswith("envi") else "in"
                elif "dir" in o and "msg" in o:              # gravador novo
                    m, d = o["msg"], o["dir"]
                    if d == "meta":
                        continue
                    if deduplicar:
                        chave = (o.get("sessao"), o.get("t"), d, json.dumps(m, sort_keys=True))
                        if chave in vistas:
                            continue
                        vistas.add(chave)
                else:                                        # mensagem crua
                    m, d = o, "?"
                if isinstance(m, dict) and isinstance(m.get("type"), str):
                    yield d, m, os.path.basename(c)


def extrair_cliente(caminhos):
    enviados = defaultdict(set)   # tipo -> chaves vistas no literal
    assinados = set()
    for c in caminhos:
        s = open(c, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r'\{type:"([a-z][a-z0-9\-]*)"((?:,[A-Za-z_$][\w$]*(?::[^,{}]{1,80})?)*)\}', s):
            t = m.group(1)
            if t in TIPOS_HTML:
                continue
            chaves = re.findall(r',([A-Za-z_$][\w$]*)', m.group(2))
            enviados[t].update(chaves)
        # assinatura de eventos: f("nome", e => ...) ou f("nome", ()=>...)
        for m in re.finditer(r'\b[A-Za-z_$][\w$]{0,2}\("([a-z][a-z0-9\-]+)",\s*(?:\(?[A-Za-z_$,\s]*\)?\s*=>|[A-Za-z_$][\w$]*\))', s):
            if m.group(1) not in EVENTOS_DOM:
                assinados.add(m.group(1))
    return enviados, assinados


def expandir(padroes):
    """Expande globs (o shell do Windows não expande) e mantém a ordem, sem repetir arquivo."""
    r = []
    for p in padroes:
        for c in (sorted(glob.glob(p)) if any(ch in p for ch in "*?[") else [p]):
            c = c.replace("\\", "/")
            if c not in r:
                r.append(c)
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cliente", nargs="*", default=[], help="arquivos ou padrões glob")
    ap.add_argument("--logs", nargs="*", default=[], help="arquivos ou padrões glob")
    ap.add_argument("--saida", required=True)
    a = ap.parse_args()
    a.cliente = expandir(a.cliente)
    a.logs = expandir(a.logs)

    enviados, assinados = extrair_cliente(a.cliente)
    esquemas = defaultdict(Esquema)
    direcoes = defaultdict(set)
    fontes = defaultdict(set)
    contagem = defaultdict(int)
    for d, m, fonte in ler_logs(a.logs):
        t = m["type"]
        if d == "?":
            d = "out" if t in enviados and t not in assinados else "in"
        chave = (t, d)
        esquemas[chave].ver({k: v for k, v in m.items() if k != "type"})
        direcoes[t].add(d)
        fontes[chave].add(fonte)
        contagem[chave] += 1

    mensagens = {}
    todos = set(enviados) | set(assinados) | {t for t, _ in esquemas}
    for t in sorted(todos):
        reg = {"no_cliente": {}}
        if t in enviados:
            reg["no_cliente"]["enviado"] = True
            reg["no_cliente"]["chaves_literal"] = sorted(enviados[t])
        if t in assinados:
            reg["no_cliente"]["assinado"] = True
        for d in ("out", "in"):
            if (t, d) in esquemas:
                reg["visto_" + d] = {
                    "vezes": contagem[(t, d)],
                    "fontes": sorted(fontes[(t, d)]),
                    "esquema": esquemas[(t, d)].dump().get("campos", {}),
                }
        mensagens[t] = reg

    saida = {
        "formato": "poke-protocolo-v1",
        "nota": "Gerado automaticamente. 'enviado' = cliente -> servidor; 'assinado' = evento que o cliente escuta. "
                "Esquemas vêm só dos logs: campo ausente não prova que o servidor nunca o envie.",
        "fontes_cliente": [os.path.basename(c) for c in a.cliente],
        "fontes_logs": [os.path.basename(c) for c in a.logs],
        "totais": {
            "tipos": len(mensagens),
            "enviados_no_cliente": len(enviados),
            "assinados_no_cliente": len(assinados),
            "vistos_em_logs": len({t for t, _ in esquemas}),
        },
        "mensagens": mensagens,
    }
    with open(a.saida, "w", encoding="utf-8", newline="\n") as f:
        json.dump(saida, f, ensure_ascii=False, indent=1)
    print(json.dumps(saida["totais"], ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
