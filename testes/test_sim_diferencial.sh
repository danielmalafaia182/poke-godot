#!/usr/bin/env bash
# Passo 4 da fase 1: teste diferencial da hunt do Rhydon com o Venusaur 109 (estado inicial real).
# 20 instâncias simuladas × 10 min (a gravação real cobre 9,3 min de UMA instância) → comparar_sim.py --por-instancia,
# que usa o analisar_gravacao.py nos dois lados. Critérios fixos no script; o resultado é medição, não alvo de ajuste.
# Uso: testes/test_sim_diferencial.sh   (saídas em saida_testes/, ignoradas pelo git)
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
REAL="poke har/gravacoes/gravacoes_unicas_2026-11-09.jsonl"
for s in $(seq 1 20); do
  TEMPO_MAX=60 testes/rodar.sh res://testes/rodar_sim.gd --segundos 600 --semente "$s" --saida "saida_testes/inst_s$s.jsonl" > /dev/null 2>&1
done
python -I ferramentas/gravador/comparar_sim.py --slug rhydon --especie 112 --real "$REAL" \
  --sim saida_testes/inst_s*.jsonl --por-instancia --json saida_testes/diferencial_instancias.json
