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
build_action=
case "${LECTERN_PREVIEW_REUSE_BUILD:-0}" in
  0) ;;
  1) build_action=--test-without-building ;;
  *) echo 'LECTERN_PREVIEW_REUSE_BUILD must be 0 or 1.' >&2; exit 1 ;;
esac
# TEST_RUNNER_ forwards these variables to the isolated app test process.
native_status=0
TEST_RUNNER_LECTERN_PREVIEW_PROFILE_INPUT="$1" \
TEST_RUNNER_LECTERN_PREVIEW_PROFILE_OUTPUT="$2" \
TEST_RUNNER_LECTERN_PREVIEW_SHARED_FONTS="${LECTERN_PREVIEW_SHARED_FONTS:-0}" \
LECTERN_TEST_CONFIGURATION=Release \
  bash scripts/test-app.sh ${build_action:+"$build_action"} \
    -only-testing:LecternAppTests/PreviewPipelineProfileTests \
    -parallel-testing-enabled NO || native_status=$?
# A skipped/mis-selected test must never look like a successful measurement.
# Complete rejected pixel comparisons still need identity evidence. Preserve the
# native failure status even if receipt validation also fails.
validation_status=0
python3 - "$1" "$2" "${LECTERN_TEST_DERIVED_DATA_PATH:-.build-xcode-tests}" \
  "$native_status" "${LECTERN_PREVIEW_SHARED_FONTS:-0}" <<'PY' || validation_status=$?
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import sys

input_path, output, products = map(Path, sys.argv[1:4])
native_status = int(sys.argv[4])
mode = 'shared' if sys.argv[5] == '1' else 'inline'
report = json.loads((output / 'timings.json').read_text())
validation = runpy.run_path('scripts/compare-preview-loading.py')
mismatches = validation['validate_timings'](report, mode, validation['profile_slide_numbers'](output))
# Require the ordered diagnostics receipt as well as all measured operations.
json.loads((output / 'diagnostics.json').read_text())

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
            'nativeExitStatus': native_status, 'pixelAcceptance': not mismatches,
            'scope': 'Exact test host and input identity; timing scopes are in timings.json. Native visual acceptance pending.'}
(output / 'provenance.json').write_text(json.dumps(metadata, indent=2, sort_keys=True) + '\n')
if mismatches and native_status == 0:
    raise SystemExit('Shared font resources did not pass exact native bitmap comparison')
PY
if [ "$native_status" -ne 0 ]; then
  exit "$native_status"
fi
exit "$validation_status"
