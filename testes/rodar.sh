#!/usr/bin/env bash
# Roda um teste headless do Godot com user:// isolado (APPDATA temporário): o save real nunca é tocado.
# Uso: testes/rodar.sh res://testes/test_sim_grade.gd [args extras para o script após --]
# Variáveis: GODOT (executável), POKE_SNAPSHOT (pasta do snapshot, opcional).
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/dmala/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
SCRIPT="$1"; shift || true
ISOLADO="$(mktemp -d "${TMPDIR:-/tmp}/poke_teste_XXXXXX")"
if command -v cygpath >/dev/null 2>&1; then APP="$(cygpath -w "$ISOLADO")"; else APP="$ISOLADO"; fi
export APPDATA="$APP" XDG_DATA_HOME="$ISOLADO" HOME_ISOLADO="$ISOLADO"
# Limite de tempo (TEMPO_MAX em s, padrão 600): script com erro de compilação não chama quit() e travaria.
timeout --kill-after=5 "${TEMPO_MAX:-600}" "$GODOT" --headless --path "$RAIZ" --script "$SCRIPT" -- "$@"
