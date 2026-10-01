#!/usr/bin/env python3
"""Independently raster-check Rostrum's exported image-mapping fixtures.

Generate the inputs from the repository root:
  ROSTRUM_IMAGE_ORACLE_OUTPUT=.build/image-oracles swift test --filter PictureMapping
Then, using an environment with resvg-py==0.5.0 and Pillow==12.3.0:
  python Tools/conformance/check_image_mapping.py .build/image-oracles

The fixture is an independently encoded 4x4 RGBA quadrant PNG. These probes
check orientation, asymmetric crop, rotation/flips, and alpha compositing.
This is a separate SVG rasterizer oracle, not a PowerPoint conformance oracle.
The white slide background makes one 50%-alpha yellow layer RGB(255,255,127);
the intentionally overlapping shape and table fills yield RGB(255,255,63).
"""

import argparse
import importlib.metadata
import io
import json
from pathlib import Path
import re
import sys

VERSIONS = {"resvg-py": "0.5.0", "Pillow": "12.3.0"}
PROBES = {
    "stretch": [
        ((200, 250), (255, 0, 0)), ((400, 250), (0, 255, 0)),
        ((200, 350), (0, 0, 255)), ((400, 350), (255, 255, 127)),
    ],
    "asymmetric-crop": [
        ((200, 250), (0, 255, 0)), ((400, 250), (0, 255, 0)),
        ((200, 350), (255, 255, 127)), ((400, 350), (255, 255, 127)),
    ],
    "rotation-flips": [
        ((300, 200), (255, 255, 127)), ((300, 400), (0, 0, 255)),
    ],
    "tile": [
        ((112, 212), (255, 0, 0)), ((163, 212), (0, 255, 0)),
        ((112, 263), (0, 0, 255)), ((163, 263), (255, 255, 63)),
    ],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("fixtures", type=Path, help="directory containing the four exported SVG files")
    args = parser.parse_args()
    actual_versions = {}
    for name, expected in VERSIONS.items():
        try:
            actual = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            parser.error(f"missing {name}; install {name}=={expected} in a dedicated Python environment")
        if actual != expected:
            parser.error(f"{name}=={actual} found; this exact-pixel oracle requires {name}=={expected}")
        actual_versions[name] = actual

    import resvg_py
    from PIL import Image

    report = {"versions": actual_versions, "viewport": [0, 0, 700000, 700000],
              "rasterSize": [700, 700], "fixtures": [], "passed": True}
    for name, probes in PROBES.items():
        source = args.fixtures / f"{name}.svg"
        svg = source.read_text(encoding="utf-8")
        # Only zoom the root viewport; leave all drawing geometry untouched.
        match = re.search(r"<svg\b[^>]*>", svg)
        if match is None:
            parser.error(f"{source}: no root SVG element")
        root = match.group()
        for attribute, value in [("viewBox", "0 0 700000 700000"), ("width", "700"), ("height", "700")]:
            root, count = re.subn(rf'\b{attribute}="[^"]*"', f'{attribute}="{value}"', root, count=1)
            if count != 1:
                parser.error(f"{source}: missing root {attribute}")
        svg = svg[:match.start()] + root + svg[match.end():]
        png = resvg_py.svg_to_bytes(svg_string=svg, width=700, height=700,
                                    skip_system_fonts=True, image_rendering="optimize_speed")
        (args.fixtures / f"{name}.png").write_bytes(png)
        raster = Image.open(io.BytesIO(png)).convert("RGB")
        result = {"name": name, "probes": []}
        for point, expected in probes:
            actual = raster.getpixel(point)
            passed = actual == expected
            result["probes"].append({"point": point, "expectedRGB": expected,
                                     "actualRGB": actual, "passed": passed})
            report["passed"] = report["passed"] and passed
        report["fixtures"].append(result)
    encoded = json.dumps(report, indent=2) + "\n"
    (args.fixtures / "image-mapping-results.json").write_text(encoded, encoding="utf-8")
    sys.stdout.write(encoded)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
