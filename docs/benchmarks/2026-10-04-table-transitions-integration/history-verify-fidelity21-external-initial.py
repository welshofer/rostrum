from pathlib import Path
from zipfile import ZipFile
from datetime import datetime, timezone
import hashlib, json, subprocess
from lxml import etree
from pptx import Presentation

import argparse
parser=argparse.ArgumentParser();parser.add_argument('--root-gate-complete',action='store_true');parser.add_argument('--checkpoint',required=True);args=parser.parse_args()
assert args.root_gate_complete, 'Root must confirm completed gate before running proof.'
ROOT = Path('/path/to/user/Developer/rostrum')
PRIOR = json.loads(Path('/tmp/lectern-fidelity20-external.json').read_text())
KINDS = ['lab', 'alignment', 'markers', 'mixed', 'tables', 'table-pipeline', 'profiles', 'profiles-pipeline', 'partial', 'partial-pipeline', 'transitions', 'transitions-pipeline']
DIRS = {k: Path(f'/tmp/lectern-fidelity21-{k}') for k in KINDS}
OUT = Path('/tmp/lectern-fidelity21-external.json')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def pin(p): return {'path': str(p), 'sha256': sha(p)}
def parse(data): return etree.fromstring(data, etree.XMLParser(resolve_entities=False))
def package_diff(a, b):
    with ZipFile(a) as za, ZipFile(b) as zb:
        aa, bb = set(za.namelist()), set(zb.namelist())
        return {'added': sorted(aa-bb), 'removed': sorted(bb-aa),
                'changed': sorted(n for n in aa & bb if za.read(n) != zb.read(n))}
assert not OUT.exists(), 'Retain prior receipts; choose another output rather than overwrite.'
for p in DIRS.values(): assert p.is_dir(), p
files = sorted(p for d in DIRS.values() for p in d.rglob('*') if p.is_file())
before = {str(p): sha(p) for p in files}
fixture_dirs = [ROOT/'Tests/RostrumTests/Fixtures/NativeTableDefault', ROOT/'Tests/RostrumTests/Fixtures/NativeTableJoins', ROOT/'Tests/RostrumTests/Fixtures/NativeTableJoinProfiles', ROOT/'Tests/RostrumTests/Fixtures/NativeTableStyleFallback', ROOT/'Tests/RostrumTests/Fixtures/NativeTableTransitions']
fixture_files = sorted(p for d in fixture_dirs for p in d.rglob('*') if p.is_file())
fixture_before = {str(p): sha(p) for p in fixture_files}
subprocess.run(['git','diff','--exit-code','89aa1633cbbd07c152eb9e456c12e15686f7dbb8','--',*[str(p.relative_to(ROOT)) for p in fixture_dirs]],cwd=ROOT,check=True,stdout=subprocess.PIPE)
reports, packages, directories = [], [], []
for kind, directory in DIRS.items():
    ds = {'path': str(directory), 'fileCount': sum(directory in p.parents for p in files),
          'reports': 0, 'checks': 0, 'passedChecks': 0, 'findings': 0,
          'pptxReopens': 0, 'reopenedSlides': 0, 'xmlPartsParsed': 0}
    for p in sorted(directory.rglob('report.json')):
        report = json.loads(p.read_text())
        assert report['checks'] and all(c['passed'] for c in report['checks']), p
        reports.append(dict(report, **pin(p)))
        ds['reports'] += 1
        ds['checks'] += len(report['checks'])
        ds['passedChecks'] += sum(c['passed'] for c in report['checks'])
        ds['findings'] += len(report['findings'])
    for p in sorted(directory.rglob('*.pptx')):
        with ZipFile(p) as z:
            assert z.testzip() is None, p
            assert len(z.namelist()) == len(set(z.namelist())), p
            parts = [n for n in z.namelist() if n.endswith(('.xml', '.rels'))]
            for n in parts: parse(z.read(n))
        external = Presentation(p)
        count = len(external.slides)
        packages.append(dict(pin(p), slides=count, xmlParts=len(parts), zipCRC='PASS', externalReader='python-pptx'))
        ds['pptxReopens'] += 1
        ds['reopenedSlides'] += count
        ds['xmlPartsParsed'] += len(parts)
    directories.append(ds)
