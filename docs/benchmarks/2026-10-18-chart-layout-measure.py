#!/usr/bin/env python3
"""Pair Release chart-layout builds; permit only explicitly listed preview changes.

This fidelity comparison is separate from the strict output-preserving pipeline
profiler. Private decks and generated evidence stay in the caller's directory.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
from statistics import median
import subprocess
import time


def sha(path):
    # Avoid inheriting a large executable-sized allocation at process launch;
    # that can impose a false floor on wait4's child peak-RSS measurement.
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(65_536), b''):
            digest.update(chunk)
    return digest.hexdigest()


def artifacts(directory):
    return {str(p.relative_to(directory)): sha(p) for p in directory.rglob('*')
            if p.is_file() and p.name != 'timings.json'}


def preserved(directory):
    data = json.loads((directory / 'inspection.json').read_text())
    assert all(p['rendered'] for p in data['previews']), 'Failed preview'
    assert not data['schemaIssues'] and not data['readWarnings'], 'Read/schema failure'
    assert all(not d['failure'] for d in data['previewDiagnostics']), 'Render failure'
    for key in ['previews', 'previewDiagnostics']:
        del data[key]
    return data, artifacts(directory / 'export')


def run(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    binaries = {'baseline': args.baseline.resolve(), 'candidate': args.candidate.resolve()}
    source = args.input.resolve()
    source_hash = sha(source)
    binary_hashes = {name: sha(path) for name, path in binaries.items()}
    allowed = {f'slide-{int(n)}.svg' for n in args.changed_slides.split(',') if n}
    rows, references, content = [], {}, None
    for iteration in range(args.pairs + 1):
        order = ['baseline', 'candidate'] if iteration % 2 == 0 else ['candidate', 'baseline']
        for name in order:
            destination = output / f'{name}-{iteration}'
            with (output / f'{name}-{iteration}.log').open('w') as log:
                start = time.perf_counter()
                process = subprocess.Popen([str(binaries[name]), str(source), str(destination), '--repeat', '2'],
                                           stdout=log, stderr=subprocess.STDOUT)
                _, status, usage = os.wait4(process.pid, 0)
                elapsed = time.perf_counter() - start
                process.returncode = os.waitstatus_to_exitcode(status)
                if process.returncode:
                    raise RuntimeError(f'{name} exited {process.returncode}; see {log.name}')
            operations = []
            for index in [1, 2]:
                directory = destination / f'run-{index}'
                current = artifacts(directory)
                if name in references:
                    assert current == references[name], f'Nondeterministic {name} output'
                else:
                    references[name] = current
                retained = preserved(directory)
                if content is None:
                    content = retained
                assert retained == content, 'Extracted content or export bytes changed'
                timings = json.loads((directory / 'timings.json').read_text())
                assert timings['firstPreviewRendered']
                assert timings['stages']['droppedSamples'] == 0
                stage_cpu, stage_elapsed = {}, {}
                for sample in timings['stages']['samples']:
                    assert sample['outcome'] == 'completed', sample
                    key = sample['stage']
                    stage_cpu[key] = stage_cpu.get(key, 0) + sample['cpuSeconds']
                    stage_elapsed[key] = stage_elapsed.get(key, 0) + sample['elapsedSeconds']
                operations.append({'inspectionCPUSeconds': timings['inspection']['cpuSeconds'],
                    'inspectionElapsedSeconds': timings['inspection']['elapsedSeconds'],
                    'firstSVGSlotElapsedSeconds': timings['firstPreviewSlotCompleted']['elapsedSeconds'],
                    'stageCPUSeconds': stage_cpu, 'stageElapsedSeconds': stage_elapsed})
            rss = usage.ru_maxrss if platform.system() == 'Darwin' else usage.ru_maxrss * 1024
            rows.append({'variant': name, 'warmup': iteration == 0, 'iteration': iteration,
                         'processElapsedSeconds': elapsed, 'processCPUSeconds': usage.ru_utime + usage.ru_stime,
                         'processPeakRSSBytes': rss, 'operations': operations})
    actual = {k for k in references['baseline'] if references['baseline'][k] != references['candidate'].get(k)}
    assert set(references['baseline']) == set(references['candidate'])
    assert actual - {'inspection.json'} == allowed, (actual, allowed)
    # Diagnostics may change only on the listed chart slides.
    before = json.loads((output / 'baseline-0/run-1/inspection.json').read_text())
    after = json.loads((output / 'candidate-0/run-1/inspection.json').read_text())
    assert len(before['previews']) == len(after['previews']) == before['slideCount']
    for key, number in [('previews', 'number'), ('previewDiagnostics', 'slideNumber')]:
        # Diagnostic records are sparse: clean slides need not have a record.
        a = {item[number]: item for item in before[key]}
        b = {item[number]: item for item in after[key]}
        assert len(a) == len(before[key]) and len(b) == len(after[key]), key
        for index in a.keys() | b.keys():
            if f'slide-{index}.svg' not in allowed:
                assert a.get(index) == b.get(index), f'{key} changed on untouched slide {index}'
    assert sha(source) == source_hash
    assert {n: sha(p) for n, p in binaries.items()} == binary_hashes
    summary = {}
    for name in binaries:
        measured = [r for r in rows if r['variant'] == name and not r['warmup']]
        summary[name] = {key: median(r[key] for r in measured)
                         for key in ['processElapsedSeconds', 'processCPUSeconds', 'processPeakRSSBytes']}
        summary[name]['operations'] = []
        for index in [0, 1]:
            values = [r['operations'][index] for r in measured]
            item = {key: median(r[key] for r in values) for key in
                    ['inspectionCPUSeconds', 'inspectionElapsedSeconds', 'firstSVGSlotElapsedSeconds']}
            for key in ['stageCPUSeconds', 'stageElapsedSeconds']:
                item[key] = {stage: median(r[key][stage] for r in values) for stage in values[0][key]}
            summary[name]['operations'].append(item)
    result = {'schemaVersion': 1, 'configuration': 'Release', 'platform': platform.platform(),
              'inputSHA256': source_hash, 'binarySHA256': binary_hashes, 'pairs': args.pairs,
              'baselineRevision': 'dc5d2a31761ab045a11a02cc5e1bb3dbd81ca006',
              'method': 'One warm-up then alternating fresh processes, two new inspections per process. '
                        'wait4 process CPU/peak RSS includes export/evidence writes. Stage costs use PipelineTrace. '
                        'No concurrent builds/tests. No WebKit, installed Mac fonts, or first-visible-frame measurement.',
              'expectedChangedSlides': sorted(allowed), 'unchangedExports': len(content[1]),
              'unchangedSVGCount': sum(k.endswith('.svg') and k not in allowed for k in references['baseline']),
              'artifactSHA256': references, 'medians': summary, 'samples': rows}
    (output / 'results.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--changed-slides', default='')
    parser.add_argument('--pairs', type=int, default=5)
    args = parser.parse_args()
    if not 3 <= args.pairs <= 30:
        parser.error('--pairs must be 3...30')
    run(args)
