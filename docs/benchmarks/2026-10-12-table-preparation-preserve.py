"""Compare exact geometry, ordered diagnostics, decks and SVGs across binaries.

Run from the repository root with the scratch directory containing the
baseline/candidate binaries as the sole argument. No timings are accepted here.
"""
import json
import pathlib
import subprocess
import sys
import zipfile

scratch = pathlib.Path(sys.argv[1])
root = scratch / "preservation"
cases = [(24, "distinct", "measured"), (30, "mixed", "measured"),
         (1000, "repeated", "measured"), (1000, "distinct", "measured"),
         (100, "distinct", "measured"), (24, "distinct", "estimated")]
record = []
for count, labels, sizing in cases:
    name = f"{count}-{labels}-{sizing}"
    for variant in ["baseline", "candidate"]:
        subprocess.run([str(scratch / variant), str(count), labels, sizing, "1", "artifacts",
                        str(root / f"{variant}-{name}")], check=True, stdout=subprocess.DEVNULL)
    before, after = [root / f"{v}-{name}" for v in ["baseline", "candidate"]]
    files = sorted(p.name for p in before.iterdir())
    assert files == sorted(p.name for p in after.iterdir())
    for filename in files:
        a, b = (before / filename).read_bytes(), (after / filename).read_bytes()
        # JSONEncoder does not promise object key order. Arrays, including
        # diagnostic order, compare exactly; all non-JSON artifacts compare bytes.
        assert (json.loads(a) == json.loads(b)) if filename.endswith(".json") else a == b, (name, filename)
    with zipfile.ZipFile(after / "saved.pptx") as archive:
        assert archive.testzip() is None
    pages = json.loads((after / "geometry.json").read_text())
    assert [r for page in pages for r in page["body_rows"]] == list(range(1, count + 1))
    record.append({"case": name, "files": len(files), "pages": len(pages), "exact": True})
print(json.dumps(record, indent=2, sort_keys=True))
