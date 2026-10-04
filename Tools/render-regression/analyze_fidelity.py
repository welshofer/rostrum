#!/usr/bin/env python3
"""Diagnose the 1200x700 python-tables-v3 comparison without changing its gate.

Requires Pillow==12.3.0 and resvg-py==0.5.0. The candidate must already have
been rasterized using verified fonts (see conformance/check_text_rendering.py).
The fixed border zones apply only to this fixture. The standalone stroke and
its 2x area-sampled rendering are supplemental diagnostics, never acceptance.
"""
import argparse
import hashlib
import importlib.metadata
from io import BytesIO
import json
from pathlib import Path
import platform
import sys

from PIL import Image, ImageChops
import resvg_py

CONFORMANCE = Path(__file__).resolve().parents[1] / 'conformance'
sys.path.insert(0, str(CONFORMANCE))
from compare_images import compare

VERTICAL = [(100, 100, 600), (400, 350, 600), (600, 100, 600),
            (850, 100, 600), (1100, 100, 600)]
HORIZONTAL = [(100, 100, 1100), (225, 600, 1100), (350, 100, 1100),
              (475, 100, 1100), (600, 100, 1100)]
PADDING = 4


def identity(path):
    try:
        label = path.resolve().relative_to(CONFORMANCE.parents[1])
    except ValueError:
        label = path
    return {'path': str(label), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def on_white(path):
    with Image.open(path) as image:
        rgba = image.convert('RGBA')
    return Image.alpha_composite(Image.new('RGBA', rgba.size, 'white'), rgba).convert('RGB')


def stroke_zone(x, y):
    return (any(abs(x - c) <= PADDING and lo - PADDING <= y <= hi + PADDING
                for c, lo, hi in VERTICAL)
            or any(abs(y - c) <= PADDING and lo - PADDING <= x <= hi + PADDING
                   for c, lo, hi in HORIZONTAL))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--candidate-revision', help='Revision that produced the supplied candidate')
    args = parser.parse_args()
    versions = {name: importlib.metadata.version(name) for name in ['Pillow', 'resvg-py']}
    if versions != {'Pillow': '12.3.0', 'resvg-py': '0.5.0'}:
        parser.error('Pillow==12.3.0 and resvg-py==0.5.0 are required')
    # Match the unchanged comparator's white-background alpha policy.
    reference, candidate = on_white(args.reference), on_white(args.candidate)
    if reference.size != (1200, 700) or candidate.size != reference.size:
        parser.error('The fixed python-tables-v3 zones require two 1200x700 images')
    acceptance = compare(args.reference, args.candidate)
    tolerance = acceptance['channelTolerance']
    difference = ImageChops.difference(reference, candidate)
    total = borders = 0
    for index, pixel in enumerate(difference.get_flattened_data()):
        if max(pixel) > tolerance:
            total += 1
            borders += stroke_zone(index % 1200, index // 1200)

    fixture = Path(__file__).with_name('fixtures') / 'fractional-stroke.svg'
    svg = fixture.read_text()
    native = Image.open(BytesIO(resvg_py.svg_to_bytes(svg_string=svg))).convert('RGB')
    high = Image.open(BytesIO(resvg_py.svg_to_bytes(svg_string=svg, width=2400, height=1400)))
    sampled = high.convert('RGB').resize((1200, 700), Image.Resampling.BOX)
    coverage = (25400 / 9144) / 2 - 1
    report = {
        'schema': 1,
        'scope': 'Supplemental fixture-specific diagnosis. No acceptance thresholds, references, or renderer geometry are changed.',
        'tools': dict(versions, python=platform.python_version()),
        'inputs': {'candidate': identity(args.candidate), 'reference': identity(args.reference)},
        'candidateRevision': args.candidate_revision,
        'analysisSource': identity(Path(__file__)),
        'acceptanceSource': identity(CONFORMANCE / 'compare_images.py'),
        'unchangedAcceptance': acceptance,
        'partition': {
            'dimensions': [1200, 700], 'differingPixels': total,
            'strokeZonePixels': borders, 'outsideStrokeZonePixels': total - borders,
            'outsideStrokeZoneInterpretation': 'Text for this fixture; this classification is not general-purpose.',
            'zones': {'verticalXAndYRange': VERTICAL, 'horizontalYAndXRange': HORIZONTAL,
                      'paddingPixels': PADDING, 'boundsInclusive': True}},
        'standaloneStrokeDiagnostic': {
            'scope': 'Independent SVG primitive; no Rostrum, fonts, or EMU-coordinate transforms. Supplemental only.',
            'fixture': identity(fixture), 'samplePixel': [300, 98],
            'strokeWidthPixels': 25400 / 9144,
            'mathematicalCoverage': coverage,
            'mathematicalRGBApprox': [round(255 + (c - 255) * coverage) for c in [204, 51, 0]],
            'officeReferenceRGB': reference.getpixel((300, 98)),
            'nativeResvgRGB': native.getpixel((300, 98)),
            'supplemental2xBoxRGB': sampled.getpixel((300, 98))}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'report': str(args.output), 'unchangedAcceptance': acceptance,
                      'differingPixels': total, 'strokeZonePixels': borders,
                      'outsideStrokeZonePixels': total - borders}, indent=2))
    # Success means the diagnostic completed; use unchangedAcceptance.passed
    # (or run the existing conformance gate) for the actual acceptance result.


if __name__ == '__main__':
    main()
