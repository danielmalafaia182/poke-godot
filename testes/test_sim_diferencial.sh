#!/usr/bin/env bash
# Teste diferencial da hunt do Rhydon com o Venusaur (estado inicial real tirado da própria gravação).
# N instâncias simuladas × SEGUNDOS → comparar_sim.py --por-instancia, que usa o analisar_gravacao.py nos dois lados.
# Critérios fixos no script; o resultado é medição, não alvo de ajuste.
#
# Uso: testes/test_sim_diferencial.sh [antiga|1h]      (saídas em saida_testes/, ignoradas pelo git)
#   antiga: gravacoes_unicas (9,3 min, Venusaur 109) × 20 instâncias de 10 min
#   1h:     rhydon-1h (88 min, Venusaur 119–124) × 20 instâncias de 60 min   [referência principal]
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
CASO="${1:-1h}"
case "$CASO" in
  antiga) REAL="poke har/gravacoes/gravacoes_unicas_2026-11-09.jsonl"; ESTADO="dados/testes/estado_rhydon_venusaur.json"; SEG=600 ;;
  1h)     REAL="poke har/gravacoes/rhydon-1h.jsonl"; ESTADO="dados/testes/estado_rhydon_venusaur_1h.json"; SEG=3600 ;;
  *) echo "caso desconhecido: $CASO"; exit 2 ;;
esac
N="${INSTANCIAS:-20}"
PARALELO="${PARALELO:-4}"          # instâncias simultâneas (cada uma é um processo Godot independente)
rm -f saida_testes/dif_${CASO}_s*.jsonl
for s in $(seq 1 "$N"); do
  TEMPO_MAX=900 testes/rodar.sh res://testes/rodar_sim.gd --estado "$ESTADO" --segundos "$SEG" --semente "$s" \
    --saida "saida_testes/dif_${CASO}_s$s.jsonl" > /dev/null 2>&1 &
  if (( s % PARALELO == 0 )); then wait; fi
done
wait
python -I ferramentas/gravador/comparar_sim.py --slug rhydon --especie 112 --real "$REAL" \
  --sim saida_testes/dif_${CASO}_s*.jsonl --por-instancia --json "saida_testes/diferencial_${CASO}.json"
