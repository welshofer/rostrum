# Real-deck corpus

Drop **foreign-authored** `.pptx` files here — created by real PowerPoint,
Keynote, or Google Slides, *not* by Rostrum — and the suite automatically
enrolls them in the release-gate invariants (`RealDeckCorpusTests`):

1. open → save with no edits keeps every **content part** byte-identical at
   the zip-entry level (`.rels` parts and `[Content_Types].xml` are the
   documented exception: parsed and deterministically re-serialized —
   semantics preserved, foreign byte layout normalized),
2. resaving the resave is a fixed point (determinism on foreign input),
3. slides and shapes enumerate without trapping.

Rostrum-generated corpora can't exercise foreign XML habits — attribute
order on dirty parts, exotic parts and vendor extensions, data descriptors
in the zip — so the lossless-round-trip hard rule is only proven as far as
this directory is populated.

Guidelines for good fixtures:

- Author in the real application, ideally more than one (PowerPoint,
  Keynote export, Google Slides export).
- Exercise variety: themes, master edits, pictures, charts, SmartArt,
  tables, notes, comments, animations, embedded media.
- Keep files small where possible; a handful of focused decks beats one
  giant one.
- Only check in decks you authored yourself (they ship with the repo).
