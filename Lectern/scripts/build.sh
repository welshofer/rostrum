#!/bin/bash
# Build the Lectern macOS app. Kept as the canonical build command so every build
# uses the same stable Development signing (see project.yml) — which is what lets
# login-keychain API keys persist across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project Lectern.xcodeproj -scheme Lectern -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build-xcode build "$@"
