"""Paired normal-Release render controls and absolute crowded-panel measurements.

Usage: python3 SCRIPT REPO SCRATCH
SCRATCH/{baseline,candidate}/CompositionRegression must include SwiftPM resources;
SCRATCH/font-templates contains private Calibri-{16x9,4x3}.potx review templates.
Run after builds/tests stop. No private inputs are copied into the repository.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import time

repo, scratch = (Path(p).resolve() for p in sys.argv[1:3])
spec = importlib.util.spec_from_file_location("profile", repo / "Tools/preview-profile/run.py")
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)
if hasattr(os, "sched_setaffinity"):
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
launcher = scratch / "measure-child"
subprocess.run(["cc", "-O2", str(repo / "docs/benchmarks/2026-10-16-measure-child.c"), "-o", str(launcher)], check=True)
templates = [scratch / f"font-templates/Calibri-{ratio}.potx" for ratio in ["16x9", "4x3"]]
fixture = repo / "Lectern/Tests/LecternCoreTests/Fixtures/crowded-panels.json"
cases = {"mixed": [""] * 3, "fitting-panels": ["--layouts"] + [""] * 3,
         "template-panels": ["--layouts"] + [str(templates[0])] * 3}
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
record = {"baseline_commit": "ddab73ba09554727d936039aaa30b8b3069fb200", "platform": platform.platform(),
          "toolchain": subprocess.check_output(["swift", "--version"], text=True).strip(),
          "memory_method": "native wait4; fresh process peak RSS in KiB", "warmups": 1, "pairs_per_case": 7,
          "binary_hashes": {v: sha(scratch / v / "CompositionRegression") for v in ["baseline", "candidate"]},
          "inputs": {p.name: sha(p) for p in templates + [fixture]}, "pairs": [], "crowded": [], "complete": False}
record["source_hashes"] = {str(p.relative_to(repo)): sha(p) for folder in ["Sources", "Lectern/Sources"]
                           for p in sorted((repo / folder).rglob("*.swift"))}
references = {}


def run(variant, name, args):
    output = scratch / "samples" / name
    output.parent.mkdir(exist_ok=True)
    usage = output.with_suffix(".usage.json")
    start = time.perf_counter()
    result = subprocess.run([str(launcher), str(usage), str(scratch / variant / "CompositionRegression"),
                             str(output), *args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    sample = {"elapsed_ms": (time.perf_counter() - start) * 1000, **json.loads(usage.read_text()),
              "stages": json.loads((output / "timings.json").read_text())}
    return sample, profile.composition_artifacts(output)


for pair in range(-1, 7):
    for case, args in cases.items():
        item = {"pair": pair, "warmup": pair < 0, "case": case,
                "order": ["baseline", "candidate"] if pair % 2 == 0 else ["candidate", "baseline"]}
        for variant in item["order"]:
            sample, artifacts = run(variant, f"{case}-{pair + 1}-{variant}", args)
            item[variant] = sample
            if case in references:
                assert artifacts == references[case], (case, variant, "changed saved output")
            else:
                references[case] = artifacts
        record["pairs"].append(item)
        print(case, pair, "identical output", flush=True)
    sample, artifacts = run("candidate", f"crowded-{pair + 1}",
                            ["--replay", str(fixture), "", *map(str, templates)])
    if "crowded" in references:
        assert artifacts == references["crowded"], "non-deterministic reflow"
    else:
        references["crowded"] = artifacts
    record["crowded"].append({"warmup": pair < 0, **sample})
    (scratch / "comparison.json").write_text(json.dumps(record, indent=2) + "\n")
record["artifacts"] = references
record["complete"] = True
(scratch / "comparison.json").write_text(json.dumps(record, indent=2) + "\n")
for case in cases:
    pairs = [p for p in record["pairs"] if p["case"] == case and not p["warmup"]]
    print(case, {k: statistics.median(100 * (p["candidate"][k] / p["baseline"][k] - 1) for p in pairs)
                 for k in ["process_cpu_ms", "elapsed_ms", "rss_kib"]})
print("crowded", {k: statistics.median(p[k] for p in record["crowded"] if not p["warmup"])
                  for k in ["process_cpu_ms", "elapsed_ms", "rss_kib"]})
