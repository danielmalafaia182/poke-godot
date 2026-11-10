#!/usr/bin/env python3
"""Fase 3, S3 (Gyarados 214 × Rhyhorn 30, conta B): o golpe escolhido por indivíduo é coerente com "maior dano esperado"
com os stats do indivíduo? Para cada slot: pares (IV_hp, Q) que dão o maxHp (A); SpD (Hydro Pump) ou Def (Aqua Tail)
sem arredondar que explicam todos os hits (fórmula F, piso e aleatório 0,85–1,00); para cada um, o outro stat sobre
IV 1..32 com o mesmo Q, e a escolha que a regra faria (110·SpA/SpD × 90·Atk/Def; os dois golpes Água, STAB, eff 5,5).
Stats do Gyarados = os do pokes-chunk do S1/S2 (mesma sessão, A): Atk 647, SpA 370.
"coerentes" > 0 → existe indivíduo compatível com a regra; "contrarias" > 0 → a escolha restringiu o indivíduo.
Uso: python -I ferramentas/fase3/s3_individuos.py
"""
import os
import json, sys, collections
RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
sys.path.insert(0, os.path.join(RAIZ, 'ferramentas', 'gravador'))
import relatorio_individuos as R
L = 30
LA = 214; SPA = 370; ATK = 647
POD = {'Hydro Pump': 110, 'Aqua Tail': 90}
K = {'Hydro Pump': (2 * LA / 5 + 2) * 110 * SPA / 50 * 1.5 * 5.5, 'Aqua Tail': (2 * LA / 5 + 2) * 90 * ATK / 50 * 1.5 * 5.5}
hits = collections.defaultdict(list); mx = {}
for l in open(os.path.join(RAIZ, 'poke har', 'gravacoes', 'fase3', 'S3.jsonl'), encoding='utf-8'):
    m = json.loads(l)['msg']
    if m.get('type') != 'field':
        continue
    for mb in m['mobs']:
        mx[mb['slot']] = mb['maxHp']
    for h in m.get('hits', []):
        hits[h['slot']].append((h['move'], h['amount']))


def cont(b, iv, q, e):
    return L / 100 * (b + 2 * iv) * q ** e


n_coer = n_restr = 0
for s in sorted(hits):
    mv = hits[s][0][0]
    assert all(x[0] == mv for x in hits[s])
    qs = sorted({q for iv, q, w in R.pares_hp(80, L, mx[s])})
    ok = contra = ndmg = 0
    for q in qs:
        D = [cont(95, i, q, 0.8) for i in range(1, 33)]
        S = [cont(30, i, q, 0.8) for i in range(1, 33)]
        obs = S if mv == 'Hydro Pump' else D
        ok_obs = [v for v in obs if all(K[mv] * 0.85 / v - 0.5 <= a <= K[mv] / v + 0.5 for _, a in hits[s])]
        outro = D if mv == 'Hydro Pump' else S
        for v in ok_obs:
            for w in outro:
                ndmg += 1
                sd, df = (v, w) if mv == 'Hydro Pump' else (w, v)
                esc = 'Hydro Pump' if 110 * SPA / sd > 90 * ATK / df else 'Aqua Tail'
                if esc == mv:
                    ok += 1
                else:
                    contra += 1
    print(s, mv, mx[s], 'nhits', len(hits[s]), 'Q', (qs[0], qs[-1]) if qs else None, 'combos', ndmg, 'coerentes', ok, 'contrarias', contra)
    n_coer += ok > 0
    n_restr += contra > 0
sys.stdout.reconfigure(encoding="utf-8")
print("slots com combinação coerente", n_coer, "de", len(hits), "; slots onde havia combinação contrária", n_restr)
