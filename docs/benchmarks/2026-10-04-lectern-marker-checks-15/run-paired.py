from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import time

BASE = Path(__file__).resolve().parent
OUT = BASE / 'paired'
assert not OUT.exists(), 'A campaign already exists; do not silently repeat it.'
OUT.mkdir()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(name, data):
    (OUT / name).write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')

def validate_products():
    checked = {}
    for kind in ('baseline', 'candidate'):
        receipt_path = BASE / f'{kind}-products-pins.json'
        receipt = json.loads(receipt_path.read_text())
        entries = receipt['files'] if kind == 'baseline' else receipt['products']
        for relative, expected in entries.items():
            path = BASE / f'{kind}-products' / relative
            actual = sha(path)
            assert actual == expected, (path, actual, expected)
            checked[str(path)] = actual
    for name in ('benchmark-plan.json', 'benchmark-memory-addendum.json'):
        checked[str(BASE / name)] = sha(BASE / name)
    return checked

def host_snapshot(name):
    raw = subprocess.check_output(['ps', '-axo', 'pid,pcpu,comm'], text=True)
    wanted = ('WindowServer', 'backupd', 'photoanalysisd', 'mdworker', 'mds',
              'swift', 'xcodebuild', 'MarkerAuditProbe', 'rostrum-benchmark',
              'native-benchmark', 'LecternCorePackageTests')
    rows = [line for line in raw.splitlines() if any(term in line for term in wanted)]
    write(name, {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'rows': rows})

pins_before = validate_products()
source_receipt = json.loads((BASE / 'candidate-products-pins.json').read_text())
for path, expected in source_receipt['sourceFiles'].items():
    assert sha(BASE.parents[1] / path) == expected, path
write('pins-before.json', pins_before)
host_snapshot('host-start.json')
started = time.perf_counter()
rows = []
reference_artifacts = {}
reference_reports = {}
expected_native_source = {
    False: '35f93dacab1c562d2c9ac621b8e80232c5c9425bf6e2db2c10225140a255e05f',
    True: '67dbf7b5156c3903fab4470f85ba28c0158d992ea6fe68776be783241724e5e1',
}
try:
    for alternative in (False, True):
        label = str(alternative).lower()
        for pair in range(11):
            order = ('baseline', 'candidate') if pair % 2 == 0 else ('candidate', 'baseline')
            for kind in order:
                stem = f'{label}-{pair:02d}-{kind}'
                argv = ['/usr/bin/time', '-l', str(BASE / f'{kind}-products' / 'MarkerAuditProbe'),
                        str(OUT / 'artifacts' / stem), label]
                begin = time.perf_counter()
                result = subprocess.run(argv, capture_output=True, text=True)
                child_wall = time.perf_counter() - begin
                (OUT / f'{stem}-stdout.json').write_text(result.stdout)
                (OUT / f'{stem}-stderr.log').write_text(result.stderr)
                assert result.returncode == 0, (stem, result.returncode)
                record = json.loads(result.stdout)
                assert record['passed'] and record['checks'] == 58
                assert record['findings'] == 0 and record['slides'] == 5
                assert record['alternative'] == alternative
                rss = re.search(r'^\s*(\d+)\s+maximum resident set size\s*$', result.stderr, re.M)
                assert rss, (stem, 'Missing whole-process RSS')
                folder = Path(record['directory'])
                artifacts = {str(p.relative_to(folder)): sha(p)
                             for p in sorted(folder.rglob('*')) if p.is_file() and p.name != 'report.json'}
                assert artifacts['listMarkers.pptx'] == expected_native_source[alternative]
                report = json.loads((folder / 'report.json').read_text())
                assert set(report) == {'checks', 'elapsedSeconds', 'findings', 'limitations', 'operations',
                                       'options', 'recipe', 'slideCount', 'title'}
                report.pop('elapsedSeconds')
                if alternative not in reference_artifacts:
                    reference_artifacts[alternative] = artifacts
                    reference_reports[alternative] = report
                assert artifacts == reference_artifacts[alternative], (stem, 'Artifact mismatch')
                assert report == reference_reports[alternative], (stem, 'Report mismatch beyond elapsedSeconds')
                rows.append({'alternative': alternative, 'pair': pair, 'warmup': pair == 0,
                             'kind': kind, 'order': list(order), 'argv': argv, 'exitCode': result.returncode,
                             'seconds': record['seconds'], 'childWallSeconds': child_wall,
                             'peakRSSBytes': int(rss.group(1)), 'directory': str(folder),
                             'reportSHA256': sha(folder / 'report.json'), 'artifactHashes': artifacts,
                             'stdoutSHA256': sha(OUT / f'{stem}-stdout.json'),
                             'stderrSHA256': sha(OUT / f'{stem}-stderr.log')})
                write('raw.json', rows)
            if pair == 5:
                host_snapshot(f'host-{label}-midpoint.json')
        host_snapshot(f'host-{label}-complete.json')
    assert len(rows) == 44
    pins_after = validate_products()
    assert pins_before == pins_after
    write('pins-after.json', pins_after)
    host_snapshot('host-end.json')
    write('execution-receipt.json', {'status': 'PASS', 'freshChildren': len(rows),
          'elapsedSeconds': time.perf_counter() - started, 'artifactsExactPerAlternative': True,
          'reportsExactExceptElapsedSeconds': True, 'nativeSourceIdentity': expected_native_source,
          'inputProductsUnchanged': True, 'runnerSHA256': sha(Path(__file__))})
    print('PASS: 44 children; exact packages, SVGs, exports and report checks for both alternatives.', flush=True)
except BaseException as error:
    write('failure.json', {'error': repr(error), 'completedChildren': len(rows),
                          'elapsedSeconds': time.perf_counter() - started})
    raise
