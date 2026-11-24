import tempfile
import unittest
from pathlib import Path
from montar_build import build_path


class BuildDestinationTests(unittest.TestCase):
    def test_rejects_escape_reserved_names_and_existing_build(self):
        with tempfile.TemporaryDirectory(prefix='poke_build_test_') as folder:
            root = Path(folder)
            for name in ('../fora', '..\\fora', 'C:\\fora', '/fora', '', '.', 'CON', 'LPT1'):
                with self.subTest(name=name), self.assertRaises(ValueError):
                    build_path(root, name)
            old = root / 'builds/v1'
            old.mkdir(parents=True)
            marker = old / 'preservar.txt'
            marker.write_text('build anterior', encoding='utf-8')
            with self.assertRaises(ValueError):
                build_path(root, 'v1')
            self.assertEqual(marker.read_text(encoding='utf-8'), 'build anterior')

    def test_valid_destination_is_a_new_child_without_side_effects(self):
        with tempfile.TemporaryDirectory(prefix='poke_build_test_') as folder:
            root = Path(folder)
            destination = build_path(root, 'v1_0-1')
            self.assertEqual(destination.parent, (root / 'builds').resolve())
            self.assertFalse(destination.exists())


if __name__ == '__main__':
    unittest.main()
