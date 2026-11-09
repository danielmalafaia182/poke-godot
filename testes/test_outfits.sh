#!/usr/bin/env bash
# Paleta original (Node) + teste dos outfits e lista dos que faltam no snapshot.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
mkdir -p saida_testes
node ferramentas/render/referencia_cores.js poke-local/public/_next/static/chunks/0wl3dp5-44hi8.js saida_testes/ref_cores.json
TEMPO_MAX=900 testes/rodar.sh res://testes/test_outfits.gd
