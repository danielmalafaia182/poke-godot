#!/usr/bin/env bash
# Monta o jogo para Windows em builds/<nome>/ (padrão ciclo2): PokeIdle.pck (export-pack do preset "Windows Desktop"),
# PokeIdle.exe (o executável do Godot 4.7.2: sem os templates de exportação instalados, o binário do Godot roda o .pck
# de mesmo nome ao lado dele), dados/, o snapshot do servidor e as páginas do poke-local (cadáveres que faltam no snapshot).
# Depois verifica com ferramentas/build/verificar_build.gd e APPDATA isolado (o save real nunca é tocado).
# Uso: ferramentas/build/montar_build.sh [nome]
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
NOME="${1:-ciclo2}"
GODOT_DIR="${GODOT_DIR:-/c/Users/dmala/Desktop/Godot}"
B="$RAIZ/builds/$NOME"
mkdir -p "$B/dados" "$B/poke har/extraido" "$B/poke-local/public"
"$GODOT_DIR/Godot_v4.7.2-stable_win64_console.exe" --headless --path "$RAIZ" --export-pack "Windows Desktop" "$B/PokeIdle.pck" >/dev/null 2>&1
cp "$GODOT_DIR/Godot_v4.7.2-stable_win64.exe" "$B/PokeIdle.exe"
for d in gerados fase4 pacotes mapas referencias caca combate importados; do cp -r "$RAIZ/dados/$d" "$B/dados/"; done
cp "$RAIZ"/dados/*.json "$B/dados/"
[ -d "$B/poke har/extraido/snapshot_2026-11-09" ] || cp -r "$RAIZ/poke har/extraido/snapshot_2026-11-09" "$B/poke har/extraido/"
[ -d "$B/poke-local/public/game" ] || cp -r "$RAIZ/poke-local/public/game" "$B/poke-local/public/"
ISO="$(mktemp -d)"; SHOTS="$(mktemp -d)"
( cd "$B" && APPDATA="$(cygpath -w "$ISO")" VERIF_SAIDA="$(cygpath -m "$SHOTS")" timeout 600 ./PokeIdle.exe --script "$(cygpath -m "$RAIZ/ferramentas/build/verificar_build.gd")" 2>&1 | grep -E "^OK|FALHA|RESULTADO" )
echo "capturas em $SHOTS"
