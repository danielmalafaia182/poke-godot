#!/usr/bin/env python3
"""Organiza os quadros extraídos (referencia_visual/quadros/brutos) por tela, pela posição nas folhas de contato
(folhas/indice.txt; folha NN, posição 0–19). A separação foi feita olhando as folhas (ciclo 4). Copia (não move)
para referencia_visual/quadros/<tela>/ e escreve quadros/indice_telas.md.
Uso: python -I ferramentas/visual/organizar_quadros.py
"""
import os
import shutil

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
Q = os.path.join(RAIZ, "referencia_visual", "quadros")


def r(f, a, b):
    return [(f, i) for i in range(a, b + 1)]


TELAS = {
    "01_landing": r(0, 0, 1),
    "02_login_cadastro": r(0, 2, 16),
    "03_criar_personagem": r(0, 17, 19) + r(1, 0, 0),
    "04_carregando": r(1, 1, 1) + r(1, 4, 4) + r(9, 5, 6),
    "05_tutorial_cidade": r(1, 2, 3) + r(1, 5, 10) + r(1, 12, 16) + r(2, 3, 10) + r(2, 13, 14),
    "06_nurse_joy": r(1, 11, 11),
    "07_depot": r(1, 17, 19) + r(2, 0, 2),
    "08_mapa": r(2, 11, 12) + r(8, 15, 19) + r(9, 0, 1) + r(12, 18, 19) + r(13, 0, 5),
    "09_primeira_hunt": r(2, 15, 19) + r(3, 0, 0),
    "10_cidade": r(3, 1, 3) + r(3, 11, 12) + r(3, 19, 19) + r(4, 6, 7) + r(4, 10, 10) + r(5, 6, 6) + r(5, 12, 13) + r(6, 0, 1) + r(6, 12, 12) + r(6, 18, 19) + r(7, 6, 8) + r(7, 12, 12) + r(8, 1, 1) + r(8, 13, 14) + r(9, 2, 4) + r(9, 7, 7) + r(9, 10, 11) + r(9, 15, 16) + r(10, 5, 7) + r(10, 12, 15) + r(11, 0, 2) + r(11, 9, 10) + r(11, 14, 16) + r(11, 19, 19) + r(12, 0, 1) + r(12, 4, 4) + r(12, 8, 9) + r(12, 16, 17) + r(13, 6, 6),
    "11_time_my_pokes": r(3, 4, 10),
    "12_todos_shinys": r(3, 13, 18),
    "13_perfil_outfit": r(4, 0, 5) + r(4, 8, 9),
    "14_pokedex": r(4, 11, 19) + r(5, 0, 5),
    "15_golden_stars_slot": r(5, 7, 11),
    "16_album_cards": r(5, 14, 19),
    "17_ginasios": r(6, 2, 11) + r(9, 12, 14),
    "18_bosses": r(6, 13, 17),
    "19_profissoes": r(7, 0, 5),
    "20_npc_talentos": r(7, 9, 11),
    "21_perfil": r(7, 13, 19) + r(8, 0, 0),
    "22_breeding": r(8, 2, 12),
    "23_janela_mercado": r(9, 8, 9),
    "24_mochila": r(9, 17, 19) + r(10, 0, 4),
    "25_bolas_usadas": r(10, 8, 11),
    "26_hunt_analyzer_lateral": r(10, 16, 19),
    "27_season_pass": r(11, 3, 7),
    "28_streak": r(11, 11, 13),
    "29_janela_grade": r(11, 17, 18),
    "30_quests": r(12, 2, 3),
    "31_loja": r(12, 5, 7),
    "32_sobre_logo": r(12, 10, 10),
    "33_configuracoes": r(12, 11, 15),
    "34_hunt_combate": r(13, 7, 19) + r(14, 0, 0),
}


def main():
    folhas = {}
    for linha in open(os.path.join(Q, "folhas", "indice.txt"), encoding="utf-8"):
        k, v = linha.split(":", 1)
        folhas[int(k.strip().split("_")[1])] = v.split()
    usados = set()
    md = ["# Quadros de referência por tela (ciclo 4)", "",
          "Extraídos dos vídeos do usuário jogando o original (1 por segundo, repetidos descartados): "
          "`ferramentas/visual/servidor_quadros.py` → `brutos/`; separados por `ferramentas/visual/organizar_quadros.py`.", "",
          "| Tela | Quadros |", "| --- | --- |"]
    for tela, pos in TELAS.items():
        dst = os.path.join(Q, tela)
        os.makedirs(dst, exist_ok=True)
        arqs = [folhas[f][i] for f, i in pos if f in folhas and i < len(folhas[f])]
        for a in arqs:
            shutil.copy2(os.path.join(Q, "brutos", a), os.path.join(dst, a))
            usados.add(a)
        md.append(f"| `{tela}` | {len(arqs)} ({', '.join(arqs[:4])}{'…' if len(arqs) > 4 else ''}) |")
    resto = sorted(set(sum(folhas.values(), [])) - usados)
    md += ["", f"Sem tela (transições, quadros parciais): {len(resto)}."]
    open(os.path.join(Q, "indice_telas.md"), "w", encoding="utf-8", newline="\n").write("\n".join(md) + "\n")
    print(len(TELAS), "telas,", len(usados), "quadros;", len(resto), "sem tela")


if __name__ == "__main__":
    main()
