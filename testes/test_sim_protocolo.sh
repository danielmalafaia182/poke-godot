#!/usr/bin/env bash
# Passo 3 da fase 1: 1 h simulada → JSONL no formato do gravador → validação contra dados/protocolo.json
# (gerado com todas as gravações reais; a gravação real de controle também precisa passar) → o analisador lê a saída.
# Uso: testes/test_sim_protocolo.sh   (saída em saida_testes/, ignorada pelo git)
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
REF="poke har/gravacoes/gravacoes_unicas_2026-11-09.jsonl"
SAIDA="saida_testes/sim_rhydon_1h_s1.jsonl"
TEMPO_MAX=180 testes/rodar.sh res://testes/rodar_sim.gd --segundos 3600 --semente 1 --saida "$SAIDA" 2>&1 | grep -E 'simulados|estat|SCRIPT ERROR' || true
test -s "$SAIDA"
python -I - "$SAIDA" <<'EOF'
import json, sys
n = 0
for linha in open(sys.argv[1], encoding="utf-8"):
    o = json.loads(linha)
    assert list(o) == ["sessao", "t", "dir", "msg"], list(o)
    assert o["dir"] == "in" and isinstance(o["t"], int) and "type" in o["msg"]
    n += 1
print(f"OK    formato do gravador em {n} linhas")
EOF
echo "controle (gravação real):"; python -I ferramentas/protocolo/validar_jsonl.py "$REF" | tail -1
python -I ferramentas/protocolo/validar_jsonl.py "$SAIDA"
python -I ferramentas/gravador/analisar_gravacao.py "$SAIDA" > /dev/null && echo "OK    analisar_gravacao.py leu a saída"
