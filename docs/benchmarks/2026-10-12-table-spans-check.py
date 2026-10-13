"""From the repository root: python3 this-file.py SCRATCH.

SCRATCH/spans is the Release horizontal-span driver. Verify deterministic
geometry/decks/previews and independently reopen each new deck with python-pptx.
Use table-preparation-preserve.py separately for baseline unmerged comparisons.
"""
import json
import pathlib
import subprocess
import sys
import zipfile
from pptx import Presentation

scratch = pathlib.Path(sys.argv[1])
root = scratch / "span-artifacts"
if root.exists():
    raise SystemExit(f"Move the existing {root} before running; artifact comparisons require fresh directories.")
cases = [(24, "distinct", "measured"), (30, "mixed", "measured"),
         (1000, "repeated", "measured"), (1000, "distinct", "measured"),
         (100, "distinct", "measured"), (24, "distinct", "estimated")]
scripts = ["é e\u0301\t42\nExact words", "Δοκιμή κειμένου", "Проверка текста", "مرحبا بالعالم", "日本語の文章"]
record = []
for count, labels, sizing in cases:
    name = f"{count}-{labels}-{sizing}"
    rows = [["Grouped evidence", "", "Value"]]
    for row in range(1, count + 1):
        values = ["R" if labels == "repeated" else f"R{row}", scripts[row % len(scripts)] if labels == "mixed" else
                  ("Ready" if count == 100 else "A detailed observation preserves every original word and needs room to wrap naturally."), "1,234"]
        if row % 3 == 0:
            values[0] += ": " + values[1]
            values[1] = ""
        rows.append(values)
    for trial in ["first", "repeat"]:
        subprocess.run([str(scratch / "spans"), str(count), labels, sizing, "1", "artifacts",
                        str(root / f"{trial}-{name}")], check=True, stdout=subprocess.DEVNULL)
    first, repeat = [root / f"{trial}-{name}" for trial in ["first", "repeat"]]
    files = sorted(p.name for p in first.iterdir())
    assert files == sorted(p.name for p in repeat.iterdir())
    for filename in files:
        a, b = (first / filename).read_bytes(), (repeat / filename).read_bytes()
        assert (json.loads(a) == json.loads(b)) if filename.endswith(".json") else a == b, (name, filename)
    with zipfile.ZipFile(first / "saved.pptx") as archive:
        assert archive.testzip() is None
    pages = json.loads((first / "geometry.json").read_text())
    assert len(files) == 2 + 2 * (len(pages) + 1)
    assert [r for p in pages for r in p["body_rows"]] == list(range(1, count + 1))
    deck = Presentation(first / "saved.pptx")
    # Presentation() includes its untouched initial slide before composed pages.
    assert len(deck.slides) == len(pages) + 1
    for slide, page in zip(list(deck.slides)[1:], pages):
        native, = [s.table for s in slide.shapes if s.has_table]
        assert [c.width for c in native.columns] == page["widths"]
        assert [r.height for r in native.rows] == page["heights"]
        assert page["fits"] and len(native.rows) == len(page["source_rows"])
        for local, source in enumerate(page["source_rows"]):
            cells = native.rows[local].cells
            # DrawingML soft breaks appear as VT in python-pptx text.
            assert [c.text.replace("\v", "\n") for c in cells] == rows[source], (name, source)
            merged = source % 3 == 0
            assert cells[0].is_merge_origin == merged and cells[1].is_spanned == merged
            assert cells[0].span_width == (2 if merged else 1) and cells[0].span_height == 1
            geometry = page["cells"][local * 3:(local + 1) * 3]
            assert geometry[0]["span"] == (2 if merged else 1)
            assert geometry[1]["covered"] == merged
            assert all(not c["issues"] for c in geometry)
            if merged:
                assert geometry[1]["height"] == 0 and not geometry[1]["diagnostics"]
    record.append({"case": name, "files": len(files), "pages": len(pages),
                   "deterministic": True, "independent_geometry_and_topology": True})
print(json.dumps(record, indent=2, sort_keys=True))
