#!/usr/bin/env bash
# Como testes/rodar.sh, mas COM janela (renderização real, para capturas e medição de frame time).
# user:// isolado com APPDATA temporário: o save real nunca é tocado.
# Uso: testes/rodar_janela.sh res://script.gd [args do script após --]
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/dmala/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
SCRIPT="$1"; shift || true
ISOLADO="$(mktemp -d "${TMPDIR:-/tmp}/poke_teste_XXXXXX")"
if command -v cygpath >/dev/null 2>&1; then APP="$(cygpath -w "$ISOLADO")"; else APP="$ISOLADO"; fi
export APPDATA="$APP" XDG_DATA_HOME="$ISOLADO"
[[ "${1:-}" == "--" ]] && shift
timeout --kill-after=5 "${TEMPO_MAX:-300}" "$GODOT" --path "$RAIZ" --resolution 1920x1080 ${GODOT_EXTRA:-} --script "$SCRIPT" -- "$@"
