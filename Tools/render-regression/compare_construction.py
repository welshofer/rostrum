#!/usr/bin/env python3
"""Compare supplied rostrum-bench binaries in paired fresh processes; never build.

Default scenarios are slides-10, slides-100 and slides-1000. Each scenario gets
one excluded warmup pair followed by ten measured pairs in alternating AB/BA
order. Both variants must produce the same serialized PPTX bytes throughout.
The driver's checksum includes rendered SVG and is deliberately not an equality
gate: rendering semantics can differ between source revisions.

Supply the actual build commands and flags for each binary, together with its
source tree and declared revision. Actual source, package, driver and binary
bytes are hashed before and after measurement. This detects changes during the
run, but does not independently prove that a binary was built from those files.

--output and --work-dir must not already exist. Every invocation retains raw
stdout JSON and stderr. Each scenario retains its initial baseline PPTX and the
first measured PPTX per variant; other matching PPTXs are removed after hashing.
Mismatching outputs are retained
and fail the run. A failed run writes failure.json inside its new work directory,
never a successful final report. There is no speedup or visual acceptance gate.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys


VARIANTS = ("baseline", "candidate")


def identity(path):
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
            size += len(block)
    return {"sha256": digest.hexdigest(), "bytes": size}


def source_identity(root):
    """Record actual source bytes, including dirty trees and archive extractions."""
    required = [root / "Package.swift", root / "Tools/rostrum-bench/main.swift",
                root / "Tools/rostrum-bench/run.py"]
    source = root / "Sources"
    if not source.is_dir() or not all(path.is_file() for path in required):
        raise ValueError(f"Incomplete Rostrum benchmark source tree: {root}")
    paths = [root / "Package.swift"] + sorted(path for path in source.rglob("*") if path.is_file())
    paths += sorted(path for path in (root / "Tools/rostrum-bench").rglob("*") if path.is_file())
    if (root / "Package.resolved").is_file():
        paths.append(root / "Package.resolved")
    files = {path.relative_to(root).as_posix(): identity(path) for path in sorted(paths)}
    encoded = json.dumps(files, sort_keys=True, separators=(",", ":")).encode()
    return {"root": str(root), "files": files,
            "manifestSHA256": hashlib.sha256(encoded).hexdigest()}


def write_json(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, sort_keys=True, allow_nan=False)
        stream.write("\n")


def distribution(values):
    ordered = sorted(values)
    return {"samplesMS": values, "count": len(values),
            "medianMS": statistics.median(values), "minMS": ordered[0],
            "maxMS": ordered[-1],
            "observedP95MS": ordered[min(len(ordered) - 1, int(.95 * len(ordered)))]}


def ratio(numerator, denominator):
    return numerator / denominator if denominator else None


def summarize(entries, primary_phase):
    measured = [entry for entry in entries if not entry["excludedWarmup"]]
    timings = {}
    phase_sets = {}
    for variant in VARIANTS:
        samples = [entry["sample"] for entry in measured if entry["variant"] == variant]
        phase_sets[variant] = set(samples[0]["phases"])
        if any(set(sample["phases"]) != phase_sets[variant] for sample in samples):
            raise ValueError(f"{variant}: phase names changed between samples")
        timings[variant] = {phase: distribution([sample["phases"][phase] for sample in samples])
                            for phase in sorted(phase_sets[variant])}
    common = sorted(phase_sets["baseline"] & phase_sets["candidate"])
    comparisons = {}
    for phase in common:
        baseline = timings["baseline"][phase]["medianMS"]
        candidate = timings["candidate"][phase]["medianMS"]
        pair_ratios = []
        pair_deltas = []
        for pair in sorted({entry["pair"] for entry in measured}):
            values = {entry["variant"]: entry["sample"]["phases"][phase]
                      for entry in measured if entry["pair"] == pair}
            value = ratio(values["candidate"], values["baseline"])
            if value is not None:
                pair_ratios.append(value)
            pair_deltas.append(values["candidate"] - values["baseline"])
        median_ratio = ratio(candidate, baseline)
        comparisons[phase] = {
            "candidateOverBaselineMedianRatio": median_ratio,
            "medianChangePercent": (median_ratio - 1) * 100 if median_ratio is not None else None,
            "pairedCandidateMinusBaselineMS": pair_deltas,
            "pairedCandidateOverBaselineRatios": pair_ratios,
            "medianPairedRatio": statistics.median(pair_ratios) if pair_ratios else None,
        }
    return {"timings": timings, "comparisons": comparisons, "primaryPhase": primary_phase,
            "primaryComparison": comparisons[primary_phase],
            "baselineOnlyPhases": sorted(phase_sets["baseline"] - phase_sets["candidate"]),
            "candidateOnlyPhases": sorted(phase_sets["candidate"] - phase_sets["baseline"])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for variant in VARIANTS:
        parser.add_argument("--" + variant, "--" + variant + "-binary", type=Path, required=True)
        parser.add_argument("--" + variant + "-source", type=Path, required=True)
        parser.add_argument("--" + variant + "-revision", required=True)
        parser.add_argument("--" + variant + "-build-command", required=True)
        parser.add_argument("--" + variant + "-build-flags", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--slide-counts", type=int, nargs="+", default=[10, 100, 1000])
    parser.add_argument("--runs", type=int, default=10, help="Measured pairs per scenario, 10..100")
    parser.add_argument("--warmups", type=int, default=1, help="Excluded pairs per scenario, 1..10")
    parser.add_argument("--phase", default="construct", help="Primary phase; every phase is still reported")
    parser.add_argument("--timeout", type=float, default=120, help="Seconds per fresh process, 1..600")
    parser.add_argument("--font", type=Path, help="Optional identical font for the separate post-render text-fitting phase")
    args = parser.parse_args()
    if not (10 <= args.runs <= 100 and 1 <= args.warmups <= 10 and 1 <= args.timeout <= 600):
        parser.error("Require runs 10..100, warmups 1..10 and timeout 1..600")
    if not (1 <= len(args.slide_counts) <= 8 and len(set(args.slide_counts)) == len(args.slide_counts)
            and all(1 <= count <= 5000 for count in args.slide_counts)):
        parser.error("Supply 1..8 distinct slide counts, each in 1..5000")
    for variant in VARIANTS:
        for field in ("revision", "build_command", "build_flags"):
            if not getattr(args, variant + "_" + field).strip():
                parser.error(f"{variant} {field} must be explicitly supplied")
    output, work_dir = args.output.absolute(), args.work_dir.absolute()
    if os.path.lexists(output) or os.path.lexists(work_dir):
        parser.error("Output and work directory must both be new; existing evidence is never overwritten")
    output, work_dir = output.resolve(), work_dir.resolve()
    if work_dir == output or output in work_dir.parents:
        parser.error("Output must be a file, not the work directory or its ancestor")
    binaries = {name: getattr(args, name).resolve(strict=True) for name in VARIANTS}
    roots = {name: getattr(args, name + "_source").resolve(strict=True) for name in VARIANTS}
    if any(not path.is_file() or not os.access(path, os.X_OK) for path in binaries.values()):
        parser.error("Both supplied binaries must be executable files")
    font = args.font.resolve(strict=True) if args.font else None
    runner = Path(__file__).resolve()

    def snapshot():
        return {"sources": {name: source_identity(root) for name, root in roots.items()},
                "binaries": {name: {"path": str(path), **identity(path)} for name, path in binaries.items()},
                "runner": {"path": str(runner), **identity(runner)},
                "font": {"path": str(font), **identity(font)} if font else None}

    before = snapshot()
    driver_files = {name: {path: value for path, value in before["sources"][name]["files"].items()
                           if path.startswith("Tools/rostrum-bench/") and path.endswith(".swift")}
                    for name in VARIANTS}
    if driver_files["baseline"] != driver_files["candidate"]:
        parser.error("Benchmark driver source must be byte-identical across variants")
    report = {
        "schema": 1, "status": "running", "startedUTC": datetime.now(timezone.utc).isoformat(),
        "comparison": "Paired fresh-process construction with identical serialized PPTX output",
        "acceptance": "No rendering equivalence, visual conformance, or speedup is asserted",
        "platform": platform.platform(), "machine": platform.machine(), "python": sys.version,
        "observedSwiftToolchain": subprocess.check_output(["swift", "--version"], text=True).strip(),
        "declaredBuilds": {name: {"revision": getattr(args, name + "_revision"),
                                 "command": getattr(args, name + "_build_command"),
                                 "flags": getattr(args, name + "_build_flags")} for name in VARIANTS},
        "provenanceLimit": "Actual bytes are hashed; build commands/revisions and binary-to-source linkage remain caller-supplied provenance",
        "before": before,
        "method": {"measuredPairsPerScenario": args.runs, "excludedWarmupPairsPerScenario": args.warmups,
                   "order": "Measured pair 0 AB, pair 1 BA, alternating; warmups alternate separately; never concurrent",
                   "slideCounts": args.slide_counts, "primaryPhase": args.phase,
                   "freshProcessPerSample": True, "registeredRenderingFonts": False,
                   "fontUse": "Optional font affects text-fitting after rendering only",
                   "environment": "Inherited host environment; ROSTRUM_PROFILE_FONTS removed, ROSTRUM_BENCH_FONT explicit or removed, unique ROSTRUM_BENCH_OUTPUT per process",
                   "workingDirectory": "Each variant's supplied source root",
                   "outputCapture": "Original rostrum-bench writes PPTX after all timed phases; capture hash and actual bytes, not render checksum",
                   "retention": "All stdout/stderr; initial baseline and first measured PPTX per variant/scenario; mismatching PPTXs retained",
                   "tailLimit": "Observed quantile of a small sample, not a population-tail estimate"},
        "invocations": [], "scenarios": {},
    }
    work_dir.mkdir(parents=True, exist_ok=False)
    write_json(work_dir / "provenance-before.json", report)
    environment = dict(os.environ)
    environment.pop("ROSTRUM_PROFILE_FONTS", None)
    environment.pop("ROSTRUM_BENCH_FONT", None)
    if font:
        environment["ROSTRUM_BENCH_FONT"] = str(font)
    try:
        for count in args.slide_counts:
            scenario = f"slides-{count}"
            directory = work_dir / scenario
            directory.mkdir()
            expected_output = None
            entries = []
            for ordinal in range(args.warmups + args.runs):
                excluded = ordinal < args.warmups
                pair = ordinal if excluded else ordinal - args.warmups
                order = VARIANTS if pair % 2 == 0 else tuple(reversed(VARIANTS))
                for name in order:
                    prefix = directory / f"{'warmup' if excluded else 'pair'}-{pair:03d}-{name}"
                    stdout, stderr, pptx = (Path(str(prefix) + suffix) for suffix in ("-stdout.json", "-stderr.log", ".pptx"))
                    environment["ROSTRUM_BENCH_OUTPUT"] = str(pptx)
                    command = [str(binaries[name]), scenario]
                    entry = {"scenario": scenario, "variant": name, "pair": pair,
                             "excludedWarmup": excluded, "command": command, "cwd": str(roots[name]),
                             "stdoutPath": str(stdout), "stderrPath": str(stderr), "outputPath": str(pptx)}
                    report["invocations"].append(entry)
                    with stdout.open("xb") as out_stream, stderr.open("xb") as err_stream:
                        result = subprocess.run(command, cwd=roots[name], env=environment,
                                                stdout=out_stream, stderr=err_stream,
                                                timeout=args.timeout, check=False)
                    entry["returnCode"] = result.returncode
                    entry["stdoutIdentity"], entry["stderrIdentity"] = identity(stdout), identity(stderr)
                    if result.returncode:
                        raise ValueError(f"{scenario} {name} exited {result.returncode}; see {stderr}")
                    sample = json.loads(stdout.read_bytes())
                    phases = sample.get("phases")
                    if (sample.get("scenario") != scenario or sample.get("slideCount") != count
                            or not isinstance(phases, dict) or args.phase not in phases
                            or any(type(value) not in (float, int) or not math.isfinite(value) or value < 0
                                   for value in phases.values())):
                        raise ValueError(f"{scenario} {name}: driver sample contract differs")
                    entry["sample"] = sample
                    captured = identity(pptx)
                    entry["serializedPPTX"] = captured
                    entry["outputRetained"] = True
                    if sample.get("outputBytes") != captured["bytes"]:
                        raise ValueError(f"{scenario} {name}: reported output size differs from captured PPTX")
                    if expected_output is None:
                        expected_output = captured
                    if captured != expected_output:
                        raise ValueError(f"{scenario} {name}: serialized PPTX differs across samples/revisions")
                    entries.append(entry)
                    keep_reference = excluded and pair == 0 and name == "baseline"
                    if not keep_reference and (excluded or pair != 0):
                        pptx.unlink()
                        entry["outputRetained"] = False
                    print(f"{scenario} {'warmup' if excluded else 'pair'} {pair} {name}: "
                          f"{args.phase}={phases[args.phase]:.6f} ms", flush=True)
            report["scenarios"][scenario] = {**summarize(entries, args.phase),
                                              "serializedPPTX": expected_output,
                                              "allSampleAndRevisionPPTXIdentitiesEqual": True,
                                              "referencePPTX": entries[0]["outputPath"],
                                              "representativePPTXs": [entry["outputPath"] for entry in entries
                                                                      if entry["outputRetained"] and not entry["excludedWarmup"]]}
        report["after"] = snapshot()
        report["sourceBinaryDriverAndFontUnchanged"] = report["after"] == before
        if not report["sourceBinaryDriverAndFontUnchanged"]:
            raise ValueError("Source, package, driver, runner, binary or font changed during measurement")
        report["status"] = "completed"
        report["finishedUTC"] = datetime.now(timezone.utc).isoformat()
        output.parent.mkdir(parents=True, exist_ok=True)
        write_json(output, report)
    except Exception as error:
        report["status"] = "failed"
        report["error"] = f"{type(error).__name__}: {error}"
        report["finishedUTC"] = datetime.now(timezone.utc).isoformat()
        if "after" not in report:
            try:
                report["after"] = snapshot()
                report["sourceBinaryDriverAndFontUnchanged"] = report["after"] == before
            except Exception as snapshot_error:
                report["afterSnapshotError"] = f"{type(snapshot_error).__name__}: {snapshot_error}"
        write_json(work_dir / "failure.json", report)
        raise


if __name__ == "__main__":
    main()
