#!/usr/bin/env python3
"""Run the actual AppState inspection tests without launching the SwiftUI app.

Copies unmodified app sources except the application entry point into a scratch
SwiftPM library. The test initializes AppState with an isolated defaults suite
and skipKeychain, and never calls start() (migration/pruning). Package sources
remain local. The JSON receipt pins every copied input and the exact command.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    scratch = root / ".build/inspection-headless"
    app = scratch / "Sources/Lectern"
    tests = scratch / "Tests/InspectionRequestTests"
    for directory in (app, tests):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True)

    inputs = {}
    copies = [(source, app / source.name)
              for source in sorted((root / "Lectern/App").glob("*.swift"))
              if source.name != "LecternApp.swift"]
    copies += [(root / "Lectern/AppTests/InspectionRequestTests.swift",
                tests / "InspectionRequestTests.swift"),
               (root / "Lectern/AppTests/Fixtures/hello.pptx",
                tests / "Fixtures/hello.pptx")]
    for source, destination in copies:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        assert hashlib.sha256(destination.read_bytes()).hexdigest() == digest
        inputs[str(source.relative_to(root))] = digest

    manifest = '''// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: "LecternInspectionHarness",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(name: "LecternCore", path: LECTERN_PATH),
        .package(name: "Rostrum", path: ROSTRUM_PATH)
    ],
    targets: [
        .target(name: "Lectern", dependencies: [
            .product(name: "LecternCore", package: "LecternCore"),
            .product(name: "Rostrum", package: "Rostrum")]),
        .testTarget(name: "InspectionRequestTests", dependencies: [
            "Lectern", .product(name: "LecternCore", package: "LecternCore")],
            resources: [.copy("Fixtures")])
    ])
'''.replace("LECTERN_PATH", json.dumps(str(root / "Lectern"))) \
   .replace("ROSTRUM_PATH", json.dumps(str(root)))
    (scratch / "Package.swift").write_text(manifest)
    command = ["swift", "test", "--package-path", str(scratch), "--disable-sandbox",
               "--jobs", "2", "--filter", "InspectionRequestTests"]
    environment = os.environ.copy()
    environment["CLANG_MODULE_CACHE_PATH"] = str(root / ".isolated-cache/module")
    environment["SWIFT_MODULECACHE_PATH"] = str(root / ".isolated-cache/module")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    log = args.output.with_suffix(".log")
    with log.open("w") as stream:
        result = subprocess.run(command, env=environment, stdout=stream,
                                stderr=subprocess.STDOUT, cwd=root)
    receipt = {"command": command, "copiedInputs": inputs,
               "entryPointExcluded": "Lectern/App/LecternApp.swift",
               "manifestSHA256": hashlib.sha256(manifest.encode()).hexdigest(),
               "exitCode": result.returncode, "log": str(log),
               "logSHA256": hashlib.sha256(log.read_bytes()).hexdigest()}
    args.output.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"exitCode": result.returncode, "receipt": str(args.output),
                      "log": str(log)}))
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
