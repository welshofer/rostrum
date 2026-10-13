"""Paired Release measurements; run after builds, tests and profiling finish.

Usage from repository root: python3 this-file.py SCRATCH OUTPUT.json.
SCRATCH contains baseline-{unmerged,spans} and candidate-{unmerged,spans}, built
from the corresponding 2026-10-12 drivers. CPU/elapsed cover plan and compose
(including fresh preflight); wait4 RSS includes font setup and all five trials.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import resource
import statistics
import subprocess
import sys
import tempfile

scratch = Path(sys.argv[1])
record = {"baseline_commit": "d6aaefdd695db18502109cbed3030f1e82ba9473", "pairs": [],
          "platform": platform.platform(), "swift": subprocess.check_output(["swift", "--version"], text=True)}
source = hashlib.sha256()
for path in sorted(Path("Sources").rglob("*.swift")):
    source.update(str(path).encode() + b"\0")
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(65536), b""):
            source.update(block)
record["candidate_source_sha256"] = source.hexdigest()
def binary_digest(path):
    # Do not inflate the collector before fork/exec: the child's peak RSS may
    # include its inherited pre-exec footprint. Stream large binary checksums.
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(65536), b""):
            digest.update(block)
    return digest.hexdigest()

record["binaries_sha256"] = {f"{v}-{w}": binary_digest(scratch / f"{v}-{w}")
                             for v in ["baseline", "candidate"] for w in ["unmerged", "spans"]}
cases = [(24, "repeated", "measured"), (24, "distinct", "measured"),
         (1000, "repeated", "measured"), (1000, "distinct", "measured"),
         (100, "distinct", "measured"), (1000, "distinct", "estimated")]

def run(arguments):
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
        parent_peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1024 if sys.platform == "darwin" else 1)
        process = subprocess.Popen([str(a) for a in arguments], stdout=output, stderr=errors)
        _, status, usage = os.wait4(process.pid, 0)
        process.returncode = os.waitstatus_to_exitcode(status)
        errors.seek(0)
        if process.returncode:
            raise RuntimeError(errors.read().decode())
        output.seek(0)
        return {"samples": json.load(output), "rss_kib": usage.ru_maxrss / (1024 if sys.platform == "darwin" else 1),
                "collector_peak_rss_kib_before_spawn": parent_peak}

for pair in range(5):
    for workload in ["unmerged", "spans"]:
        for count, labels, sizing in cases:
            order = ["baseline", "candidate"] if pair % 2 == 0 else ["candidate", "baseline"]
            result = {"pair": pair, "workload": workload, "rows": count, "labels": labels, "sizing": sizing, "order": order}
            for variant in order:
                result[variant] = run([scratch / f"{variant}-{workload}", count, labels, sizing, 5, "compose"])
            record["pairs"].append(result)
Path(sys.argv[2]).write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
for workload in ["unmerged", "spans"]:
    for count, labels, sizing in cases:
        pairs = [r for r in record["pairs"] if (r["workload"], r["rows"], r["labels"], r["sizing"]) == (workload, count, labels, sizing)]
        print(workload, count, labels, sizing)
        for metric in ["plan_ms", "plan_cpu_ms", "compose_ms", "compose_cpu_ms", "rss_kib"]:
            medians, changes = {"baseline": [], "candidate": []}, []
            for pair in pairs:
                values = {}
                for variant in medians:
                    values[variant] = pair[variant][metric] if metric == "rss_kib" else statistics.median(
                        x[metric] for x in pair[variant]["samples"] if x["trial"] > 0)
                    medians[variant].append(values[variant])
                changes.append((values["candidate"] / values["baseline"] - 1) * 100)
            print(metric, *[round(statistics.median(medians[v]), 3) for v in medians],
                  "paired %", round(statistics.median(changes), 2), "range", round(min(changes), 2), round(max(changes), 2))
