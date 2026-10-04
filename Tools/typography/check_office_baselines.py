#!/usr/bin/env python3
"""Verify the pinned PowerPoint baseline fixture against three Rostrum SVGs.

Development-only dependencies: PyMuPDF 1.27.2.3, fonttools 4.60.1. Supply the
same hash-pinned local font manifest used by check_text_rendering.py. Every
PDF glyph outline must match those files before a baseline is compared.
No font bytes or extracted glyph paths are written. This vector diagnostic
covers 30 cases / 46 lines, not the independent PNG acceptance gate.
"""
import argparse
import hashlib
import importlib.metadata
from io import BytesIO
import json
import math
from pathlib import Path
import re
import sys
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'Tests/RostrumTests/Fixtures/TypographyOffice'
SVG = '{http://www.w3.org/2000/svg}'
BASELINE_TOLERANCE_POINTS = 0.121  # 0.24pt Office PDF position grid plus float extraction error


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def outline(font, name):
    glyph = font['glyf'][name]
    if glyph.numberOfContours == 0:
        return ([], [], [])
    coordinates, ends, flags = glyph.getCoordinates(font['glyf'])
    return (list(coordinates), list(ends), list(flags))


def case_at(cases, x, y):
    matched = [case for case in cases
               if case['frameEMU'][0] / 12700 <= x < (case['frameEMU'][0] + case['frameEMU'][2]) / 12700
               and case['frameEMU'][1] / 12700 <= y < (case['frameEMU'][1] + case['frameEMU'][3]) / 12700]
    require(len(matched) == 1, 'Text does not belong to exactly one fixture frame')
    return matched[0]


