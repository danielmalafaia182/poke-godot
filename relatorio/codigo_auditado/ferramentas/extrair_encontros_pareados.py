"""Extrai evidência de combate sem chat, nick, inventário ou IDs de conta.
Uso: python extrair_encontros_pareados.py LOG.txt SAIDA.json
IDs de encontros são locais, derivados de slot e morte/respawn observado; não são IDs do servidor.
"""
import argparse
import hashlib
import json
from pathlib import Path


def extrair(caminho):
    caminho = Path(caminho)
    bruto = caminho.read_bytes()
    mensagens = []
    erros = 0
    for numero, linha in enumerate(bruto.decode('utf-8-sig').splitlines(), 1):
        if not linha.strip():
            continue
        try:
            envelope = json.loads(linha)
            if envelope.get('direcao') != 'recebido':
                continue
            d = envelope.get('dados', {})
            d = json.loads(d) if isinstance(d, str) else d
            if isinstance(d, dict):
                mensagens.append((numero, d))
        except (ValueError, AttributeError, TypeError):
            erros += 1
    fields = [d for _, d in mensagens if d.get('type') == 'field']
    if not fields:
        raise ValueError('Sem mensagens field recebidas.')
    inicio = fields[0]['serverNow']
    perfis = {}
    por_nome = {}
    # Usa apenas atributos observados. Não infere IVs individuais.
    for _, d in mensagens:
        if d.get('type') != 'pokes':
            continue
        for p in d.get('list', []):
            if not p.get('team') or not isinstance(p.get('stats'), dict):
                continue
            perfil = {k: p[k] for k in ['name', 'level', 'quality', 'stats', 'power', 'maxHp', 'ivTotal']}
            perfil['tipos'] = [p[k] for k in ['type1', 'type2'] if p.get(k)]
            chave = hashlib.sha256(json.dumps(perfil, sort_keys=True).encode()).hexdigest()[:10]
            pid = f'{p["name"]}_L{p["level"]}_{chave}'
            perfis[pid] = {'id': pid, 'especie': p['name'], 'nivel': p['level'],
                           'qualidade': p['quality'], 'atributos': p['stats'],
                           'power': p['power'], 'hp_maximo': p['maxHp'], 'iv_total': p['ivTotal'], 'tipos': perfil['tipos'],
                           'origem': 'pokes.list observado; IVs individuais não revelados'}
            por_nome.setdefault(p['name'], set()).add(pid)
    def perfil_field(f):
        candidatos = [pid for pid in por_nome.get(f.get('heroName'), [])
                      if perfis[pid]['hp_maximo'] == f.get('heroMaxHp')]
        # Sem assumir que dois indivíduos da mesma espécie têm atributos iguais.
        return candidatos[0] if len(candidatos) == 1 else None
    ativos = {}
    geracoes = {}
    episodios = []
    recebidos = []
    trocas = []
    ultimo_heroi = None
    hits_sem_alvo = 0
    for f in fields:
        t = round((f['serverNow'] - inicio)/1000, 3)
        pid = perfil_field(f)
        if f.get('heroName') != ultimo_heroi:
            trocas.append({'t_s': t, 'aliado': f.get('heroName'), 'perfil_id': pid})
            ultimo_heroi = f.get('heroName')
        ofensivos = {}
        for h in f.get('hits', []):
            if h.get('slot', -1) >= 0:
                ofensivos.setdefault(h['slot'], []).append(h)
            else:
                recebidos.append({'t_s': t, 'perfil_id': pid, 'aliado': f.get('heroName'),
                                  'golpe': h.get('move'), 'dano': h.get('amount'),
                                  'efetividade': h.get('eff'), 'atacante_identificado': False,
                                  'pacote_de_transicao': trocas[-1]['t_s'] == t})
        for mob in f.get('mobs', []):
            slot = mob['slot']
            anterior = ativos.get(slot)
            if anterior is None or (anterior['_fechado'] and mob['hp'] > 0):
                geracoes[slot] = geracoes.get(slot, 0) + 1
                anterior = {'id_local': f'slot_{slot}_vida_{geracoes[slot]}', 'slot': slot,
                            'geracao_observada': geracoes[slot], 'species_id': mob['speciesId'],
                            'hp_maximo': mob['maxHp'], 'inicio_s': t, 'golpes': [], 'curva_hp': [],
                            'alertas': [], 'perfil_ids': [], '_fechado': False, '_hp_anterior': None}
                ativos[slot] = anterior
                episodios.append(anterior)
            e = anterior
            antes = e['_hp_anterior']
            depois = mob['hp']
            if mob['maxHp'] != e['hp_maximo']:
                e['alertas'].append('HP máximo mudou nesta vida observada.')
            if antes is not None and depois > antes and not e['_fechado']:
                e['alertas'].append('HP aumentou antes de um KO observado; não é duelo estável.')
            hs = ofensivos.pop(slot, [])
            if hs:
                if e['_fechado']:
                    e['alertas'].append('Golpe recebido em pacote posterior ao KO observado.')
                if pid is None:
                    e['alertas'].append('Perfil do aliado ambíguo ou ausente.')
                if antes is None:
                    e['alertas'].append('HP anterior ao primeiro golpe indisponível.')
                total = sum(h['amount'] for h in hs)
                if antes is not None and antes-depois != min(antes, total):
                    e['alertas'].append('Dano do pacote não fecha a redução de HP; possível evento ausente/agrupamento.')
                for h in hs:
                    e['golpes'].append({'t_s': t, 'seq_field': f['seq'], 'perfil_id': pid,
                                        'aliado': f.get('heroName'), 'golpe': h['move'],
                                        'tipo': h['type'], 'dano': h['amount'], 'efetividade': h['eff'],
                                        'hp_antes_pacote': antes, 'hp_depois_pacote': depois,
                                        'golpes_no_pacote': len(hs)})
                    if pid not in e['perfil_ids']:
                        e['perfil_ids'].append(pid)
            ponto = {'t_s': t, 'hp': depois, 'hp_maximo': mob['maxHp'], 'aliado': f.get('heroName')}
            if not e['curva_hp'] or any(e['curva_hp'][-1][k] != ponto[k] for k in ['hp', 'hp_maximo', 'aliado']):
                e['curva_hp'].append(ponto)
            e['_hp_anterior'] = depois
            if depois == 0:
                e['_fechado'] = True
                e.setdefault('fim_s', t)
        hits_sem_alvo += sum(len(hs) for hs in ofensivos.values())
    resultado = []
    for e in episodios:
        if not e['golpes']:
            continue
        e['encerrado_em_ko'] = e['_fechado']
        e['pareado'] = len([p for p in e['perfil_ids'] if p]) > 1
        e['alertas'] = sorted(set(e['alertas']))
        e['elegivel_ajuste'] = e['encerrado_em_ko'] and not e['alertas']
        for k in list(e):
            if k.startswith('_'):
                del e[k]
        resultado.append(e)
    cooldowns = [{k: d[k] for k in ['leftMs', 'totalMs']} for _, d in mensagens
                 if d.get('type') == 'poke-swap-cooldown']
    ids_usados = {h['perfil_id'] for e in resultado for h in e['golpes']}
    ids_usados.update(h['perfil_id'] for h in recebidos)
    return {'schema': 1, 'fonte': {'arquivo': caminho.name, 'sha256': hashlib.sha256(bruto).hexdigest()},
            'fields': len(fields), 'duracao_s': round((fields[-1]['serverNow']-inicio)/1000, 3),
            'linhas_invalidas': erros, 'golpes_sem_slot_no_snapshot': hits_sem_alvo,
            'perfis': {pid: p for pid, p in perfis.items() if pid in ids_usados},
            'encontros': resultado, 'recebidos_sem_atacante': recebidos,
            'trocas_observadas': trocas, 'cooldowns_troca': cooldowns,
            'fidelidade_global_comprovada': False,
            'limites': ['Identidade do selvagem inferida por slot e continuidade de HP/morte/respawn; não é UUID do servidor.',
                       'Tempos são dos pacotes field, não de cada execução individual.',
                       'Perfis associados por espécie e HP máximo únicos nos snapshots da sessão; não se inferem IVs individuais.',
                       'HP antes/depois pertence ao pacote; múltiplos golpes no mesmo pacote não têm snapshots intermediários.',
                       'Golpes recebidos têm slot=-1 e não são atribuídos a um selvagem específico.',
                       'Uma compatibilidade de modelo não identifica a fórmula real nem comprova aleatoriedade.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log')
    parser.add_argument('saida')
    args = parser.parse_args()
    resultado = extrair(args.log)
    destino = Path(args.saida)
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(resultado, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'{len(resultado["encontros"])} encontros; '
          f'{sum(e["pareado"] for e in resultado["encontros"])} pareados; {destino}')


if __name__ == '__main__':
    main()
