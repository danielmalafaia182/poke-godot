"""Recua o horário do save (salvo_em_unix) em N segundos, refazendo o sha256 do envelope (testes de reabrir).
Uso: python -I testes/recuar_save.py <progresso_v1.json> <segundos>
"""
import hashlib
import json
import sys

p, seg = sys.argv[1], int(sys.argv[2])
env = json.load(open(p, encoding="utf-8"))
dados = json.loads(env["conteudo"])
alvo = dados.get("dados", dados)
alvo["salvo_em_unix"] = int(alvo.get("salvo_em_unix", 0)) - seg
son = alvo.get("soneca") or {}
for k in ("inicio", "fim"):
    if k in son:
        son[k] = int(son[k]) - seg
print("hunt_ao_fechar=%s salvo_em_unix=%s" % (alvo.get("hunt_ao_fechar"), alvo["salvo_em_unix"]))
env["conteudo"] = json.dumps(dados, ensure_ascii=False, separators=(",", ":"))
env["sha256"] = hashlib.sha256(env["conteudo"].encode("utf-8")).hexdigest()
json.dump(env, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
