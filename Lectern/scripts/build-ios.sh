#!/bin/bash
# Build the Lectern iOS/iPadOS app for the simulator — no signing required, so
# this works on any Mac (and in CI) without a team. To run on a real device,
# open the project in Xcode and pick your team under Signing & Capabilities.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project Lectern.xcodeproj -scheme Lectern-iOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build-xcode \
  CODE_SIGNING_ALLOWED=NO build "$@"
