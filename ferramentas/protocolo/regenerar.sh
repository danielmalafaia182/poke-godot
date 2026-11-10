#!/usr/bin/env bash
# Regenera dados/protocolo.json a partir do cliente original e de TODAS as gravações reais que existem hoje.
# Cliente: os 5 chunks do jogo (os outros 24 só acrescentam literais de bibliotecas/DOM: destroy, paint, params…).
# Logs: gravador novo em poke har/gravacoes/ (e fase3/) e na raiz (deduplicados por sessão+instante+conteúdo, porque os exports
# se sobrepõem) + os 3 logs crus antigos da raiz. Uso: ferramentas/protocolo/regenerar.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$RAIZ"
CH=poke-local/public/_next/static/chunks
python -I ferramentas/protocolo/gerar_protocolo.py \
  --cliente $CH/0gx72gz9qjk5j.js $CH/26sc7h-33qbis.js $CH/2nsq1ek51g625.js $CH/329j824l1odqw.js $CH/3vooh2axx98am.js \
  --logs "poke har/gravacoes/*.jsonl" "poke har/gravacoes/fase3/*.jsonl" "*.jsonl" loogs.txt "logs rhyhorn.txt" "logs hitmonlee.txt" \
  --saida dados/protocolo.json
