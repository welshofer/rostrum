#!/bin/bash
# Shared selection for the single-run and paired native preview collectors.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 1 ]; then
  echo 'Usage: test-preview-regressions.sh /absolute/new-regressions.xcresult' >&2
  exit 1
fi
case "$1" in /*) ;; *) echo 'Result bundle path must be absolute.' >&2; exit 1 ;; esac
if [ -e "$1" ]; then echo 'Result bundle must not exist.' >&2; exit 1; fi
unset TEST_RUNNER_LECTERN_PREVIEW_PROFILE_INPUT TEST_RUNNER_LECTERN_PREVIEW_PROFILE_OUTPUT
unset LECTERN_PREVIEW_PROFILE_INPUT LECTERN_PREVIEW_PROFILE_OUTPUT
build_action=
case "${LECTERN_PREVIEW_REUSE_BUILD:-0}" in
  0) ;;
  1) build_action=--test-without-building ;;
  *) echo 'LECTERN_PREVIEW_REUSE_BUILD must be 0 or 1.' >&2; exit 1 ;;
esac
LECTERN_TEST_CONFIGURATION=Release bash scripts/test-app.sh ${build_action:+"$build_action"} \
  -only-testing:LecternAppTests/SlidePreviewGeometryTests \
  -only-testing:LecternAppTests/SlideRasterizerTests \
  -only-testing:LecternAppTests/PreviewPipelineTraceTests \
  '-only-testing:LecternAppTests/GlyphPaintWebKitTests/invalidEmbeddedFontFailsAndTheOwnedHostRecovers(sharedFonts:)' \
  '-only-testing:LecternAppTests/GlyphPaintWebKitTests/cancelledNavigationCannotCompleteTheNextCapture(sharedFonts:)' \
  -parallel-testing-enabled NO -resultBundlePath "$1"
