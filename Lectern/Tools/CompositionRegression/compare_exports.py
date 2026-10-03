#!/usr/bin/env python3
"""Compare PowerPoint exports; pixel equality is not a visual quality verdict.
Requires Pillow. Never renders slides or certifies unreviewed output.
"""
import argparse
import hashlib
import json
import re
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image, ImageChops, ImageStat


def exports(directory):
    found = {}
    for path in Path(directory).iterdir():
        if path.suffix.lower() not in ('.png', '.jpg', '.jpeg'):
            continue
        match = re.search(r'(\d+)$', path.stem)
        if not match:
            continue
        number = int(match[1])
        if number in found:
            raise ValueError(f'Duplicate slide {number}')
        found[number] = path
    if not found or sorted(found) != list(range(1, len(found) + 1)):
        raise ValueError('Exports must contain consecutive numbered slides starting at 1')
    return found


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    record = sub.add_parser('record', help='Record a completed human PowerPoint review')
    record.add_argument('deck', type=Path)
    record.add_argument('exports', type=Path)
    record.add_argument('manifest', type=Path)
    record.add_argument('--reviewer', required=True)
    record.add_argument('--powerpoint-version', required=True)
    record.add_argument('--reviewed-slides', required=True, help='Every reviewed slide number, comma separated')
    record.add_argument('--font-substitutions', default='None observed')
    compare = sub.add_parser('compare')
    compare.add_argument('baseline', type=Path)
    compare.add_argument('exports', type=Path)
    compare.add_argument('output', type=Path)
    args = parser.parse_args()
    current = exports(args.exports)
    if args.command == 'record':
        with zipfile.ZipFile(args.deck) as package:
            presentation = ET.fromstring(package.read('ppt/presentation.xml'))
            slide_count = len(presentation.findall('{http://schemas.openxmlformats.org/presentationml/2006/main}sldIdLst/{http://schemas.openxmlformats.org/presentationml/2006/main}sldId'))
        if len(current) != slide_count:
            parser.error('Export count must match the presentation slide count')
        reviewed = {int(n) for n in args.reviewed_slides.split(',')}
        if reviewed != set(current):
            parser.error('Every exported slide needs explicit review')
        if not args.reviewer.strip() or not args.powerpoint_version.strip():
            parser.error('Reviewer and PowerPoint version must be identified')
        records = [{'slide': n, 'path': str(p.resolve()), 'sha256': digest(p),
                    'size': list(Image.open(p).size)} for n, p in sorted(current.items())]
        data = dict(deck=str(args.deck.resolve()), deckSHA256=digest(args.deck),
                    reviewer=args.reviewer, powerpointVersion=args.powerpoint_version,
                    fontSubstitutions=args.font_substitutions, slides=records)
        args.manifest.write_text(json.dumps(data, indent=2) + '\n')
        return 0
    baseline = json.loads(args.baseline.read_text())
    prior = {item['slide']: item for item in baseline['slides']}
    if set(prior) != set(current):
        parser.error('Slide counts differ; review the structural change first')
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    for n, path in sorted(current.items()):
        old = prior[n]
        if digest(old['path']) != old['sha256']:
            parser.error(f'Baseline slide {n} changed after its recorded review')
        with Image.open(old['path']) as a, Image.open(path) as b:
            if a.size != b.size:
                parser.error(f'Slide {n} dimensions differ; export at the same size')
            difference = ImageChops.difference(a.convert('RGB'), b.convert('RGB'))
            changed = difference.getbbox() is not None
            records.append(dict(slide=n, status='review-required' if changed else 'unchanged',
                                meanChannelDifference=ImageStat.Stat(difference).mean))
            if changed:
                difference.save(args.output / f'Slide{n}-difference.png')
    (args.output / 'comparison.json').write_text(json.dumps(records, indent=2) + '\n')
    print(json.dumps(records, indent=2))
    return int(any(r['status'] == 'review-required' for r in records))


if __name__ == '__main__':
    raise SystemExit(main())
