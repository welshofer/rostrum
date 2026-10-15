#!/usr/bin/env python3
"""Local Mac paired measurement; normal app loading stays unchanged."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import zipfile


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def collect(deck, output, pairs=3, run=subprocess.run):
    if pairs < 1:
        raise ValueError('At least one measured pair is required')
    deck = deck.resolve(strict=True)
    if (not deck.is_file() or output.exists() or Path(str(output) + '.zip').exists()
            or Path(str(output) + '.failed.zip').exists()):
        raise ValueError('Input must be a file and output/archive must not exist')
    output.mkdir(parents=True)
    input_hash = sha256(deck)
    runner = Path(__file__).resolve().with_name('test-preview.sh')
    records = []
    reference = identity = None
    manifest = {'complete': False, 'inputSHA256': input_hash, 'samples': records}
    try:
        # One warmup per mode, then alternating pairs of fresh test processes.
        for pair in range(pairs + 1):
            modes = ('inline', 'shared') if pair % 2 == 0 else ('shared', 'inline')
            for mode in modes:
                name = f'{pair:02d}-{mode}'
                target = output / name
                print(f'{name}: {"warmup" if pair == 0 else "measured"}', flush=True)
                env = dict(os.environ, LECTERN_PREVIEW_SHARED_FONTS='1' if mode == 'shared' else '0')
                run(['bash', str(runner), str(deck), str(target)], env=env, check=True)
                provenance = json.loads((target / 'profile/provenance.json').read_text())
                timings = json.loads((target / 'profile/timings.json').read_text())
                svgs = json.loads((target / 'svg-manifest.json').read_text())
                tests = json.loads((target / 'regressions.json').read_text())
                if provenance['inputSHA256'] != input_hash or sha256(deck) != input_hash:
                    raise ValueError('Input changed during the comparison')
                current_identity = {key: provenance[key] for key in
                                    ('sourceRevision', 'testHostSHA256', 'testBundleSHA256', 'xcode')}
                current_identity['platform'] = timings['platform']
                if identity is not None and identity != current_identity:
                    raise ValueError('Source revision, test host or Xcode changed during the comparison')
                identity = current_identity
                if not svgs or (reference is not None and reference != svgs):
                    raise ValueError('Standalone SVG output changed between runs')
                reference = svgs
                if (timings.get('fontResourceMode') != mode or timings['buildMode'] != 'release'
                        or len(timings['samples']) != 2):
                    raise ValueError('Missing requested Release mode or operations')
                if mode == 'shared' and timings.get('bitmapParityCount') != len(svgs):
                    raise ValueError('Missing exact bitmap parity for the candidate')
                if (tests['result'] != 'Passed' or tests['failedTests'] or tests['skippedTests']
                        or tests['passedTests'] < 14):
                    raise ValueError('Native regressions did not all execute successfully')
                for operation, sample in enumerate(timings['samples'], 1):
                    trace = sample['stages']
                    requests = [s for s in trace['samples'] if s['stage'] == 'thumbnail.request']
                    expected = 'rendered' if operation == 1 else 'cacheHit'
                    if (trace['droppedSamples'] or len(requests) != len(svgs)
                            or any(s['outcome'] != expected for s in requests)):
                        raise ValueError('Incomplete render/cache-hit trace; choose a deck that fits the cache')
                records.append({'pair': pair, 'warmup': pair == 0, 'mode': mode,
                                'directory': name, 'provenance': provenance, 'timings': timings})
        manifest['complete'] = True
    except Exception as error:
        manifest['failure'] = str(error)
        raise
    finally:
        (output / 'comparison.json').write_text(json.dumps(manifest, indent=2) + '\n')
        if not manifest['complete']:
            # A failed native experiment must still be easy to diagnose. Keep
            # the failed receipt and logs, never the deck, SVGs or result bundle.
            with zipfile.ZipFile(str(output) + '.failed.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
                archive.write(output / 'comparison.json', str(Path(output.name) / 'comparison.json'))
                for relative in ('profile.log', 'regressions.log', 'regressions.json',
                                 'profile/timings.json', 'profile/provenance.json', 'svg-manifest.json'):
                    for path in sorted(output.glob('*/' + relative)):
                        archive.write(path, str(Path(output.name) / path.relative_to(output)))
            print(f'Comparison failed. Send back diagnostics: {output}.failed.zip', flush=True)
    lines = ['Paired native preview loading comparison', f'Input SHA256: {input_hash}',
             f'{len(reference)} identical standalone SVGs in every run; all candidate bitmaps match inline.',
             f'{pairs} measured pairs; one warmup per mode excluded.', '']
    for operation in (0, 1):
        for mode in ('inline', 'shared'):
            samples = [r['timings']['samples'][operation] for r in records if not r['warmup'] and r['mode'] == mode]
            median = statistics.median
            elapsed = median(s['firstBitmapAvailableSeconds'] for s in samples)
            rss = median(s['appProcessLifetimePeakRSSBytes'] / 1048576 for s in samples)
            cpu = median(sum(t['cpuSeconds'] for t in s['stages']['samples']
                             if t['stage'] == 'thumbnail.request') for s in samples)
            lines.append(f'{mode}, operation {operation + 1}: median first bitmap {elapsed:.3f}s; '
                         f'thumbnail request CPU {cpu:.3f}s; app lifetime peak RSS {rss:.1f} MiB')
    lines += ['', 'CPU and RSS exclude WebKit helper processes. RSS includes earlier operations and startup.',
              'First bitmap is not first visible frame. Pixel comparisons run after measured operations.',
              'This candidate remains opt-in; results do not establish PowerPoint visual acceptance.']
    (output / 'SUMMARY.txt').write_text('\n'.join(lines) + '\n')
    with zipfile.ZipFile(str(output) + '.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
        for path in [output / 'SUMMARY.txt', output / 'comparison.json', *sorted(output.glob('*.zip'))]:
            archive.write(path, str(Path(output.name) / path.name))
    print('\n'.join(lines))
    print(f'\nSend back: {output}.zip')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('deck', type=Path)
    parser.add_argument('output', nargs='?', type=Path)
    parser.add_argument('--pairs', type=int, default=3)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    output = args.output or repo / '.build' / ('preview-loading-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    collect(args.deck, output.resolve(), args.pairs)


if __name__ == '__main__':
    main()
