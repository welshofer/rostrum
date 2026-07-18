# Rostrum — project conventions

Rostrum is a zero-dependency pure-Swift library for reading and writing
PowerPoint `.pptx` files: a ground-up port of python-pptx with the explicit
goal of surpassing it (see ROADMAP.md). Reference python-pptx source lives in
scratch clones only — never vendor Python code or translate it line-by-line;
port semantics, not syntax.

## Hard rules

- **Zero dependencies.** No SwiftPM dependencies, ever. We own the zip
  container, DEFLATE, XML, and everything above. `Foundation` (and
  `FoundationXML` on Linux) is the only import.
- **Platforms:** macOS, iOS, Linux. Never use APIs absent on any of the three
  (notably `XMLDocument`/`XMLNode` — iOS lacks them; use `Sources/Rostrum/XML`).
- **Lossless round-trip is sacred.** Opening a file and saving it must never
  drop or corrupt XML we don't model. Any feature that can't guarantee this
  doesn't ship.
- **Determinism is a feature.** Same input → byte-identical output (fixed zip
  timestamps, sorted part order, stable attribute ordering). Don't break it.
- **Layer boundaries:** Zip knows bytes; XML knows trees; OPC knows parts,
  content types and relationships (never slides); Presentation and above know
  PresentationML. Dependencies point strictly downward.

## Testing

- swift-testing (`import Testing`, `@Test`, `#expect`), suites per module.
- External oracles are encouraged and already in use: `/usr/bin/unzip -t` for
  archives we write, `/usr/bin/zip` + `python3 -c "import zlib…"` to generate
  DEFLATE fixtures, and python-pptx itself (venv in the session scratchpad) to
  open decks Rostrum produces. A deck isn't "valid" until python-pptx and
  PowerPoint both open it without repair.
- Run `swift test` before declaring anything done.

## Naming

- OOXML element names stay qualified as in the spec (`p:sldMasterIdLst`) in
  string literals; Swift API names are Swift-native (`slideMasters`, not
  `sldMasterLst`). python-pptx's class names are precedent but not law.
- EMU is the canonical length type (`Sources/Rostrum/Core/Units.swift`).
