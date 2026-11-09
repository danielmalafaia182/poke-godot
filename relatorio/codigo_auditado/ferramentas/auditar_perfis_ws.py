"""Audita HP por slot/instância sem importar chat ou identificadores de conta.
Uso: python ferramentas/auditar_perfis_ws.py LOG.txt RESULTADO.json
"""
import argparse
import hashlib
import json
from pathlib import Path


def auditar(path):
    path = Path(path)
    bruto = path.read_bytes()
    instancias = {}
    anterior = {}
    retornos = []
    instancia = 0
    chave_hunt = None
    invalidas = 0
    fields = 0
    for linha in bruto.decode('utf-8-sig').splitlines():
        if not linha.strip():
            continue
        try:
            e = json.loads(linha)
            if e.get('direcao') != 'recebido':
                continue
            d = e.get('dados', {})
            d = json.loads(d) if isinstance(d, str) else d
            if not isinstance(d, dict):
                continue
            if d.get('type') == 'field-init':
                nova = d.get('huntKey')
                if nova is None or nova != chave_hunt:
                    instancia += 1
                    anterior = {}
                    chave_hunt = nova
                continue
            if d.get('type') != 'field':
                continue
            fields += 1
            for m in d.get('mobs', []):
                slot = int(m['slot'])
                key = f'{instancia}:{slot}'
                registro = instancias.setdefault(key, {'instancia_local': instancia, 'slot': slot,
                                                       'primeiro_maximo': m['maxHp'], 'maximos_vistos': []})
                if m['maxHp'] not in registro['maximos_vistos']:
                    registro['maximos_vistos'].append(m['maxHp'])
                prev = anterior.get(slot)
                if prev and prev['hp'] == 0 and m['hp'] > 0:
                    retornos.append({'instancia_local': instancia, 'slot': slot, 'seq': d['seq'],
                                     'hp_maximo_antes': prev['maxHp'], 'hp_maximo_depois': m['maxHp'],
                                     'maximo_preservado': prev['maxHp'] == m['maxHp']})
                anterior[slot] = {'hp': m['hp'], 'maxHp': m['maxHp']}
        except (ValueError, TypeError, KeyError, AttributeError):
            invalidas += 1
    return {'schema': 1, 'fonte': {'arquivo': path.name, 'sha256': hashlib.sha256(bruto).hexdigest()},
            'fields': fields, 'linhas_invalidas': invalidas,
            'perfis_por_instancia_slot_observados': list(instancias.values()),
            'retornos_zero_para_vivo': retornos,
            'total_retornos': len(retornos), 'retornos_maximo_preservado': sum(r['maximo_preservado'] for r in retornos),
            'fidelidade_comprovada': False,
            'limites': ['Retorno0→vivo é transição observada, não UUID de respawn do servidor.',
                       'HP igual não comprova IV/qualidade ou outros atributos iguais.',
                       'Não conta cada vida como perfil populacional independente.',
                       'O WS não informa o perfil capturável correspondente ao perfil de combate.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('log')
    p.add_argument('saida')
    args = p.parse_args()
    r = auditar(args.log)
    Path(args.saida).write_text(json.dumps(r, ensure_ascii=False, indent=2) + '\n')
    print(f"{r['retornos_maximo_preservado']}/{r['total_retornos']} retornos com HP máximo preservado")


if __name__ == '__main__':
    main()
