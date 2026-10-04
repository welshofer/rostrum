#!/usr/bin/env python3
"""Compare Rostrum SVG text with an independent fixed-size PNG using exact fonts.

resvg-py 0.5.0 ignores CSS @font-face data URLs. This development-only adapter
verifies every embedded face against a caller-supplied local-font manifest,
resolves its generated alias to the actual SFNT family, and explicitly loads
only those files. It never substitutes an unverified font. No fonts are copied.

Manifest: {"fonts": [{"family": "Calibri", "path": "/local/Calibri.ttf",
                       "sha256": "<64 hex digits>"}, ...]}
Paths may be relative to the manifest. Install resvg-py==0.5.0 and Pillow==12.3.0
in an isolated development environment. Output contains PNGs and JSON evidence,
not an embedded-font SVG. Exit 1 means the unchanged pixel gate failed; exit 2
means inputs/dependencies could not be verified. This tool covers generated SVG
with explicit text attributes, not arbitrary SVG/CSS layout.
"""
import argparse
import base64
import hashlib
import importlib.metadata
from io import BytesIO
import json
import math
from pathlib import Path
import re
import struct
import sys
from xml.etree import ElementTree as ET

SVG = 'http://www.w3.org/2000/svg'
FACE = re.compile(r"@font-face\{font-family:'([^']+)';font-style:(normal|italic);font-weight:([1-9]00);src:url\(data:font/(?:ttf|otf);base64,([A-Za-z0-9+/=]+)\) format\('(?:truetype|opentype)'\);\}")
MAX_FONT_BYTES = 64 * 1024 * 1024
MAX_SVG_BYTES = 128 * 1024 * 1024
TOLERANCE = 16
MAX_DIFFERENCE_FRACTION = 0.005


def require(condition, message):
    if not condition:
        raise ValueError(message)


def font_families(data):
    """Read standard name IDs 1/16 to validate the requested physical family."""
    require(len(data) >= 12 and data[:4] in (b'\x00\x01\x00\x00', b'OTTO', b'true'),
            'Only standalone SFNT fonts are supported by this oracle adapter')
    count = struct.unpack_from('>H', data, 4)[0]
    require(12 + 16 * count <= len(data), 'Truncated SFNT directory')
    names = None
    for i in range(count):
        tag, _, offset, length = struct.unpack_from('>4sIII', data, 12 + 16 * i)
        require(offset + length <= len(data), 'SFNT table exceeds font bounds')
        if tag == b'name':
            require(names is None, 'Duplicate SFNT name table')
            names = data[offset:offset + length]
    require(names is not None and len(names) >= 6, 'Missing SFNT name table')
    _, count, strings = struct.unpack_from('>HHH', names)
    require(6 + 12 * count <= len(names), 'Truncated SFNT name records')
    families = set()
    for i in range(count):
        platform, _, _, identifier, length, offset = struct.unpack_from('>6H', names, 6 + 12 * i)
        require(strings + offset + length <= len(names), 'SFNT name string exceeds table bounds')
        if identifier in (1, 16) and platform in (0, 1, 3):
            raw = names[strings + offset:strings + offset + length]
            families.add(raw.decode('mac_roman' if platform == 1 else 'utf-16-be'))
    return families


def local_fonts(manifest_path):
    records = json.loads(manifest_path.read_text())['fonts']
    require(isinstance(records, list) and 0 < len(records) <= 256, 'Expected 1–256 font manifest entries')
    by_hash = {}
    for record in records:
        family, digest = record['family'], record['sha256'].lower()
        require(isinstance(family, str) and family and not re.search(r"[,'\"\r\n]", family), 'Unsupported physical family name')
        require(re.fullmatch('[0-9a-f]{64}', digest), 'Invalid font SHA-256')
        path = Path(record['path'])
        if not path.is_absolute():
            path = manifest_path.parent / path
        require(path.is_file() and path.stat().st_size <= MAX_FONT_BYTES, f'Missing or oversized font: {path}')
        data = path.read_bytes()
        require(hashlib.sha256(data).hexdigest() == digest, f'Font hash mismatch: {path}')
        require(family in font_families(data), f'Family {family!r} is not declared by {path}')
        require(digest not in by_hash, f'Ambiguous duplicate font hash: {digest}')
        by_hash[digest] = {'family': family, 'path': str(path.resolve()), 'sha256': digest}
    return by_hash


