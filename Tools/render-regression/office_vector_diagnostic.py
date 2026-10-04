#!/usr/bin/env python3
"""Supplemental vector diagnosis for the pinned python-tables-v3 Office PDF.

Run `extract` with PyMuPDF/fonttools/HarfBuzz, then `raster` with Pillow/resvg-py.
Separate interpreters are supported so no runtime needs new dependencies.
The crop comes from the PDF's slide-background rectangle, never a fit to PNG.
PDF print text has independently rounded sizes and baselines: its text is not
an interchangeable acceptance reference for the Office slide PNG. Extracted
glyph-path SVGs belong in scratch storage, not the redistributable fixtures.
Existing acceptance tools and thresholds are neither changed nor replaced.
"""
import argparse
import hashlib
import importlib.metadata
from io import BytesIO
import json
from pathlib import Path
import re
import subprocess
import sys
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SVG = '{http://www.w3.org/2000/svg}'
PDF_HASH = 'ab34afde5b7663d6759591bff3f7e28796abb58a9a9d716610c307eab3bddd4d'
PNG_HASH = '118605ddc801546321cca798c59f9c894e46b96e0770f4d232bec4cae94b2c01'
FRAME = (113.0, 101.0, 498.25, 325.625)
SCALE = ((FRAME[2] - FRAME[0]) / 1200, (FRAME[3] - FRAME[1]) / 700)
TEXT_REGIONS = [
    ('merged-origin', 100, 100, 600, 350), ('R0C2', 600, 100, 850, 225), ('R0C3', 850, 100, 1100, 225),
    ('R1C2', 600, 225, 850, 350), ('R1C3', 850, 225, 1100, 350), ('R2C0', 100, 350, 400, 475),
    ('R2C1-first-line', 400, 350, 600, 395), ('R2C1-second-line', 400, 395, 600, 475),
    ('R2C2', 600, 350, 850, 475), ('R2C3', 850, 350, 1100, 475), ('R3C0', 100, 475, 400, 600),
    ('R3C1', 400, 475, 600, 600), ('R3C2', 600, 475, 850, 600), ('R3C3', 850, 475, 1100, 600)]


