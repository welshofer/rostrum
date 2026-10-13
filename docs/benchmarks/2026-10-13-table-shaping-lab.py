"""Compare two fresh Templates Library Lab batches, including inspector reports.

Usage: python3 this-file.py BASELINE_PARENT CANDIDATE_PARENT.
Both parents must contain exactly the 16:9 and 4:3 Templates recipe results.
"""
import json
from pathlib import Path
import sys
import zipfile
from pptx import Presentation

def batch(root):
    result = {}
    for path in Path(root).glob("templates-*/report.json"):
        report = json.loads(path.read_text())
        alternative = report["options"]["alternative"]
        assert alternative not in result
        result[alternative] = (path.parent, report)
    assert set(result) == {False, True}
    return result

baseline, candidate = [batch(p) for p in sys.argv[1:]]
results = []
for alternative in [False, True]:
    before, before_report = baseline[alternative]
    after, after_report = candidate[alternative]
    for report in [before_report, after_report]:
        del report["elapsedSeconds"]
        assert all(c["passed"] for c in report["checks"])
    assert before_report == after_report
    files = sorted(str(p.relative_to(before)) for p in before.rglob("*") if p.is_file() and p.name != "report.json")
    assert files == sorted(str(p.relative_to(after)) for p in after.rglob("*") if p.is_file() and p.name != "report.json")
    archives = reopened = decks_and_previews = 0
    for name in files:
        assert (before / name).read_bytes() == (after / name).read_bytes(), name
        suffix = Path(name).suffix
        if suffix in [".pptx", ".potx", ".ppsx", ".svg"]:
            decks_and_previews += 1
        if suffix in [".pptx", ".potx", ".ppsx"]:
            with zipfile.ZipFile(after / name) as archive:
                assert archive.testzip() is None
            archives += 1
        if suffix == ".pptx":
            assert len(Presentation(after / name).slides) > 0
            reopened += 1
    results.append({"alternative": alternative, "slides": after_report["slideCount"],
                    "checks": len(after_report["checks"]), "identical_files": len(files),
                    "identical_decks_and_previews": decks_and_previews,
                    "archives_crc_validated": archives, "independently_reopened_pptx": reopened,
                    "identical_report_except_elapsed_time": True})
print(json.dumps(results, indent=2, sort_keys=True))
