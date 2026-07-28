# Real-deck corpus

**Foreign-authored** `.pptx` files — created by real PowerPoint, Keynote, or
Google Slides, *not* by Rostrum. `RealDeckCorpusTests` enrolls every deck in
here automatically and holds it to the release-gate invariants:

1. open → save with no edits keeps **every zip entry's decompressed bytes**
   identical, `.rels` parts and `[Content_Types].xml` included, and invents
   no new entries — the entry's *encoding* (compression method, data
   descriptors, order) is deliberately outside the gate; see the test's own
   doc comment for why and for what that currently costs,
2. resaving the resave is a fixed point (determinism on foreign input),
3. the whole shape tree — groups recursed into — enumerates without trapping.

Rostrum-generated corpora can't exercise foreign XML habits: attribute order
on dirty parts, exotic parts and vendor extensions, data descriptors in the
zip, namespace prefixes nobody else picks. So the lossless-round-trip hard
rule is only proven as far as this directory is populated, and the suite says
so out loud when it isn't.

## What's here

| Deck | Authored in | Exercises |
|---|---|---|
| `SimplePowerPoint.pptx` | PowerPoint for Mac | the plain baseline: one theme, a few text shapes |
| `MovieAndComments.pptx` | PowerPoint for Mac | modern comments (`ppt/comments/modernComment_*.xml`, `ppt/authors.xml`) and a 15.8 MB embedded `.mp4` |
| `FromKeynote.pptx` | Keynote export | Keynote's own idea of PresentationML, photographic media, empty `docProps` |
| `FromGoogleSlides.pptx` | Google Slides export | a third writer's conventions, no `docProps/core.xml` at all |

### Wanted

Two gaps, both from decks removed on 2026-07-28 for being a third party's
brand template rather than the owner's own work — see "Check the provenance"
below, which exists because of them:

- **SmartArt.** `ppt/diagrams/` — the `dgm:` data, layout, colors and
  quickStyle parts, four per diagram, none of which Rostrum models. Any deck
  built from PowerPoint's stock SmartArt layouts covers this; the content is
  irrelevant, the parts are the point.
- **A `.potx`.** The template content type
  (`…presentationml.template.main+xml`) on `/ppt/presentation.xml`. This one
  earned its keep in a day: it caught Rostrum silently retyping a template to
  a presentation on open, so a `.potx` could not survive a round trip at all.
  `POTXTests` pins that contract synthetically now, but nothing here proves it
  against a template PowerPoint actually wrote.

## Adding one

- Author it in the real application. A fourth writer's habits are worth more
  than a fifth deck from one you already have.
- Exercise variety: master edits, pictures, charts, tables, notes, comments,
  animations, embedded media.
- Keep it small where you can — these ship with the repo and every clone pays
  for them forever. A focused deck beats a big one.
- Check the metadata before committing. `docProps/core.xml` carries
  `dc:creator` and `cp:lastModifiedBy`; `docProps/app.xml` can carry a
  template name and the full slide-title list. Scrub in PowerPoint *before*
  the file lands here — editing the XML afterwards would forge a deck no
  application actually wrote, which is the one thing this corpus can't use.
- **Check the provenance, not just the metadata.** These files ship in a
  public MIT-licensed repository, so a deck has to be yours to give away.
  Starting from a corporate or downloaded template carries its theme, its
  masters and often its copyright notice into git history, and history is
  the hard part to undo. Two decks were removed on 2026-07-28 for exactly
  this: they were built on a vendor's internal brand template and carried
  its `© … All rights reserved` run text in six parts each. Worth grepping
  for before you commit:

  ```sh
  unzip -p deck.pptx '*' | grep -aiE '©|all rights reserved|confidential'
  unzip -p deck.pptx ppt/theme/theme1.xml | grep -o 'themeFamily name="[^"]*"'
  ```

## Decks you can't publish

The most valuable fixture is often a real work deck that can't go in a public
repo. Point the gate at it without checking it in:

```sh
ROSTRUM_REAL_DECKS=~/private-decks swift test --filter RealDeckCorpusTests
```

The variable replaces this directory for that run. Nothing is copied, nothing
is staged, and the invariants are identical.
