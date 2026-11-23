#!/usr/bin/env bash
# Roda um teste headless do Godot com user:// isolado (APPDATA temporário): o save real nunca é tocado.
# Uso: testes/rodar.sh res://testes/test_sim_grade.gd [args extras para o script após --]
# Variáveis: GODOT (executável), POKE_SNAPSHOT (pasta do snapshot, opcional).
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/dmala/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
SCRIPT="$1"; shift || true
# ISOLADO (opcional): reusar um diretório isolado entre duas execuções (ex.: preparar fixture e depois testar).
ISOLADO="${ISOLADO:-$(mktemp -d "${TMPDIR:-/tmp}/poke_teste_XXXXXX")}"
if command -v cygpath >/dev/null 2>&1; then APP="$(cygpath -w "$ISOLADO")"; else APP="$ISOLADO"; fi
export APPDATA="$APP" XDG_DATA_HOME="$ISOLADO" HOME_ISOLADO="$ISOLADO"
# Regras: o teste usa o perfil "original" (ou PERFIL_REGRAS), mesmo com outro perfil ativo no projeto
# (dados/regras/perfil.txt): o user:// tem precedência (sim/regras_jogo.gd).
mkdir -p "$ISOLADO/Godot/app_userdata/PokeIdle/regras"
[ -f "$ISOLADO/Godot/app_userdata/PokeIdle/regras/perfil.txt" ] || printf '%s' "${PERFIL_REGRAS:-original}" > "$ISOLADO/Godot/app_userdata/PokeIdle/regras/perfil.txt"
# Limite de tempo (TEMPO_MAX em s, padrão 600): script com erro de compilação não chama quit() e travaria.
timeout --kill-after=5 "${TEMPO_MAX:-600}" "$GODOT" --headless --path "$RAIZ" --script "$SCRIPT" -- "$@"
