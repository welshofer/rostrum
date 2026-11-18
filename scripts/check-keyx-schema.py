#!/usr/bin/env python3
"""Validate .keyx output against Apple's separately downloaded schema archive.

Test-only dependency: jsonschema==4.25.1. No schemas or theme assets are bundled.
Source: https://developer.apple.com/download/files/keynote-interchange-format-json-schema.zip
"""

import argparse
import json
import zipfile

from jsonschema import Draft202012Validator
from jsonschema.exceptions import best_match
from referencing import Registry, Resource


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schemas", required=True, help="Apple's JSON Schema ZIP")
    parser.add_argument("decks", nargs="+")
    args = parser.parse_args()
    base = "https://rostrum.invalid/keyx-schema/"
    schemas = {}
    with zipfile.ZipFile(args.schemas) as archive:
        for name in archive.namelist():
            if name.endswith(".schema.json"):
                schema = json.loads(archive.read(name))
                filename = name.rsplit("/", 1)[-1]
                # Only rebase the retrieval URI; relative schema references
                # resolve locally. Validation never downloads anything.
                schema["$id"] = base + filename
                schemas[filename] = schema
    registry = Registry().with_resources(
        (base + name, Resource.from_contents(schema))
        for name, schema in schemas.items()
    )
    failures = 0
    for deck in args.decks:
        deck_failures = 0
        with zipfile.ZipFile(deck) as archive:
            inputs = [
                ("main.json", "Presentation.schema.json", json.loads(archive.read("main.json"))),
                ("manifest.json", "Manifest.schema.json", json.loads(archive.read("manifest.json"))),
            ]
            inputs += [
                (f"presets.json/{index}", "Preset.schema.json", preset)
                for index, preset in enumerate(json.loads(archive.read("presets.json")))
            ]
            for entry, name, value in inputs:
                errors = list(Draft202012Validator(schemas[name], registry=registry).iter_errors(value))
                for error in errors[:10]:
                    detail = best_match([error])
                    print(f"FAIL {deck}:{entry}:{detail.json_path}: {detail.message[:500]}")
                deck_failures += len(errors)
        failures += deck_failures
        if not deck_failures:
            print(f"PASS {deck}: main, manifest and presets ({len(schemas)} authoritative schemas)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
