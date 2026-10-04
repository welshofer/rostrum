#!/usr/bin/env python3
"""Generate owned lookup data from pinned Unicode 17.0.0 DerivedJoiningType.
Usage: python3 Tools/typography/make_joining_data.py PATH_TO_DerivedJoiningType.txt
Unicode data license: Tests/RostrumTests/Fixtures/Typography/LICENSE-Unicode.txt.
"""
from pathlib import Path
import hashlib
import sys
source = Path(sys.argv[1]).read_bytes()
assert hashlib.sha256(source).hexdigest() == 'f39ebe974825d6736aee15582250307aa532b2cfab3caf3f86bd23fddc9c5c4d', 'Pinned Unicode 17.0.0 data required'
rows = []
for line in source.decode().splitlines():
    line = line.split('#')[0].strip()
    if not line: continue
    code, kind = map(str.strip, line.split(';'))
    bounds = code.split('..'); start, end = int(bounds[0], 16), int(bounds[-1], 16)
    rows.append((start, end, kind))
rows.sort()
root = Path(__file__).resolve().parents[2]
header = '''import Foundation

/// Generated from Unicode 17.0.0 DerivedJoiningType.txt; Unicode data license
/// is retained in Fixtures/Typography/LICENSE-Unicode.txt. Do not edit ranges.
/// Source: https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedJoiningType.txt
'''
header += '/// SHA256: ' + hashlib.sha256(source).hexdigest() + '\n'
header += '''enum ArabicJoining {
    enum Kind: UInt8 { case U, R, L, D, C, T }
    private struct Entry { let first: UInt32; let last: UInt32; let kind: Kind }
    static func kind(_ scalar: UInt32) -> Kind {
        var low = 0, high = entries.count
        while low < high {
            let mid = (low + high) / 2, entry = entries[mid]
            if scalar < entry.first { high = mid }
            else if scalar > entry.last { low = mid + 1 }
            else { return entry.kind }
        }
        return .U
    }
    static func isArabic(_ scalar: UInt32) -> Bool {
        (0x0600...0x06FF).contains(scalar) || (0x0750...0x077F).contains(scalar)
            || (0x0870...0x08FF).contains(scalar) || (0x10EC0...0x10EFF).contains(scalar)
    }
    private static let entries: [Entry] = [
'''
header += ''.join(f'        Entry(first: 0x{a:X}, last: 0x{b:X}, kind: .{k}),\n' for a,b,k in rows)
header += '    ]\n}\n'
(root/'Sources/Rostrum/Fonts/ArabicJoining.swift').write_text(header)
