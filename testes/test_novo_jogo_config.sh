#!/usr/bin/env bash
# "Novo jogo" nas Configurações (ciclo 5, item 98): APPDATA isolado, duas execuções (testes/test_novo_jogo_config.gd).
# Uso: testes/test_novo_jogo_config.sh [pasta para o print]
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
GODOT="${GODOT:-/c/Users/dmala/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
ISO="$(mktemp -d)"; S="$(mktemp -d)"; V="$(cygpath -m testes/test_novo_jogo_config.gd)"
for F in 1 2; do
	APPDATA="$(cygpath -w "$ISO")" POKE_VERIFICAR="$V" POKE_NOVO_JOGO_SEM_REINICIAR=1 SAIDA="$(cygpath -m "$S")" FASE=$F timeout 300 "$GODOT" --path . >/dev/null 2>&1
done
cat "$S/novo_jogo_fase1.txt" "$S/novo_jogo_fase2.txt" 2>/dev/null
[ -n "${1:-}" ] && cp "$S/98_confirmacao.png" "$1/" 2>/dev/null
ok=$(cat "$S"/novo_jogo_fase*.txt 2>/dev/null | grep -c "^OK"); tot=$(cat "$S"/novo_jogo_fase*.txt 2>/dev/null | grep -c "^OK\|^FALHA")
echo "RESULTADO: $ok/$tot"
[ "$ok" -eq "$tot" ] && [ "$tot" -eq 12 ]
