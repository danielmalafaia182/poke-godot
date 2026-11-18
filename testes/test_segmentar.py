#!/usr/bin/env python3
"""Gravação livre (18/11): segmentador e processador com exportações sobrepostas, buraco de aba e zoom (sem Godot).

Monta, numa pasta temporária, uma "gravação livre" a partir de gravações reais (T1: cidade e três hunts; G11: troca de
time no meio):
  - duas exportações que se sobrepõem (a 2ª repete as últimas 500 linhas da 1ª) → as linhas repetidas contam uma vez;
  - um buraco de 40 s nos fields de uma hunt (aba em segundo plano) → corte "buraco";
  - um comando view com outro {hc, hr} no meio de uma hunt → corte "zoom".
Confere os cortes, a cidade, a penalidade, os usos e que o processador gera o relatório com a tabela de trechos.
Uso: python -I testes/test_segmentar.py
"""
import json
import os
import subprocess
import sys
import tempfile

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas", "gravador"))
sys.path.insert(0, os.path.join(RAIZ, "ferramentas"))
import segmentar as SG  # noqa: E402

falhas = 0
total = 0


def checar(ok, nome, det=""):
    global falhas, total
    total += 1
    falhas += 0 if ok else 1
    print(("OK    " if ok else "FALHA ") + nome + (f"  ({det})" if det else ""))


def ler(c):
    return [l for l in open(c, encoding="utf-8") if l.strip()]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    t1 = ler(os.path.join(RAIZ, "poke har", "gravacoes", "fase3", "t1_transacoes.jsonl"))
    g11 = ler(os.path.join(RAIZ, "poke har", "gravacoes", "fase 4", "G11.jsonl"))
    # buraco de 40 s e zoom: na G11, depois do 300º field
    novo = []
    nf = 0
    pulo = 0
    for l in g11:
        o = json.loads(l)
        m = o["msg"]
        if m.get("type") == "field":
            nf += 1
            if nf == 300:
                novo.append(json.dumps({"sessao": o["sessao"], "t": o["t"], "dir": "out", "msg": {"type": "view", "hc": 15, "hr": 9}}) + "\n")
            if 400 <= nf < 500:
                continue                 # 100 fields fora (≈ 40 s sem field)
        novo.append(l)
    tmp = tempfile.mkdtemp(prefix="livre_teste_")
    a = os.path.join(tmp, "dia1.jsonl")
    b = os.path.join(tmp, "dia2.jsonl")
    open(a, "w", encoding="utf-8").writelines(t1)
    open(b, "w", encoding="utf-8").writelines(t1[-500:] + novo)
    tr = SG.segmentar([tmp])
    hunts = [x for x in tr if x["tipo"] == "hunt"]
    cid = [x for x in tr if x["tipo"] == "cidade"]
    mot = [x["motivo_inicio"] for x in hunts]
    checar(len({x["huntKey"] for x in hunts}) == 5, "5 instâncias de hunt (4 da T1 + 1 da G11), sem repetir a sobreposição", str(len({x["huntKey"] for x in hunts})))
    checar(mot.count("buraco") == 1 and mot.count("zoom") == 1 and mot.count("troca de time") == 1, "cortes: 1 buraco, 1 zoom, 1 troca de time", str(mot))
    bur = [x for x in hunts if x["motivo_inicio"] == "buraco"][0]
    checar(bur["slug"] == "rattata" and bur["fields"] > 50, "o buraco corta a hunt da G11 e o resto continua num pedaço novo", f"{bur['fields']} fields")
    z = [x for x in hunts if x["motivo_inicio"] == "zoom"][0]
    checar(z["view"] == [15, 9], "o pedaço depois do zoom tem o view novo", str(z["view"]))
    checar(len(cid) >= 2, "trechos de cidade entre as hunts", str(len(cid)))
    pen = [x for x in hunts if "penalidade" in x["uteis"]]
    checar(len(pen) == 4, "entradas novas com lock úteis para a penalidade (3 da T1 + a da G11)", str(len(pen)))
    tro = [x for x in hunts if x["motivo_inicio"] == "troca de time"][0]
    checar(tro["lider"][0] == "Larvitar" and tro["niveis_lider"] == [1], "troca de time: o pedaço novo tem o Larvitar e o nível dele", f"{tro['lider']} {tro['niveis_lider']}")
    checar(sum(x["abates"] for x in hunts) == 84 + 35, "abates sem duplicar: 84 da T1 + 35 da G11", str(sum(x['abates'] for x in hunts)))
    # processador na pasta
    saida = tempfile.mkdtemp(prefix="rel_")
    r = subprocess.run([sys.executable, "-I", os.path.join(RAIZ, "ferramentas", "processar_gravacao.py"), tmp, "--nome", "livre_teste",
                        "--saida", saida, "--sem-dano"], capture_output=True, text=True, encoding="utf-8")
    md = open(os.path.join(saida, "gravacao_livre_teste.md"), encoding="utf-8").read() if r.returncode == 0 else ""
    checar(r.returncode == 0 and "## Trechos" in md and "| buraco |" in md and "| zoom |" in md, "processador: relatório da pasta com a tabela de trechos",
           (r.stderr or "")[-200:])
    checar("Penalidade = lock de 60 s" in md, "processador: penalidade conferida por entrada na gravação juntada")
    print(f"RESULTADO: {total - falhas}/{total}")
    sys.exit(1 if falhas else 0)


if __name__ == "__main__":
    main()
