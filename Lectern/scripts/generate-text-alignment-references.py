#!/usr/bin/env python3
"""Project independent PowerPoint evidence into the offline alignment Lab resource.

Run after the NativeBodyAlignment fixtures are available in this checkout.
No Rostrum layout result is used to derive the expected glyph geometry.
"""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Tests/RostrumTests/Fixtures/NativeBodyAlignment"
OUTPUT = ROOT / "Lectern/Sources/LecternCore/Resources/LibraryLab"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


cases = json.loads((SOURCE / "cases.json").read_text())
native = json.loads((SOURCE / "native-alignment-metrics.json").read_text())
manifest = json.loads((SOURCE / "manifest.json").read_text())
assert manifest["sourceSHA256"] == "98c27b081f8ecb9c297d46e04019b83bcdc969ed3d42113f89491aa0b9d70dac"
assert manifest["pdfSHA256"] == "49b3001cee2777ec1c319c191f40836c4c20391a65224b49f6289d54908b6b66"
assert sha(SOURCE / manifest["source"]) == manifest["sourceSHA256"]
assert sha(SOURCE / "powerpoint.pdf") == manifest["pdfSHA256"]
metrics = {case["name"]: case for case in native["cases"]}
assert len(cases) == len(metrics) == 24
reference = {
    "scope": "Finite captured centered/right LTR Latin text; first scalar x .025pt, each scalar x .06pt, baseline .121pt, paint/ink dimensions .002pt. Table stored scale is diagnosed and ignored. Computed fifth-page fits are separate from native-selected autofit.",
    "source": manifest["source"], "sourceSHA256": manifest["sourceSHA256"],
    "nativePDFSHA256": manifest["pdfSHA256"],
    "casesSHA256": sha(SOURCE / "cases.json"),
    "metricsSHA256": sha(SOURCE / "native-alignment-metrics.json"),
    "faces": [dict(id=key, **face) for key, face in manifest["faces"].items()],
    "cases": [],
}
for case in cases:
    measured = metrics[case["name"]]
    assert measured["expectedVisibleScalars"] == measured["consumedVisibleScalars"]
    reference["cases"].append(dict(
        id=case["name"], slide=case["page"], source=manifest["source"],
        x=case["x"], y=case["y"], width=case["width"], height=case["height"],
        table=case.get("table", False), face=measured["selectedFace"],
        alignment=case["alignment"], expectedVisibleScalars=measured["expectedVisibleScalars"],
        lines=[dict(visibleText=line["visibleText"], baseline=line["baseline"],
                    glyphs=[{key: glyph[key] for key in ["text", "x", "baseline", "rawPDFPaintScale",
                              "sourceGlyphBounds", "geometricInkBounds", "sourceGlyphMatches"]}
                            for glyph in line["characters"]]) for line in measured["lines"]],
    ))
assert sum(case["expectedVisibleScalars"] for case in reference["cases"]) == 172
(OUTPUT / "TextAlignmentReferences.json").write_text(json.dumps(reference, indent=2) + "\n")
shutil.copyfile(SOURCE / manifest["source"], OUTPUT / manifest["source"])
