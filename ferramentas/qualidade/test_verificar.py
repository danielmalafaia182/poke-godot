"""O portão de qualidade precisa falhar quando o teste imprime um falso sucesso."""
import unittest
from verificar import assess, isolated_env
from pathlib import Path
import tempfile


class QualityGateTests(unittest.TestCase):
    def test_script_error_even_with_successful_assertions(self):
        self.assertFalse(assess('SCRIPT ERROR: runtime error\nRESULTADO: 10/10', 0)['passed'])

    def test_failure_line_even_with_zero_exit(self):
        self.assertFalse(assess('FALHA save perdido\nRESULTADO: 9/10', 0)['passed'])

    def test_exit_code_and_completion_required(self):
        self.assertFalse(assess('RESULTADO: 10/10', 1)['passed'])
        self.assertFalse(assess('', 0)['passed'])
        self.assertTrue(assess('RESULTADO: 10/10', 0)['passed'])

    def test_shutdown_leaks_are_not_silently_ignored(self):
        self.assertFalse(assess('ERROR: resources still in use at exit\nRESULTADO: 1/1', 0)['passed'])
        self.assertFalse(assess('WARNING: ObjectDB instances leaked at exit\nRESULTADO: 1/1', 0)['passed'])

    def test_incomplete_summary_and_colored_errors(self):
        self.assertFalse(assess('RESULTADO: 9/10', 0)['passed'])
        self.assertFalse(assess('RESULTADO: 0/0', 0)['passed'])
        self.assertFalse(assess('\x1b[31mERROR: falhou\x1b[0m\nRESULTADO: 1/1', 0)['passed'])

    def test_user_data_and_rules_are_isolated(self):
        with tempfile.TemporaryDirectory(prefix='poke_gate_') as temp:
            env = isolated_env(Path(temp))
            self.assertEqual(env['APPDATA'], str(Path(temp).resolve()))
            self.assertNotIn('POKE_VERIFICAR', env)
            self.assertEqual((Path(temp) / 'PokeIdle/regras/perfil.txt').read_text(), 'original')


if __name__ == '__main__':
    unittest.main()
