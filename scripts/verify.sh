#!/bin/bash
# The gate before a pull request.
#
# CI runs Linux only, because GitHub's hosted macOS runners bill at 10x and
# this repository pushes often. That does not make the Apple platforms
# unverified — it makes them verified here, where a Mac is free. Everything
# below either cannot run on a Linux runner, or is worth running once more
# against the real toolchain before you push.
#
#   ./scripts/verify.sh            everything
#   ./scripts/verify.sh --fast     skip the app builds (the slow part)
#
# Signing: Lectern/scripts/build.sh picks up Lectern/.signing.local when it
# exists, so a stable development identity keeps saved API keys working across
# rebuilds. Without it the build is ad-hoc signed and still succeeds.
set -euo pipefail
cd "$(dirname "$0")/.."

fast=false
[ "${1:-}" = "--fast" ] && fast=true

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

step "Rostrum tests"
swift test

step "LecternCore tests"
(cd Lectern && swift test)

step "README snippets (docs can't rot)"
swift run ReadmeSnippets "$(mktemp -d)"

if [ "$fast" = true ]; then
  printf '\n\033[1mSkipped the app builds (--fast).\033[0m\n'
  exit 0
fi

# The SwiftUI app targets never compile under `swift test` — they are not part
# of any SwiftPM target — so nothing else in this script would catch a break in
# them. This is the only thing that does.
step "Lectern macOS app"
Lectern/scripts/build.sh -quiet

step "Lectern iOS app (simulator)"
Lectern/scripts/build-ios.sh -quiet

printf '\n\033[1mAll green.\033[0m\n'
printf 'If you touched packaging or a part'"'"'s XML, also run:\n'
printf '  Tools/ppt-check.sh <file.pptx>   # opens it in PowerPoint\n'
