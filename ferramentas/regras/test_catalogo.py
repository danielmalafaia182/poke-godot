import copy
import unittest
from catalogo import origem_de, revisar_metadados, STATUS
from gerar_recursos import unidade


class MetadataTests(unittest.TestCase):
    def test_hypothesis_is_not_promoted_by_context(self):
        self.assertEqual(origem_de('C: tela de captura. Forma (F, ajustada a sequências A)', 'E'), 'F')
        self.assertEqual(origem_de('C: requisito; custo classe 3', 'C'), 'E')

    def test_source_is_not_automatic_proof(self):
        self.assertNotIn('comprovada', STATUS['A'])
        self.assertIn('Pokepedia', STATUS['B'])
        self.assertIn('localmente', STATUS['D'])

    def test_metadata_review_preserves_values(self):
        entry = dict(fonte='sim', chave='captura_c', descricao='C: tela', origem='C', status='antigo', literal='0.814')
        cat = dict(parametros=[entry], regras=[])
        before = copy.deepcopy(cat)
        revisar_metadados(cat)
        self.assertEqual(entry['literal'], before['parametros'][0]['literal'])
        self.assertEqual(entry['origem'], 'F')
        self.assertEqual(revisar_metadados(copy.deepcopy(cat)), cat)

    def test_units_respect_word_boundaries(self):
        self.assertEqual(unidade('shiny_chance'), 'fração 0–1')
        self.assertEqual(unidade('fator_selvagem'), 'multiplicador')
        self.assertEqual(unidade('duracao_s'), 'segundos')
        self.assertEqual(unidade('craft_s_unidade'), 'segundos')

    def test_context_does_not_promote_existing_decision(self):
        entry = dict(fonte='sim', chave='exemplo', descricao='A: limite parcialmente observado', origem='E', status='antigo', literal='10')
        revisar_metadados(dict(parametros=[entry], regras=[]))
        self.assertEqual(entry['origem'], 'E')


if __name__ == '__main__':
    unittest.main()
