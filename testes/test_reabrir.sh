#!/usr/bin/env bash
# Reabrir depois de 3 h fechado numa hunt sem soneca (ciclo 5, item 99): APPDATA isolado; fase 1 caça e fecha, o save é
# recuado 3 h (testes/recuar_save.py), fase 2 abre a cidade. Confere: contaram 15 min, a mensagem diz quanto se perdeu
# e por quê, e houve abates e XP. Uso: testes/test_reabrir.sh
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
GODOT="${GODOT:-/c/Users/dmala/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
ISO="$(mktemp -d)"; S="$(mktemp -d)"; V="$(cygpath -m testes/test_reabrir.gd)"
APPDATA="$(cygpath -w "$ISO")" POKE_VERIFICAR="$V" SAIDA="$(cygpath -m "$S")" FASE=1 timeout 300 "$GODOT" --path . >/dev/null 2>&1
SAVE=$(find "$ISO" -name progresso_v1.json | head -1)
python -I testes/recuar_save.py "$SAVE" 10800 >/dev/null
APPDATA="$(cygpath -w "$ISO")" POKE_VERIFICAR="$V" SAIDA="$(cygpath -m "$S")" FASE=2 timeout 300 "$GODOT" --path . >/dev/null 2>&1
M="$(cat "$S/reabrir_fase2.txt" 2>/dev/null)"
echo "$M"
ok=0; tot=0
chk() { tot=$((tot+1)); if echo "$M" | grep -qE "$1"; then ok=$((ok+1)); echo "OK    $2"; else echo "FALHA $2"; fi; }
chk "Fechado há 3 h" "diz quanto tempo ficou fechado"
chk "Contaram 15 min de caça" "contaram os 15 min da sessão"
chk "não renderam" "diz quanto se perdeu e por quê (Modo Soneca)"
chk "Resultado: [1-9][0-9]* abates, \\+[1-9][0-9]* XP" "a caça recuperada rendeu abates e XP"
echo "RESULTADO: $ok/$tot"
[ "$ok" -eq "$tot" ]
