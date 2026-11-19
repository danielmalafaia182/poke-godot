#!/usr/bin/env python3
"""Pacote de textos do jogo (conteúdo trocável, ESTRATEGIA.md): os textos em português do cliente original (C), extraídos
por ferramentas/inventario/extrair_textos.js, vão para dados/pacotes/textos_pt.json, que o jogo lê por textos.gd.
Trocar o pacote = trocar este arquivo (mesmas chaves).

Uso: python -I ferramentas/inventario/gerar_pacote_textos.py saida_testes/textos_cliente.json [dados/pacotes/textos_pt.json]
"""
import json
import sys


def main():
    origem = sys.argv[1]
    destino = sys.argv[2] if len(sys.argv) > 2 else "dados/pacotes/textos_pt.json"
    d = json.load(open(origem, encoding="utf-8"))
    pt = d.get("pt") or next(iter(d.values()))
    saida = {"_doc": "Textos do cliente original em português (C). Pacote trocável: o jogo lê as chaves por textos.gd; "
                     "gerado por ferramentas/inventario/gerar_pacote_textos.py, não editar à mão.",
             "pt": pt}
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        json.dump(saida, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(destino, sum(1 for _ in json.dumps(pt)), "bytes")


if __name__ == "__main__":
    main()
