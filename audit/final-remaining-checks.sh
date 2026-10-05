#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests
(cd Lectern && swift build && swift test)
python3 scripts/readme-snippets.py
swift run ReadmeSnippets "$(mktemp -d)"
Lectern/scripts/build.sh -quiet
Lectern/scripts/build-ios.sh -quiet
Lectern/scripts/test-app.sh -quiet
printf 'Remaining gate stages passed.\n'
