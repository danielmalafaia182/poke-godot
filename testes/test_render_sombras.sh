#!/usr/bin/env bash
# Gera a referência das sombras com o código original do cliente (Node) e confere o porte (render/sombras.gd).
# Uso: testes/test_render_sombras.sh [slug ...]   (padrão: rhydon)
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
SLUGS=("${@:-rhydon}")
mkdir -p saida_testes
for s in "${SLUGS[@]}"; do
  node ferramentas/render/referencia_sombras.js poke-local/public/_next/static/chunks/0gx72gz9qjk5j.js \
    "poke har/extraido/snapshot_2026-11-09/game" "$s" "saida_testes/ref_sombras_$s.json"
done
TEMPO_MAX=600 testes/rodar.sh res://testes/test_render_sombras.gd "${SLUGS[@]}"
