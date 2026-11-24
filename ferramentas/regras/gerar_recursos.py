#!/usr/bin/env python3
"""Game Master, passo 3: gera os Resources de regras a partir de dados/regras/catalogo.json.

- dados/regras/scripts/<recurso>.gd: `class_name RegrasX extends Resource`, um @export por parâmetro, agrupados por
  @export_group (o prefixo da chave), com @export_range para números e um comentário ## (o que faz, unidade, origem A–F,
  status, valor no jogo original). O valor padrão de cada campo É o valor atual do jogo (o literal exato de var_to_str),
  então o perfil "original" é um .tres sem nenhuma alteração e "restaurar original" = voltar ao padrão.
- dados/regras/original/<recurso>.tres: o perfil original (só a referência ao script; nunca é editado).
Uso: python -I ferramentas/regras/gerar_recursos.py
"""
import json
import os
import re

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BASE = os.path.join(RAIZ, "dados", "regras")


def nome_arquivo(rec):
    return re.sub("(?<=[a-z])([A-Z])", lambda m: "_" + m.group(1), rec).lower()


def unidade(k):
    for suf, u in (("_ms", "milissegundos"), ("_s", "segundos"), ("_pct", "%"), ("_ticks", "ticks de 200 ms"), ("_ouro", "ouro"),
                   ("chance", "fração 0–1"), ("fator", "multiplicador"), ("prob", "probabilidade 0–1"), ("fracao", "fração")):
        if k.endswith(suf) or (suf.startswith("_") and suf + "_" in k) or (not suf.startswith("_") and suf in k):
            return u
    return ""


def faixa(e):
    lit = e["literal"]
    if e["tipo"] == "bool":
        return ""
    if e["tipo"] not in ("int", "float"):
        return ""
    v = float(lit)
    k = e["chave"]
    if e["tipo"] == "float" and 0.0 <= v <= 1.0 and any(x in k for x in ("chance", "prob", "fracao", "fator_selvagem", "aleatorio", "limiar", "penalidade_fator")):
        return '@export_range(0.0, 1.0, 0.0001) '
    hi = max(1.0, abs(v) * 10.0)
    if e["tipo"] == "int":
        return '@export_range(%d, %d, 1, "or_greater") ' % (min(0, int(v)), int(hi))
    return '@export_range(%s, %s, 0.0001, "or_greater") ' % ("0.0" if v >= 0 else repr(v * 10.0), repr(hi))


def comentario(e):
    partes = [e["descricao"].strip() or "sem descrição no código"]
    u = unidade(e["chave"])
    if u:
        partes.append("unidade: " + u)
    partes.append("origem %s (%s)" % (e["origem"], e["status"]))
    if e["original_jogo"]:
        partes.append("no jogo original: " + e["original_jogo"])
    partes.append("evidência: " + e["evidencia"])
    txt = " · ".join(partes).replace("\n", " ")
    linhas, atual = [], ""
    for palavra in txt.split(" "):
        if len(atual) + len(palavra) > 110:
            linhas.append(atual)
            atual = palavra
        else:
            atual = (atual + " " + palavra).strip()
    linhas.append(atual)
    return "\n".join("## " + l for l in linhas)


def main():
    cat = json.load(open(os.path.join(BASE, "catalogo.json"), encoding="utf-8"))
    por_rec = {}
    for e in cat["parametros"]:
        por_rec.setdefault(e["recurso"], []).append(e)
    os.makedirs(os.path.join(BASE, "scripts"), exist_ok=True)
    os.makedirs(os.path.join(BASE, "original"), exist_ok=True)
    for rec, es in sorted(por_rec.items()):
        prefixos = {}
        for e in es:
            prefixos[e["chave"].split("_")[0]] = prefixos.get(e["chave"].split("_")[0], 0) + 1
        grupo = lambda e: e["chave"].split("_")[0].capitalize() if prefixos[e["chave"].split("_")[0]] >= 2 else "Geral"
        es.sort(key=lambda e: (grupo(e) == "Geral", grupo(e), e["chave"]))
        L = ["@tool", "class_name %s" % rec, "extends Resource", "## %s — %s." % (rec, cat["sistemas"][rec]),
             "## Gerado por ferramentas/regras/gerar_recursos.py a partir de dados/regras/catalogo.json; não edite à mão.",
             "## O padrão de cada campo é o valor atual do jogo (perfil \"original\"); os perfis em dados/regras/<perfil>/ e",
             "## user://regras/<perfil>/ guardam só o que muda.", ""]
        g_atual = None
        for e in es:
            g = grupo(e)
            if g != g_atual:
                L.append('@export_group("%s")' % g)
                g_atual = g
            tipo = {"int": "int", "float": "float", "bool": "bool", "String": "String", "Dictionary": "Dictionary", "Array": "Array"}.get(e["tipo"], "Variant")
            L.append(comentario(e))
            fx = faixa(e)
            L.append("%s%s var %s: %s = %s" % (fx, "" if fx else "@export", e["chave"], tipo, e["literal"]))
            L.append("")
        arq = nome_arquivo(rec)
        open(os.path.join(BASE, "scripts", arq + ".gd"), "w", encoding="utf-8", newline="\n").write("\n".join(L))
        tres = ('[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]\n\n'
                '[ext_resource type="Script" path="res://dados/regras/scripts/%s.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n') % (rec, arq)
        open(os.path.join(BASE, "original", rec + ".tres"), "w", encoding="utf-8", newline="\n").write(tres)
    print("Resources: %d scripts e %d .tres em dados/regras/" % (len(por_rec), len(por_rec)))


if __name__ == "__main__":
    main()
