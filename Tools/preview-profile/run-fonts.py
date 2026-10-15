#!/usr/bin/env python3
"""Compare production font registration with fixed candidate files in fresh processes."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import resource
import subprocess
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--baseline-binary', type=Path, required=True)
    parser.add_argument('--workloads', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--runs', type=int, default=7)
    parser.add_argument('--warmups', type=int, default=1)
    args = parser.parse_args()
    if args.runs < 1 or args.warmups < 0:
        parser.error('runs must be positive; warmups nonnegative')
    workloads = json.loads(args.workloads.read_text())['workloads']
    names = [case['name'] for case in workloads]
    if not names or len(set(names)) != len(names) or any(
            not name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-_' for c in name) for name in names):
        parser.error('workload names must be unique simple directory names')
    args.output.mkdir(parents=True, exist_ok=False)
    binaries = {'baseline': args.baseline_binary.resolve(), 'candidate': args.binary.resolve()}
    binary_hashes = {name: digest(path) for name, path in binaries.items()}
    cases = []
    for case in workloads:
        paths = [(args.workloads.parent / p).resolve() for p in case['paths']]
        inputs = [{'name': p.name, 'bytes': p.stat().st_size, 'sha256': digest(p)} for p in paths]
        manifest = args.output / (case['name'] + '.json')
        manifest.write_text(json.dumps({'paths': [str(p) for p in paths], 'families': case['families']}))
        expected = None
        samples = []
        for pair in range(args.runs + args.warmups):
            order = ['baseline', 'candidate'] if pair % 2 == 0 else ['candidate', 'baseline']
            for variant in order:
                destination = args.output / f"{case['name']}-{pair}-{variant}"
                cpu = resource.getrusage(resource.RUSAGE_CHILDREN)
                start = time.monotonic()
                result = subprocess.run([str(binaries[variant]), str(manifest.resolve()), str(destination.resolve())],
                                        text=True, capture_output=True, check=True)
                elapsed = time.monotonic() - start
                after = resource.getrusage(resource.RUSAGE_CHILDREN)
                report = json.loads(result.stdout)
                artifacts = {p.name: digest(p) for p in sorted(destination.iterdir()) if p.is_file()}
                if not artifacts or expected is not None and artifacts != expected:
                    raise ValueError(f"Output differs: {case['name']} {pair} {variant}")
                expected = artifacts
                samples.append({'pair': pair, 'variant': variant, 'warmup': pair < args.warmups,
                                'processElapsedSeconds': elapsed,
                                'processCPUSeconds': after.ru_utime + after.ru_stime - cpu.ru_utime - cpu.ru_stime,
                                **report})
        if [digest(p) for p in paths] != [item['sha256'] for item in inputs]:
            raise ValueError('Input changed during collection')
        cases.append({'name': case['name'], 'families': case['families'], 'inputs': inputs,
                      'artifacts': expected, 'samples': samples})
    if {name: digest(path) for name, path in binaries.items()} != binary_hashes:
        raise ValueError('Executable changed during collection')
    root = Path(__file__).resolve().parents[2]
    sources = [root / p for p in ('Sources/Rostrum/Fonts/PreparedFont.swift', 'Sources/Rostrum/Fonts/FontLibrary.swift',
               'Lectern/Sources/LecternCore/Rendering/InstalledFonts.swift', 'Tools/preview-profile/font-probe.swift',
               'Tools/preview-profile/run-fonts.py')]
    report = {'schemaVersion': 1, 'platform': platform.platform(),
              'swift': subprocess.check_output(['swift', '--version'], text=True).strip(),
              'candidateRevision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'candidateDirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip()),
              'candidateSourceSHA256': {str(p.relative_to(root)): digest(p) for p in sources},
              'executableSHA256': binary_hashes, 'workloads': cases,
              'scope': 'Release font-registration probe; candidate file discovery is injected. '
                       'Two fresh production sessions per process include file reads, validation and registration. '
                       'Stage timings exclude fixture authoring, rendering and artifact writes; process timings and '
                       'lifetime peak RSS include all of them. OS lookup, WebKit and UI are not measured. '
                       'Input hashing and warmups can warm filesystem caches. Binary hashes identify measured builds; '
                       'source revision alone does not establish binary provenance.'}
    (args.output / 'results.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(args.output / 'results.json')


if __name__ == '__main__':
    main()
