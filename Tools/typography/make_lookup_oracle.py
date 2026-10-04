#!/usr/bin/env python3
"""Regenerate owned lookup-filter fixtures with HarfBuzz 14.4.0 (development only).

No font library or copied implementation is used: this assembles the minimal
OpenType tables documented by Microsoft. Glyphs use ASCII codepoints deliberately
so GDEF classification, rather than Unicode category heuristics, controls filters.
The generated outline-free test font and generator are under the repository license.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'Tests/RostrumTests/Fixtures/Typography'
def u16(*values): return b''.join(struct.pack('>H', value & 65535) for value in values)
def u32(*values): return b''.join(struct.pack('>I', value) for value in values)
def gid(char): return ord(char) - 31

def coverage(glyphs): return u16(1, len(glyphs), *glyphs)
def classes(mapping):
    return u16(2, len(mapping)) + b''.join(u16(g, g, c) for g, c in sorted(mapping.items()))

def layout(tag, records):
    lookups = []
    for left, right, flags, second in records:
        if tag == 'liga':
            sub = u16(1, 8, 1, 14) + coverage([gid(left)]) + u16(1, 4, 96, 2, gid(right))
            kind = 4
        else:
            values = u16(15, -20, -80) + (u16(5, 10, second) if second else b'')
            sub = u16(1, 12, 7, 7 if second else 0, 1, 18) + coverage([gid(left)])
            sub += u16(1, gid(right)) + values
            kind = 2
        header = u16(kind, flags, 1, 10 if flags & 16 else 8)
        if flags & 16: header += u16(0)
        lookups.append(header + sub)
    scripts = u16(1) + b'latn' + u16(8, 4, 0, 0, 65535, 1, 0)
    features = u16(1) + tag.encode() + u16(8, 0, len(lookups), *range(len(lookups)))
    offsets, body = [], b''
    for lookup in lookups:
        offsets.append(2 + 2 * len(lookups) + len(body)); body += lookup
    lookup_list = u16(len(lookups), *offsets) + body
    return u16(1, 0, 10, 10 + len(scripts), 10 + len(scripts) + len(features)) + scripts + features + lookup_list

def font():
    glyph_classes = {g: 1 for g in range(1, 96)}
    glyph_classes.update({gid('^'): 3, gid('~'): 3, gid('_'): 2, gid('#'): 4, gid('@'): 0, 96: 2})
    gclass = classes(glyph_classes)
    mclass = classes({gid('^'): 2, gid('~'): 1})
    marksets = u16(1, 1) + u32(8) + coverage([gid('^')])
    gdef = u16(1, 2, 14, 0, 0, 14 + len(gclass), 14 + len(gclass) + len(mclass)) + gclass + mclass + marksets
    cmap = u16(0, 1, 3, 1) + u32(12) + u16(4, 32, 0, 4, 4, 1, 0, 126, 65535, 0, 32, 65535, -31, 1, 0, 0)
    head = (u32(0x10000, 0, 0, 0x5F0F3CF5) + u16(0, 1000)).ljust(54, b'\0')
    hhea = (u32(0x10000) + u16(800, -200, 0)).ljust(34, b'\0') + u16(97)
    tables = {
        'head': head, 'hhea': hhea, 'maxp': u32(0x5000) + u16(97), 'cmap': cmap,
        'hmtx': b''.join(u16(900 if g == 96 else 600, 0) for g in range(97)),
        'GDEF': gdef,
        'GSUB': layout('liga', [('f','i',8,0), ('g','i',16,0), ('h','i',0x100,0), ('j','i',0x118,0), ('k','i',1,0), ('l','i',4,0), ('^','~',2,0)]),
        'GPOS': layout('kern', [('A','V',8,0), ('B','V',16,0), ('C','V',0x100,0), ('D','V',0x110,0), ('E','V',0x118,0), ('F','V',1,0), ('G','V',4,0), ('~','^',2,0), ('H','H',8,10)]),
    }
    directory, body = u32(0x10000) + u16(len(tables), 128, 3, 0), b''
    for tag, data in sorted(tables.items()):
        padded = data + b'\0' * (-len(data) % 4)
        checksum = sum(struct.unpack('>' + 'I' * (len(padded)//4), padded)) & 0xffffffff
        directory += tag.encode() + u32(checksum, 12 + 16 * len(tables) + len(body), len(data))
        body += padded
    return directory + body

TEXTS = ['fi', 'f^i', 'f~~i', 'f^i^', 'f^iV', 'g~i', 'g^i', 'h^i', 'h~i', 'j^~i', 'ki', 'k^i', 'l_i', '^A~', '^@~', '^#~',
         'AV', 'A^V', 'A~~V', 'B~V', 'B^V', 'C^V', 'C~V', 'D~V', 'D^V', 'E^~V', 'FV', 'F^V', 'G_V', 'HHH', 'H^HH', '~A^', '~@^', 'A#V', 'A@V']
def reference(path, texts):
    cases = []
    for text in texts:
        glyphs = json.loads(subprocess.check_output(['hb-shape', str(path), text, '--output-format=json', '--no-glyph-names', '--direction=ltr']))
        cases.append({'text': text, 'direction': 'ltr', 'supported': True, 'glyphs': glyphs})
    return cases

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local-font', type=Path, help='also record local-font evidence without copying font bytes')
    parser.add_argument('--local-output', type=Path)
    args = parser.parse_args()
    version = subprocess.check_output(['hb-shape', '--version'], text=True).splitlines()[0]
    if version != 'hb-shape (HarfBuzz) 14.4.0': parser.error('HarfBuzz 14.4.0 required')
    path = FIXTURE / 'LookupFlags.ttf'
    path.write_bytes(font())
    cases = reference(path, TEXTS)
    (FIXTURE / 'lookup-flags-harfbuzz-14.4.0.json').write_text(json.dumps(cases, indent=2) + '\n')
    manifest = {'engine': version, 'fontSHA256': hashlib.sha256(path.read_bytes()).hexdigest(), 'caseCount': len(cases)}
    (FIXTURE / 'lookup-flags-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if args.local_font:
        if not args.local_output: parser.error('--local-output required with --local-font')
        data = {'fontPath': str(args.local_font.resolve()), 'fontSHA256': hashlib.sha256(args.local_font.read_bytes()).hexdigest(),
                'engine': version, 'cases': reference(args.local_font, ['AV office', 'To WA fi fl ffi', 'Typography 123', 'f^i A^V'])}
        args.local_output.write_text(json.dumps(data, indent=2) + '\n')

if __name__ == '__main__': main()
