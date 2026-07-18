# Tools — generated schema stratum

Rostrum's schema tables are **mechanically extracted from python-pptx's own
source** (its `xmlchemy` descriptor declarations and `register_element_cls`
registrations) — never retyped by hand. See `docs/ARCHITECTURE.md`,
"Generated schema stratum".

## Two-step regeneration flow

Step 1 — extract python-pptx's declarations into a checked-in JSON table
(stdlib-only Python; python-pptx is parsed as AST, never imported, so no pip
installs are needed):

```sh
python3 Tools/extract-schema.py <path-to-python-pptx-clone>/src/pptx
# writes Tools/tables/oxml-schema.json (deterministic, sorted — diffs cleanly)
```

Step 2 — regenerate the Swift schema tables from the JSON (zero-dependency
executable target; Foundation + JSONSerialization only):

```sh
swift run rostrum-gen Tools/tables/oxml-schema.json
# writes Sources/Rostrum/Schema/GeneratedSchema.swift
```

Both outputs are checked in. Run step 1 only when bumping the python-pptx
reference checkout; run step 2 whenever `oxml-schema.json` or the generator
changes. `Tests/RostrumTests/GeneratedSchemaTests.swift` sanity-checks the
generated tables (`swift test --filter GeneratedSchemaTests`).

## What the tables contain

`OOXMLSchema` in `GeneratedSchema.swift`:

- `childSuccessors` — parent tag → child tag → successor tags, driving
  schema-ordered insertion (insert before the first successor present).
- `attributeDefaults` — element tag → XML attribute → default value in XML
  lexical form (read-absent-as-default, write-default-elides).
- `requiredAttributes` — element tag → required XML attribute names.
- `elementTags` — every distinct element tag known to the schema.

`Tools/tables/oxml-schema.json` additionally records, per element class, the
python property names, simple-type names, cardinalities
(`OneAndOnlyOne`/`ZeroOrOne`/`ZeroOrMore`/`OneOrMore`/`ZeroOrOneChoice`) and
choice-group membership — input for future rostrum-gen output (typed facades).
Class declarations are inheritance-flattened (what the class effectively
carries at runtime); successor lists preserve declared order because that
order is the insertion semantic.

## ppt-check.sh — PowerPoint acceptance oracle (macOS)

`Tools/ppt-check.sh <file.pptx>` opens the deck in Microsoft PowerPoint via
LaunchServices (the double-click code path — scripted AppleScript opens skip
the integrity check and give false negatives), watches for the repair dialog
via Accessibility, auto-dismisses it, and prints OK / REPAIR / STUCK. This is
the only oracle that catches what PowerPoint's strictest validation catches;
python-pptx and LibreOffice both tolerated the shared-theme bug this tool
found.
