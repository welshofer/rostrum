"""Compare retained -O drivers, with exact untimed transport reconstruction.

Run from the repository root; see PREVIEW-PREPARATION-20261016.md.
"""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import time


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline', type=Path, required=True)
parser.add_argument('--candidate', type=Path, required=True)
parser.add_argument('--baseline-source', type=Path, required=True)
parser.add_argument('--workload', action='append', required=True, help='NAME=absolute-manifest.json')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--pairs', type=int, default=5)
args = parser.parse_args()
if args.pairs < 1:
    parser.error('pairs must be positive')
args.output.mkdir(parents=True, exist_ok=False)
launcher = args.output / 'measure-child'
subprocess.run(['cc', '-O2', 'docs/benchmarks/2026-10-16-measure-child.c', '-o', str(launcher)], check=True)
binaries = {name: getattr(args, name).resolve(strict=True) for name in ('baseline', 'candidate')}
binary_hashes = {name: digest(path) for name, path in binaries.items()}
workloads = dict(item.split('=', 1) for item in args.workload)
inputs = {name: [Path(path) for path in json.loads(Path(manifest).read_text())] for name, manifest in workloads.items()}
identities = {name: [{'name': p.name, 'bytes': p.stat().st_size, 'sha256': digest(p)} for p in paths]
              for name, paths in inputs.items()}
sources = [Path('Lectern/Sources/LecternCore/Inspection/PreviewFontResources.swift'),
           Path('Lectern/Sources/LecternCore/Inspection/CostLimitedCache.swift'),
           Path('Tools/preview-profile/font-resource-probe.swift'), Path(__file__)]
report = {'complete': False, 'platform': platform.platform(),
          'swift': subprocess.check_output(['swift', '--version'], text=True).strip(),
          'sourceRevision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
          'sourceDirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
          'sourceHashes': {str(p): digest(p) for p in sources}, 'baselineSourceHash': digest(args.baseline_source),
          'binaryHashes': binary_hashes, 'inputs': identities, 'samples': [], 'preservation': {},
          'scope': 'One warmup plus alternating fresh-process pairs. Two preparation passes per process. '
                   'Stage timings exclude SVG reads and verification. Process CPU/elapsed/RSS include reads and both passes. '
                   'wait4 launcher forks after exec to avoid inherited Python RSS. No WebKit or visible frame measurement.'}
try:
    for name, manifest in workloads.items():
        for pair in range(args.pairs + 1):
            order = ('baseline', 'candidate') if pair % 2 == 0 else ('candidate', 'baseline')
            for variant in order:
                usage = args.output / 'usage.json'
                start = time.monotonic()
                result = subprocess.run([str(launcher), str(usage), str(binaries[variant]), 'shared', manifest],
                                        capture_output=True, text=True, check=True)
                elapsed = time.monotonic() - start
                sample = json.loads(result.stdout)
                assert sample['mode'] == 'shared' and len(sample['samples']) == 2
                report['samples'].append(dict(sample, workload=name, pair=pair, warmup=pair == 0,
                    variant=variant, processElapsedSeconds=elapsed, **json.loads(usage.read_text())))
        # No verification allocations or restoration CPU enter the measurements.
        hashes = []
        for variant in binaries:
            output = args.output / (name + '-' + variant)
            subprocess.run([str(binaries[variant]), 'shared', manifest, 'verify', 'artifacts', str(output)],
                           capture_output=True, text=True, check=True)
            hashes.append({p.name: digest(p) for p in output.iterdir()})
        assert hashes[0] == hashes[1], name
        samples = [s for s in report['samples'] if s['workload'] == name]
        for key in ('decodedResources', 'retainedBytes'):
            assert len({s[key] for s in samples}) == 1, key
        for operation in range(2):
            for key in ('htmlBytes', 'fontBytesIfRequestedEverySlide'):
                assert len({s['samples'][operation][key] for s in samples}) == 1, key
        report['preservation'][name] = {'identicalFiles': len(hashes[0]), 'sha256': hashes[0],
                                        'exactSourceReconstruction': True, 'resourceAccountingUnchanged': True}
    assert binary_hashes == {name: digest(path) for name, path in binaries.items()}
    for name, paths in inputs.items():
        assert [digest(p) for p in paths] == [p['sha256'] for p in identities[name]]
    assert report['sourceHashes'] == {str(p): digest(p) for p in sources}
    report['complete'] = True
finally:
    (args.output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
print(args.output / 'results.json')
