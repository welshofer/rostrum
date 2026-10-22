#!/usr/bin/env python3
"""Local Mac paired measurement; normal app loading stays unchanged."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import sys
import zipfile


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def native_identity(repo, env):
    """Fingerprint the built host and resources outside every timed process."""
    def command(*args):
        return subprocess.check_output(args, cwd=repo, env=env)
    products = Path(env.get('LECTERN_TEST_DERIVED_DATA_PATH', '.build-xcode-tests'))
    if not products.is_absolute():
        products = repo / 'Lectern' / products
    products = products / 'Build/Products/Release'
    host = products / 'LecternTestHost.app'
    binary = host / 'Contents/MacOS/LecternTestHost'
    tests = host / 'Contents/PlugIns/LecternAppTests.xctest/Contents/MacOS/LecternAppTests'
    resources = {}
    # Include the host's test bundle, assets and signing receipts, and the
    # SwiftPM resource bundles beside it. Symlinks retain their target identity.
    for root in [host, *sorted(products.glob('*.bundle'))]:
        for path in sorted(root.rglob('*')):
            if path.is_file() or path.is_symlink():
                resources[str(path.relative_to(products))] = (
                    {'symlink': os.readlink(path)} if path.is_symlink() else {'sha256': sha256(path)})
    return {
        'sourceRevision': command('git', 'rev-parse', 'HEAD').decode().strip(),
        'trackedSourceDiffSHA256': hashlib.sha256(command(
            'git', 'diff', '--binary', '--no-ext-diff', '--no-textconv', 'HEAD')).hexdigest(),
        'testHostSHA256': sha256(binary), 'testBundleSHA256': sha256(tests),
        'testResourcesSHA256': hashlib.sha256(json.dumps(resources, sort_keys=True).encode()).hexdigest(),
        'xcode': command('xcodebuild', '-version').decode().strip(),
    }


def stage_total(sample, stage, field):
    # Only sum repetitions of the SAME stage. Nested stages overlap.
    return sum(s[field] for s in sample['stages']['samples'] if s['stage'] == stage)


def summarize(records):
    """Keep paired differences, adverse pairs and stage costs; never infer adoption."""
    metrics = {
        'firstBitmapSeconds': lambda s: s['firstBitmapAvailableSeconds'],
        'appLifetimePeakRSSBytes': lambda s: s['appProcessLifetimePeakRSSBytes'],
    }
    stages = sorted({s['stage'] for r in records for sample in r['timings']['samples']
                     for s in sample['stages']['samples']})
    for stage in stages:
        for field in ('cpuSeconds', 'elapsedSeconds'):
            metrics[f'{stage}.{field}'] = lambda s, stage=stage, field=field: stage_total(s, stage, field)
    measured = [r for r in records if not r['warmup']]
    pairs = sorted({r['pair'] for r in measured})
    result = []
    for operation in (0, 1):
        values = {}
        for name, metric in metrics.items():
            inline, shared = [], []
            for pair in pairs:
                for mode, dest in [('inline', inline), ('shared', shared)]:
                    record, = [r for r in measured if r['pair'] == pair and r['mode'] == mode]
                    dest.append(metric(record['timings']['samples'][operation]))
            deltas = [b - a for a, b in zip(inline, shared)]
            values[name] = {'inlineMedian': statistics.median(inline),
                           'sharedMedian': statistics.median(shared),
                           'pairedDeltas': deltas, 'pairedDeltaMedian': statistics.median(deltas),
                           'pairedDeltaMin': min(deltas), 'pairedDeltaMax': max(deltas)}
        result.append({'operationInProcess': operation + 1, 'metrics': values})
    return result


def collect(deck, output, pairs=3, run=subprocess.run, identity_reader=native_identity):
    if pairs < 1:
        raise ValueError('At least one measured pair is required')
    deck = deck.resolve(strict=True)
    if (not deck.is_file() or output.exists() or Path(str(output) + '.zip').exists()
            or Path(str(output) + '.failed.zip').exists()):
        raise ValueError('Input must be a file and output/archive must not exist')
    output.mkdir(parents=True)
    input_hash = sha256(deck)
    scripts = Path(__file__).resolve().parent
    repo = scripts.parents[1]
    records = []
    reference = reference_diagnostics = platform = None
    manifest = {'schemaVersion': 2, 'complete': False, 'inputSHA256': input_hash, 'samples': records}
    # A dedicated products directory prevents normal app/test builds from
    # replacing this run's binaries. Paths and the deck stay local to the Mac.
    env = dict(os.environ, LECTERN_TEST_CONFIGURATION='Release',
               LECTERN_TEST_DERIVED_DATA_PATH=str(output / 'build'),
               LECTERN_PREVIEW_REUSE_BUILD='1')

    def execute(command, log, process_env=env):
        with log.open('w') as stream:
            run(command, env=process_env, check=True, stdout=stream, stderr=subprocess.STDOUT)

    def verify_identity():
        if sha256(deck) != input_hash or identity_reader(repo, env) != manifest['buildIdentity']:
            raise ValueError('Input, source, test host, test resources or Xcode changed during the comparison')

    try:
        print(f'Results: {output}\nBuilding the isolated Release test host once; log: {output / "build.log"}', flush=True)
        execute(['bash', str(scripts / 'test-app.sh'), '--build-only'], output / 'build.log')
        manifest['buildIdentity'] = identity_reader(repo, env)
        # One warmup per mode, then alternating pairs of fresh test processes.
        for pair in range(pairs + 1):
            modes = ('inline', 'shared') if pair % 2 == 0 else ('shared', 'inline')
            for mode in modes:
                verify_identity()
                name = f'{pair:02d}-{mode}'
                target = output / name
                target.mkdir()
                print(f'{name}: {"warmup" if pair == 0 else "measured"}', flush=True)
                process_env = dict(env, LECTERN_PREVIEW_SHARED_FONTS='1' if mode == 'shared' else '0')
                execute(['bash', str(scripts / 'profile-preview.sh'), str(deck), str(target / 'profile')],
                        target / 'profile.log', process_env)
                verify_identity()
                provenance = json.loads((target / 'profile/provenance.json').read_text())
                timings = json.loads((target / 'profile/timings.json').read_text())
                svgs = {p.name: {'sha256': sha256(p), 'bytes': p.stat().st_size}
                        for p in sorted((target / 'profile').glob('slide-*.svg'))}
                (target / 'svg-manifest.json').write_text(json.dumps(svgs, indent=2) + '\n')
                if provenance['inputSHA256'] != input_hash:
                    raise ValueError('Profile used a different input')
                if any(provenance[k] != manifest['buildIdentity'][k] for k in
                       ('sourceRevision', 'testHostSHA256', 'testBundleSHA256', 'xcode')):
                    raise ValueError('Profile used a different test host or Xcode')
                if platform is not None and platform != timings['platform']:
                    raise ValueError('Platform changed during the comparison')
                platform = timings['platform']
                if not svgs or (reference is not None and reference != svgs):
                    raise ValueError('Standalone SVG output changed between runs')
                reference = svgs
                diagnostics_hash = sha256(target / 'profile/diagnostics.json')
                if reference_diagnostics is not None and reference_diagnostics != diagnostics_hash:
                    raise ValueError('Ordered diagnostics changed between runs')
                reference_diagnostics = diagnostics_hash
                if (timings.get('schemaVersion') != 3 or timings.get('fontResourceMode') != mode
                        or timings['buildMode'] != 'release' or len(timings['samples']) != 2):
                    raise ValueError('Missing requested Release mode, schema or operations')
                if mode == 'shared' and timings.get('bitmapParityCount') != len(svgs):
                    raise ValueError('Missing exact bitmap parity for the candidate')
                for operation, sample in enumerate(timings['samples'], 1):
                    if sample['operationInProcess'] != operation:
                        raise ValueError('Unexpected profile operation order')
                    for value in [sample['firstBitmapAvailableSeconds'], sample['appProcessLifetimePeakRSSBytes'],
                                  *[s[f] for s in sample['stages']['samples'] for f in ('cpuSeconds', 'elapsedSeconds')]]:
                        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
                            raise ValueError('Missing or invalid profile measurement')
                    trace = sample['stages']
                    requests = [s for s in trace['samples'] if s['stage'] == 'thumbnail.request']
                    expected = 'rendered' if operation == 1 else 'cacheHit'
                    if (trace['droppedSamples'] or len(requests) != len(svgs)
                            or any(s['outcome'] != expected for s in requests)):
                        raise ValueError('Incomplete render/cache-hit trace; choose a deck that fits the cache')
                records.append({'pair': pair, 'warmup': pair == 0, 'mode': mode,
                                'directory': name, 'provenance': provenance, 'timings': timings,
                                'diagnosticsSHA256': diagnostics_hash})
        print('Running native regressions once on the same Release build…', flush=True)
        verify_identity()
        execute(['bash', str(scripts / 'test-preview-regressions.sh'), str(output / 'regressions.xcresult')],
                output / 'regressions.log')
        with (output / 'regressions.json').open('w') as stream:
            run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path',
                 str(output / 'regressions.xcresult')], env=env, check=True, stdout=stream)
        verify_identity()
        tests = json.loads((output / 'regressions.json').read_text())
        if (tests['result'] != 'Passed' or tests['failedTests'] or tests['skippedTests']
                or tests['passedTests'] < 14 or tests['passedTests'] != tests['totalTestCount']):
            raise ValueError('Native regressions did not all execute successfully')
        manifest['regressions'] = tests
        manifest['summary'] = summarize(records)
        manifest['complete'] = True
    except Exception as error:
        manifest['failure'] = str(error)
        raise
    finally:
        (output / 'comparison.json').write_text(json.dumps(manifest, indent=2) + '\n')
        if not manifest['complete']:
            archive_evidence(output, '.failed.zip')
            print(f'Comparison failed. Send back diagnostics: {output}.failed.zip', flush=True)
    lines = ['Paired native preview loading comparison', f'Input SHA256: {input_hash}',
             f'{len(reference)} identical standalone SVGs and ordered diagnostics in every run; all candidate bitmaps match inline.',
             f'{pairs} measured pairs; one warmup per mode excluded. One build and one regression run.',
             'Paired differences below are shared minus inline; negative is lower. Stages overlap: do not add them.', '']
    for operation in manifest['summary']:
        lines.append(f"Operation {operation['operationInProcess']}:")
        for name, metric in operation['metrics'].items():
            lines.append(f"  {name}: inline {metric['inlineMedian']:.6g}; shared {metric['sharedMedian']:.6g}; "
                         f"paired delta median {metric['pairedDeltaMedian']:+.6g} "
                         f"[min {metric['pairedDeltaMin']:+.6g}, max {metric['pairedDeltaMax']:+.6g}]")
    lines += ['', 'CPU and RSS exclude WebKit helper processes. RSS includes earlier operations and startup.',
              'First bitmap is not first visible frame. Pixel comparisons run after measured operations.',
              'This candidate remains opt-in; results do not establish PowerPoint visual acceptance.']
    (output / 'SUMMARY.txt').write_text('\n'.join(lines) + '\n')
    archive_evidence(output, '.zip')
    print('\n'.join(lines))
    print(f'\nSend back: {output}.zip')
    return manifest


def archive_evidence(output, suffix):
    # Explicit allowlist: no decks, full SVGs, build products or result bundles.
    files = [output / name for name in ('SUMMARY.txt', 'comparison.json', 'build.log',
                                      'regressions.log', 'regressions.json')]
    for relative in ('profile.log', 'profile/timings.json', 'profile/provenance.json', 'svg-manifest.json'):
        files.extend(sorted(output.glob('*/' + relative)))
    with zipfile.ZipFile(str(output) + suffix, 'x', zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            if path.is_file():
                archive.write(path, str(Path(output.name) / path.relative_to(output)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('deck', type=Path)
    parser.add_argument('output', nargs='?', type=Path)
    parser.add_argument('--pairs', type=int, default=3)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('This comparison needs macOS and native WebKit; no build was started.')
    repo = Path(__file__).resolve().parents[2]
    output = args.output or repo / '.build' / ('preview-loading-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    collect(args.deck, output.resolve(), args.pairs)


if __name__ == '__main__':
    main()
