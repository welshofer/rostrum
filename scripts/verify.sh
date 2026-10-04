#!/bin/bash
# The gate before a push.
#
# CI runs Linux checks on pushes and a macOS build/test job on pull requests.
# This local gate also builds the iOS simulator app and runs app-hosted tests,
# which the SwiftPM-only test commands cannot discover.
#
#   ./scripts/verify.sh            everything
#   ./scripts/verify.sh --fast     skip app builds and app-hosted tests
#
# Install scripts/hooks/pre-push once (./scripts/install-hooks.sh) to have
# `git push` run this automatically and refuse the push if it fails.
#
# Signing: Lectern/scripts/build.sh picks up Lectern/.signing.local when it
# exists, so a stable development identity keeps saved API keys working across
# rebuilds. Without it the build is ad-hoc signed and still succeeds.
set -euo pipefail
cd "$(dirname "$0")/.."

fast=false
if [ "${1:-}" = "--fast" ]; then fast=true; fi

# Track the current stage so a failure names exactly where it stopped, rather
# than leaving you to guess from the last thing that scrolled past. An EXIT
# trap (not ERR) reports it: under `set -e` a failing subshell stage aborts the
# script but does not fire the ERR trap in bash 3.2, whereas EXIT always runs.
stage="startup"
step() { stage="$1"; printf '\n\033[1m==> %s\033[0m\n' "$1"; }
report() {
  code=$?
  if [ "$code" -ne 0 ]; then
    printf '\n\033[1;31mx verify.sh failed at: %s (exit %d)\033[0m\n' "$stage" "$code" >&2
  fi
}
trap report EXIT

step "Offline workflow checks"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests

step "Rostrum build + tests"
swift build
swift test

step "LecternCore build + tests"
(cd Lectern && swift build && swift test)

step "README snippets (docs can't rot)"
python3 scripts/readme-snippets.py
swift run ReadmeSnippets "$(mktemp -d)"

if [ "$fast" = true ]; then
  printf '\n\033[1mSkipped app builds and app-hosted tests (--fast).\033[0m\n'
  exit 0
fi

# The SwiftUI app targets never compile under `swift test` — they are not part
# of any SwiftPM target — so nothing else here would catch a break in them, and
# their tests (Lectern/AppTests) would never run in any gate at all. This does.
step "Lectern macOS app"
# Preserve full compiler output. A zero exit from a quiet build has previously
# accompanied contradictory compiler diagnostics; the complete log is needed
# to assess and retain the result.
Lectern/scripts/build.sh

step "Lectern iOS app (simulator)"
Lectern/scripts/build-ios.sh

step "Lectern app-hosted tests (AppTests — invisible to swift test)"
Lectern/scripts/test-app.sh

printf '\n\033[1mAll green.\033[0m\n'
printf 'If you touched packaging or a part'"'"'s XML, also run:\n'
printf '  Tools/ppt-check.sh <file.pptx>   # opens it in PowerPoint\n'