catalog_reports = [r for r in reports if str(DIRS['lab']) in r['path']]
assert len(catalog_reports) == 33 and len({r['recipe'] for r in catalog_reports}) == 33
assert len(reports) == 41
for report in reports:
    if report['recipe'] == 'tableDefaults':
        assert report['slideCount'] == 4 and len(report['checks']) == 63 and not report['findings'], report['path']
for report in reports:
    if report['recipe'] == 'tableJoinProfiles':
        assert report['slideCount'] == 3 and len(report['checks']) == 44 and not report['findings'], report['path']
for report in reports:
    if report['recipe'] == 'partialTableStyles':
        assert report['slideCount'] == 3 and len(report['checks']) == 62 and not report['findings'], report['path']
for report in reports:
    if report['recipe'] == 'tableTransitions':
        assert report['slideCount']==5 and len(report['checks'])==68 and not report['findings']
marker_report = next(r for r in reports if r['recipe'] == 'listMarkers')
assert marker_report['slideCount'] == 5 and not marker_report['findings']

identity, lab_differences = [], []; svg_roots=[]
for old_report in PRIOR['reports']:
    oldkind = next(k for k in KINDS if str(Path(f'/tmp/lectern-fidelity20-{k}')) + '/' in old_report['path'])
    current_report = next(r for r in reports if r['recipe'] == old_report['recipe'] and r['options'] == old_report['options'] and str(DIRS[oldkind]) + '/' in r['path'])
    olddir, newdir = Path(old_report['path']).parent, Path(current_report['path']).parent
    svg_roots.append((olddir,newdir))
    for old in sorted(olddir.rglob('*.pptx')):
        new = newdir / old.relative_to(olddir)
        assert new.is_file(), new
        entry = {'current': str(new), 'currentSHA256': sha(new), 'prior': str(old), 'priorSHA256': sha(old)}
        entry['byteIdentical'] = entry['currentSHA256'] == entry['priorSHA256']
        identity.append(entry)
        if not entry['byteIdentical']:
            lab_differences.append(dict(entry, parts=package_diff(new, old), classification='Requires explicit review of raw XML differences.'))

# Include all separately retained raw specimens, not only report packages.
mapped={row['prior'] for row in identity}
for old_entry in PRIOR['pptx']:
    old=Path(old_entry['path'])
    if str(old) in mapped: continue
    kind=next(k for k in KINDS if str(Path(f'/tmp/lectern-fidelity20-{k}'))+'/' in str(old))
    new=DIRS[kind]/old.relative_to(Path(f'/tmp/lectern-fidelity20-{kind}'))
    assert new.is_file() and sha(old)==old_entry['sha256'] and sha(new)==sha(old),(new,old)
    identity.append({'current':str(new),'currentSHA256':sha(new),'prior':str(old),'priorSHA256':sha(old),'byteIdentical':True})
for kind in ['alignment','markers','mixed','tables','profiles','partial']:
    svg_roots.append((Path(f'/tmp/lectern-fidelity20-{kind}'),DIRS[kind]))
svg_identity=[]
for olddir,newdir in svg_roots:
    old_svgs={p.relative_to(olddir):p for p in olddir.rglob('*.svg')}
    new_svgs={p.relative_to(newdir):p for p in newdir.rglob('*.svg')}
    assert old_svgs.keys()==new_svgs.keys(),(olddir,newdir,'SVG inventory')
    for relative,old in old_svgs.items():
        new=new_svgs[relative];assert sha(old)==sha(new),(old,new,'SVG changed')
        svg_identity.append({'prior':str(old),'current':str(new),'sha256':sha(new),'byteIdentical':True})
