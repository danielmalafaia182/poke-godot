#!/usr/bin/env python3
"""Valida mensagens de um JSONL (formato do gravador {sessao,t,dir,msg} ou mensagem crua) contra dados/protocolo.json.

Para cada mensagem recebida (dir "in"):
  - o tipo precisa existir no protocolo;
  - campos obrigatórios do esquema (sem "opcional") precisam estar presentes;
  - o tipo de cada valor precisa estar entre os tipos vistos nos logs (int/float/bool/str/list/object/null);
  - listas e objetos aninhados são conferidos pelo mesmo critério;
  - campos que o esquema não conhece viram aviso (o esquema vem só de logs: ausência não prova nada).
Tipos sem esquema (só "no_cliente") passam apenas pela checagem de existência.

Uso: python ferramentas/protocolo/validar_jsonl.py arquivo.jsonl [--protocolo dados/protocolo.json] [--max-erros 20]
Saída: código 0 se não houver erro (avisos não reprovam).
"""
import argparse
import json
import sys
from collections import Counter
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]


def tipo_de(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "bool"
    if isinstance(v, int):
        return "int"
    if isinstance(v, float):
        return "float"
    if isinstance(v, str):
        return "str"
    if isinstance(v, list):
        return "list"
    if isinstance(v, dict):
        return "object"
    return type(v).__name__


def compativel(t, permitidos):
    if t in permitidos:
        return True
    # um float inteiro (ex.: 1.0) e um int representam o mesmo número em JSON
    return t == "int" and "float" in permitidos


def conferir(valor, esq, caminho, erros, avisos):
    tipos = esq.get("tipos")
    t = tipo_de(valor)
    if tipos and not compativel(t, tipos):
        erros.append(f"{caminho}: tipo {t}, esperado {tipos}")
        return
    if t == "list" and "itens" in esq:
        for i, item in enumerate(valor[:50]):
            conferir(item, esq["itens"], f"{caminho}[{i}]", erros, avisos)
    if t == "object" and "campos" in esq:
        conferir_campos(valor, esq["campos"], caminho, erros, avisos)


def conferir_campos(obj, campos, caminho, erros, avisos):
    for nome, e in campos.items():
        if nome not in obj:
            if not e.get("opcional"):
                erros.append(f"{caminho}.{nome}: ausente")
            continue
        conferir(obj[nome], e, f"{caminho}.{nome}", erros, avisos)
    for nome in obj:
        if nome not in campos and nome != "type":
            avisos.append(f"{caminho}.{nome}: campo fora do esquema")


def mensagens(caminho):
    for n, linha in enumerate(open(caminho, encoding="utf-8", errors="replace"), 1):
        linha = linha.strip()
        if not linha:
            continue
        try:
            o = json.loads(linha)
        except Exception:
            yield n, None
            continue
        if isinstance(o, dict) and "dir" in o and "msg" in o:
            if o["dir"] != "in":
                continue
            o = o["msg"]
        yield n, o


def validar(caminho, protocolo, max_erros=20):
    msgs = protocolo["mensagens"]
    por_tipo = Counter()
    erros, avisos = [], Counter()
    invalidas = 0
    for n, m in mensagens(caminho):
        if not isinstance(m, dict) or "type" not in m:
            invalidas += 1
            continue
        t = m["type"]
        por_tipo[t] += 1
        if t not in msgs:
            erros.append(f"linha {n}: tipo desconhecido {t!r}")
            continue
        esq = (msgs[t].get("visto_in") or {}).get("esquema")
        if not esq:
            continue
        e_local, a_local = [], []
        conferir_campos(m, esq, t, e_local, a_local)
        for e in e_local:
            erros.append(f"linha {n}: {e}")
        for a in a_local:
            avisos[a] += 1
    return {"por_tipo": dict(por_tipo), "erros": erros, "avisos": dict(avisos), "invalidas": invalidas}


def unir_esquemas(a, b):
    """União de dois esquemas de campo (formato do protocolo.json). Campo ausente em um dos lados vira opcional."""
    r = {"tipos": sorted(set(a.get("tipos", [])) | set(b.get("tipos", [])))}
    if a.get("opcional") or b.get("opcional"):
        r["opcional"] = True
    if "campos" in a or "campos" in b:
        ca, cb = a.get("campos", {}), b.get("campos", {})
        r["campos"] = {}
        for k in sorted(set(ca) | set(cb)):
            if k in ca and k in cb:
                r["campos"][k] = unir_esquemas(ca[k], cb[k])
            else:
                e = dict(ca.get(k) or cb.get(k))
                e["opcional"] = True
                r["campos"][k] = e
    if "itens" in a or "itens" in b:
        ia, ib = a.get("itens"), b.get("itens")
        r["itens"] = unir_esquemas(ia, ib) if ia and ib else (ia or ib)
    return r


def ampliar_com_referencia(proto, caminhos):
    """Acrescenta ao protocolo o esquema aprendido de gravações reais (fonte A), sem alterar o arquivo gerado."""
    sys.path.insert(0, str(RAIZ / "ferramentas" / "protocolo"))
    from gerar_protocolo import Esquema, ler_logs
    esq = {}
    for d, m, _ in ler_logs(caminhos):
        if d != "in":
            continue
        e = esq.setdefault(m["type"], Esquema())
        e.ver({k: v for k, v in m.items() if k != "type"})
    msgs = proto["mensagens"]
    for t, e in esq.items():
        novo = e.dump().get("campos", {})
        alvo = msgs.setdefault(t, {"no_cliente": {}})
        vi = alvo.setdefault("visto_in", {})
        if "esquema" in vi:
            vi["esquema"] = unir_esquemas({"campos": vi["esquema"]}, {"campos": novo})["campos"]
        else:
            vi["esquema"] = novo
    return proto


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivo")
    ap.add_argument("--protocolo", default=str(RAIZ / "dados" / "protocolo.json"))
    ap.add_argument("--referencia", nargs="*", default=[], help="gravações reais que ampliam o esquema (fonte A)")
    ap.add_argument("--max-erros", type=int, default=20)
    a = ap.parse_args()
    proto = json.load(open(a.protocolo, encoding="utf-8"))
    if a.referencia:
        proto = ampliar_com_referencia(proto, a.referencia)
    r = validar(a.arquivo, proto, a.max_erros)
    print("mensagens por tipo:", r["por_tipo"])
    if r["invalidas"]:
        print("linhas inválidas:", r["invalidas"])
    for k, v in sorted(r["avisos"].items()):
        print(f"aviso: {k} ({v}x)")
    for e in r["erros"][: a.max_erros]:
        print("ERRO:", e)
    if len(r["erros"]) > a.max_erros:
        print(f"... mais {len(r['erros']) - a.max_erros} erros")
    ok = not r["erros"] and not r["invalidas"]
    print("RESULTADO:", "OK" if ok else f"{len(r['erros'])} erro(s)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
