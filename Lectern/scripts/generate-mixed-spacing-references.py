#!/usr/bin/env python3
"""Project independent native mixed-face PDF evidence; never use Rostrum output."""
from pathlib import Path
import hashlib
import json
import shutil
import struct

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Tests/RostrumTests/Fixtures/NativeMixedFaceSpacing'
OUTPUT = ROOT / 'Lectern/Sources/LecternCore/Resources/LibraryLab'
PINS = {
    'base': ('4e12a5e02468873d34fadb0ea415836ee50fa92245d9e096721faee33013c014', '9d8c125d036eb15b0b0c3f2cf84e6a2b47f0f79812ca003a056814d74ca7268b'),
    'anchors': ('ade8628fe0ca6c69691ad0790e9678bf92aaa7d2cd3178b5723dcb5c2adc9ea0', '49ec14886c2dbee1701b25039f362c221569957742a20d82ea0b18dd84af1c64'),
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

reference = dict(scope='Finite native exact-point spacing for actual mixed faces with identical normalized Windows metrics. Shape context, zero reduction, compatible spacing and admitted scalar/paint profiles only. Computed 40pt fits are separate from native-selected autofit.', sources=[], faces=[], cases=[])
for page, (group, pins) in enumerate(PINS.items()):
    directory = SOURCE / group
    manifest = json.loads((directory / 'manifest.json').read_text())
    assert sha(directory / manifest['source']) == pins[0] == manifest['sourceSHA256']
    assert sha(directory / 'powerpoint.pdf') == pins[1] == manifest['pdfSHA256']
    reference['sources'].append(dict(group=group, source=manifest['source'], sourceSHA256=pins[0], nativePDFSHA256=pins[1], casesSHA256=sha(directory/'cases.json'), metricsSHA256=sha(directory/'native-mixed-face-metrics.json')))
    if page == 0:
        for key, face in manifest['faces'].items():
            path = directory / face['file']
            assert sha(path) == face['sha256']
            data = path.read_bytes()
            tables = {data[i:i+4]: struct.unpack_from('>II', data, i+8) for i in range(12,12+16*struct.unpack_from('>H',data,4)[0],16)}
            ascent, descent = struct.unpack_from('>HH', data, tables[b'OS/2'][0]+74)
            units = struct.unpack_from('>H',data,tables[b'head'][0]+18)[0]
            reference['faces'].append(dict(id=key, **face, windowsSignature=[ascent/(ascent+descent),(ascent+descent)/units]))
    native = {c['name']: c for c in json.loads((directory/'native-mixed-face-metrics.json').read_text())['cases']}
    for case in json.loads((directory/'cases.json').read_text()):
        measured = native[case['name']]
        assert measured['expectedVisibleScalars'] == measured['consumedVisibleScalars']
        reference['cases'].append(dict(id=case['name'], slide=page, source=manifest['source'], sourceGroup=group,
            x=case['x'],y=case['y'],width=case['width'],height=case['height'],expectedVisibleScalars=measured['expectedVisibleScalars'],
            lines=[dict(visibleText=line['visibleText'],baseline=line['baseline'],glyphs=[{key:g[key] for key in ['text','sourceFace','x','baseline','rawPDFPaintScale','sourceGlyphBounds','geometricInkBounds','sourceGlyphMatches']} for g in line['characters']]) for line in measured['lines']]))
    shutil.copyfile(directory/manifest['source'], OUTPUT/manifest['source'])
assert len(reference['cases']) == 12 and sum(c['expectedVisibleScalars'] for c in reference['cases']) == 96
assert reference['faces'][0]['windowsSignature'] == reference['faces'][1]['windowsSignature']
(OUTPUT/'MixedFaceSpacingReferences.json').write_text(json.dumps(reference,indent=2)+'\n')
