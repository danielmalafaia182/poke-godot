import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('extrator', Path(__file__).with_name('extrair_encontros_pareados.py'))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class Extracao(unittest.TestCase):
    def perfil(self, nome, hp, atk=10):
        return {'id': 'ID_PRIVADO_NAO_EXPORTAR', 'team': True, 'name': nome, 'level': 10,
                'quality': 1.0, 'stats': {'hp': 10, 'atk': atk, 'def': 10, 'spAtk': 10, 'spDef': 10, 'speed': 10},
                'power': 60, 'maxHp': hp, 'ivTotal': 96}

    def field(self, seq, hp, nome='A', max_aliado=40, dano=None):
        return {'type': 'field', 'serverNow': 1000+seq*200, 'seq': seq,
                'heroName': nome, 'heroMaxHp': max_aliado,
                'mobs': [{'slot': 0, 'hp': hp, 'maxHp': 100, 'speciesId': 9}],
                'hits': [] if dano is None else [{'slot': 0, 'amount': dano, 'move': 'Tackle', 'type': 'NORMAL', 'eff': 1.0}]}

    def executar_fixture(self, mensagens):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)/'ws.txt'
            p.write_text('\n'.join(json.dumps({'direcao': 'recebido', 'dados': json.dumps(m)}) for m in mensagens))
            return mod.extrair(p)

    def test_respawn_mesmo_hp_nao_mistura_vidas(self):
        ms = [{'type': 'pokes', 'list': [self.perfil('A', 40), self.perfil('B', 80)]},
              self.field(1, 100), self.field(2, 90, dano=10),
              self.field(3, 80, 'B', 80, 10), self.field(4, 0, 'B', 80, 100),
              self.field(5, 100), self.field(6, 90, dano=10), self.field(7, 0, dano=100)]
        r = self.executar_fixture(ms)
        self.assertEqual(len(r['encontros']), 2)
        self.assertTrue(r['encontros'][0]['pareado'])
        self.assertFalse(r['encontros'][1]['pareado'])
        self.assertEqual(r['encontros'][0]['golpes'][-1]['hp_antes_pacote'], 80)
        self.assertNotIn('ID_PRIVADO_NAO_EXPORTAR', json.dumps(r))

    def test_cura_sem_morte_nao_e_perfil_constante(self):
        r = self.executar_fixture([{'type': 'pokes', 'list': [self.perfil('A', 40)]},
             self.field(1, 100), self.field(2, 90, dano=10), self.field(3, 95), self.field(4, 0, dano=100)])
        self.assertFalse(r['encontros'][0]['elegivel_ajuste'])

    def test_mesma_especie_e_hp_ambiguos_nao_inventa_perfil(self):
        r = self.executar_fixture([{'type': 'pokes', 'list': [self.perfil('A', 40), self.perfil('A', 40, 20)]},
             self.field(1, 100), self.field(2, 0, dano=100)])
        self.assertIsNone(r['encontros'][0]['golpes'][0]['perfil_id'])
        self.assertFalse(r['encontros'][0]['elegivel_ajuste'])

    def test_evento_tardio_nao_silenciado_nem_usado_como_duelo_valido(self):
        r = self.executar_fixture([{'type': 'pokes', 'list': [self.perfil('A', 40)]},
             self.field(1, 100), self.field(2, 0, dano=100), self.field(3, 0, dano=100)])
        self.assertEqual(len(r['encontros'][0]['golpes']), 2)
        self.assertFalse(r['encontros'][0]['elegivel_ajuste'])


if __name__ == '__main__':
    unittest.main()