def check(args):
    import fitz
    from fontTools.ttLib import TTFont
    sys.path.insert(0, str(ROOT / 'Tools/conformance'))
    from check_text_rendering import local_fonts, prepare
    versions = {name: importlib.metadata.version(name) for name in ['PyMuPDF', 'fonttools']}
    require(versions == {'PyMuPDF': '1.27.2.3', 'fonttools': '4.60.1'}, 'Pinned extraction dependencies required')
    capture = json.loads((FIXTURE / 'manifest.json').read_text())
    for name in ['text-baseline-v1-office.pdf', 'text-baseline-v1.pptx']:
        require(digest(FIXTURE / name) == capture['files'][name], 'Capture hash mismatch: ' + name)
    source_path = (FIXTURE / capture['sourceManifest']).resolve()
    source = json.loads(source_path.read_text())
    require(source['sha256'] == capture['files']['text-baseline-v1.pptx'], 'Source identity mismatch')
    fonts = local_fonts(args.fonts)
    families = {}
    for record in capture['fontFiles']:
        key = (record['family'], record['bold'])
        require(record['sha256'] in fonts and key not in families, 'Missing or ambiguous pinned face')
        local = fonts[record['sha256']]
        font = TTFont(local['path'])
        require(bool(font['OS/2'].fsSelection & 32) == record['bold'], 'Pinned weight mismatch')
        families[key] = (font, record)
    document = fitz.open(FIXTURE / 'text-baseline-v1-office.pdf')
    require(len(document) == 3, 'Expected three direct slide pages')
    lines, verified, candidates = [], 0, []
    for page, slide in zip(document, source['slides']):
        require(page.rect == fitz.Rect(0, 0, 864, 504), 'Unexpected PDF page size')
        subsets = []
        for xref, *_ in page.get_fonts(full=True):
            name, _, _, data = document.extract_font(xref)
            subsets.append((xref, name, TTFont(BytesIO(data))))
        by_case = {}
        for trace in page.get_texttrace():
            chars = trace['chars']
            require(chars and all(32 <= char[0] < 127 for char in chars), 'Unexpected PDF character profile')
            family = 'Arial' if trace['font'].startswith('Arial') else 'Calibri'
            font, record = families[(family, bool(trace['flags'] & 16))]
            cmap = font.getBestCmap()
            matches = [xref for xref, name, subset in subsets
                       if name.endswith(trace['font']) and all(
                           gid < len(subset.getGlyphOrder())
                           and outline(subset, subset.getGlyphOrder()[gid]) == outline(font, cmap[cp])
                           for cp, gid, *_ in chars)]
            require(matches, 'PDF glyph outlines differ from pinned font: ' + trace['font'])
            verified += len(chars)
            x, y = chars[0][2]
            case = case_at(slide['cases'], x, y)
            line = by_case.setdefault(case['id'], {}).setdefault(y, [])
            line.append({'text': ''.join(chr(char[0]) for char in chars), 'font': trace['font'],
                         'fontSHA256': record['sha256'], 'pointSize': trace['size'],
                         'glyphOrigins': [char[2] for char in chars], 'verifiedSubsetXrefs': matches})
        candidate = args.candidates / f'slide-{page.number + 1:02}.svg'
        candidates.append({'file': candidate.name, 'sha256': digest(candidate)})
        # Independently validate every SVG face's bytes, aliases and physical family.
        _, _, _, aliases = prepare(candidate.read_text(), fonts, 1200, 700)
        root = ET.parse(candidate).getroot()
        actual = {}
        for text in root.iter(SVG + 'text'):
            match = re.fullmatch(r'translate\(([^,]+),([^\)]+)\) scale\(12700\)', text.get('transform', ''))
            require(match, 'Unsupported candidate text transform')
            x, y = [float(value) / 12700 for value in match.groups()]
            require(math.isfinite(x) and math.isfinite(y), 'Nonfinite candidate origin')
            case = case_at(slide['cases'], x, y)
            styled = []
            for span in text:
                alias = span.get('font-family', text.get('font-family', '')).split(',')[0].strip(" '\"")
                require(alias in aliases, 'Candidate span lacks a verified face')
                size = float(span.get('font-size', text.get('font-size', 'nan')))
                require(math.isfinite(size) and size > 0, 'Invalid candidate point size')
                styled.extend((char, aliases[alias]['sha256'], size) for char in span.text or '')
            actual.setdefault(case['id'], []).append((y, styled))
        for case in slide['cases']:
            reference = sorted(by_case.get(case['id'], {}).items())
            emitted = actual.get(case['id'], [])
            require(len(reference) == len(emitted) and reference, 'Line count mismatch: ' + case['id'])
            for index, ((baseline, spans), (candidate_y, candidate_styled)) in enumerate(zip(reference, emitted)):
                reference_styled = [(char, span['fontSHA256'], span['pointSize']) for span in spans for char in span['text']]
                require(len(candidate_styled) == len(reference_styled) and all(
                    actual_char == expected_char and actual_font == expected_font and abs(actual_size - expected_size) < 0.0001
                    for (actual_char, actual_font, actual_size), (expected_char, expected_font, expected_size)
                    in zip(candidate_styled, reference_styled)), 'Text, face, size or wrapping mismatch: ' + case['id'])
                lines.append({'case': case['id'], 'line': index, 'contentTopPoints': case['textContentTopEMU'] / 12700,
                              'officeBaselinePoints': baseline, 'candidateBaselinePoints': candidate_y,
                              'differencePoints': candidate_y - baseline, 'officeSpans': spans})
    require(verified == 268 and len(lines) == 46 and len({line['case'] for line in lines}) == 30,
            'Pinned fixture coverage changed')
    maximum = max(abs(line['differencePoints']) for line in lines)
    return {'scope': 'Baseline-only vector diagnostic. Native PNG gate remains independent and unchanged.',
            'tools': versions, 'checkerSHA256': digest(Path(__file__)),
            'pdfSHA256': capture['files']['text-baseline-v1-office.pdf'],
            'pptxSHA256': source['sha256'], 'candidateSVGs': candidates,
            'verifiedGlyphOutlines': verified, 'caseCount': 30, 'lineCount': len(lines),
            'baselineTolerancePoints': BASELINE_TOLERANCE_POINTS,
            'maximumBaselineDifferencePoints': maximum, 'passed': maximum <= BASELINE_TOLERANCE_POINTS,
            'lines': lines}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fonts', type=Path, required=True)
    parser.add_argument('--candidates', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        report = check(args)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({key: value for key, value in report.items() if key != 'lines'}, indent=2))
        return 0 if report['passed'] else 1
    except (ValueError, KeyError, OSError, ImportError) as error:
        print('Office baseline check refused: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
