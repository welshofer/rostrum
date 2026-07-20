#!/bin/bash
# Build the Lectern iOS/iPadOS app for the simulator — ad-hoc signed, so this
# works on any Mac (and in CI) without a team. Ad hoc, NOT unsigned: with
# CODE_SIGNING_ALLOWED=NO the app has no application-identifier and every
# Keychain call fails with errSecMissingEntitlement (-34018), so saved API keys
# can't work. To run on a real device, open the project in Xcode and pick your
# team under Signing & Capabilities.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project Lectern.xcodeproj -scheme Lectern-iOS -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build-xcode-ios \
  CODE_SIGN_IDENTITY=- CODE_SIGN_ENTITLEMENTS=App/Lectern-iOS-Sim.entitlements \
  build "$@"