def identity(path):
    try:
        label = path.resolve().relative_to(ROOT)
    except ValueError:
        label = path
    return {'path': str(label), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def point(value):
    return [(value[i] - FRAME[i]) / SCALE[i] for i in (0, 1)]


def spans(path):
    result = {}
    for text in ET.parse(path).getroot().findall(SVG + 'text'):
        match = re.fullmatch(r'translate\(([^,]+),([^\)]+)\) scale\(12700\)', text.get('transform', ''))
        if not match:
            raise ValueError('Unsupported text transform in fixture candidate')
        x, y = map(float, match.groups())
        for span in text:
            value = span.text or ''
            if not value.strip():
                continue
            if value in result:
                raise ValueError('Fixture profile requires unique nonblank spans')
            result[value] = {'origin': [(x + float(span.get('x')) * 12700) / 9144, y / 9144],
                             'pointSize': float(span.get('font-size')),
                             'widthPixels': float(span.get('textLength')) * 100 / 72}
    return result


def extract(args):
    import fitz
    from fontTools.ttLib import TTFont

    versions = {name: importlib.metadata.version(name) for name in ['PyMuPDF', 'fonttools']}
    if versions != {'PyMuPDF': '1.27.2.3', 'fonttools': '4.60.1'}:
        raise ValueError('PyMuPDF 1.27.2.3 and fonttools 4.60.1 are required')
    if identity(args.pdf)['sha256'] != PDF_HASH:
        raise ValueError('This diagnostic supports the pinned v3 notes PDF only')
    document = fitz.open(args.pdf)
    page = document[0]
    drawings = page.get_drawings()
    if not any(d['type'] == 'f' and d['fill'] == (1, 1, 1)
               and all(abs(a - b) < 0.001 for a, b in zip(d['rect'], FRAME)) for d in drawings):
        raise ValueError('Expected slide-background rectangle was not extracted')
    families = {}
    for record in json.loads(args.fonts.read_text())['fonts']:
        path = Path(record['path'])
        if not path.is_absolute():
            path = args.fonts.parent / path
        if identity(path)['sha256'] != record['sha256']:
            raise ValueError('Registered font hash mismatch: ' + str(path))
        font = TTFont(path)
        key = (record['family'], bool(font['OS/2'].fsSelection & 32))
        if key in families:
            raise ValueError('Ambiguous font-family/style entry in manifest')
        families[key] = (font, path, record['sha256'])
    subsets = []
    for xref, *_ in page.get_fonts(full=True):
        name, _, _, data = document.extract_font(xref)
        subsets.append((xref, name, TTFont(BytesIO(data))))

    def outline(font, name):
        glyph = font['glyf'][name]
        if glyph.numberOfContours == 0:
            return ([], [], [])
        coordinates, ends, flags = glyph.getCoordinates(font['glyf'])
        return (list(coordinates), list(ends), list(flags))

    hb_version = subprocess.check_output(['hb-shape', '--version'], text=True).splitlines()[0]
    if hb_version != 'hb-shape (HarfBuzz) 14.4.0':
        raise ValueError('HarfBuzz 14.4.0 is required')
    emitted = spans(args.candidate_svg)
    text = []
    for trace in page.get_texttrace():
        chars = trace['chars']
        value = ''.join(chr(c[0]) for c in chars)
        if value not in emitted:
            continue  # The notes paragraph is outside the slide crop.
        source = emitted[value]
        family = 'Arial' if trace['font'].startswith('Arial') else 'Calibri'
        font, font_path, digest = families[(family, bool(trace['flags'] & 16))]
        cmap = font.getBestCmap()
        matches = []
        for xref, name, subset in subsets:
            if not name.endswith(trace['font']):
                continue
            order = subset.getGlyphOrder()
            if all(gid < len(order) and outline(subset, order[gid]) == outline(font, cmap[cp])
                   for cp, gid, *_ in chars):
                matches.append(xref)
        if not matches:
            raise ValueError('PDF outlines do not match registered font: ' + value)
        shaped = json.loads(subprocess.check_output([
            'hb-shape', str(font_path), '--text=' + value, '--output-format=json',
            '--no-glyph-names', '--font-size=' + str(font['head'].unitsPerEm)], text=True))
        if [g['cl'] for g in shaped] != list(range(len(value))):
            raise ValueError('Fixture glyph-origin comparison requires one ASCII glyph per character')
        scale = source['widthPixels'] / sum(g['ax'] for g in shaped)
        cursor = source['origin'][0]
        expected = []
        for glyph in shaped:
            expected.append(cursor + glyph['dx'] * scale)
            cursor += glyph['ax'] * scale
        origins = [point(c[2]) for c in chars]
        text.append({'text': value, 'officeFont': trace['font'], 'registeredFontSHA256': digest,
                     'matchingPDFSubsetXrefs': matches, 'glyphCount': len(chars),
                     'officeNormalizedPointSize': trace['size'] / SCALE[0] * 72 / 100,
                     'rostrum': source, 'officeGlyphOrigins': origins,
                     'officeOriginMinusRostrum': [origins[0][i] - source['origin'][i] for i in (0, 1)],
                     'officeSpanWidthPixels': (chars[-1][3][2] - chars[0][2][0]) / SCALE[0],
                     'officeMinusSVGGlyphX': [p[0] - x for p, x in zip(origins, expected)],
                     'svgWidthMinusHarfBuzzPixels': source['widthPixels'] - sum(g['ax'] for g in shaped)
                     / font['head'].unitsPerEm * source['pointSize'] * 100 / 72})
    if len(text) != len(emitted):
        raise ValueError('PDF and candidate span sets differ')
    borders = []
    for drawing in drawings:
        if drawing['type'] == 's' and all(item[0] == 'l' for item in drawing['items']):
            for _, start, end in drawing['items']:
                borders.append({'start': point(start), 'end': point(end), 'color': drawing['color'],
                                'widthPixels': drawing['width'] / (SCALE[0] * SCALE[1]) ** 0.5,
                                'sequence': drawing['seqno'], 'opacity': drawing['stroke_opacity'],
                                'dashes': drawing['dashes'], 'lineCap': drawing['lineCap']})
    root = ET.fromstring(page.get_svg_image(text_as_path=True))
    root.attrib.update(width='1200', height='700', viewBox='113 101 385.25 224.625', preserveAspectRatio='none')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    cropped = args.output_dir / 'office-cropped-vectors.svg'
    cropped.write_text(ET.tostring(root, encoding='unicode'))
    report = {'scope': 'Supplemental fixed-fixture vector extraction; no fit to a PNG or replacement acceptance.',
              'tools': dict(versions, MuPDF=fitz.version[1], HarfBuzz=hb_version),
              'source': identity(Path(__file__)), 'pdf': identity(args.pdf), 'candidateSVG': identity(args.candidate_svg),
              'coordinateMap': {'source': 'Asserted slide-background vector rectangle', 'pdfRect': FRAME,
                                'pixelDimensions': [1200, 700], 'pdfPointsPerSlidePixel': SCALE},
              'croppedVectors': identity(cropped), 'text': text, 'borders': borders,
              'textCaveat': 'Office print text has independently rounded font sizes, glyph spacing, and baseline positions.'}
    write(args.output_dir / 'office-vector-measurements.json', report)
    print(json.dumps({'output': str(args.output_dir), 'spans': len(text), 'verifiedGlyphs': sum(t['glyphCount'] for t in text),
                      'strokeRuns': len(borders)}, indent=2))


def intervals(items):
    groups = {}
    for start, end, color, width in items:
        vertical = abs(start[0] - end[0]) < 0.001
        if not vertical and abs(start[1] - end[1]) >= 0.001:
            raise ValueError('Only orthogonal strokes belong to this fixture profile')
        axis = 1 if vertical else 0
        key = str(('v' if vertical else 'h', round(start[1 - axis], 3), tuple(color), round(width, 3)))
        groups.setdefault(key, []).append(sorted((start[axis], end[axis])))
    result = {}
    for key, values in groups.items():
        merged = []
        for low, high in sorted(values):
            if merged and low <= merged[-1][1] + 0.001:
                merged[-1][1] = max(merged[-1][1], high)
            else:
                merged.append([low, high])
        result[key] = merged
    return result


def raster(args):
    from PIL import Image, ImageChops
    import resvg_py
    sys.path.insert(0, str(ROOT / 'Tools/conformance'))
    from check_text_rendering import prepare, local_fonts
    from analyze_fidelity import stroke_zone

    versions = {name: importlib.metadata.version(name) for name in ['Pillow', 'resvg-py']}
    if versions != {'Pillow': '12.3.0', 'resvg-py': '0.5.0'}:
        raise ValueError('Pillow 12.3.0 and resvg-py 0.5.0 are required')
    data = json.loads((args.vector_dir / 'office-vector-measurements.json').read_text())
    if identity(args.office_png)['sha256'] != PNG_HASH:
        raise ValueError('This diagnostic supports the pinned v3 Office PNG only')
    office_svg = args.vector_dir / 'office-cropped-vectors.svg'
    if identity(office_svg)['sha256'] != data['croppedVectors']['sha256']:
        raise ValueError('Extracted Office SVG hash mismatch')
    _, _, corrected, aliases = prepare(args.candidate_svg.read_text(), local_fonts(args.fonts), 1200, 700)

    def render(svg, fonts=()):
        png = resvg_py.svg_to_bytes(svg_string=svg, skip_system_fonts=True, font_files=list(fonts), width=1200, height=700)
        rgba = Image.open(BytesIO(png)).convert('RGBA')
        return Image.alpha_composite(Image.new('RGBA', rgba.size, 'white'), rgba).convert('RGB')

    office = render(office_svg.read_text())
    candidate = render(corrected, sorted({r['path'] for r in aliases.values()}))
    reference = Image.open(args.office_png).convert('RGB')
    if reference.size != (1200, 700):
        raise ValueError('Expected a 1200x700 Office slide PNG')
    probes = []
    for xy in [(700, 300), (700, 400), (300, 99), (99, 300), (600, 300), (700, 224), (850, 400)]:
        actual, expected = office.getpixel(xy), reference.getpixel(xy)
        if actual != expected:
            raise ValueError('Core probe differs from Office PNG: ' + str(xy))
        probes.append({'pixel': xy, 'officePNGAndPDF': actual, 'candidate': candidate.getpixel(xy)})

    def difference(first, second):
        total = strokes = 0
        pixels = set()
        for i, pixel in enumerate(ImageChops.difference(first, second).get_flattened_data()):
            if max(pixel) > 16:
                total += 1
                strokes += stroke_zone(i % 1200, i // 1200)
                pixels.add(i)
        return ({'differingPixels': total, 'fraction': total / 840000,
                 'strokeZone': strokes, 'outsideStrokeZone': total - strokes}, pixels)

    comparisons = {
        'officeVectorsVersusCandidate': difference(office, candidate),
        'officeVectorsVersusOfficePNG': difference(office, reference),
        'candidateVersusOfficePNG': difference(candidate, reference)}
    a = comparisons['candidateVersusOfficePNG'][1]
    b = comparisons['officeVectorsVersusOfficePNG'][1]
    c = comparisons['officeVectorsVersusCandidate'][1]
    stroke_pixels = {i for i in a | b | c if stroke_zone(i % 1200, i // 1200)}
    text_masks = {'candidateVsOfficePNG': a - stroke_pixels, 'officeVectorsVsOfficePNG': b - stroke_pixels,
                  'candidateVsOfficeVectors': c - stroke_pixels}
    region_counts = []
    for name, x0, y0, x1, y1 in TEXT_REGIONS:
        counts = {key: sum(x0 <= i % 1200 < x1 and y0 <= i // 1200 < y1 for i in pixels)
                  for key, pixels in text_masks.items()}
        region_counts.append(dict(region=name, bounds=[x0, y0, x1, y1], **counts))
    outside_table = {key: sum(not (100 <= i % 1200 < 1100 and 100 <= i // 1200 < 600) for i in pixels)
                     for key, pixels in text_masks.items()}
    for key, pixels in text_masks.items():
        if sum(r[key] for r in region_counts) + outside_table[key] != len(pixels):
            raise ValueError('Fixed cell-region partition did not cover every residual pixel')
    residual = {
        'maskDefinitions': {'A': 'candidate versus Office PNG', 'B': 'Office vectors versus Office PNG',
                            'C': 'candidate versus Office vectors'},
        'strokeOverlap': {'A': len(a & stroke_pixels), 'B': len(b & stroke_pixels), 'C': len(c & stroke_pixels),
                          'AintersectB': len(a & b & stroke_pixels), 'AsymmetricDifferenceB': len((a ^ b) & stroke_pixels)},
        'outsideStrokeOverlap': {'A': len(a - stroke_pixels), 'B': len(b - stroke_pixels), 'C': len(c - stroke_pixels),
                                 'AintersectB': len((a & b) - stroke_pixels), 'Aonly': len(a - b - stroke_pixels),
                                 'Bonly': len(b - a - stroke_pixels), 'AunionB': len((a | b) - stroke_pixels)},
        'regions': region_counts, 'outsideTable': outside_table,
        'regionPolicy': 'Half-open table-cell bounds; mixed cell split at y395 in the empty gap between lines. Stroke zones excluded.',
        'outsideTableCaveat': 'The PDF crop can expose print-page furniture at its bottom corners; these pixels are separated from table text.',
        'nonadditivity': 'Pairwise thresholded pixel sets are not additive error contributions. PDF print typography makes text mask B more than raster error.'}

    original = intervals((r['start'], r['end'], [round(c * 255) for c in r['color']], r['widthPixels']) for r in data['borders'])
    candidate_lines = []
    for line in ET.parse(args.candidate_svg).getroot().findall(SVG + 'line'):
        a = line.attrib
        color = a['stroke'].lstrip('#')
        if (not re.fullmatch('[0-9A-Fa-f]{6}', color) or 'stroke-dasharray' in a
                or float(a.get('stroke-opacity', '1')) != 1 or float(a.get('opacity', '1')) != 1):
            raise ValueError('Vector interval matching supports solid opaque fixture strokes only')
        candidate_lines.append(([float(a['x1']) / 9144, float(a['y1']) / 9144],
                                [float(a['x2']) / 9144, float(a['y2']) / 9144],
                                [int(color[i:i + 2], 16) for i in (0, 2, 4)], float(a['stroke-width']) / 9144))
    emitted = intervals(candidate_lines)
    keys_match = original.keys() == emitted.keys() and all(len(original[k]) == len(emitted[k]) for k in original)
    errors = []
    if keys_match:
        for key in sorted(original):
            for wanted, actual in zip(original[key], emitted[key]):
                errors.append({'style': key, 'office': wanted, 'candidate': actual,
                               'maximumEndpointDeltaPixels': max(abs(x - y) for x, y in zip(wanted, actual))})
    report = {'scope': 'Supplemental common-resvg attribution. PDF print text is not a replacement PNG acceptance reference.',
              'tools': versions, 'source': identity(Path(__file__)),
              'dependencySources': [identity(ROOT / 'Tools/conformance/check_text_rendering.py'),
                                    identity(ROOT / 'Tools/render-regression/analyze_fidelity.py')],
              'vectorMeasurementSource': identity(args.vector_dir / 'office-vector-measurements.json'),
              'candidate': identity(args.candidate_svg),
              'officeSVG': identity(office_svg), 'officePNG': identity(args.office_png), 'fontAliases': aliases,
              'coreProbes': probes, **{key: value[0] for key, value in comparisons.items()}, 'residualAttribution': residual,
              'mergedStrokeStyleKeysMatch': keys_match, 'strokeIntervals': errors,
              'maximumEndpointDeltaPixels': max((e['maximumEndpointDeltaPixels'] for e in errors), default=None)}
    write(args.output, report)
    candidate.save(args.output.with_suffix('.png'))
    office.save(args.vector_dir / 'office-vectors-resvg.png')
    print(json.dumps({k: report[k] for k in ['officeVectorsVersusCandidate', 'candidateVersusOfficePNG',
                                            'mergedStrokeStyleKeysMatch', 'maximumEndpointDeltaPixels']}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest='mode', required=True)
    first = modes.add_parser('extract', help='Requires PyMuPDF, fonttools, and hb-shape 14.4.0')
    first.add_argument('--pdf', type=Path, required=True)
    first.add_argument('--candidate-svg', type=Path, required=True)
    first.add_argument('--fonts', type=Path, required=True)
    first.add_argument('--output-dir', type=Path, required=True)
    second = modes.add_parser('raster', help='Requires Pillow 12.3.0 and resvg-py 0.5.0')
    second.add_argument('--vector-dir', type=Path, required=True)
    second.add_argument('--candidate-svg', type=Path, required=True)
    second.add_argument('--fonts', type=Path, required=True)
    second.add_argument('--office-png', type=Path, required=True)
    second.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        (extract if args.mode == 'extract' else raster)(args)
    except (ImportError, OSError, ValueError, KeyError, subprocess.CalledProcessError,
            importlib.metadata.PackageNotFoundError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()
