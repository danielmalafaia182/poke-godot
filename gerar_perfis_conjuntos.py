"""Procura exemplos conjuntos; não revela IVs e não modifica o projeto Godot.
Uso: python gerar_perfis_conjuntos.py
Reproduz hipóteses fixas desta análise: níveis94–99, HPx35, STAB1,5, variação85–100%.
"""
import json
import math
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CAT = json.loads((ROOT / 'entradas/catalogo.json').read_text())
EFET = json.loads((ROOT / 'entradas/efetividade.json').read_text())
FONTES = json.loads((ROOT / 'entradas/fontes.json').read_text())
PERFIS = {pid: p for f in FONTES for pid, p in f['perfis'].items()}
QUALIDADES = [i / 1000 for i in [*range(800, 1600), *range(1700, 1800), 1800]]
NIVEIS = range(94, 100)
BASE = CAT['Blastoise']


def arredondar(n):
    return math.floor(n + 0.5)


def stat(nivel, base, iv, q, expoente):
    return arredondar(nivel / 100 * (base + 2 * iv) * q ** expoente)


def golpe(p, nome):
    return next(g for g in CAT[p['especie']]['attacks'] if g['name'] == nome)


def bruto(p, g, df, sdf, eff):
    fisico = g['category'] == 'PHYSICAL'
    atk = p['atributos']['atk' if fisico else 'spAtk']
    defesa = df if fisico else sdf
    stab = 1.5 if g['type'] in p['tipos'] else 1.0
    return (((2 * p['nivel'] / 5 + 2) * g['power'] * atk / defesa) / 50 + 2) * eff * stab


@lru_cache(None)
def melhor(pid, df, sdf):
    p = PERFIS[pid]
    melhor_nome, maior = '', 0
    for g in sorted(CAT[p['especie']]['attacks'], key=lambda g: (g['learnLevel'], g['name'])):
        if g.get('tm') or g['category'] not in ['PHYSICAL', 'SPECIAL'] or g['learnLevel'] > p['nivel']:
            continue
        eff = EFET.get(g['type'], {}).get(BASE['type1'], 1)
        segundo = BASE.get('type2')
        if segundo and segundo != BASE['type1']:
            eff *= EFET.get(g['type'], {}).get(segundo, 1)
        eff = 1 + (eff - 1) * 1.5 if eff > 1 else eff / 1.5 if eff < 1 else eff
        dano = max(2, arredondar(bruto(p, g, df, sdf, eff))) if eff > 0 else 0
        if dano > maior:
            melhor_nome, maior = g['name'], dano
    return melhor_nome


def casos_com_restricoes():
    casos = []
    # Teto500 excede os atributos defensivos possíveis nos níveis pesquisados.
    for f in FONTES:
        for e in f['encontros']:
            assert e['elegivel_ajuste'], 'Encontro com alerta não deve entrar no ajuste.'
            validas = {'def': set(range(1, 501)), 'spDef': set(range(1, 501))}
            for h in e['golpes']:
                p = f['perfis'][h['perfil_id']]
                g = golpe(p, h['golpe'])
                eixo = 'def' if g['category'] == 'PHYSICAL' else 'spDef'
                validas[eixo] = {d for d in validas[eixo]
                                if arredondar(bruto(p, g, d, d, h['efetividade']) * 0.85)
                                <= h['dano'] <= arredondar(bruto(p, g, d, d, h['efetividade']))}
            casos.append((f['fonte']['arquivo'], e, validas))
    return casos


def procurar(nivel, e, validas):
    preferidos = {(h['perfil_id'], h['golpe']) for h in e['golpes']}
    for q in QUALIDADES:
        hp = [iv for iv in range(1, 33)
              if max(120, stat(nivel, BASE['baseHp'], iv, q, 0.95) * 35) == e['hp_maximo']]
        if not hp:
            continue
        defs = [(iv, stat(nivel, BASE['baseDef'], iv, q, 0.8)) for iv in range(1, 33)]
        sdefs = [(iv, stat(nivel, BASE['baseSpDef'], iv, q, 0.8)) for iv in range(1, 33)]
        for ivd, df in defs:
            if df not in validas['def']:
                continue
            for ivs, sdf in sdefs:
                if sdf in validas['spDef'] and all(melhor(pid, df, sdf) == nome for pid, nome in preferidos):
                    return {'nivel': nivel, 'qualidade': q, 'iv_hp': hp[0],
                            'iv_def': ivd, 'iv_sp_def': ivs, 'ivs_livres': ['atk', 'spAtk', 'speed']}
    return None


def main():
    resultados = {}
    casos = casos_com_restricoes()
    for nivel in NIVEIS:
        linhas = []
        for fonte, e, validas in casos:
            exemplo = procurar(nivel, e, validas)
            linhas.append({'fonte': fonte, 'encontro': e['id_local'],
                           'compativel': exemplo is not None, 'exemplo': exemplo})
        resultados[str(nivel)] = linhas
        print(nivel, sum(r['compativel'] for r in linhas), '/', len(linhas))
    saida = {'schema': 1, 'fidelidade_comprovada': False,
             'fontes': [f['fonte'] for f in FONTES], 'resultados_por_nivel': resultados,
             'limites': ['Exemplos condicionais, não IVs revelados.',
                        'Atk, SpAtk e Speed do selvagem continuam livres.',
                        'Golpes recebidos não têm atacante identificado e não entram neste ajuste por indivíduo.',
                        'Ajuste aos dados conhecidos; não é validação com nova amostra.']}
    (ROOT / 'resultados/perfis_conjuntos.json').write_text(json.dumps(saida, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
