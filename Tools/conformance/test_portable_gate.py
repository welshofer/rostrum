"""Negative controls for the mandatory portable gate."""
import importlib.metadata
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_dependencies
from compare_images import compare
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


class PortableGateTests(unittest.TestCase):
    def test_missing_oracles_fail_instead_of_skipping(self):
        result = subprocess.run([sys.executable, '-S', str(Path(check_dependencies.__file__))],
                                capture_output=True, text=True, env={'PATH': ''})
        self.assertNotEqual(result.returncode, 0)
        for missing in ('python-pptx', 'resvg-py', 'zip', 'unzip'):
            self.assertIn(missing, result.stderr)

    def test_wrong_rasterizer_version_is_rejected(self):
        version = importlib.metadata.version
        with patch.object(importlib.metadata, 'version',
                          side_effect=lambda name: '0.0.0' if name == 'resvg-py' else version(name)):
            self.assertIn('resvg-py: expected 0.5.0, found 0.0.0', check_dependencies.check())

    def test_shifted_pixels_fail_the_unchanged_threshold(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / name for name in ('reference.png', 'candidate.png')]
            for path, offset in zip(paths, (0, 3)):
                image = Image.new('RGB', (100, 100), 'white')
                ImageDraw.Draw(image).rectangle((20 + offset, 20, 80 + offset, 80), fill='black')
                image.save(path)
            self.assertTrue(compare(paths[0], paths[0])['passed'])
            result = compare(*paths)
            self.assertFalse(result['passed'])
            self.assertEqual(result['channelTolerance'], 16)
            self.assertEqual(result['fractionTolerance'], 0.005)

    def test_changed_producer_fixture_is_rejected(self):
        fixture = ROOT / 'Tests/RostrumTests/Fixtures/ImageOffice'
        manifest = json.loads((fixture / 'manifest.json').read_text())
        for variant in manifest['variants']:
            variant['source'] = str(fixture / variant['source'])
            variant['sourceSHA256'] = '0' * 64
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'manifest.json'
            path.write_text(json.dumps(manifest))
            result = subprocess.run([sys.executable, str(ROOT / 'Tools/conformance/check_image_office.py'),
                                     str(path), directory, '--output', directory], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('producer fixture hash mismatch', result.stderr)


if __name__ == '__main__':
    unittest.main()
