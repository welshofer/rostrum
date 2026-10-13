"""From the repository root: python3 this-file.py SCRATCH OUTPUT.json.

SCRATCH contains baseline/candidate binaries built from the same Swift driver.
Run only after all builds/tests finish. Uses wait4 to retain per-process RSS.
"""
import json
import os
import pathlib
import statistics
import subprocess
import sys
import tempfile

scratch = pathlib.Path(sys.argv[1])
record = {"baseline_commit": "9359abd927b4305704d5ee0d3defad41194029f9", "pairs": []}
cases = [(24, "repeated", "measured"), (24, "distinct", "measured"),
         (1000, "repeated", "measured"), (1000, "distinct", "measured"),
         (100, "distinct", "measured"), (1000, "distinct", "estimated")]

def run(arguments):
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
        process = subprocess.Popen([str(a) for a in arguments], stdout=output, stderr=errors)
        _, status, usage = os.wait4(process.pid, 0)
        process.returncode = os.waitstatus_to_exitcode(status)
        errors.seek(0)
        if process.returncode:
            raise RuntimeError(errors.read().decode())
        output.seek(0)
        return {"samples": json.load(output), "rss_kib": usage.ru_maxrss / (1024 if sys.platform == "darwin" else 1)}

for pair in range(5):
    for count, labels, sizing in cases:
        order = ["baseline", "candidate"] if pair % 2 == 0 else ["candidate", "baseline"]
        result = {"pair": pair, "rows": count, "labels": labels, "sizing": sizing, "order": order}
        for variant in order:
            result[variant] = run([scratch / variant, count, labels, sizing, 5, "compose"])
        record["pairs"].append(result)
pathlib.Path(sys.argv[2]).write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
for count, labels, sizing in cases:
    pairs = [r for r in record["pairs"] if (r["rows"], r["labels"], r["sizing"]) == (count, labels, sizing)]
    print(count, labels, sizing)
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
              "paired %", round(statistics.median(changes), 2),
              "range", round(min(changes), 2), round(max(changes), 2))
