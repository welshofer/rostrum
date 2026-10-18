#!/usr/bin/env bash
# Offline review pack through the same renderer used by generation and recovery.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [NEW_OUTPUT_DIRECTORY] [template.potx | design.md ...]"
  echo "Runs focused regressions and writes editable review decks, SVGs and saved content. No model calls."
  exit 0
fi
output="${1:-$repo/.build/generated-layout-review-$(date -u +%Y%m%dT%H%M%SZ)}"
if [[ $# -gt 0 ]]; then shift; fi
if [[ -e "$output" ]]; then echo "Choose a new output directory: $output" >&2; exit 2; fi
swift test --package-path "$repo/Lectern" --filter GeneratedLayoutTests
swift run -c release --package-path "$repo/Lectern" CompositionRegression "$output" --layouts "$@"
echo "Review files: $output"
echo "Open the PPTX files in PowerPoint; retain slide-view and PDF-export results separately."
