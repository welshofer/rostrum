#!/bin/bash
# Run the app-hosted tests locally. These exercise AppState and the SwiftUI
# target, which SwiftPM's LecternCore tests cannot import.
#
# A separate test host and derived-data directory protect the user's app.
# LECTERN_TEST_DERIVED_DATA_PATH is intentionally separate from the app override.
# Signing still follows build.sh; this script never terminates running apps.
#
# Test execution is local-only. --build-only compiles the test host in CI
# without launching it, so native test code is also checked by the compiler.
set -euo pipefail
cd "$(dirname "$0")/.."
action=test
if [ "${1:-}" = --build-only ]; then
  action=build-for-testing
  shift
elif [ "${1:-}" = --test-without-building ]; then
  # The comparison runner builds once, fingerprints the products, then starts
  # fresh processes without regenerating or rebuilding between measurements.
  action=test-without-building
  shift
fi

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

# Apply manual signing to SwiftPM resource bundles as well as the app.
# Automatic bundle signing otherwise requests a team even for a local build.
configuration="${LECTERN_TEST_CONFIGURATION:-Debug}"
case "$configuration" in
  Debug|Release) ;;
  *) echo "error: LECTERN_TEST_CONFIGURATION must be Debug or Release" >&2; exit 1 ;;
esac
if [ "$action" = test-without-building ]; then
  products="${LECTERN_TEST_DERIVED_DATA_PATH:-.build-xcode-tests}/Build/Products/$configuration"
  if [ ! -d Lectern.xcodeproj ] || \
     [ ! -f "$products/LecternTestHost.app/Contents/MacOS/LecternTestHost" ] || \
     [ ! -f "$products/LecternTestHost.app/Contents/PlugIns/LecternAppTests.xctest/Contents/MacOS/LecternAppTests" ]; then
    echo "error: Build the $configuration test host with --build-only before --test-without-building." >&2
    exit 1
  fi
else
  bash scripts/generate-project.sh
fi
require_idle_apps

xcodebuild -project Lectern.xcodeproj -scheme LecternTests -configuration "$configuration" \
  -destination 'platform=macOS' -derivedDataPath "${LECTERN_TEST_DERIVED_DATA_PATH:-.build-xcode-tests}" \
  CODE_SIGN_STYLE=Manual ENABLE_TESTABILITY=YES \
  ${LECTERN_SIGN_IDENTITY:+CODE_SIGN_IDENTITY="$LECTERN_SIGN_IDENTITY"} \
  "$action" "$@"
