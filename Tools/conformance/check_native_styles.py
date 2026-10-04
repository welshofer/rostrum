#!/usr/bin/env python3
"""Compare all 1,480 cell-fill probes against pinned PowerPoint PNGs.

Requires resvg-py 0.5.0 and Pillow 12.3.0. This checks sampled fills only;
text, borders, effects, general gradients and whole-slide fidelity are separate.
"""
import argparse
import hashlib
import importlib.metadata
import io
import json
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET
from PIL import Image
import resvg_py


def digest(data):
    return hashlib.sha256(data).hexdigest()


def compare(svg_directory, fixture_directory):
    manifest = json.loads((fixture_directory/'manifest.json').read_text())
    for name, expected in manifest['sha256'].items():
        if digest((fixture_directory/name).read_bytes()) != expected:
            raise ValueError(f'pinned fixture hash differs: {name}')
    failures = []
    candidate_hashes = {}
    count = 0
    with zipfile.ZipFile(fixture_directory/manifest['references']) as references:
        for style in manifest['styles']:
            reference_bytes = references.read(style['reference'])
            if digest(reference_bytes) != style['sha256']:
                raise ValueError(f'pinned reference hash differs: {style["reference"]}')
            expected = Image.open(io.BytesIO(reference_bytes)).convert('RGB')
            candidate = svg_directory/f'slide-{style["slide"]:02d}.svg'
            candidate_hashes[candidate.name] = digest(candidate.read_bytes())
            svg = ET.fromstring(candidate.read_text())
            if svg.attrib.get('viewBox') != '0 0 10972800 6400800':
                raise ValueError('candidate must retain the 12x7-inch fixture viewBox')
            # Match the reference viewport, avoiding the integer 1280x747
            # default SVG viewport's one-pixel rounding at a 1200px export.
            svg.set('width', '1200'); svg.set('height', '700')
            rendered = resvg_py.svg_to_bytes(svg_string=ET.tostring(svg, encoding='unicode'),
                                            width=1200, height=700, skip_system_fonts=True)
            actual = Image.open(io.BytesIO(rendered)).convert('RGB')
            if actual.size != expected.size or actual.size != (1200, 700):
                raise ValueError('reference and candidate must be 1200x700')
            for row in range(5):
                for column in range(4):
                    point = (round(50+(column+.5)*275), round(100+(row+.5)*80))
                    a, b = actual.getpixel(point), expected.getpixel(point)
                    count += 1
                    if max(abs(x-y) for x,y in zip(a,b)) > manifest['channelTolerance']:
                        failures.append({'slide': style['slide'], 'style': style['name'], 'row': row,
                                         'column': column, 'actual': a, 'expected': b})
    return {'probes': count, 'passed': count-len(failures), 'failures': failures,
            'scope': manifest['scope'], 'candidateSHA256': candidate_hashes,
            'fixtureSHA256': manifest['sha256'],
            'rasterizer': 'resvg-py 0.5.0', 'imageReader': 'Pillow 12.3.0',
            'viewport': [1200, 700], 'channelTolerance': manifest['channelTolerance']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('svg_directory', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    for name, version in [('resvg-py','0.5.0'), ('Pillow','12.3.0')]:
        if importlib.metadata.version(name) != version: parser.error(f'requires {name}=={version}')
    fixtures = Path(__file__).resolve().parents[2]/'Tests/RostrumTests/Fixtures/NativeTableStyles'
    result = compare(args.svg_directory, fixtures)
    if args.report: args.report.write_text(json.dumps(result, indent=2)+'\n')
    print(f'{result["passed"]}/{result["probes"]} PowerPoint cell-fill probes passed')
    for failure in result['failures'][:10]: print(json.dumps(failure))
    return 1 if result['failures'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
