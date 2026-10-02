#!/usr/bin/env python3
"""Compare two separately compiled render drivers, including exact outputs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--baseline', type=Path, required=True)
p.add_argument('--candidate', type=Path, required=True)
p.add_argument('--baseline-revision', required=True)
p.add_argument('--candidate-revision', required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--work-dir', type=Path, required=True)
p.add_argument('--iterations', type=int, default=12)
a = p.parse_args()
if not 3 <= a.iterations <= 100:
    p.error('--iterations must be between 3 and 100')
a.work_dir.mkdir(parents=True, exist_ok=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

binaries = {'baseline': a.baseline.resolve(), 'candidate': a.candidate.resolve()}
environment = dict(os.environ)
environment.pop('ROSTRUM_PROFILE_FONTS', None)
report = dict(platform=platform.platform(), compiler=subprocess.check_output(['swift', '--version'], text=True).strip(),
              baselineRevision=a.baseline_revision, candidateRevision=a.candidate_revision,
              driverSHA256=digest(Path(__file__).with_name('main.swift')),
              binarySHA256={name: digest(path) for name, path in binaries.items()},
              method='Two paired warm-render rounds in AB then BA order; first sample excluded in each invocation; no registered fonts.',
              scenarios={})
for scenario in ['table-banded', 'table-grid', 'images-unique', 'images-repeated']:
    samples = {'baseline': [], 'candidate': []}
    warmups = {'baseline': [], 'candidate': []}
    hashes = {}
    for round_index, order in enumerate([['baseline', 'candidate'], ['candidate', 'baseline']]):
        for name in order:
            prefix = a.work_dir / f'{scenario}-{round_index}-{name}'
            result = json.loads(subprocess.check_output([str(binaries[name]), scenario, str(a.iterations), str(prefix)], text=True, env=environment))
            timings = result['millisecondsIncludingWarmup']
            warmups[name].append(timings[0])
            samples[name].extend(timings[1:])
            identity = {suffix: digest(Path(str(prefix) + suffix)) for suffix in ['.svg', '-issues.json', '-inheritance.json']}
            if hashes and identity != next(iter(hashes.values())):
                raise RuntimeError(f'{scenario}: SVG or ordered diagnostics changed')
            hashes[name] = identity
    medians = {name: statistics.median(values) for name, values in samples.items()}
    report['scenarios'][scenario] = dict(samplesMS=samples, warmupsMS=warmups, medianMS=medians,
                                        candidateReductionPercent=100 * (1 - medians['candidate'] / medians['baseline']),
                                        outputSHA256=hashes, exactOutputs=True)
    a.output.write_text(json.dumps(report, indent=2) + '\n')
    print(scenario, medians, flush=True)
