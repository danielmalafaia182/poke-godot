#!/usr/bin/env bash
# Roda os testes antigos do P04 (test_*.gd na raiz), cada um com save isolado e limite de tempo, e resume
# código de saída + linhas de falha. Uso: testes/rodar_antigos.sh saida.tsv
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
SAIDA="${1:-saida_testes/antigos.tsv}"
: > "$SAIDA"
for f in test_*.gd; do
  if [ "$f" = "test_compatibilidade_save.gd" ]; then
    log="$(TEMPO_MAX="${TEMPO_MAX:-180}" bash testes/test_compatibilidade_save.sh 2>&1)"   # precisa da fixture no user://
  else
    log="$(TEMPO_MAX="${TEMPO_MAX:-180}" testes/rodar.sh "res://$f" 2>&1)"
  fi
  cod=$?
  nfal=$(printf '%s\n' "$log" | grep -ciE "^(FALHA|FALHOU|FAIL)|falha:" || true)
  erro=$(printf '%s\n' "$log" | grep -c "SCRIPT ERROR" || true)
  printf '%s\t%s\t%s\t%s\n' "$f" "$cod" "$nfal" "$erro" >> "$SAIDA"
done
cat "$SAIDA"
