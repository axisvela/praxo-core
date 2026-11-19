import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


class SnapshotOrderingTest(unittest.TestCase):
    def test_linux_and_windows_ordering_match(self):
        root = Path(__file__).resolve().parents[1]
        for language in ("matlab", "octave"):
            with self.subTest(language=language):
                script = root / language / "api-snapshot.py"
                spec = importlib.util.spec_from_file_location(language + "_api", script)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                expected = module.snapshot()

                def linux_sorted(paths, *, key=None):
                    return sorted(paths, key=key or (lambda path: path.name))

                with patch.object(module, "sorted", linux_sorted, create=True):
                    self.assertEqual(expected, module.snapshot())


if __name__ == "__main__":
    unittest.main()
