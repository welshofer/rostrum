#!/bin/bash
# Run the app-hosted tests locally. These exercise AppState and the SwiftUI
# target, which SwiftPM's LecternCore tests cannot import.
#
# Deliberately local-only: never add a hosted macOS Actions job for this repo.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate --quiet

xcodebuild -project Lectern.xcodeproj -scheme Lectern -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build-xcode \
  test "$@"
