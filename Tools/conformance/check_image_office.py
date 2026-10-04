#!/usr/bin/env python3
"""Compare independent Office image references with rendered candidate SVGs.

Pins the producer fixture and every reference byte, requires exact raster tool
versions, normalizes only the SVG viewport, and keeps channel16/fraction0.005.
Image-only fixtures use no text and no system fonts. References are never edited.
"""
import argparse
import hashlib
import importlib.metadata
import io
import json
from pathlib import Path
import re
import zipfile
from compare_images import compare


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('svg_directory', type=Path)
    parser.add_argument('--variant', choices=['v1', 'v2'], default='v2')
    parser.add_argument('--width', type=int, default=1200)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    versions = {name: importlib.metadata.version(name) for name in ('resvg-py', 'Pillow')}
    if versions != {'resvg-py': '0.5.0', 'Pillow': '12.3.0'}:
        parser.error('requires resvg-py==0.5.0 and Pillow==12.3.0')
    import resvg_py
    from PIL import Image
    manifest = json.loads(args.manifest.read_text())
    root = args.manifest.parent
    variant = next(item for item in manifest['variants'] if item['id'] == args.variant)
    source = root / variant['source']
    if sha(source.read_bytes()) != variant['sourceSHA256']:
        parser.error('producer fixture hash mismatch')
    reference = next((item for item in variant['referenceSets'] if item['width'] == args.width), None)
    if reference is None:
        parser.error('no reference at this size')
    archive = root / manifest['referenceArchive']
    if sha(archive.read_bytes()) != manifest['referenceArchiveSHA256']:
        parser.error('reference archive hash mismatch')
    if len(reference['files']) != len(variant['cases']):
        parser.error('reference count does not match authored cases')
    args.output.mkdir(parents=True, exist_ok=True)
    report = {'variant': args.variant, 'sourceSHA256': variant['sourceSHA256'],
              'referenceArchiveSHA256': manifest['referenceArchiveSHA256'],
              'versions': versions, 'width': reference['width'], 'height': reference['height'],
              'channelTolerance': 16, 'fractionTolerance': 0.005, 'cases': [], 'passed': True}
    with zipfile.ZipFile(archive) as references:
        for case, ref in zip(variant['cases'], reference['files']):
            if case['slide'] != ref['slide']:
                parser.error('reference slide order mismatch')
            pixels = references.read(ref['member'])
            if sha(pixels) != ref['sha256']:
                parser.error('reference PNG hash mismatch')
            if Image.open(io.BytesIO(pixels)).size != (reference['width'], reference['height']):
                parser.error('reference dimensions differ from manifest')
            source_svg = args.svg_directory / f"slide-{case['slide']:02}.svg"
            original = source_svg.read_text()
            match = re.search(r'<svg\b[^>]*>', original)
            if match is None:
                parser.error('missing SVG root')
            viewport = match.group()
            viewbox = re.search(r'\bviewBox="([^"]*)"', viewport)
            coordinates = list(map(float, viewbox.group(1).split())) if viewbox else []
            if len(coordinates) != 4 or coordinates[:2] != [0, 0] or coordinates[2:] != [10972800, 6400800]:
                parser.error('unexpected image fixture viewBox')
            for attribute in ('width', 'height'):
                viewport, count = re.subn(rf'\b{attribute}="[^"]*"', f'{attribute}="{reference[attribute]}"', viewport)
                if count != 1:
                    parser.error('missing or duplicate SVG dimensions')
            normalized = original[:match.start()] + viewport + original[match.end():]
            rendered = resvg_py.svg_to_bytes(svg_string=normalized, skip_system_fonts=True)
            candidate_path = args.output / f"slide-{case['slide']:02}-candidate.png"
            reference_path = args.output / f"slide-{case['slide']:02}-reference.png"
            candidate_path.write_bytes(rendered)
            reference_path.write_bytes(pixels)
            result = compare(reference_path, candidate_path)
            report['cases'].append({'id': case['id'], 'slide': case['slide'],
                                    'svgSHA256': sha(original.encode()), 'normalizedSVGSHA256': sha(normalized.encode()),
                                    'candidateSHA256': sha(rendered), 'referenceSHA256': ref['sha256'], **result})
            report['passed'] &= result['passed']
    (args.output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'passed': report['passed'], 'cases': len(report['cases']), 'report': str(args.output / 'report.json')}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
