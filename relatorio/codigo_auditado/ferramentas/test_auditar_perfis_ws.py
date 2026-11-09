import json
import tempfile
import unittest
from pathlib import Path
from auditar_perfis_ws import auditar


class Auditoria(unittest.TestCase):
    def executar(self, mensagens):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'log.txt'
            p.write_text('\n'.join(json.dumps({'direcao': 'recebido', 'dados': json.dumps(d)}) for d in mensagens))
            return auditar(p)

    def field(self, hp, maximo=120, seq=1):
        return {'type': 'field', 'seq': seq, 'mobs': [{'slot': 0, 'hp': hp, 'maxHp': maximo}]}

    def test_retorno_e_perfil_sao_contagens_distintas(self):
        r = self.executar([self.field(120), self.field(0), self.field(120), self.field(0), self.field(120)])
        self.assertEqual(r['total_retornos'], 2)
        self.assertEqual(len(r['perfis_por_instancia_slot_observados']), 1)

    def test_nova_instancia_nao_e_respawn(self):
        r = self.executar([{'type': 'field-init', 'huntKey': 'a'}, self.field(0),
                           {'type': 'field-init', 'huntKey': 'b'}, self.field(120)])
        self.assertEqual(r['total_retornos'], 0)
        self.assertEqual(len(r['perfis_por_instancia_slot_observados']), 2)

    def test_maximo_alterado_fica_explicito(self):
        r = self.executar([self.field(0), self.field(140, 140)])
        self.assertEqual(r['retornos_maximo_preservado'], 0)
        self.assertEqual(r['perfis_por_instancia_slot_observados'][0]['maximos_vistos'], [120, 140])


if __name__ == '__main__':
    unittest.main()
