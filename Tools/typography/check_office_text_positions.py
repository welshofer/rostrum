#!/usr/bin/env python3
"""Diagnose the pinned Office text corpus without changing its acceptance gate.

Requires the baseline checker's pinned PyMuPDF/fonttools, HarfBuzz 14.4.0,
resvg-py 0.5.0 and Pillow 12.3.0. Verifies capture/font identities, compares
candidate span widths with independent shaping and glyph origins with the
verified PDF, then applies the unchanged native PNG gate. Optional PDF raster
and textLength ablations are diagnostics only, never candidate replacements.
No font bytes, extracted outlines or modified references are written.
Exit 0: original candidate passes; 1: original candidate fails; 2: invalid evidence.
"""
import argparse
from io import BytesIO
import hashlib
import importlib.metadata
import json
from pathlib import Path
import re
import subprocess
import sys
from xml.etree import ElementTree as ET
import zipfile

from check_office_baselines import check as baselines, case_at, digest, FIXTURE, ROOT, SVG, require
sys.path.insert(0, str(ROOT / 'Tools/conformance'))
from check_text_rendering import local_fonts, prepare, TOLERANCE, MAX_DIFFERENCE_FRACTION


def check(args):
    import fitz
    import resvg_py
    from PIL import Image, ImageChops
    from fontTools.ttLib import TTFont
    versions = {name: importlib.metadata.version(name) for name in ['resvg-py', 'Pillow']}
    require(versions == {'resvg-py': '0.5.0', 'Pillow': '12.3.0'}, 'Pinned raster dependencies required')
    hb = subprocess.check_output(['hb-shape', '--version'], text=True).splitlines()[0]
    require(hb == 'hb-shape (HarfBuzz) 14.4.0', 'Pinned shaping executable required')
    baseline = baselines(args)  # verifies all 268 PDF glyph outlines and source identity
    fonts = local_fonts(args.fonts)
    units = {key: TTFont(value['path'])['head'].unitsPerEm for key, value in fonts.items()}
    capture = json.loads((FIXTURE / 'manifest.json').read_text())
    source = json.loads((FIXTURE / capture['sourceManifest']).resolve().read_text())
    archive_path = FIXTURE / 'powerpoint-16.113.3-png.zip'
    require(digest(archive_path) == capture['files'][archive_path.name], 'PNG archive identity mismatch')
    reference_lines = {}
    for line in baseline['lines']:
        reference_lines.setdefault(line['case'], []).append(line)
    spans, origins, rasters = [], [], []
    document = fitz.open(FIXTURE / 'text-baseline-v1-office.pdf')
    with zipfile.ZipFile(archive_path) as archive:
        for slide in source['slides']:
            number = slide['slideIndex']
            path = args.candidates / f'slide-{number:02}.svg'
            svg = path.read_text()
            _, _, _, aliases = prepare(svg, fonts, 1200, 700)
            occurrence = {}
            for text in ET.fromstring(svg).iter(SVG + 'text'):
                match = re.fullmatch(r'translate\(([^,]+),([^\)]+)\) scale\(12700\)', text.get('transform', ''))
                require(match, 'Unsupported text transform')
                x, y = [float(value) / 12700 for value in match.groups()]
                case = case_at(slide['cases'], x, y)['id']
                index = occurrence.get(case, 0)
                occurrence[case] = index + 1
                reference = reference_lines[case][index]
                expected = [(char, origin) for span in reference['officeSpans']
                            for char, origin in zip(span['text'], span['glyphOrigins'])]
                actual = []
                for span in text:
                    value = span.text or ''
                    alias = span.get('font-family', '').split(',')[0].strip(" '\"")
                    record = aliases[alias]
                    size = float(span.get('font-size'))
                    require(float(span.get('letter-spacing', '0')) == 0, 'This corpus has no tracking')
                    scale = size / units[record['sha256']]
                    command = ['hb-shape', record['path'], value, '--output-format=json', '--no-glyph-names',
                               '--font-size=' + str(units[record['sha256']]), '--features=kern=' +
                               ('0' if span.get('kerning') == '0' else '1')]
                    glyphs = json.loads(subprocess.check_output(command, text=True))
                    require(len(glyphs) == len(value) and [g['cl'] for g in glyphs] == list(range(len(value))),
                            'Expected the pinned one-glyph-per-ASCII-character profile')
                    shaped_width = sum(glyph['ax'] for glyph in glyphs) * scale
                    candidate_width = float(span.get('textLength'))
                    spans.append({'case': case, 'line': index, 'text': value, 'fontSHA256': record['sha256'],
                                  'candidateWidthPoints': candidate_width, 'harfBuzzWidthPoints': shaped_width,
                                  'differencePoints': candidate_width - shaped_width})
                    pen = x + float(span.get('x'))
                    for char, glyph in zip(value, glyphs):
                        actual.append((char, (pen + glyph['dx'] * scale, y - glyph['dy'] * scale)))
                        pen += glyph['ax'] * scale
                require([char for char, _ in expected] == [char for char, _ in actual], 'Glyph text mismatch')
                for ordinal, ((char, origin), (_, measured)) in enumerate(zip(expected, actual)):
                    origins.append({'case': case, 'line': index, 'characterIndex': ordinal, 'text': char,
                                    'officeOriginPoints': origin, 'candidateOriginPoints': measured,
                                    'differenceXPoints': measured[0] - origin[0]})
            for width, height in [(1200, 700), (2400, 1400)]:
                name = f'{width}x{height}/Slide{number}.png'
                data = archive.read(name)
                expected_hash = next(member['sha256'] for member in capture['pngMembers'] if member['file'] == name)
                require(hashlib.sha256(data).hexdigest() == expected_hash, 'PNG member identity mismatch')
                reference = Image.open(BytesIO(data)).convert('RGB')
                require(reference.size == (width, height), 'Reference dimensions changed')
                _, _, corrected, aliases = prepare(svg, fonts, width, height)
                options = dict(width=width, height=height, skip_system_fonts=True,
                               font_files=sorted({record['path'] for record in aliases.values()}))
                def compare(candidate):
                    require(candidate.size == reference.size, 'Raster dimensions changed')
                    difference = ImageChops.difference(candidate.convert('RGB'), reference)
                    changed = sum(max(pixel) > TOLERANCE for pixel in difference.get_flattened_data())
                    return {'differingPixels': changed, 'fraction': changed / (width * height),
                            'passed': changed / (width * height) <= MAX_DIFFERENCE_FRACTION}
                raster = Image.open(BytesIO(resvg_py.svg_to_bytes(svg_string=corrected, **options)))
                entry = {'slide': number, 'width': width, 'height': height, 'svgSHA256': digest(path),
                         'referenceSHA256': expected_hash, 'candidate': compare(raster)}
                if args.ablations:
                    root = ET.fromstring(corrected)
                    for span in root.iter(SVG + 'tspan'):
                        span.attrib.pop('textLength', None)
                        span.attrib.pop('lengthAdjust', None)
                    entry['withoutTextLengthDiagnostic'] = compare(Image.open(BytesIO(resvg_py.svg_to_bytes(
                        svg_string=ET.tostring(root, encoding='unicode'), **options))))
                    pixmap = document[number - 1].get_pixmap(matrix=fitz.Matrix(width / 864, height / 504), alpha=False)
                    entry['officePDFRasterDiagnostic'] = compare(Image.frombytes('RGB', (pixmap.width, pixmap.height), pixmap.samples))
                rasters.append(entry)
    require(len(origins) == 268, 'Glyph coverage changed')
    return {'scope': 'Horizontal measurement and native PNG acceptance; ablations never replace the original candidate.',
            'tools': dict(baseline['tools'], **versions, HarfBuzz=hb), 'checkerSHA256': digest(Path(__file__)),
            'baselineCheckerSHA256': baseline['checkerSHA256'], 'captureManifestSHA256': digest(FIXTURE / 'manifest.json'),
            'pdfSHA256': baseline['pdfSHA256'], 'pptxSHA256': baseline['pptxSHA256'],
            'candidateSVGs': baseline['candidateSVGs'], 'fontHashes': sorted(fonts),
            'verifiedGlyphOutlines': 268, 'caseCount': 30, 'lineCount': 46,
            'baselinePassed': baseline['passed'], 'baselineTolerancePoints': baseline['baselineTolerancePoints'],
            'maximumBaselineDifferencePoints': baseline['maximumBaselineDifferencePoints'],
            'maximumSpanWidthDifferencePoints': max(abs(span['differencePoints']) for span in spans),
            'maximumGlyphOriginXDifferencePoints': max(abs(origin['differenceXPoints']) for origin in origins),
            'channelTolerance': TOLERANCE, 'maximumDifferenceFraction': MAX_DIFFERENCE_FRACTION,
            'passed': baseline['passed'] and all(entry['candidate']['passed'] for entry in rasters),
            'rasterComparisons': rasters, 'spanMeasurements': spans, 'glyphOrigins': origins}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fonts', type=Path, required=True)
    parser.add_argument('--candidates', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ablations', action='store_true')
    args = parser.parse_args()
    try:
        report = check(args)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({key: value for key, value in report.items()
                          if key not in ['spanMeasurements', 'glyphOrigins']}, indent=2))
        return 0 if report['passed'] else 1
    except (ValueError, KeyError, OSError, ImportError, subprocess.CalledProcessError) as error:
        print('Office text positions check refused: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
