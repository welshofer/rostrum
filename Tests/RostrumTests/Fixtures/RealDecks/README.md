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
| `SmartArtExamples.pptx` | PowerPoint for Mac | SmartArt — `dgm:` data/layout/colors/quickStyle parts, 1308 entries |
| `Template.potx` | PowerPoint for Mac | the template content type (`…presentationml.template.main+xml`) |
| `MovieAndComments.pptx` | PowerPoint for Mac | modern comments (`ppt/comments/modernComment_*.xml`, `ppt/authors.xml`) and a 15.8 MB embedded `.mp4` |
| `FromKeynote.pptx` | Keynote export | Keynote's own idea of PresentationML, photographic media, empty `docProps` |
| `FromGoogleSlides.pptx` | Google Slides export | a third writer's conventions, no `docProps/core.xml` at all |

`Template.potx` is `SmartArtExamples.pptx` saved as a template: the same 1308
entries under the same names, 17 of them differing byte-wise —
`[Content_Types].xml`, `docProps/{app,core}.xml`, the six `customXml/` parts
(renumbered, same payloads), `ppt/theme/theme1.xml`, `ppt/viewProps.xml`,
`ppt/handoutMasters/handoutMaster1.xml` and five `notesSlides` whose date
fields moved. The one that earns its place is the `[Content_Types].xml`
override naming `/ppt/presentation.xml` a template rather than a
presentation: it is the only input proving a `.potx` survives the round trip
as a `.potx`, and it caught a real defect the day it landed. A much smaller
template would buy the same coverage for a fraction of the 5.3 MB.

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

## Decks you can't publish

The most valuable fixture is often a real work deck that can't go in a public
repo. Point the gate at it without checking it in:

```sh
ROSTRUM_REAL_DECKS=~/private-decks swift test --filter RealDeckCorpusTests
```

The variable replaces this directory for that run. Nothing is copied, nothing
is staged, and the invariants are identical.
