#!/usr/bin/env python3
"""Collect document-preparation costs; this does not run WebKit."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import resource
import subprocess
import time


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True, help='JSON array of absolute SVG paths')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--runs', type=int, default=7)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error('runs must be positive')
    paths = [Path(p) for p in json.loads(args.manifest.read_text())]
    if not paths or any(not p.is_absolute() for p in paths):
        parser.error('manifest must contain absolute SVG paths')
    args.output.mkdir(parents=True, exist_ok=False)
    inputs = [{'name': p.name, 'bytes': p.stat().st_size, 'sha256': digest(p)} for p in paths]
    binary_hash = digest(args.binary)
    samples = []
    for pair in range(args.runs + 1):
        for mode in (('inline', 'shared') if pair % 2 == 0 else ('shared', 'inline')):
            start_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
            start = time.monotonic()
            result = subprocess.run([str(args.binary.resolve()), mode, str(args.manifest.resolve())],
                                    capture_output=True, text=True, check=True)
            elapsed = time.monotonic() - start
            end_cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
            sample = json.loads(result.stdout)
            if sample['mode'] != mode or len(sample['samples']) != 2:
                raise ValueError('Missing preparation operations')
            samples.append(dict(sample, pair=pair, warmup=pair == 0, processElapsedSeconds=elapsed,
                                processCPUSeconds=end_cpu.ru_utime + end_cpu.ru_stime
                                - start_cpu.ru_utime - start_cpu.ru_stime))
    # Reconstruction is independently checked after measurements, to keep its
    # allocations and CPU out of the preparation benchmark.
    subprocess.run([str(args.binary.resolve()), 'shared', str(args.manifest.resolve()), 'verify'],
                   capture_output=True, text=True, check=True)
    if digest(args.binary) != binary_hash or [digest(p) for p in paths] != [i['sha256'] for i in inputs]:
        raise ValueError('Executable or input changed')
    root = Path(__file__).resolve().parents[2]
    source_names = ['Tools/preview-profile/font-resource-probe.swift',
                    'Lectern/Sources/LecternCore/Inspection/PreviewFontResources.swift',
                    'Lectern/Sources/LecternCore/Inspection/CostLimitedCache.swift']
    report = {'schemaVersion': 1, 'platform': platform.platform(),
              'swift': subprocess.check_output(['swift', '--version'], text=True).strip(),
              'sourceRevision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'sourceDirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip()),
              'sourceSHA256': {name: digest(root / name) for name in source_names},
              'executableSHA256': binary_hash, 'inputs': inputs, 'samples': samples,
              'exactReconstructionPassed': True,
              'scope': 'Swift -O preparation only; no WebKit. One warmup and alternating fresh processes. '
                       'Two passes share the resource cache. Input reads are outside stage timings and inside '
                       'process CPU/elapsed/peak RSS. Exact SVG reconstruction runs separately afterward.'}
    (args.output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(args.output / 'results.json')


if __name__ == '__main__':
    main()
