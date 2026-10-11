#!/bin/bash
# Portable checks against immutable references; no live Office installation needed.
# Run after swift test. Each invocation uses fresh outputs to reject stale evidence.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Tools/conformance/check_dependencies.py
mkdir -p .build/fidelity-checks
output=$(mktemp -d "$PWD/.build/fidelity-checks/run.XXXXXX")
trap 'printf "Fidelity artifacts: %s\n" "$output"' EXIT
python3 -m unittest discover -s Tools/conformance -p 'test_*.py'
python3 Tools/conformance/release_gate.py --semantic-only > "$output/semantic.json"

ROSTRUM_IMAGE_ORACLE_OUTPUT="$output/image-mapping" swift test --skip-build --filter PictureMappingTests > "$output/image-mapping-tests.log" 2>&1
python3 Tools/conformance/check_image_mapping.py "$output/image-mapping" > "$output/image-mapping.json"

binary_directory=$(swift build --show-bin-path)
manifest=Tests/RostrumTests/Fixtures/ImageOffice/manifest.json
for variant in v1 v2; do
  "$binary_directory/pptx-tool" render "Tests/RostrumTests/Fixtures/ImageOffice/image-mapping-$variant.pptx" "$output/$variant/svg" > "$output/$variant-render.log" 2>&1
  python3 Tools/conformance/check_image_office.py "$manifest" "$output/$variant/svg" --variant "$variant" --width 1200 --output "$output/$variant/1200"
done
python3 Tools/conformance/check_image_office.py "$manifest" "$output/v1/svg" --variant v1 --width 2400 --output "$output/v1/2400"
