#!/usr/bin/env python3
"""Measure changed rendering semantics on one immutable PPTX, without a pass claim.

Build pptx-tool in each source tree (it exists in both eras), then compile the
same historical_compare.swift with -O -parse-as-library against each Rostrum
module/object. Add -DROSTRUM_HAS_FIDELITY only where fidelityIssues exists.
Provide the actual flags as --library-build-flags=... and --driver-build-flags=....
This script does not build, register fonts, modify inputs, or use Office.

Every fresh process opens the same PPTX and traverses shapes. Its first timed
render is reported separately from later warm renders. Process order alternates
AB/BA, and complete initial process pairs are excluded as warmups. SVG capture
and diagnostics serialization happen after the first timed call. The historical
API has no fidelityIssues; its null result must not be described as zero issues.
"""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import xml.etree.ElementTree as ET


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_identity(root):
    """Hash actual library source bytes, including uncommitted/archive trees."""
    package = root / 'Package.swift'
    source = root / 'Sources' / 'Rostrum'
    if not package.is_file() or not source.is_dir():
        raise ValueError(f'Not a Rostrum source tree: {root}')
    paths = [package] + sorted(p for p in source.rglob('*') if p.is_file())
    files = {p.relative_to(root).as_posix(): digest(p) for p in paths}
    encoded = json.dumps(files, sort_keys=True, separators=(',', ':')).encode()
    return {'root': str(root), 'files': files, 'manifestSHA256': hashlib.sha256(encoded).hexdigest()}


def svg_identity(path):
    data = path.read_bytes()
    root = ET.fromstring(data)
    counts = Counter(node.tag.rsplit('}', 1)[-1] for node in root.iter())
    return {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data),
            'rootAttributes': dict(root.attrib), 'elementCounts': dict(sorted(counts.items())),
            'rectanglesWithStroke': sum(node.tag.rsplit('}', 1)[-1] == 'rect'
                                       and node.get('stroke') not in [None, 'none'] for node in root.iter())}


