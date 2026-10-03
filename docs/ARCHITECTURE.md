# Rostrum architecture

Decided 2026-07-18 after a three-proposal bake-off (faithful python-pptx port
vs. fully-typed decode model vs. hybrid). Winner: **Pristine-DOM Hybrid with
generated typed facades.** This document is the constitution; ROADMAP.md is
the schedule.

## The one-sentence version

A mutable XML DOM is the storage layer — parts keep their **original bytes
untouched until first mutation** — and the public API is typed Swift facades
that read and write through to the DOM via a generated schema stratum.

## Why this design

- **Lossless round-trip becomes structural, not aspirational.** A part that
  was never touched is re-emitted from its pristine bytes. Open-then-save with
  no edits must produce byte-identical zip entries — a mechanical CI gate with
  zero judgment calls, and with no exceptions: `.rels` parts and
  `[Content_Types].xml` keep their original bytes too, and rebuild only when
  a relationship or content-type actually changes.
- **The serializer's blast radius is only what the user edited.** "PowerPoint
  wants to repair this file" bugs come from re-serializing parts you didn't
  need to touch. (python-pptx re-serializes every part on save — a perfectly
reasonable design; byte-identity is simply a different goal.)
- **Typed facades give Swift-native ergonomics** without betting losslessness
  on typed structs modeling 100% of a gigantic schema (the fully-typed
  proposal's fatal flaw: every unmodeled sibling is a distributed data-loss
  hazard).

## Layers

```
Rostrum          public API: Presentation, Slide, shapes, text, charts…
RostrumSchema    generated ordering/attribute tables and shared DOM helpers
RostrumOPC       parts, content types, relationship graph, pristine blobs
RostrumXML       DOM: ordered attrs, prefix-preserving, deterministic serializer
RostrumZip       reader and deterministic writer (STORED+DEFLATE)
```

Today all five live as directories inside the single `Rostrum` target; they
split into SwiftPM targets when size justifies it. Dependencies point strictly
downward.

## Load-bearing mechanisms

**Pristine-until-mutated.** Every `Part` holds its original blob and a dirty
flag. Facades parse the blob into a DOM lazily; the first actual mutation
flips authority to the DOM (one-way). Save re-emits pristine bytes for clean
parts and serializes the DOM for dirty ones. All mutations funnel through one
`markMutated` hook — dual-representation coherence is a fuzzable invariant,
not a convention.

**Generated schema stratum.** python-pptx's `xmlchemy` synthesizes accessors
at class-creation time (`RequiredAttribute`, `ZeroOrOne("p:sldSz",
successors:…)`, choice groups). Swift can't do runtime synthesis; the
equivalent is `rostrum-gen`, a standalone generator (not a macro, not a build
plugin — consumers see zero deps, generated code is diffable) whose input
tables are mechanically extracted from python-pptx's descriptor declarations
by Tools/extract-schema.py. Semantics to preserve exactly:
get-or-add for optional children, successor-list insertion order, choice-group
replacement, typed attribute conversion with default-elision. The generator
currently emits tables, not per-element typed accessors. Typed accessors and
an exclusions manifest for manual extensions remain future architecture;
there are no CT_Foo+Manual.swift files today.

**Accessors are plain computed properties** over shared generic runtime
primitives — not property wrappers (they need stored properties), not
keypaths. Boring and greppable.

**Preserve unknown content, report malformed input.** Unmodeled XML remains
in the DOM or pristine part bytes. Malformed input may throw; best-effort
inspection records failures. Write helpers preserve schema ordering and
refuse edits they cannot perform safely.

**Lexical attribute discipline.** The DOM keeps the original source token for
every attribute; typed getters parse on read, and only a genuine set replaces
the token. An untouched `rot="0"` re-emits exactly as read, even in a dirty
part.

**Orphan preservation.** Zip members unreachable from the relationship graph
are preserved on save (a stricter posture than python-pptx, which
re-packages only reachable parts). What a read could *not* keep is reported:
`deck.readWarnings` names any carried entry that failed to decode and was
dropped, rather than letting it vanish silently. A general orphan-audit API
and an opt-in `prune()` are intended but **not yet implemented**.

**Slide access.** `deck.slides[index]` and `slide(at:)` use zero-based positions
and throw if the position or relationship is invalid. Positions change after
reordering/deletion. Stable handles keyed by OOXML IDs remain a planned API;
do not pass an OOXML slide ID to the positional subscript.

## Relationship graph semantics (ported from python-pptx, kept)

- rIds are the join table between part XML (`r:id`, `r:embed`) and the part
  graph; mint the lowest free `rIdN`; dedupe `relate_to` by
  (type, target, mode); reference-counted drop (only remove a rel when its
  last `r:id` reference goes).
- Slide order lives in `p:sldIdLst`; z-order lives in `p:spTree`; identity
  lives in the rels graph. All views derive from XML on every access.

## Testing doctrine

- **Byte-identity corpus gate** (live from day one at the zip layer, extended
  per layer): open→save every corpus deck; every untouched zip entry must be
  byte-identical. Corpus: real decks from PowerPoint, Keynote export, Google
  Slides export.
- **External oracles:** `/usr/bin/unzip -t` validates archives we write;
  `zlib` (via python3) generates DEFLATE fixtures for inflate; **python-pptx
  itself opens every deck Rostrum produces** in CI.
- **Differential replay:** python-pptx's own unit tests for oxml semantics
  (successor ordering, get-or-add, choice swap, default-elision) are ported as
  validation of the schema stratum — 15 years of field-hardened behavior,
  bisectable.
- Determinism: same input → byte-identical output (fixed zip timestamps,
  sorted parts, stable attribute order).

## Known deviations from python-pptx (deliberate)

- Default new deck is 16:9 built from inspectable XML constants (theirs: 4:3
  bundled binary `default.pptx`).
- Pure-Swift fixed-Huffman/LZ77 DEFLATE on write when it saves space;
  already-compressed media can remain STORED. Both paths are deterministic.
- Unreachable parts survive save (see orphan preservation).
- `Presentation.package` is public — the OPC escape hatch is a feature.
