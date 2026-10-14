#!/usr/bin/env python3
"""Alternate isolated Release processes; retain all samples, including regressions.

Usage: python3 this.py /scratch/with/baseline/and/candidate report.json
Requires Linux and the repository's pinned python-pptx oracle.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import resource
import sys
import zipfile

root, report = Path(sys.argv[1]), Path(sys.argv[2])
cases = ["control", "comparison", "dense", "source", "long-source", "cited-dense", "repeated-source", "table"]
records = []
collector_rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
for case in cases:
    for pair in range(11):  # first pair warms executable/filesystem state
        for kind in (["baseline", "candidate"] if pair % 2 == 0 else ["candidate", "baseline"]):
            output = root / f"{kind}-{case}-{pair}"
            output.mkdir(exist_ok=False)
            pid = os.posix_spawn(str(root / kind), [str(root / kind), str(output), case], os.environ,
                file_actions=[(os.POSIX_SPAWN_OPEN, 1, os.devnull, os.O_WRONLY, 0)])
            _, status, resources = os.wait4(pid, 0)
            assert os.waitstatus_to_exitcode(status) == 0, (case, kind, pair, status)
            data = json.loads((output / "result.json").read_text())
            data.update(binary=kind, pair=pair, warmup=pair == 0, peakRSSKiB=resources.ru_maxrss)
            records.append(data)

# Independent read-back: ZIP integrity, exact original paragraphs, notes and
# coverage of native sections. Text can span pages, but facts cannot duplicate.
# Import heavier oracle modules only after timing and memory collection.
from pptx import Presentation
from lxml import etree
checks = []
for case in cases:
    for kind in ["baseline", "candidate"]:
        output = root / f"{kind}-{case}-1"
        path = output / "saved.pptx"
        with zipfile.ZipFile(path) as archive:
            assert archive.testzip() is None
        deck = Presentation(path)
        source = json.loads((output / "input.json").read_text())
        words = "\n".join(shape.text for slide in deck.slides for shape in slide.shapes if shape.has_text_frame)
        for item in source["slides"]:
            body = item.get("body") or {}
            paragraphs = [bullet["text"] for bullet in body.get("bullets", [])]
            for side in ["left", "right"]:
                paragraphs.extend(body.get(side, {}).get("bullets", []))
            for text in paragraphs:
                assert words.count(text) == 1, (case, kind, text)
            if item.get("notes"):
                assert all(item["notes"] in slide.notes_slide.notes_text_frame.text for slide in deck.slides)
            if case == "source":
                assert words.count(body["source"]) == 1
        # lxml XPath's namespace set is independent of python-pptx's registry.
        tree = etree.fromstring(deck.part.blob)
        ns = {"p": "http://schemas.openxmlformats.org/presentationml/2006/main",
              "p14": "http://schemas.microsoft.com/office/powerpoint/2010/main"}
        slides = tree.xpath("./p:sldIdLst/p:sldId/@id", namespaces=ns)
        sections = tree.xpath(".//p14:section/p14:sldIdLst/p14:sldId/@id", namespaces=ns)
        assert sections == slides
        checks.append({"case": case, "binary": kind, "slides": len(deck.slides),
                       "zip": "passed", "content": "passed", "sections": "passed",
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})

for case in cases:
    for pair in range(11):
        before, after = [root / f"{kind}-{case}-{pair}" for kind in ["baseline", "candidate"]]
        assert (before / "saved.pptx").read_bytes() == (after / "saved.pptx").read_bytes(), (case, pair, "PPTX differs")
        assert (before / "diagnostics.json").read_bytes() == (after / "diagnostics.json").read_bytes(), (case, pair, "Diagnostics differ")
        assert sorted(p.name for p in before.glob("*.svg")) == sorted(p.name for p in after.glob("*.svg"))
        assert all(svg.read_bytes() == (after / svg.name).read_bytes() for svg in before.glob("*.svg")), (case, pair, "SVG differs")
for case in cases:
    for kind in ["baseline", "candidate"]:
        hashes = {hashlib.sha256((root / f"{kind}-{case}-{pair}" / "saved.pptx").read_bytes()).hexdigest()
                  for pair in range(11)}
        assert len(hashes) == 1, (case, kind, "Nondeterministic saved output")
summary = {}
for case in cases:
    samples = [r for r in records if r["case"] == case and not r["warmup"]]
    summary[case] = {}
    for kind in ["baseline", "candidate"]:
        selected = [r for r in samples if r["binary"] == kind]
        summary[case][kind] = {key: statistics.median(r[key] for r in selected)
                               for key in ["cpuSeconds", "elapsedSeconds", "peakRSSKiB", "slides"]}
    ratios = []
    for pair in range(1, 11):
        values = {r["binary"]: r["cpuSeconds"] for r in samples if r["pair"] == pair}
        ratios.append(100 * (values["candidate"] / values["baseline"] - 1))
    summary[case]["pairedCPUPercent"] = {"median": statistics.median(ratios), "min": min(ratios), "max": max(ratios)}

report.write_text(json.dumps({"platform": platform.platform(), "baselineCommit": "27bf372db83aea787afab096af2143025aa6f622",
    "binaries": {kind: hashlib.sha256((root / kind).read_bytes()).hexdigest() for kind in ["baseline", "candidate"]},
    "driverSHA256": hashlib.sha256(Path(__file__).with_suffix(".swift").read_bytes()).hexdigest(),
    "scope": "Production render CPU/elapsed includes save and SVG previews; process RSS includes startup and read-back. Missing fonts are recorded per sample.",
    "collectorPeakRSSBeforeSpawnKiB": collector_rss,
    "allPPTXSVGAndDiagnosticsByteIdentical": True,
    "repeatedPPTXOutputsIdentical": True,
    "checks": checks, "summary": summary, "samples": records}, indent=2) + "\n")
print(json.dumps(summary, indent=2))
