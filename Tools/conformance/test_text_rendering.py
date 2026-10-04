#!/usr/bin/env python3
"""Portable input-contract tests; no installed fonts or raster dependencies."""
import base64
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
import check_text_rendering as check


def minimal_named_font():
    value = 'Owned Test'.encode('utf-16-be')
    names = struct.pack('>3H', 0, 1, 18) + struct.pack('>6H', 3, 1, 0x409, 1, len(value), 0) + value
    return struct.pack('>I4H', 0x10000, 1, 16, 0, 0) + struct.pack('>4sIII', b'name', 0, 28, len(names)) + names


class TextRenderingInputs(unittest.TestCase):
    def setUp(self):
        self.data = minimal_named_font()
        self.digest = hashlib.sha256(self.data).hexdigest()
        self.fonts = {self.digest: {'family': 'Owned Test', 'path': '/unused/font.ttf', 'sha256': self.digest}}
        encoded = base64.b64encode(self.data).decode()
        self.svg = '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="70" viewBox="0 0 1200 700"><defs><style>' \
            + "@font-face{font-family:'Face1';font-style:normal;font-weight:400;src:url(data:font/ttf;base64," \
            + encoded + ") format('truetype');}</style></defs><text><tspan font-family=\"Face1, sans-serif\">Test</tspan></text></svg>"

    def test_exact_alias_and_family_resolve(self):
        before, stripped, after, aliases = check.prepare(self.svg, self.fonts, 1200, 700)
        self.assertIn('font-family="Owned Test"', after)
        self.assertNotIn('@font-face', after)
        self.assertIn('@font-face', before)
        self.assertNotIn('@font-face', stripped)
        self.assertEqual(aliases['Face1']['sha256'], self.digest)
        self.assertEqual(check.font_families(self.data), {'Owned Test'})

    def test_unverified_alias_missing_font_and_unsupported_css_refuse(self):
        bad = [self.svg.replace('Face1, sans-serif', 'Unknown, sans-serif'),
               self.svg.replace(' font-family="Face1, sans-serif"', ''),
               self.svg.replace('</style>', 'text{font-family:Arial}</style>'),
               self.svg.replace('<tspan ', '<tspan style="font-family:Arial" '),
               self.svg.replace('<text>', '<image href="file:///private/image.png"/><text>')]
        for svg in bad:
            with self.subTest(svg=svg[-160:]), self.assertRaises(ValueError):
                check.prepare(svg, self.fonts, 1200, 700)
        with self.assertRaises(ValueError):
            check.prepare(self.svg, {}, 1200, 700)

    def test_bad_or_mismatched_geometry_refuses(self):
        for view in ['0 0 0 700', '0 0 nan 700', '0 0 1200', '0 0 1200 800']:
            with self.subTest(view=view), self.assertRaises(ValueError):
                check.prepare(self.svg.replace('0 0 1200 700', view), self.fonts, 1200, 700)

    def test_hash_family_and_missing_file_refuse(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root/'font.ttf').write_bytes(self.data)
            record = {'family': 'Owned Test', 'path': 'font.ttf', 'sha256': self.digest}
            manifest = root/'fonts.json'
            manifest.write_text(json.dumps({'fonts': [record]}))
            self.assertIn(self.digest, check.local_fonts(manifest))
            for key, value in [('path', 'missing.ttf'), ('sha256', '0'*64), ('family', 'Unrelated')]:
                manifest.write_text(json.dumps({'fonts': [dict(record, **{key: value})]}))
                with self.subTest(key=key), self.assertRaises(ValueError):
                    check.local_fonts(manifest)
            manifest.write_text(json.dumps({'fonts': [record, record]}))
            with self.assertRaises(ValueError):
                check.local_fonts(manifest)

    def test_bad_sfnt_bounds_refuse(self):
        for count in range(len(self.data)):
            with self.subTest(count=count), self.assertRaises((ValueError, struct.error)):
                check.font_families(self.data[:count])


if __name__ == '__main__':
    unittest.main()
