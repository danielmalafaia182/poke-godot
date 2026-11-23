#!/usr/bin/env bash
# Monta o jogo para Windows em builds/<nome>/ (padrão ciclo3) e verifica (ciclo 3):
#   PokeIdle.exe + PokeIdle.pck   export-release com o template oficial do Godot 4.7.2 (ícone e nome do preset)
#   jogo/                         pacote de execução (ferramentas/build/gerar_pacote_jogo.gd): mapas .json.zst, atlas,
#                                 outfits, cadáveres, hunt-config, ícones — sem o snapshot bruto
#   dados/                        só o que o jogo lê do disco: gerados/, pacotes/, balanceamento.json, corpos_por_especie.json
# Nada de gravações, ferramentas, testes ou relatórios. O save do jogo exportado fica em %APPDATA%/PokeIdle
# (use_custom_user_dir só no template); a pasta do projeto continua só para desenvolvimento.
# Verificação com APPDATA isolado (o save real nunca é tocado): o exe de release carrega ferramentas/build/verificar_build.gd
# por POKE_VERIFICAR (o template não roda --script) em 3 execuções
# (jogo novo → tutorial → caça → salva; reabre e continua; importação de um save "do projeto").
# Uso: ferramentas/build/montar_build.sh [nome]
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
NOME="${1:-ciclo4}"
GODOT="${GODOT:-/c/Users/dmala/Desktop/Godot/Godot_v4.7.2-stable_win64_console.exe}"
B="$RAIZ/builds/$NOME"
rm -rf "$B"
mkdir -p "$B/dados"
"$GODOT" --headless --path "$RAIZ" --export-release "Windows Desktop" "$(cygpath -m "$B/PokeIdle.exe")" > "$B.export.log" 2>&1 || { tail -20 "$B.export.log"; exit 1; }
"$GODOT" --headless --path "$RAIZ" --script res://ferramentas/build/gerar_pacote_jogo.gd -- "$(cygpath -m "$B/jogo")" 2>&1 | grep PACOTE
cp -r "$RAIZ/dados/gerados" "$RAIZ/dados/pacotes" "$B/dados/"
cp "$RAIZ/dados/corpos_por_especie.json" "$B/dados/"   # as regras (dados/regras/*.tres) vão no pck; user://regras/ sobrescreve
echo "tamanho: $(du -sh "$B" | cut -f1)  ($(du -sh "$B"/* | tr '\n' ' '))"
ISO="$(mktemp -d)"; SHOTS="$(mktemp -d)"
V="$(cygpath -m "$RAIZ/ferramentas/build/verificar_build.gd")"
cd "$B"
for fase in 1 2; do
  APPDATA="$(cygpath -w "$ISO")" POKE_VERIFICAR="$V" VERIF_SAIDA="$(cygpath -m "$SHOTS")" VERIF_FASE=$fase timeout 600 ./PokeIdle.exe > /dev/null 2>&1 || true
  cat "$SHOTS/resultado_fase$fase.txt" 2>/dev/null || echo "FALHA [fase $fase] sem resultado (o jogo não terminou)"
done
ISO3="$(mktemp -d)"; mkdir -p "$ISO3/Godot/app_userdata/PokeIdle"
cp "$ISO/PokeIdle/progresso_v1.json" "$ISO3/Godot/app_userdata/PokeIdle/"
APPDATA="$(cygpath -w "$ISO3")" POKE_VERIFICAR="$V" VERIF_SAIDA="$(cygpath -m "$SHOTS")" VERIF_FASE=3 timeout 600 ./PokeIdle.exe > /dev/null 2>&1 || true
cat "$SHOTS/resultado_fase3.txt" 2>/dev/null || echo "FALHA [fase 3] sem resultado"
echo "capturas em $SHOTS; saves em $ISO"
