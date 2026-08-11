#!/bin/bash
# Run the app-hosted tests locally. These exercise AppState and the SwiftUI
# target, which SwiftPM's LecternCore tests cannot import.
#
# Signing: identical to scripts/build.sh, and that is not optional. Both write
# into the same derived-data path, so whichever ran last decides how the app in
# .build-xcode is signed. This script used to leave it at project.yml's ad-hoc
# default, whose cdhash changes on every build — which re-sealed the app after
# each test run and orphaned the login-keychain items saved by the previous,
# stably-signed one. The symptom is a key the app can find and cannot read:
# Settings says "saved" in the field and "no key stored" beside it.
#
# Deliberately local-only: never add a hosted macOS Actions job for this repo.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .signing.local ]; then
  # shellcheck disable=SC1091
  source .signing.local
fi

xcodegen generate --quiet

xcodebuild -project Lectern.xcodeproj -scheme Lectern -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build-xcode \
  ${LECTERN_SIGN_IDENTITY:+CODE_SIGN_IDENTITY="$LECTERN_SIGN_IDENTITY"} \
  test "$@"
