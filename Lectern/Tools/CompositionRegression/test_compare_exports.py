import json
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from PIL import Image

SCRIPT = Path(__file__).with_name('compare_exports.py')

class ExportComparisonTests(unittest.TestCase):
    def test_review_coverage_changes_and_baseline_tampering(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            old, new = root / 'old', root / 'new'
            old.mkdir(); new.mkdir()
            for directory in (old, new):
                Image.new('RGB', (32, 18), 'white').save(directory / 'Slide1.png')
            deck = root / 'deck.pptx'
            with zipfile.ZipFile(deck, 'w') as package:
                package.writestr('ppt/presentation.xml', '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:sldIdLst><p:sldId id="256"/></p:sldIdLst></p:presentation>')
            manifest = root / 'baseline.json'
            def run(*args):
                return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)], capture_output=True).returncode
            record = ['record', deck, old, manifest, '--reviewer', 'Test', '--powerpoint-version', 'Test']
            self.assertNotEqual(run(*record, '--reviewed-slides', '2'), 0)
            self.assertEqual(run(*record, '--reviewed-slides', '1'), 0)
            self.assertEqual(run('compare', manifest, new, root / 'diff'), 0)
            Image.new('RGB', (32, 18), 'black').save(new / 'Slide1.png')
            self.assertEqual(run('compare', manifest, new, root / 'diff'), 1)
            self.assertTrue((root / 'diff' / 'Slide1-difference.png').exists())
            Image.new('RGB', (32, 18), 'red').save(old / 'Slide1.png')
            self.assertNotEqual(run('compare', manifest, new, root / 'diff'), 0)

if __name__ == '__main__':
    unittest.main()
