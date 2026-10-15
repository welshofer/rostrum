#!/bin/bash
# Local Mac follow-up: measure first, then run thumbnail regressions, then bundle.
set -euo pipefail

usage() {
  echo 'Usage: bash Lectern/scripts/test-preview.sh deck.pptx [new-output-directory]'
  echo 'Quit Lectern first. Requires macOS, full Xcode, XcodeGen and Python 3.'
}
if [ "${1:-}" = --help ]; then usage; exit 0; fi
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then usage >&2; exit 1; fi
if [ "$(uname -s)" != Darwin ]; then
  echo 'error: This run needs macOS and native WebKit.' >&2
  exit 1
fi
for tool in python3 xcodebuild xcrun xcodegen git; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "error: Missing $tool. See Lectern/README.md for Mac setup." >&2
    exit 1
  }
done

# Resolve caller-relative paths before entering the repository.
deck=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve(strict=True))' "$1")
if [ ! -f "$deck" ]; then echo 'error: Input must be a deck file.' >&2; exit 1; fi
repo=$(cd "$(dirname "$0")/../.." && pwd)
output=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' \
  "${2:-$repo/.build/preview-test-$(date -u +%Y%m%dT%H%M%SZ)}")
if [ -e "$output" ] || [ -e "$output.zip" ]; then
  echo 'error: Choose a new output directory; existing results will not be overwritten.' >&2
  exit 1
fi
mkdir -p "$(dirname "$output")"
mkdir "$output"
cd "$repo"
stage='Release preview profile'
report_failure() {
  code=$?
  if [ "$code" -ne 0 ]; then
    printf '\nFailed at %s (exit %d). Logs retained in: %s\n' "$stage" "$code" "$output" >&2
  fi
}
trap report_failure EXIT

printf 'Results: %s\nProfiling your deck before running regression tests…\n' "$output"
# Each wrapper keeps the normal signing configuration and refuses active apps.
# No build/test runs concurrently with the measured operations.
bash Lectern/scripts/profile-preview.sh "$deck" "$output/profile" 2>&1 | tee "$output/profile.log"

stage='native thumbnail regression tests'
# Do not let an inherited opt-in profile configuration affect the second run.
unset TEST_RUNNER_LECTERN_PREVIEW_PROFILE_INPUT TEST_RUNNER_LECTERN_PREVIEW_PROFILE_OUTPUT
unset LECTERN_PREVIEW_PROFILE_INPUT LECTERN_PREVIEW_PROFILE_OUTPUT
LECTERN_TEST_CONFIGURATION=Release bash Lectern/scripts/test-app.sh \
  -only-testing:LecternAppTests/SlidePreviewGeometryTests \
  -only-testing:LecternAppTests/SlideRasterizerTests \
  -only-testing:LecternAppTests/PreviewPipelineTraceTests \
  -parallel-testing-enabled NO \
  -resultBundlePath "$output/regressions.xcresult" 2>&1 | tee "$output/regressions.log"

stage='result verification and archive'
xcrun xcresulttool get test-results summary --path "$output/regressions.xcresult" > "$output/regressions.json"
python3 - "$output" <<'PY'
import json
from pathlib import Path
import sys
import zipfile

output = Path(sys.argv[1])
tests = json.loads((output / 'regressions.json').read_text())
if (tests['totalTestCount'] <= 0 or tests['passedTests'] <= 0
        or tests['failedTests'] != 0 or tests['result'] != 'Passed'):
    raise SystemExit('Native regressions did not execute successfully; inspect regressions.xcresult')
timings = json.loads((output / 'profile/timings.json').read_text())
provenance = json.loads((output / 'profile/provenance.json').read_text())
summary = [
    'Lectern Mac preview test run',
    f"Source: {provenance['sourceRevision']} (dirty: {provenance['sourceDirty']})",
    f"Input SHA256: {provenance['inputSHA256']}",
    f"Regressions: {tests['passedTests']} passed, {tests['failedTests']} failed, {tests['skippedTests']} skipped",
]
for sample in timings['samples']:
    summary.append(
        f"Operation {sample['operationInProcess']}: first bitmap "
        f"{sample['firstBitmapAvailableSeconds']:.3f}s; "
        f"cache accounted {sample['thumbnailCacheAccountedBytes'] / 1048576:.1f} MiB; "
        f"app lifetime peak RSS {sample['appProcessLifetimePeakRSSBytes'] / 1048576:.1f} MiB")
summary += [
    '', 'First bitmap is not first visible frame. RSS excludes WebKit helper processes.',
    'Raw per-stage CPU and elapsed times are in profile/timings.json.',
    'This run does not establish PowerPoint visual acceptance or a speedup by itself.',
    'The ZIP includes slide SVGs (with deck content/resources), timings, provenance and logs.',
    'The original PPTX and full regressions.xcresult stay outside the ZIP.',
]
(output / 'SUMMARY.txt').write_text('\n'.join(summary) + '\n')
# Exclusive creation also protects an archive created while the tests were running.
with zipfile.ZipFile(str(output) + '.zip', 'x', zipfile.ZIP_DEFLATED) as archive:
    files = [output / name for name in ('SUMMARY.txt', 'profile.log', 'regressions.log', 'regressions.json')]
    files += sorted((output / 'profile').rglob('*'))
    for path in files:
        if path.is_file():
            archive.write(path, str(Path(output.name) / path.relative_to(output)))
print('\n'.join(summary))
PY
printf '\nDone. Send back this ZIP:\n%s.zip\n' "$output"
