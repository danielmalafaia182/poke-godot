#!/usr/bin/env bash
# Gera a referência de interpolação com o código original (Node, fields reais da rhydon-1h) e confere o porte.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
mkdir -p saida_testes
node ferramentas/render/referencia_interpolacao.js poke-local/public/_next/static/chunks/0gx72gz9qjk5j.js \
  "poke har/gravacoes/rhydon-1h.jsonl" "${FIELDS:-1500}" saida_testes/ref_interp.json
TEMPO_MAX=600 testes/rodar.sh res://testes/test_render_interpolacao.gd
