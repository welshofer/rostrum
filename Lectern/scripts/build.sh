#!/bin/bash
# Build the Lectern macOS app — the canonical build command.
#
# Signing: project.yml defaults to ad-hoc so a fresh clone builds with no
# cert. If Lectern/.signing.local exists (gitignored) and defines
# LECTERN_SIGN_IDENTITY, that stable development identity is used instead —
# which is what lets login-keychain API keys persist across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/generate-project.sh

if [ -f .signing.local ]; then
  # shellcheck disable=SC1091
  source .signing.local
fi

# Apply manual signing to SwiftPM resource bundles as well as the app.
# Automatic bundle signing otherwise requests a team even for a local build.
xcodebuild -project Lectern.xcodeproj -scheme Lectern -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "${LECTERN_DERIVED_DATA_PATH:-.build-xcode}" \
  CODE_SIGN_STYLE=Manual \
  ${LECTERN_SIGN_IDENTITY:+CODE_SIGN_IDENTITY="$LECTERN_SIGN_IDENTITY"} \
  build "$@"
