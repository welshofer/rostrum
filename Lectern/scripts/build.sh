#!/bin/bash
# Build Lectern, then re-sign the finished bundle with the keychain-access-groups
# entitlement so API keys live in the rebuild-stable data-protection keychain.
#
# Why re-sign instead of setting CODE_SIGN_ENTITLEMENTS: keychain-access-groups is
# a profile-gated entitlement, so putting it in the build settings makes Xcode
# demand a provisioning profile (which this app doesn't have). A Development cert
# can still apply it locally via a post-build codesign, and that survives — unlike
# a Run Script phase, which Xcode's own codesign would run after and re-strip.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project Lectern.xcodeproj -scheme Lectern -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath .build-xcode build "$@"

APP=".build-xcode/Build/Products/Debug/Lectern.app"
codesign --force --sign "Apple Development: Jay Welshofer (XP6YTXD955)" \
  --entitlements App/Lectern.entitlements --generate-entitlement-der \
  --timestamp=none "$APP"

if codesign -d --entitlements - "$APP" 2>/dev/null | tr -d '\0' | grep -qi keychain-access; then
  echo "✅ re-signed with keychain-access-groups (rebuild-stable keys)"
else
  echo "⚠️  keychain entitlement missing after re-sign"
fi
