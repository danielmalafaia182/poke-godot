#!/usr/bin/env python3
"""Confere o processador de gravações (ferramentas/processar_gravacao.py) contra as conclusões já registradas em
CLAUDE.md / CALIBRACAO_FASE3/4.md: para cada gravação, as regras que ela fechou têm de sair "confirmou".
Uso: python -I testes/test_processar_gravacao.py"""
import os
import sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas"))
import processar_gravacao as P   # noqa: E402

G = os.path.join(RAIZ, "poke har", "gravacoes")
CASOS = [
    ("fase 4/G8.jsonl", True, ["Tipo do Dia: typeDay", "Loot × tabela (tipo do dia", "Tipo do Dia (rotação", "XP base"]),
    ("fase 4/G10.jsonl", True, ["Loot × tabela (normal", "Tipo do Dia (rotação"]),
    ("fase 4/G6.jsonl", True, ["Soneca: xp50"]),
    ("fase 4/G7.jsonl", True, ["Streak:", "Daily Gift:"]),
    ("fase 4/G9.jsonl", True, ["Daily Kill:", "Daily Catch:", "Tarefa entregue", "Daily Gift:"]),
    ("fase 4/G3.jsonl", True, ["Receita de pedras"]),
    ("rhydon-1h.jsonl", False, ["Auto-Potion dispara", "Auto-Potion usa", "Passo do herói", "Passo do selvagem", "VIP =",
                                "Penalidade = lock", "HP de combate do aliado", "HP do selvagem", "Piso de dano do aliado",
                                "Fórmula de dano da sim (aliado, atacante nível 80"]),
    ("fase3/C5.jsonl", True, ["Penalidade = lock"]),
]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    falhas = total = 0
    for arq, sem_dano, esperadas in CASOS:
        c = os.path.join(G, arq)
        if not os.path.exists(c):
            c = os.path.join(G, arq.replace("C5", "c5"))
        R, _ = P.processar(c, sem_dano)
        for pref in esperadas:
            sts = R.status(pref)
            ok = bool(sts) and all(s == P.CONFIRMOU for s in sts)
            total += 1
            falhas += 0 if ok else 1
            print(("OK    " if ok else "FALHA ") + "%s: %s → %s" % (arq, pref, sts))
        contra = [(r, d) for r, _, s, d in R.itens if s == P.CONTRADISSE]
        for r, d in contra:
            print("      (contradisse em %s: %s — %s)" % (arq, r, d))
    print("RESULTADO: %d/%d" % (total - falhas, total))
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
