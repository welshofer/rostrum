"""The typography oracle reads both emitted scalar origins and legacy extents."""
from pathlib import Path
import sys
import unittest
from xml.etree import ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'Tools/typography'))
from check_office_text_positions import span_positions


class OfficeTextPositionTests(unittest.TestCase):
    glyphs = [{'ax': 10, 'dx': 0, 'dy': 0}, {'ax': 20, 'dx': 0, 'dy': 0},
              {'ax': 30, 'dx': 0, 'dy': 0}]

    def test_scalar_origins_are_read_without_inventing_a_final_advance(self):
        span = ET.fromstring('<tspan x="7.92 18.045 25.795">Hpx</tspan>')
        origins, measurement = span_positions(span, self.glyphs, 0.5)
        self.assertEqual(origins, [7.92, 18.045, 25.795])
        self.assertIsNone(measurement['candidateWidthPoints'])
        self.assertIsNone(measurement['differencePoints'])
        self.assertAlmostEqual(measurement['candidatePositionSpanPoints'], 17.875)
        self.assertEqual(measurement['harfBuzzPositionSpanPoints'], 15)
        self.assertEqual(measurement['harfBuzzWidthPoints'], 30)

    def test_single_scalar_has_an_origin_but_no_declared_extent(self):
        origins, measurement = span_positions(ET.fromstring('<tspan x="4">H</tspan>'), self.glyphs[:1], 1)
        self.assertEqual(origins, [4])
        self.assertEqual(measurement['candidatePositionSpanPoints'], 0)
        self.assertIsNone(measurement['candidateWidthPoints'])

    def test_legacy_width_scales_glyph_origins(self):
        span = ET.fromstring('<tspan x="4" textLength="60" lengthAdjust="spacingAndGlyphs">Hpx</tspan>')
        origins, measurement = span_positions(span, self.glyphs, 0.5)
        self.assertEqual(origins, [4, 14, 34])
        self.assertEqual(measurement['candidateWidthPoints'], 60)
        self.assertEqual(measurement['differencePoints'], 30)
        self.assertEqual(measurement['positioning'], 'textLengthSpacingAndGlyphs')

    def test_refuses_partial_positions_or_unsupported_geometry(self):
        for attributes in ['x="4"', 'x="4 8"', 'x="4 8 nan"', 'x="4 8 inf"',
                           'x="4 8 12" dx="1"', 'x="4 8 12" y="3"',
                           'x="4 8 12" textLength="30" lengthAdjust="spacingAndGlyphs"',
                           'x="4" textLength="30" lengthAdjust="spacing"',
                           'x="4" textLength="nan" lengthAdjust="spacingAndGlyphs"']:
            with self.subTest(attributes=attributes), self.assertRaises(ValueError):
                span_positions(ET.fromstring(f'<tspan {attributes}>Hpx</tspan>'), self.glyphs, 1)


if __name__ == '__main__':
    unittest.main()
