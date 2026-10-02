"""Acceptance-helper process contract, without launching Office."""
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('ppt_check', Path(__file__).resolve().parents[2] / 'Tools/ppt-check.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class AcceptanceTests(unittest.TestCase):
    def test_status_and_owned_copy(self):
        for status, code in [('OK', 0), ('REPAIR', 1), ('REJECTED-DIALOG', 1), ('TIMEOUT', 3), ('AMBIGUOUS-DIALOG', 4), ('UNSAVED-COPY', 4)]:
            with self.subTest(status=status), tempfile.TemporaryDirectory() as folder:
                source = Path(folder) / 'user source.pptx'
                with zipfile.ZipFile(source, 'w') as archive:
                    archive.writestr('sentinel', 'unchanged')
                original = source.read_bytes()
                owned = Path(folder) / 'owned'
                owned.mkdir()
                calls = []
                def run(args, **kwargs):
                    calls.append(args)
                    if args[0] == 'open':
                        self.assertNotEqual(Path(args[-1]), source)
                        self.assertEqual(Path(args[-1]).read_bytes(), original)
                        return subprocess.CompletedProcess(args, 0, '')
                    self.assertEqual(args[2], calls[0][-1])
                    self.assertNotIn('close every', kwargs['input'])
                    return subprocess.CompletedProcess(args, 0, status)
                with patch.object(module.tempfile, 'mkdtemp', return_value=str(owned)), patch.object(module.subprocess, 'run', side_effect=run), patch('sys.argv', ['ppt-check', str(source)]), patch('sys.stdout', new_callable=io.StringIO):
                    self.assertEqual(module.main(), code)
                self.assertEqual(source.read_bytes(), original)
                self.assertEqual(owned.exists(), code != 0)

    def test_automation_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'test.pptx'
            with zipfile.ZipFile(source, 'w') as archive:
                archive.writestr('test', 'test')
            for failure, expected in [(OSError('no automation'), 4), (subprocess.TimeoutExpired('osascript', 40), 3)]:
                owned = Path(folder) / str(expected)
                owned.mkdir()
                with patch.object(module.tempfile, 'mkdtemp', return_value=str(owned)), patch.object(module.subprocess, 'run', side_effect=failure), patch('sys.argv', ['ppt-check', str(source)]), patch('sys.stdout', new_callable=io.StringIO):
                    self.assertEqual(module.main(), expected)

    def test_missing_input(self):
        with patch('sys.argv', ['ppt-check', '/missing/never.pptx']), patch('sys.stderr', new_callable=io.StringIO):
            with self.assertRaises(SystemExit) as error:
                module.main()
            self.assertEqual(error.exception.code, 2)

if __name__ == '__main__':
    unittest.main()
