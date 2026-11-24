#!/usr/bin/env bash
# Entrada compatível para Git Bash; implementação e critérios em montar_build.py.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
exec python "$RAIZ/ferramentas/build/montar_build.py" "$@"
