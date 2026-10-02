#!/usr/bin/env python3
"""Check shared-border ownership against the 42-case PowerPoint reference.

Requires resvg-py==0.5.0 and Pillow==12.3.0. Export the fixture's slides as
Slide1.svg ... Slide42.svg at any SVG viewport size, then run:
  python Tools/conformance/check_table_borders.py MANIFEST REFERENCES SVG_DIRECTORY
REFERENCES is a PNG directory or zip (nested SlideN.png entries are supported).

The pass criterion checks shared-edge colors, RTL outer edges, and stable
interiors of dash/gap runs. One RGB level is allowed for raster rounding.
Neighborhood differences are reported separately, without claiming whole-image
pixel equivalence: Office and resvg have different stroke antialiasing.
"""
import argparse
import importlib.metadata
import io
import json
from pathlib import Path
import sys
import zipfile

VERSIONS = {"resvg-py": "0.5.0", "Pillow": "12.3.0"}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("references", type=Path)
    parser.add_argument("svg_directory", type=Path)
    args = parser.parse_args()
    for name, expected in VERSIONS.items():
        try:
            actual = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            parser.error(f"install {name}=={expected} in a dedicated Python environment")
        if actual != expected:
            parser.error(f"expected {name}=={expected}, found {actual}")
    import resvg_py
    from PIL import Image

    archive = zipfile.ZipFile(args.references) if args.references.is_file() else None
    references = {}
    for name in archive.namelist() if archive else args.references.rglob("*.png"):
        basename = Path(name).name
        if not basename.startswith("Slide") or not basename.endswith(".png"):
            continue
        if basename in references:
            parser.error(f"ambiguous reference basename {basename}")
        references[basename] = name
    cases = json.loads(args.manifest.read_text(encoding="utf-8"))["cases"]
    if len(cases) != 42 or len({case["id"] for case in cases}) != 42:
        parser.error("expected the distinct 42-case corrected-order fixture")
    report = {"versions": VERSIONS, "size": [1200, 700], "passed": True, "cases": []}
    for case in cases:
        stem = f'Slide{case["slide"]}'
        name = references.get(stem + ".png")
        if name is None:
            parser.error(f"missing reference {stem}.png")
        reference_bytes = archive.read(name) if archive else Path(name).read_bytes()
        reference = Image.open(io.BytesIO(reference_bytes)).convert("RGB")
        if reference.size != (1200, 700):
            parser.error(f"{stem}: reference must be 1200x700")
        png = resvg_py.svg_to_bytes(svg_path=str(args.svg_directory / (stem + ".svg")), width=1200, height=700)
        (args.svg_directory / (stem + ".png")).write_bytes(png)
        actual = Image.open(io.BytesIO(png)).convert("RGB")
        horizontal = case["direction"] in ("horizontal", "merge-top")
        points = [(350, 350), (850, 350)] if horizontal else [(600, 250), (600, 450)]
        if case["direction"] == "rtl":
            points += [(100, 250), (1100, 250)]
        if case["first"]["style"] == "dash":
            # Select only reference run interiors, not antialiased dash ends.
            # This verifies gaps do not reveal the losing neighbor's color.
            for position in range(125 if horizontal else 175, 1075 if horizontal else 525):
                point = (position, 350) if horizontal else (600, position)
                expected = reference.getpixel(point)
                if expected not in ((0, 0, 255), (255, 255, 255)):
                    continue
                neighbors = [(position + d, 350) if horizontal else (600, position + d) for d in range(-2, 3)]
                if all(reference.getpixel(p) == expected for p in neighbors):
                    points.append(point)
        probes = []
        for point in points:
            expected, observed = reference.getpixel(point), actual.getpixel(point)
            delta = max(abs(a - b) for a, b in zip(expected, observed))
            probes.append({"point": point, "referenceRGB": expected, "actualRGB": observed, "maxDelta": delta})
            report["passed"] &= delta <= 1
        # Wide enough to detect a thick losing border outside a thin winner.
        if horizontal:
            neighborhood = [(a, b) for a in range(125, 1075) if abs(a - 600) > 12 for b in range(340, 361)]
        else:
            neighborhood = [(a, b) for a in range(590, 611) for b in range(175, 525) if abs(b - 350) > 12]
        deltas = [max(abs(a - b) for a, b in zip(reference.getpixel(p), actual.getpixel(p))) for p in neighborhood]
        report["cases"].append({"id": case["id"], "probes": probes, "neighborhood": {
            "samples": len(deltas), "maxDelta": max(deltas),
            "differingByMoreThan1": sum(d > 1 for d in deltas),
            "differingByMoreThan32": sum(d > 32 for d in deltas)}})
    if archive:
        archive.close()
    output = args.svg_directory / "table-border-results.json"
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    count = sum(len(case["probes"]) for case in report["cases"])
    sys.stdout.write(f'{"PASS" if report["passed"] else "FAIL"}: {count} ownership probes across {len(cases)} cases; full residual metrics: {output}\n')
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
