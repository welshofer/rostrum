#!/bin/bash
# Local Mac only; the test runner refuses to touch a running Lectern app.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 2 ] || [ "$(uname -s)" != Darwin ]; then
  echo 'Usage (macOS): profile-preview.sh /absolute/deck.pptx /absolute/new-output' >&2
  exit 1
fi
case "$1:$2" in /*:/*) ;; *) echo 'Both paths must be absolute.' >&2; exit 1 ;; esac
if [ ! -f "$1" ] || [ -e "$2" ]; then
  echo 'Input must exist and output must be a new directory.' >&2
  exit 1
fi
case "${LECTERN_PREVIEW_SHARED_FONTS:-0}" in
  0|1) ;;
  *) echo 'LECTERN_PREVIEW_SHARED_FONTS must be 0 or 1.' >&2; exit 1 ;;
esac
# TEST_RUNNER_ forwards these variables to the isolated app test process.
TEST_RUNNER_LECTERN_PREVIEW_PROFILE_INPUT="$1" \
TEST_RUNNER_LECTERN_PREVIEW_PROFILE_OUTPUT="$2" \
TEST_RUNNER_LECTERN_PREVIEW_SHARED_FONTS="${LECTERN_PREVIEW_SHARED_FONTS:-0}" \
LECTERN_TEST_CONFIGURATION=Release \
  bash scripts/test-app.sh \
    -only-testing:LecternAppTests/PreviewPipelineProfileTests \
    -parallel-testing-enabled NO
# A skipped/mis-selected test must never look like a successful measurement.
python3 - "$1" "$2" "${LECTERN_TEST_DERIVED_DATA_PATH:-.build-xcode-tests}" <<'PY'
import hashlib
import json
from pathlib import Path
import subprocess
import sys

input_path, output, products = map(Path, sys.argv[1:])
report = json.loads((output / 'timings.json').read_text())
if report['buildMode'] != 'release' or len(report['samples']) != 2:
    raise SystemExit('Native profile did not execute both Release operations')
for sample in report['samples']:
    if sample['stages']['droppedSamples'] or not any(s['stage'] == 'thumbnail.request' for s in sample['stages']['samples']):
        raise SystemExit('Native profile is missing complete thumbnail measurements')
if report.get('fontResourceMode') == 'shared':
    rendered = sum(s['stage'] == 'thumbnail.request' for s in report['samples'][0]['stages']['samples'])
    if report.get('bitmapParityCount') != rendered:
        raise SystemExit('Shared font resources did not pass exact native bitmap comparison')

def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()

binary = products / 'Build/Products/Release/LecternTestHost.app/Contents/MacOS/LecternTestHost'
test_binary = products / 'Build/Products/Release/LecternTestHost.app/Contents/PlugIns/LecternAppTests.xctest/Contents/MacOS/LecternAppTests'
metadata = {'sourceRevision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
            'sourceDirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True).strip()),
            'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
            'inputSHA256': sha256(input_path), 'testHostSHA256': sha256(binary),
            'testBundleSHA256': sha256(test_binary),
            'scope': 'Exact test host and input identity; timing scopes are in timings.json. Native visual acceptance pending.'}
(output / 'provenance.json').write_text(json.dumps(metadata, indent=2, sort_keys=True) + '\n')
PY
