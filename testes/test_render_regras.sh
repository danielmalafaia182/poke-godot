#!/usr/bin/env bash
# Gera a referência de desenho com o código original do cliente (Node) e confere o porte GDScript contra ela.
# Uso: testes/test_render_regras.sh [slug ...]   (padrão: rhydon)
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
SLUGS=("${@:-rhydon}")
mkdir -p saida_testes
for s in "${SLUGS[@]}"; do
  node ferramentas/render/referencia_desenho.js poke-local/public/_next/static/chunks/0gx72gz9qjk5j.js \
    "poke har/extraido/snapshot_2026-11-09/game" "$s" "saida_testes/ref_desenho_$s.json"
done
TEMPO_MAX=600 testes/rodar.sh res://testes/test_render_regras.gd "${SLUGS[@]}"
