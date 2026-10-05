#!/bin/bash
# Run the app-hosted tests locally. These exercise AppState and the SwiftUI
# target, which SwiftPM's LecternCore tests cannot import.
#
# A separate test host and derived-data directory protect the user's app.
# LECTERN_TEST_DERIVED_DATA_PATH is intentionally separate from the app override.
# Signing still follows build.sh; this script never terminates running apps.
#
# Deliberately local-only: never add a hosted macOS Actions job for this repo.
set -euo pipefail
cd "$(dirname "$0")/.."

require_idle_apps() {
  local app process_status
  for app in Lectern LecternTestHost; do
    if pgrep -x "$app" >/dev/null 2>&1; then
      echo "error: $app is running. Finish your work and quit it before running app tests; no process was stopped." >&2
      exit 1
    else
      process_status=$?
      if [ "$process_status" -ne 1 ]; then
        echo "error: Could not check whether $app is running; app tests were not started." >&2
        exit 1
      fi
    fi
  done
}

require_idle_apps

if [ -f .signing.local ]; then
  # shellcheck disable=SC1091
  source .signing.local
fi

bash scripts/generate-project.sh

require_idle_apps

# Apply manual signing to SwiftPM resource bundles as well as the app.
# Automatic bundle signing otherwise requests a team even for a local build.
xcodebuild -project Lectern.xcodeproj -scheme LecternTests -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath "${LECTERN_TEST_DERIVED_DATA_PATH:-.build-xcode-tests}" \
  CODE_SIGN_STYLE=Manual \
  ${LECTERN_SIGN_IDENTITY:+CODE_SIGN_IDENTITY="$LECTERN_SIGN_IDENTITY"} \
  test "$@"
