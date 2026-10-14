#!/usr/bin/env python3
"""Collect caller-font fidelity profiles in fresh processes (macOS/Linux)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def json_write(path, data):
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def command_output(*args):
    if args[0] == "git":
        # Container checkouts can be owned by the host runner. Trust only this
        # tool's checkout for these read-only provenance queries, never '*'.
        args = ("git", "-c", f"safe.directory={ROOT}", *args[1:])
    try:
        return subprocess.check_output(args, cwd=ROOT, text=True, stderr=subprocess.STDOUT).strip()
    except subprocess.CalledProcessError as error:
        raise RuntimeError(f"Metadata command failed: {args}\n{error.output}") from error


def process_sample(command, log):
    # wait4 is per child; RUSAGE_CHILDREN would mix earlier processes' peaks.
    start = time.perf_counter()
    with log.open("wb") as stream:
        child = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT)
        _, status, usage = os.wait4(child.pid, 0)
        child.returncode = os.waitstatus_to_exitcode(status)
    elapsed = time.perf_counter() - start
    if child.returncode:
        raise RuntimeError(f"Profile failed ({child.returncode}); see {log}\n{log.read_text()}")
    return {"elapsedSeconds": elapsed, "userCPUSeconds": usage.ru_utime,
            "systemCPUSeconds": usage.ru_stime,
            "peakRSSBytes": usage.ru_maxrss * (1 if sys.platform == "darwin" else 1024)}


def collect(binary, fonts, output, runs=1, build_mode="unspecified"):
    binary, fonts, output = binary.resolve(), fonts.resolve(), output.resolve()
    if runs < 1:
        raise ValueError("runs must be positive")
    if output.exists():
        raise ValueError("Output already exists; choose a fresh directory")
    config = json.loads(fonts.read_text())
    font_hashes = {role: sha256(fonts.parent / config[role])
                   for role in ("regular", "bold", "italic", "boldItalic") if config.get(role)}
    binary_hash = sha256(binary)
    metadata = {"schemaVersion": 1, "sourceRevision": command_output("git", "rev-parse", "HEAD"),
                "sourceStatus": command_output("git", "status", "--porcelain"),
                "platform": platform.platform(), "machine": platform.machine(),
                "swift": command_output("swift", "--version"),
                "buildModeDeclaredByCaller": build_mode, "executableSHA256": binary_hash,
                "fontManifestSHA256": sha256(fonts), "fontSHA256": font_hashes,
                "powerpointSlideView": "pending", "powerpointExport": "pending", "lecternInspect": "pending",
                "measurementScope": "Each process includes preparation, validation, artifact writes and verification. "
                "Swift phases exclude artifact writes and verification except explicit fresh compose checks. "
                "RSS is the whole process peak. No OS font discovery, WebKit rasterization or UI first-preview measurement.",
                "profiles": [], "complete": False}
    output.mkdir(parents=True)
    json_write(output / "manifest.json", metadata)
    for aspect in ("4x3", "16x9"):
        for mode in ("external", "embedded"):
            name = f"{aspect}-{mode}"
            profile = {"name": name, "samples": []}
            reference = None
            reference_pages = None
            for run in range(1, runs + 1):
                case = output / f"{name}-{run}"
                sample = process_sample([str(binary), str(fonts), str(case), aspect, mode],
                                        output / f"{name}-{run}.log")
                report = json.loads((case / "report.json").read_text())
                artifacts = {p.name: sha256(p) for p in sorted(case.iterdir()) if p.name != "report.json"}
                if reference is not None and (artifacts != reference or report["pages"] != reference_pages):
                    raise RuntimeError(f"Nondeterministic decks, SVGs, diagnostics or geometry: {name}")
                reference, reference_pages = artifacts, report["pages"]
                sample.update(directory=case.name, artifactSHA256=artifacts,
                              reportSHA256=sha256(case / "report.json"), phases=report["phases"])
                profile["samples"].append(sample)
            metadata["profiles"].append(profile)
            json_write(output / "manifest.json", metadata)
    if binary_hash != sha256(binary) or metadata["fontManifestSHA256"] != sha256(fonts) or any(
        sha256(fonts.parent / config[role]) != digest for role, digest in font_hashes.items()
    ):
        raise RuntimeError("Executable or font inputs changed during collection; discard this run")
    metadata["complete"] = True
    json_write(output / "manifest.json", metadata)
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--fonts", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--build-mode", choices=("release", "debug", "unspecified"), default="unspecified")
    args = parser.parse_args()
    collect(args.binary, args.fonts, args.output, args.runs, args.build_mode)
    print(f"Four profiles saved to {args.output}. Native PowerPoint and Lectern review pending.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
