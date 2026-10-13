"""Run after all builds/tests finish. Paths: scratch directory, output JSON.

Expected binaries: pagination-baseline/candidate, small-baseline/candidate,
columns. Baselines are preserved before changing the algorithms.
"""
import json
import pathlib
import resource
import statistics
import subprocess
import sys

scratch = pathlib.Path(sys.argv[1])
record = {"baseline_commit": "d9354b6", "pairs": []}
for pair in range(5):
    for workload in ["small", "pagination"]:
        samples = {}
        order = ["baseline", "candidate"] if pair % 2 == 0 else ["candidate", "baseline"]
        for variant in order:
            samples[variant] = json.loads(subprocess.check_output([scratch / f"{workload}-{variant}"]))
        record["pairs"].append({"pair": pair, "workload": workload, "order": order, **samples})
record["columns"] = json.loads(subprocess.check_output([scratch / "columns", scratch / "column-specimens"]))
record["max_child_rss_kib"] = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
pathlib.Path(sys.argv[2]).write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")

for workload in ["small", "pagination"]:
    for distinct in [False, True]:
        for count in ([0] if workload == "small" else [100, 1000]):
            baseline, candidate, changes = [], [], []
            for pair in record["pairs"]:
                if pair["workload"] != workload:
                    continue
                medians = []
                for variant in ["baseline", "candidate"]:
                    samples = [x for x in pair[variant] if x["trial"] > 0
                               and x.get("unique", x.get("distinct_labels")) == distinct
                               and x.get("body_rows", 0) == count]
                    medians.append(statistics.median(x.get("seconds", x.get("plan_seconds")) for x in samples))
                baseline.append(medians[0]); candidate.append(medians[1])
                changes.append((medians[1] / medians[0] - 1) * 100)
            print(workload, distinct, count, "baseline/candidate ms", statistics.median(baseline) * 1000,
                  statistics.median(candidate) * 1000, "paired %", statistics.median(changes),
                  "range", min(changes), max(changes))
for count in [24, 1000, 100]:
    for distinct in [False, True]:
        for measured in [False, True]:
            rows = [x for x in record["columns"] if x["body_rows"] == count
                    and x["distinct_labels"] == distinct and x["measured"] == measured and x["trial"] > 0]
            print("columns", count, distinct, measured, "pages", rows[0]["pages"],
                  "plan/compose ms", *[statistics.median(x[k] for x in rows) * 1000
                                       for k in ["plan_seconds", "compose_with_preflight_seconds"]],
                  "candidates/extra/reuse", *[rows[0].get(k) for k in
                    ["evaluated_candidates", "additional_cell_measurements", "reused_cell_measurements"]])
print("max child RSS MiB", record["max_child_rss_kib"] / 1024)
