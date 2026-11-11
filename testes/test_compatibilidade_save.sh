#!/usr/bin/env bash
# Compatibilidade com o save anterior (teste do P04): grava a fixture validacao_qualidade/save_anterior_fixture.json no
# user:// ISOLADO (preparar_save.gd) e roda o teste no MESMO diretório, para o autoload carregar o save antigo ao iniciar
# (o runner antigo validacao_qualidade/executar.py fazia assim). O save real nunca é tocado.
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
export ISOLADO="$(mktemp -d "${TMPDIR:-/tmp}/poke_compat_XXXXXX")"
TEMPO_MAX="${TEMPO_MAX:-120}" testes/rodar.sh res://validacao_qualidade/preparar_save.gd > /dev/null 2>&1
TEMPO_MAX="${TEMPO_MAX:-120}" testes/rodar.sh res://test_compatibilidade_save.gd