def distribution(values):
    ordered = sorted(values)
    return {'samplesMS': values, 'count': len(values), 'medianMS': statistics.median(values),
            'minMS': ordered[0], 'maxMS': ordered[-1],
            'observedP95MS': ordered[min(len(ordered) - 1, int(.95 * len(ordered)))]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['baseline', 'candidate', 'input', 'baseline-source', 'candidate-source', 'output', 'work-dir']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--baseline-revision', required=True)
    parser.add_argument('--candidate-revision', required=True)
    parser.add_argument('--library-build-flags', required=True)
    parser.add_argument('--driver-build-flags', required=True)
    parser.add_argument('--runs', type=int, default=5)
    parser.add_argument('--warmups', type=int, default=1)
    parser.add_argument('--iterations', type=int, default=12)
    parser.add_argument('--pixel-width', type=int, default=1280)
    args = parser.parse_args()
    if not (2 <= args.runs <= 100 and 0 <= args.warmups <= 20 and 2 <= args.iterations <= 100
            and 1 <= args.pixel_width <= 16384):
        parser.error('Require runs 2..100, warmups 0..20, iterations 2..100, pixel-width 1..16384')
    args.output = args.output.resolve()
    args.work_dir = args.work_dir.resolve()
    args.input = args.input.resolve()
    if args.output.exists() or (args.work_dir.exists() and any(args.work_dir.iterdir())):
        parser.error('Use a new output path and a new or empty artifact directory; prior evidence is never overwritten')
    binaries = {'baseline': args.baseline.resolve(), 'candidate': args.candidate.resolve()}
    source_roots = {'baseline': args.baseline_source.resolve(), 'candidate': args.candidate_source.resolve()}
    source_hashes = {name: source_identity(root) for name, root in source_roots.items()}
    binary_hashes = {name: digest(path) for name, path in binaries.items()}
    input_hash = digest(args.input)
    args.work_dir.mkdir(parents=True, exist_ok=True)
    driver = Path(__file__).with_name('historical_compare.swift')
    report = {
        'schema': 1, 'comparison': 'Historical behavior comparison; rendering semantics differ',
        'acceptance': 'No exact-output pass, pixel-conformance pass, or identical-work speedup is asserted',
        'platform': platform.platform(), 'machine': platform.machine(), 'python': sys.version,
        'compiler': subprocess.check_output(['swift', '--version'], text=True).strip(),
        'input': {'path': str(args.input), 'sha256': input_hash, 'bytes': args.input.stat().st_size},
        'binaries': {name: {'path': str(path), 'sha256': binary_hashes[name]} for name, path in binaries.items()},
        'declaredRevisions': {'baseline': args.baseline_revision, 'candidate': args.candidate_revision},
        'sourceIdentity': source_hashes, 'driverSHA256': digest(driver), 'runnerSHA256': digest(Path(__file__)),
        'declaredBuildFlags': {'library': args.library_build_flags, 'driverCommon': args.driver_build_flags,
                              'optionalModernDriverDefine': '-DROSTRUM_HAS_FIDELITY'},
        'provenanceLimit': 'Source paths and build flags are caller-supplied provenance; source/binary linkage is not independently inferred',
        'method': {'runs': args.runs, 'warmupProcessPairs': args.warmups, 'rendersPerProcess': args.iterations,
                   'order': 'alternating AB/BA process pairs; never concurrent', 'pixelWidth': args.pixel_width,
                   'registeredFonts': False, 'freshRender': 'first call after opening and shape traversal',
                   'warmRender': 'remaining calls; excludes first call of each process',
                   'capture': 'first result only, outside render timer; later output byte counts retained',
                   'tailLimit': 'Observed quantile of this small sample; not a population tail estimate'},
        'invocations': [],
    }
    environment = dict(os.environ)
    environment.pop('ROSTRUM_PROFILE_FONTS', None)
    environment.pop('ROSTRUM_BENCH_FONT', None)
    fresh = {name: [] for name in binaries}
    warm = {name: [] for name in binaries}
    identities = {name: [] for name in binaries}
    for pair in range(args.warmups + args.runs):
        order = ['baseline', 'candidate'] if pair % 2 == 0 else ['candidate', 'baseline']
        for name in order:
            prefix = args.work_dir / f'pair-{pair:03d}-{name}'
            result = subprocess.run([str(binaries[name]), str(args.input), str(args.iterations), str(prefix), str(args.pixel_width)],
                                    env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            Path(str(prefix) + '-stderr.log').write_text(result.stderr)
            Path(str(prefix) + '-timings.json').write_text(result.stdout)
            if result.returncode:
                raise RuntimeError(f'{name} exited {result.returncode}; see {prefix}-stderr.log')
            sample = json.loads(result.stdout)
            timings = sample['milliseconds']
            if len(timings) != args.iterations or sample['registeredFonts'] or sample['pixelWidth'] != args.pixel_width:
                raise ValueError(f'{name}: driver contract differs')
            svg = svg_identity(Path(str(prefix) + '.svg'))
            inheritance_path = Path(str(prefix) + '-inheritance.json')
            issues_path = Path(str(prefix) + '-issues.json')
            issues = json.loads(issues_path.read_text())
            if sample['fidelityIssuesSupported'] != (issues is not None):
                raise ValueError(f'{name}: issue support/capture disagree')
            entry = {'pair': pair, 'era': name, 'excludedWarmup': pair < args.warmups,
                     'artifactPrefix': str(prefix), 'sample': sample, 'svg': svg,
                     'inheritance': json.loads(inheritance_path.read_text()),
                     'inheritanceSHA256': digest(inheritance_path), 'issuesSHA256': digest(issues_path),
                     'issueCodes': dict(Counter(issue['code'] for issue in issues)) if issues is not None else None}
            report['invocations'].append(entry)
            identities[name].append((svg['sha256'], entry['inheritanceSHA256'], entry['issuesSHA256']))
            if pair >= args.warmups:
                fresh[name].append(timings[0])
                warm[name].extend(timings[1:])
            print(f'pair {pair} {name}: first={timings[0]:.6f} ms, warm median={statistics.median(timings[1:]):.6f} ms', flush=True)
    # Abort if source, executable, or input changed during the observation.
    if digest(args.input) != input_hash or any(digest(binaries[name]) != binary_hashes[name] for name in binaries):
        raise ValueError('Input or executable changed during measurement')
    if any(source_identity(root) != source_hashes[name] for name, root in source_roots.items()):
        raise ValueError('Library source changed during measurement')
    report['timings'] = {'firstRender': {name: distribution(values) for name, values in fresh.items()},
                         'warmRender': {name: distribution(values) for name, values in warm.items()}}
    report['candidateOverBaselineMedianRatio'] = {
        'firstRender': statistics.median(fresh['candidate']) / statistics.median(fresh['baseline']),
        'warmRender': statistics.median(warm['candidate']) / statistics.median(warm['baseline'])}
    report['withinEraFirstOutputStable'] = {name: len(set(values)) == 1 for name, values in identities.items()}
    report['crossEraFirstOutputHashesEqual'] = identities['baseline'][0] == identities['candidate'][0]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
