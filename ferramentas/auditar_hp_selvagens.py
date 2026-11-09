"""Auditoria reproduzível do suporte de HP; não modifica Godot nem infere IV real.
Uso: python ferramentas/auditar_hp_selvagens.py [saida.json]
"""
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]


def qualidades_locais():
    # Mesmos valores alcançáveis por DadosPokemon.sortear_qualidade(), sem pesos.
    return [n / 1000 for n in [*range(800, 1600), *range(1700, 1800), 1800]]


def suporte(base_hp, nivel, fator):
    resultados = {}
    for q in qualidades_locais():
        for iv in range(1, 33):
            atributo = math.floor(nivel / 100 * (base_hp + 2 * iv) * q ** 0.95 + 0.5)
            # Ambas as regras respeitam120HP mínimos; caso atual = max(24,12*hp)*5.
            hp = max(120, atributo * fator)
            resultados.setdefault(hp, {'iv_hp_exemplo': iv, 'qualidade_exemplo': q,
                                       'atributo_hp_exemplo': atributo,
                                       'exemplo_nao_identifica_pokemon_original': True})
    return resultados


def auditar(dados):
    resultados = []
    for fator, nome in [(60, 'atual_hp_aliado_x5'), (35, 'candidata_atributo_hp_x35')]:
        s = suporte(dados['base_hp'], dados['nivel_local'], fator)
        casos = [dict(c, compativel=c['hp_maximo'] in s,
                      exemplo=s.get(c['hp_maximo'])) for c in dados['casos']]
        resultados.append({'modelo': nome, 'fator': fator,
                           'compativeis': sum(c['compativel'] for c in casos),
                           'total': len(casos), 'hp_minimo_possivel': min(s),
                           'hp_maximo_possivel': max(s), 'casos': casos})
    return {'schema': 1, 'especie': dados['especie'], 'nivel_local': dados['nivel_local'],
            'resultados': resultados, 'fidelidade_comprovada': False,
            'limites': dados['limites'] + ['Não valida dano recebido, Defesa, SpDef ou correlação entre atributos.',
                                         '24 encontros são duas sessões de Blastoise, não todas as hunts.']}


def main():
    dados = json.loads((ROOT / 'dados/combate/hp_selvagens_observados.json').read_text())
    r = auditar(dados)
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(json.dumps(r, ensure_ascii=False, indent=2) + '\n')
    for modelo in r['resultados']:
        print(f"{modelo['modelo']}: {modelo['compativeis']}/{modelo['total']} compatíveis")


if __name__ == '__main__':
    main()
