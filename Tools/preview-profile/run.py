#!/usr/bin/env python3
"""Profile production LecternCore in fresh processes; retain all raw evidence."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import platform
import sys

# The imported collector lives inside a SwiftPM executable directory.
# Do not leave Python bytecode there as an unhandled package resource.
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("native_fidelity_collector", ROOT / "Tools/native-fidelity/run.py")
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)


def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def inspection_artifacts(directory):
    return {str(p.relative_to(directory)): shared.sha256(p) for p in sorted(directory.rglob("*"))
            if p.is_file() and p != directory / "timings.json"}


def composition_artifacts(directory):
    """Normalize only output paths, random snapshot names and elapsed timing."""
    manifest = json.loads((directory / "manifest.json").read_text())
    artifacts = {}
    for index, record in enumerate(manifest):
        if record.get("structuralStatus") != "passed":
            raise ValueError("Composition failed its saved-content checks")
        record = dict(record)
        deck = Path(record.pop("deck"))
        snapshot = Path(record.pop("snapshot"))
        record.pop("renderSeconds")
        artifacts[f"{index}/result"] = canonical(record)
        artifacts[f"{index}/snapshot"] = canonical(json.loads(snapshot.read_text()))
        for path in sorted(deck.parent.iterdir()):
            if path.suffix in (".pptx", ".svg") or path.name == "preview-diagnostics.json":
                artifacts[f"{index}/{path.name}"] = shared.sha256(path)
    return artifacts


def load_workloads(path):
    config = json.loads(path.read_text())
    result, names = [], set()
    for source in config["workloads"]:
        case = dict(source)
        name = case["name"]
        if not name or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in name) or name in names:
            raise ValueError("Workload names must be unique simple directory names")
        names.add(name)
        files = []
        if case["kind"] == "inspect":
            case["input"] = str((path.parent / case["input"]).resolve())
            files = [case["input"]]
        elif case["kind"] == "compose":
            args = case.get("arguments", [])
            resolved = []
            for arg in args:
                if arg in ("--tables", "--replay"):
                    resolved.append(arg)
                elif arg.startswith("--"):
                    raise ValueError(f"Unsupported composition option: {arg}")
                else:
                    file = str((path.parent / arg).resolve())
                    files.append(file); resolved.append(file)
            if "--replay" in resolved and (resolved[-1] == "--replay" or resolved[resolved.index("--replay") + 1].startswith("--")):
                raise ValueError("--replay requires a file")
            case["arguments"] = resolved
        else:
            raise ValueError("Workload kind must be inspect or compose")
        case["inputSHA256"] = {f: shared.sha256(f) for f in files}
        result.append(case)
    if not result:
        raise ValueError("At least one workload is required")
    return result


def collect(config, output, inspection, composition=None, runs=3, warmups=1, repeat=2, build_mode="unspecified",
            baseline_inspection=None, baseline_composition=None):
    if runs < 1 or warmups < 0 or not 1 <= repeat <= 100:
        raise ValueError("Invalid run, warmup or repeat count")
    if output.exists():
        raise ValueError("Output already exists; choose a fresh directory")
    config = config.resolve()
    workloads = load_workloads(config)
    executables = {"inspect": inspection.resolve()}
    if any(w["kind"] == "compose" for w in workloads):
        if composition is None:
            raise ValueError("Composition workloads require --composition-binary")
        executables["compose"] = composition.resolve()
    variants = {"candidate": executables}
    if baseline_inspection is not None:
        baseline = {"inspect": baseline_inspection.resolve()}
        if "compose" in executables:
            if baseline_composition is None:
                raise ValueError("Composition comparison requires --baseline-composition-binary")
            baseline["compose"] = baseline_composition.resolve()
        variants["baseline"] = baseline
    elif baseline_composition is not None:
        raise ValueError("Baseline composition requires --baseline-inspection-binary")
    hashes = {str(p): shared.sha256(p) for variant in variants.values() for p in variant.values()}
    manifest = {"schemaVersion": 1, "complete": False, "buildMode": build_mode,
        "platform": platform.platform(), "python": platform.python_version(),
        "swiftVersion": shared.command_output("swift", "--version"),
        "sourceRevision": shared.command_output("git", "rev-parse", "HEAD"),
        "sourceDirty": bool(shared.command_output("git", "status", "--porcelain")),
        "executables": {v: {k: str(p) for k, p in bins.items()} for v, bins in variants.items()},
        "executableSHA256": hashes, "configSHA256": shared.sha256(config),
        "warmups": warmups, "runs": runs, "inspectionOperationsPerProcess": repeat,
        "measurementScope": "Release must be selected by the caller after building. Executable hashes identify binaries; checkout SHA does not establish how they were built. Every sample and warmup uses a fresh process; filesystem caches can be warm. Inspection repeats reuse the process, not a presentation or font registry. Composition is one operation per style per process. Stage CPU is all threads in that process. Whole-process CPU, elapsed and peak RSS include exports and evidence writes. No WebKit or UI; no native visual acceptance.",
        "workloads": []}
    output.mkdir(parents=True)
    shared.json_write(output / "manifest.json", manifest)
    for case in workloads:
        record = dict(case, samples=[])
        manifest["workloads"].append(record)
        reference = None
        for index in range(warmups + runs):
            order = list(variants) if index % 2 == 0 else list(reversed(variants))
            for variant in order:
                name = f"{case['name']}-{variant}-{index + 1}"
                directory = output / name
                command = [str(variants[variant][case["kind"]])]
                if case["kind"] == "inspect":
                    command += [case["input"], str(directory), "--repeat", str(repeat)]
                else:
                    command += [str(directory)] + case["arguments"]
                sample = shared.process_sample(command, output / f"{name}.log")
                if case["kind"] == "inspect":
                    operations = [directory] if repeat == 1 else [directory / f"run-{n + 1}" for n in range(repeat)]
                    artifacts = inspection_artifacts(operations[0])
                    if any(inspection_artifacts(p) != artifacts for p in operations[1:]):
                        raise ValueError(f"Repeated inspection output changed: {name}")
                    timings = [json.loads((p / "timings.json").read_text()) for p in operations]
                else:
                    artifacts = composition_artifacts(directory)
                    timings = json.loads((directory / "timings.json").read_text())
                if any(t.get("stages", {}).get("droppedSamples") != 0 for t in timings):
                    raise ValueError("Missing or truncated stage trace")
                if reference is not None and reference != artifacts:
                    raise ValueError(f"Output changed between fresh processes: {name}")
                reference = artifacts
                if any(shared.sha256(p) != h for p, h in case["inputSHA256"].items()):
                    raise ValueError("Workload modified its source input")
                sample.update(variant=variant, directory=name, warmup=index < warmups, artifactSHA256=artifacts, timings=timings)
                record["samples"].append(sample)
                shared.json_write(output / "manifest.json", manifest)
    if any(shared.sha256(p) != h for case in workloads for p, h in case["inputSHA256"].items()):
        raise ValueError("Workload input changed during collection")
    if any(shared.sha256(p) != h for p, h in hashes.items()) or shared.sha256(config) != manifest["configSHA256"]:
        raise ValueError("Executable or config changed during collection")
    manifest["complete"] = True
    shared.json_write(output / "manifest.json", manifest)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workloads", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--inspection-binary", type=Path, required=True)
    parser.add_argument("--composition-binary", type=Path)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--warmups", type=int, default=1)
    parser.add_argument("--repeat", type=int, default=2)
    parser.add_argument("--build-mode", choices=("release", "debug", "unspecified"), default="unspecified")
    parser.add_argument("--baseline-inspection-binary", type=Path)
    parser.add_argument("--baseline-composition-binary", type=Path)
    args = parser.parse_args()
    collect(args.workloads, args.output.resolve(), args.inspection_binary, args.composition_binary,
            args.runs, args.warmups, args.repeat, args.build_mode,
            args.baseline_inspection_binary, args.baseline_composition_binary)
    print(f"Saved profiles and identical-output evidence to {args.output}; native measurements remain separate.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError) as error:
        sys.exit(str(error))
