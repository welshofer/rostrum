#!/usr/bin/env python3
"""Run AppTests without launching the SwiftUI application.

Defaults to InspectionRequestTests; --all-app-tests runs every app test and
--filter selects a bounded subset. Copies exact app/test sources and assets;
only LecternApp.swift is excluded. AppState tests own isolated defaults and
libraries, skip keychain access, and never call startup/migration. Local package
sources remain unchanged. The receipt hashes all copied and dependency inputs.
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
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--all-app-tests", action="store_true")
    selection.add_argument("--filter", default=None)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    scratch = root / ".build/app-headless"
    # Preserve the source layout for icon tests that resolve assets via #filePath.
    copied_tree = scratch / "Lectern"
    if copied_tree.exists():
        shutil.rmtree(copied_tree)
    copied_tree.mkdir(parents=True)
    entry = root / "Lectern/App/LecternApp.swift"
    sources = sorted(source for source in (root / "Lectern/App").rglob("*.swift") if source != entry)
    sources += sorted(source for source in (root / "Lectern/AppTests").rglob("*") if source.is_file())
    sources += sorted(source for source in (root / "Lectern/App/Assets.xcassets").rglob("*") if source.is_file())
    inputs = {}
    for source in sources:
        destination = scratch / source.relative_to(root)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256(destination.read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"copied input changed: {source}")
        inputs[str(source.relative_to(root))] = digest

    dependency_inputs = {}
    dependencies = [root / "Package.swift", root / "Lectern/Package.swift"]
    for directory in (root / "Sources", root / "Lectern/Sources"):
        dependencies += sorted(source for source in directory.rglob("*") if source.is_file())
    for source in dependencies:
        dependency_inputs[str(source.relative_to(root))] = hashlib.sha256(source.read_bytes()).hexdigest()

    manifest = '''// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: "LecternAppHarness",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(name: "LecternCore", path: LECTERN_PATH),
        .package(name: "Rostrum", path: ROSTRUM_PATH)
    ],
    targets: [
        .target(name: "Lectern", dependencies: [
            .product(name: "LecternCore", package: "LecternCore"),
            .product(name: "Rostrum", package: "Rostrum")],
            path: "Lectern/App", exclude: ["Assets.xcassets"]),
        .testTarget(name: "LecternAppTests", dependencies: [
            "Lectern", .product(name: "LecternCore", package: "LecternCore")],
            path: "Lectern/AppTests", resources: [.copy("Fixtures")])
    ])
'''.replace("LECTERN_PATH", json.dumps(str(root / "Lectern"))) \
   .replace("ROSTRUM_PATH", json.dumps(str(root)))
    (scratch / "Package.swift").write_text(manifest)
    command = ["swift", "test", "--package-path", str(scratch), "--disable-sandbox",
               "--jobs", "2"]
    if not args.all_app_tests:
        command += ["--filter", args.filter or "InspectionRequestTests"]
    environment = os.environ.copy()
    environment["CLANG_MODULE_CACHE_PATH"] = str(root / ".build/headless-module-cache")
    environment["SWIFT_MODULECACHE_PATH"] = str(root / ".build/headless-module-cache")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    log = args.output.with_suffix(".log")
    with log.open("w") as stream:
        result = subprocess.run(command, env=environment, stdout=stream,
                                stderr=subprocess.STDOUT, cwd=root)
    # Refuse a receipt that would mix revisions changed during the run.
    for relative, digest in {**inputs, **dependency_inputs}.items():
        if hashlib.sha256((root / relative).read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"source changed during verification: {relative}")
    receipt = {"command": command, "copiedInputs": inputs,
               "dependencyInputs": dependency_inputs,
               "testSelection": "all AppTests" if args.all_app_tests else args.filter or "InspectionRequestTests",
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
