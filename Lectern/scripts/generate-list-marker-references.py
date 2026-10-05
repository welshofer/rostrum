#!/usr/bin/env python3
"""Copy owned native inputs and reduce their independently extracted evidence.

Development-only, standard-library script. Does not call Rostrum or generate
expected geometry. Native source/PDF pins are deliberately fixed.
"""
import hashlib
import json
from pathlib import Path
import shutil

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "Tests/RostrumTests/Fixtures/NativeListMarkers"
OUTPUT = REPO / "Lectern/Sources/LecternCore/Resources/LibraryLab"
PINS = [
    ("", 0, "db317bc89840fc1dea1d4abf11fdd26e8c08c470dd86dee822ed8f01987a92d8", "4153ef4949c6aa554497ab16958f62016d8406d06d6cc88b1842e9d40920f1ea"),
    ("followup", 3, "6baeaa1cb40ccd22f512aa6e9f14dcc9b21024139bde29cc14d96ed03095b1dd", "745576408a02c63c21dca8c243847ef1cf89163758e948e3c3faec61ee59452c"),
]

def read(path):
    return json.loads(path.read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

reference = {
    "scope": "24 independently captured native cases. Character U+2022 and Arabic-period numbering; bundled actual DejaVu regular, Serif and bold faces. Finite captured glyph origins tolerance .06pt, baselines .121pt, paint and outline dimensions .002pt. Three inherited markers are explicitly absent. Computed fits are separate from native autofit choices.",
    "faces": [], "cases": [],
}
for key, face in read(SOURCE / "manifest.json")["faces"].items():
    assert digest(SOURCE / face["file"]) == face["sha256"]
    reference["faces"].append({"id": key, "family": face["family"], "bold": face["bold"], "sha256": face["sha256"]})
for folder, offset, source_hash, pdf_hash in PINS:
    directory = SOURCE / folder
    manifest = read(directory / "manifest.json")
    source = directory / manifest["source"]
    assert digest(source) == source_hash
    assert digest(directory / "powerpoint.pdf") == pdf_hash
    authored = read(directory / "cases.json")
    captured = read(directory / "native-marker-metrics.json")["cases"]
    assert len(authored) == len(captured) == manifest["caseCount"]
    shutil.copyfile(source, OUTPUT / source.name)
    for case, native in zip(authored, captured):
        assert case["name"] == native["name"]
        glyphs = [{key: glyph[key] for key in ("text", "x", "baseline", "matchingSourceFaces", "rawPDFPaintScale", "sourceGlyphBounds", "geometricInkBounds")} for glyph in native["markerGlyphs"] + native["bodyGlyphs"]]
        reference["cases"].append(dict(
            id=case["name"], slide=case["page"] + offset, source=source.name,
            sourcePage=case["page"], sourceSHA256=source_hash, nativePDFSHA256=pdf_hash,
            x=case["x"], y=case["y"], width=case["width"], height=case["height"],
            textBodyXML=case["sourceTextBodyXML"], markerCount=len(native["markerGlyphs"]),
            omittedMarkers=[glyph["text"] for glyph in native["explicitlyOmittedMarkers"]],
            expectedVisibleScalars=native["expectedVisibleScalars"],
            bodyLines=[line["visibleText"] for line in native["bodyLines"]], glyphs=glyphs))
assert len(reference["cases"]) == 24
assert sum(len(case["glyphs"]) for case in reference["cases"]) == 277
assert sum(len(case["omittedMarkers"]) for case in reference["cases"]) == 3
(OUTPUT / "ListMarkerReferences.json").write_text(json.dumps(reference, indent=2) + "\n")
