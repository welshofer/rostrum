#!/usr/bin/env python3
"""Alternate fresh cache-only probe processes; never copy private SVGs into results."""
import argparse
import hashlib
import json
import platform
from pathlib import Path
import resource
import subprocess
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True, help='JSON array of absolute SVG paths')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--runs', type=int, default=7)
    parser.add_argument('--warmups', type=int, default=1)
    args = parser.parse_args()
    if args.runs < 1 or args.warmups < 0:
        parser.error('runs must be positive; warmups nonnegative')
    args.output.mkdir(parents=True, exist_ok=False)
    paths = [Path(p) for p in json.loads(args.manifest.read_text())]
    if not paths or any(not p.is_absolute() for p in paths):
        parser.error('manifest must contain absolute SVG paths')
    inputs = [{'name': p.name, 'bytes': p.stat().st_size, 'sha256': digest(p)} for p in paths]
    executable_hash = digest(args.binary)
    rounds = []
    for pair in range(args.runs + args.warmups):
        order = ['baseline', 'candidate'] if pair % 2 == 0 else ['candidate', 'baseline']
        for variant in order:
            start_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
            start = time.monotonic()
            process = subprocess.run([str(args.binary.resolve()), variant, str(args.manifest.resolve())],
                                     text=True, capture_output=True, check=True)
            elapsed = time.monotonic() - start
            end_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
            result = json.loads(process.stdout)
            assert result['variant'] == variant and result['slides'] == len(paths)
            assert result['receipt'] == len(paths) * (len(paths) - 1)
            assert result['svgBytes'] == sum(item['bytes'] for item in inputs)
            rounds.append({'pair': pair, 'warmup': pair < args.warmups,
                           'processElapsedSeconds': elapsed,
                           'processCPUSeconds': (end_cpu.ru_utime + end_cpu.ru_stime
                                                 - start_cpu.ru_utime - start_cpu.ru_stime), **result})
    assert digest(args.binary) == executable_hash
    assert [digest(p) for p in paths] == [item['sha256'] for item in inputs]
    root = Path(__file__).resolve().parents[2]
    sources = [root / 'Tools/preview-profile/cache-probe.swift',
               *[root / 'Lectern/Sources/LecternCore' / name for name in (
                   'Inspection/PreviewContent.swift', 'Inspection/CostLimitedCache.swift', 'Rendering/PipelineTrace.swift')]]
    report = {'schemaVersion': 1, 'platform': platform.platform(),
              'swift': subprocess.check_output(['swift', '--version'], text=True).strip(),
              'sourceRevision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'sourceDirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip()),
              'sourceSHA256': {str(p.relative_to(root)): digest(p) for p in sources},
              'executableSHA256': executable_hash, 'inputs': inputs, 'samples': rounds,
              'scope': 'Cache-only Swift -O probe (build mode supplied by caller). No bitmap allocations, WebKit, UI or deck generation. '
                       'Input reads/decoding are outside stage timings, inside process CPU/elapsed and lifetime peak RSS. '
                       'Both copies of all SVGs remain live. Hashing inputs can warm filesystem caches. '
                       'Preparation and lookup are separate, nonoverlapping stages. Native Mac performance requires remeasurement.'}
    (args.output / 'results.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(args.output / 'results.json')


if __name__ == '__main__':
    main()