def prepare(svg, fonts, width, height):
    root = ET.fromstring(svg)
    require(root.tag == '{' + SVG + '}svg', 'Expected an SVG root')
    view = [float(x) for x in root.attrib.get('viewBox', '').replace(',', ' ').split()]
    require(len(view) == 4 and all(math.isfinite(x) for x in view) and view[2] > 0 and view[3] > 0,
            'A finite positive viewBox is required')
    require(abs(view[2] / view[3] - width / height) <= 1e-6, 'Reference size and SVG viewBox aspect differ')
    # The generated integer CSS width/height may round the aspect ratio. Render
    # both comparators at the independently recorded reference dimensions.
    root.set('width', str(width)); root.set('height', str(height))
    aliases = {}
    styles = []
    for parent in root.iter():
        for child in parent:
            if child.tag == '{' + SVG + '}style':
                css = child.text or ''
                matches = list(FACE.finditer(css))
                require(not FACE.sub('', css).strip(), 'Unsupported CSS in generated SVG')
                for match in matches:
                    alias, style, weight, encoded = match.groups()
                    data = base64.b64decode(encoded, validate=True)
                    require(len(data) <= MAX_FONT_BYTES, 'Embedded font exceeds budget')
                    digest = hashlib.sha256(data).hexdigest()
                    require(alias not in aliases, f'Duplicate embedded font alias: {alias}')
                    require(digest in fonts, f'No hash-verified local font for {alias}: {digest}')
                    aliases[alias] = dict(fonts[digest], style=style, weight=int(weight))
                styles.append((parent, child))
    require(aliases, 'No verifiable embedded font aliases found')
    original = ET.tostring(root, encoding='unicode')
    for parent, style in styles:
        parent.remove(style)
    stripped = ET.tostring(root, encoding='unicode')
    used = set()
    def visit(node, family=None, inside_text=False):
        require('style' not in node.attrib, 'Inline CSS is outside the generated-SVG oracle profile')
        for key, value in node.attrib.items():
            if key.split('}')[-1] == 'href':
                require(value.startswith(('#', 'data:')), 'External SVG resources are not permitted')
        own = node.attrib.get('font-family')
        if own is not None:
            first = own.split(',')[0].strip().strip("'\"")
            require(first in aliases, f'Unresolved text font alias: {first}')
            family = first
            node.set('font-family', aliases[first]['family'])
        inside_text = inside_text or node.tag == '{' + SVG + '}text'
        if inside_text and node.text:
            require(family in aliases, 'Text has no verified font alias')
            used.add(family)
        for child in node:
            visit(child, family, inside_text)
            if inside_text and child.tail and child.tail.strip():
                require(family in aliases, 'Text tail has no verified font alias')
                used.add(family)
    visit(root)
    require(used, 'No text using verified fonts was found')
    return original, stripped, ET.tostring(root, encoding='unicode'), aliases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--svg', type=Path, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--fonts', type=Path, required=True)
    parser.add_argument('--width', type=int, required=True)
    parser.add_argument('--height', type=int, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        for package, version in [('resvg-py', '0.5.0'), ('Pillow', '12.3.0')]:
            require(importlib.metadata.version(package) == version, f'{package}=={version} required')
        import resvg_py
        from PIL import Image, ImageChops
        require(0 < args.width <= 16384 and 0 < args.height <= 16384
                and args.width * args.height <= 32_000_000, 'Invalid or oversized reference dimensions')
        require(args.svg.stat().st_size <= MAX_SVG_BYTES, 'SVG exceeds input budget')
        reference = Image.open(args.reference)
        require(reference.size == (args.width, args.height), 'Reference PNG dimensions do not match requested dimensions')
        require(reference.format == 'PNG', 'Reference must be an independently captured PNG')
        reference = reference.convert('RGB')
        original, stripped, corrected, aliases = prepare(args.svg.read_text(), local_fonts(args.fonts), args.width, args.height)
        options = dict(width=args.width, height=args.height)
        before = resvg_py.svg_to_bytes(svg_string=original, **options)
        without = resvg_py.svg_to_bytes(svg_string=stripped, **options)
        after = resvg_py.svg_to_bytes(svg_string=corrected, skip_system_fonts=True,
            font_files=sorted({record['path'] for record in aliases.values()}), **options)
        report = {'rasterizer': 'resvg-py 0.5.0', 'imageReader': 'Pillow 12.3.0',
            'svgSHA256': hashlib.sha256(args.svg.read_bytes()).hexdigest(),
            'referenceSHA256': hashlib.sha256(args.reference.read_bytes()).hexdigest(),
            'width': args.width, 'height': args.height, 'fontAliases': aliases,
            'dimensionPolicy': 'Both SVG roots use the verified reference dimensions and matching viewBox aspect',
            'embeddedStylesIgnored': before == without,
            'channelTolerance': TOLERANCE, 'maximumDifferenceFraction': MAX_DIFFERENCE_FRACTION}
        for label, data in [('original', before), ('corrected', after)]:
            candidate = Image.open(BytesIO(data)).convert('RGB')
            require(candidate.size == reference.size, 'Rasterizer returned unexpected dimensions')
            difference = ImageChops.difference(reference, candidate)
            changed = sum(max(pixel) > TOLERANCE for pixel in difference.get_flattened_data())
            report[label] = {'differingPixels': changed, 'fraction': changed / (args.width * args.height)}
        report['passed'] = report['corrected']['fraction'] <= MAX_DIFFERENCE_FRACTION
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / 'original.png').write_bytes(before)
        (args.output / 'corrected.png').write_bytes(after)
        (args.output / 'comparison.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2))
        return 0 if report['passed'] else 1
    except (ValueError, KeyError, OSError, TypeError, struct.error, UnicodeError, ET.ParseError,
            importlib.metadata.PackageNotFoundError) as error:
        print(f'Font-aware comparison refused: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
