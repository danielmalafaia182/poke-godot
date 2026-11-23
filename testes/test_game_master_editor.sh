#!/usr/bin/env bash
# O plugin Game Master abre no editor sem erro (editor headless, APPDATA isolado; não grava nada no projeto).
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/c/Users/dmala/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
ISO="$(mktemp -d "${TMPDIR:-/tmp}/poke_gm_XXXXXX")"
if command -v cygpath >/dev/null 2>&1; then export APPDATA="$(cygpath -w "$ISO")"; else export APPDATA="$ISO"; fi
SAIDA="$(timeout --kill-after=5 300 "$GODOT" --headless --editor --path "$RAIZ" --quit-after 600 2>&1)"
ok=0
echo "$SAIDA" | grep -q "Game Master: dock carregado" && ok=$((ok+1)) && echo "OK    dock carregado" || echo "FALHA dock não carregou"
ERROS="$(echo "$SAIDA" | grep -E "SCRIPT ERROR|Parse Error|game_master" | grep -v "dock carregado")"
[ -z "$ERROS" ] && ok=$((ok+1)) && echo "OK    nenhum erro do plugin" || { echo "FALHA erros:"; echo "$ERROS" | head; }
echo "RESULTADO: $ok/2"
[ $ok -eq 2 ]