assert len(identity)==88 and len(lab_differences)==4
assert all(Path(e['current']).name in ['comments.pptx','comments-before.pptx','import-source.pptx','slideImport.pptx'] for e in lab_differences)
native_identity = []
for kind,recipe,nativeBase in [('alignment','textAlignment','/tmp/lectern-fidelity15-alignment-native'),('markers','listMarkers','/tmp/lectern-fidelity14-native'),('mixed','mixedFaceSpacing','/tmp/lectern-fidelity16-mixed-native'),('tables','tableDefaults','/tmp/lectern-fidelity17-tables-native'),('profiles','tableJoinProfiles','/tmp/lectern-fidelity19-generated-native/tableJoinProfiles'),('partial','partialTableStyles','/tmp/lectern-fidelity20-generated-native/partialTableStyles')]:
    for alternative in [False, True]:
        variant = str(alternative).lower()
        new = DIRS[kind] / f'alternative-{variant}/{recipe}.pptx'
        native = Path(nativeBase)/f'alternative-{variant}/{recipe}.pptx'
        assert sha(new)==sha(native), (new,native)
        native_identity.append({'current':str(new),'priorNativeSource':str(native),'sha256':sha(new),'byteIdentical':True,'kind':kind,'alternative':alternative})

for report in reports:
    if report['recipe'] not in ['tableDefaults', 'tableJoinProfiles', 'partialTableStyles', 'tableTransitions']: continue
    recipe = report['recipe']
    alternative = report['options']['alternative']
    current = Path(report['path']).parent/(recipe+'.pptx')
    base = '/tmp/lectern-fidelity17-tables-native' if recipe == 'tableDefaults' else '/tmp/lectern-fidelity19-generated-native/' + recipe
    if recipe == 'tableTransitions': base='/tmp/lectern-fidelity21-generated-native'
    native = Path(base)/f'alternative-{str(alternative).lower()}/{recipe}.pptx'
    assert sha(current)==sha(native), (current,native)
    native_identity.append({'current':str(current),'priorNativeSource':str(native),'sha256':sha(current),'byteIdentical':True,'kind':recipe+' report output','alternative':alternative})
fixture_after = {str(p): sha(p) for p in fixture_files}
assert fixture_before == fixture_after
after = {str(p): sha(p) for p in files}
assert before == after
result = {'status': 'EXTERNAL_REOPEN_AND_NATIVE_INPUT_IDENTITY_PASS',
          'createdUTC': datetime.now(timezone.utc).isoformat(),
          'checkpoint': args.checkpoint,
          'sourcesTree':subprocess.check_output(['git','rev-parse',args.checkpoint+':Sources'],cwd=ROOT,text=True).strip(),
          'scope': 'S21 output-preserving comparison: all prior SVGs exact; all88 prior packages exact except four strictly classified comment UUID/timestamp variations. All 33 catalog reports plus eight separately retained table-default/profile/partial-style/transition variant pipeline reports and their packages independently parsed/reopened. Native transfer requires exact source bytes; no new native rendering or whole-deck parity asserted here.',
          'directories': directories, 'reports': reports, 'pptx': packages,
          'catalogTotals': next(d for d in directories if d['path'] == str(DIRS['lab'])),
          'additionalTablePipelineReports': 8,
          'totals': {k: sum(d[k] for d in directories) for k in directories[0] if k != 'path'},
          'fixtureHashesBefore': fixture_before, 'fixtureHashesAfter': fixture_after, 'unchangedFixtureBytes': True,
          'fixtureCommit': '89aa1633cbbd07c152eb9e456c12e15686f7dbb8',
          'inputHashesBefore': before, 'inputHashesAfter': after, 'unchangedInputBytes': True,
          'priorGateIdentity': identity, 'priorSVGIdentity':svg_identity, 'wholePriorPackageCount':88, 'byteIdenticalPriorPackages':84, 'allPriorSVGBytesExact':True,
          'nativeSourceIdentity': native_identity, 'labPackageDifferences': lab_differences,
          'priorReceipt': pin('/tmp/lectern-fidelity20-external.json'), 'verifier': pin(__file__)}
OUT.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
print(json.dumps({'receipt': str(OUT), 'sha256': sha(OUT), 'totals': result['totals'], 'labPackageDifferences': len(lab_differences)}))
