#!/usr/bin/env python3
"""Relatório da campanha do zero (testes/campanha.gd) e da jogabilidade das 451 hunts (testes/jogabilidade_hunts.gd).

Uso: python -I ferramentas/fase4/relatorio_campanha.py saida_testes/campanha.json saida_testes/jogabilidade.json \
        dados/relatorios/campanha_<data>.md
"""
import json
import sys
from collections import Counter


def main():
    camp = json.load(open(sys.argv[1], encoding="utf-8"))
    jog = json.load(open(sys.argv[2], encoding="utf-8"))
    out = []
    w = out.append
    w("# Campanha do zero e jogabilidade das hunts (sim pura)\n")
    w("Gerado por `ferramentas/fase4/relatorio_campanha.py` a partir de `testes/campanha.gd` e `testes/jogabilidade_hunts.gd`.")
    w("A política do jogador é E (descrita no cabeçalho de `testes/campanha.gd`); as regras do jogo são as da `sim/`.\n")
    w("## Campanha\n")
    w(f"- Começo: jogo novo do projeto, Geodude Lv.1, treinador 1, 100 Small Potions, 100 Poké Balls, ouro 0 (semente {camp['args']['semente']}).")
    ouro = f"{camp['ouro_final']:,}".replace(",", ".")
    areas = sorted({h["area"] for h in camp["por_hunt"]})
    w(f"- Resultado: **{camp['minutos_jogados'] / 60:.1f} h jogadas**, treinador **{camp['treinador_final']}**, líder **{camp['especie_final']} {camp['lider_final']}**, "
      f"ouro {ouro}, {len(camp['por_hunt'])} hunts visitadas ({', '.join(areas)}), {camp['segundos_reais']:.0f} s de execução.")
    w("- Orre abre no nível 500 e Nightmare no 2000 do treinador (C): a campanha não chegou lá. Essas regiões ficam cobertas pela "
      "varredura de jogabilidade abaixo.")
    evol = [x for x in camp["linha_tempo"] if x.get("evoluiu")]
    for e in evol:
        w(f"- Evoluiu para **{e['evoluiu']}** antes da sessão {e['sessao']} ({e['h']} h; líder {e['lider'].split('→')[0]}).")
    mortes = sum(h["mortes"] for h in camp["por_hunt"])
    w(f"- Mortes (time sem reserva viva → cidade): {mortes} em {len(camp['linha_tempo'])} sessões. Pedras obtidas: {camp.get('pedras_obtidas', {})}.")
    lt = camp["linha_tempo"]
    loops = sorted({lt[i]["slug"] for i in range(1, len(lt)) if lt[i]["morte"] and lt[i - 1]["morte"] and lt[i]["slug"] == lt[i - 1]["slug"]})
    sem_abate = sorted({h["slug"] for h in camp["por_hunt"] if h["abates"] == 0})
    travadas = sorted({h["slug"] for h in camp["por_hunt"] if h["travado_max_s"] >= 60})
    w(f"- **Morte em loop** (duas sessões seguidas morrendo na mesma hunt): **{loops or 'nenhuma'}**. 0 abates: **{sem_abate or 'nenhuma'}**. "
      f"Travada ≥ 60 s: **{travadas or 'nenhuma'}**.")
    tres = [h for h in camp["por_hunt"] if h["mortes"] >= 3]
    if tres:
        w("- Hunts com 3 ou mais mortes no total, espaçadas: " + ", ".join(f"{h['slug']} ({h['mortes']} em {h['sessoes']} sessões)" for h in tres)
          + ". A política volta a tentar depois de +10 níveis; são hunts boas de Rock Stone, que a sonda de 2 min aprova e a sessão "
          "de 60 min derruba, até o líder aguentar.\n")
    else:
        w("")
    w("| Hunt | Área | Nível | Líder (de → até) | Tempo (min) | Abates/min | Mortes | XP/h (treinador) | Ouro/h (venda do loot) | Poções/h | Capturas | Maior trecho travado (s) |")
    w("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for h in camp["por_hunt"]:
        w(f"| {h['slug']} | {h['area']} | {h['nivel']} | {h['lider_de']} → {h['lider_ate']} | {h['min']:.0f} | {h['abates_min']} | {h['mortes']} | "
          f"{h['xp_h']:,} | {h['ouro_h']:,} | {h['pocoes_h']} | {h['capturas']} | {h['travado_max_s']} |".replace(",", "."))
    w("\n### Linha do tempo (uma linha a cada 10 sessões e as evoluções/mortes)\n")
    w("| Sessão | h | Hunt (nível) | Treinador | Líder | Abates | Morte | Ouro |")
    w("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for x in camp["linha_tempo"]:
        if x["sessao"] % 10 == 1 or x.get("evoluiu") or x["morte"]:
            w(f"| {x['sessao']} | {x['h']} | {x['slug']} ({x['nivel_hunt']}) | {x['treinador']} | {x['lider']}{' (evoluiu: ' + x['evoluiu'] + ')' if x.get('evoluiu') else ''} | {x['abates']} | {'sim' if x['morte'] else ''} | {x['ouro']} |")
    w("\n## Jogabilidade das 451 hunts\n")
    hs = jog["hunts"]
    c = Counter(x["area"] for x in hs)
    ok = Counter(x["area"] for x in hs if x["ok"])
    w(f"5 min por hunt. Time igual: linha do Geodude no nível da hunt (mesmos IV e Quality do jogo novo). Quem falha roda com o time "
      f"forte (IV 32, Q 1,8, nível 3 × hunt + 50). Travado = herói parado, sem lutar, com selvagem vivo e alvo definido.\n")
    w("| Área | Hunts | Passam com time igual | Passam com time forte | Maior trecho travado (s) |")
    w("| --- | --- | --- | --- | --- |")
    for a in ("kanto", "outland", "orre", "nightmare"):
        sub = [x for x in hs if x["area"] == a]
        forte = sum(1 for x in sub if x["ok"] or x.get("forte", {}).get("ok"))
        trav = max(max(x["travado_max_s"], x.get("forte", {}).get("travado_max_s", 0)) for x in sub)
        w(f"| {a} | {c[a]} | {ok[a]} | {forte} | {trav} |")
    sem_abate_sem_morte = [x["slug"] for x in hs if x["abates"] == 0 and not x["morte"]]
    w(f"\n- **Trava de mecânica** (falha também com o time forte): **{jog['falham_time_forte'] or 'nenhuma'}**.")
    w(f"- 0 abates sem morte: {sem_abate_sem_morte or 'nenhuma'}. Maior trecho travado em todas as corridas: "
      f"{max(max(x['travado_max_s'], x.get('forte', {}).get('travado_max_s', 0)) for x in hs)} s.")
    lento = sorted(hs, key=lambda x: -(x.get("forte") or x)["primeiro_abate_s"])[:5]
    w("- Primeiro abate mais demorado (time que passou): " + ", ".join(f"{x['slug']} {(x.get('forte') or x)['primeiro_abate_s']:.0f} s" for x in lento) + ".")
    falha = [x for x in hs if not x["ok"]]
    w(f"- Com o time igual, {len(falha)} hunts terminam em morte em 5 min ({sum(1 for x in falha if x['abates'] == 0)} sem nenhum abate). "
      "É dificuldade, não trava: o selvagem tem 35× de HP contra 12× do aliado e bate com ×1,8 (A). Não há gravação de um time no "
      "mesmo nível da hunt para dizer se o original é igual (F).")
    open(sys.argv[3], "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    sys.stdout.reconfigure(encoding="utf-8")
    print("\n".join(out[:14]))


if __name__ == "__main__":
    main()
