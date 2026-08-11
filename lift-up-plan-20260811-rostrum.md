# Lift-Up Plan: Rostrum

> Platform: Swift library — macOS 13+, iOS 16+, Linux (from `Package.swift` `platforms:`; zero SwiftPM dependencies)
> Surveyed: 2026-08-11
> Coverage: full for `Sources/Rostrum/` (Zip, XML, OPC, Core, Presentation, Drawing, Charts, Fonts, Schema); `Tools/` and `Examples/` surveyed but not audited line-by-line
> Attractiveness anchor: inferred — **python-pptx**, the library Rostrum is a port of in spirit and the one its users will compare it to. For a library, "attractiveness" reads as API elegance, documentation, and the quality of the XML it emits.
> Model tier: Opus 5 (frontier) — no rerun needed.

**Read the counts before the items.** This is Rostrum's third audit, it carries 627 tests
including a foreign-deck corpus and a round-trip fixed-point gate, and it shows.
Most candidates died in verification because the guard was already there — the
zip budget, the DTD block, the depth cap, the bounded-int helpers all exist. Four
dimensions ship fewer than five items and two ship none. Padding them would have
meant inventing work; the empty sections are the finding.

## Performance

### 1. `ShapeCollection` re-walks the XML tree on every access

- **Location:** `Sources/Rostrum/Presentation/Shapes.swift:26`
- **Proof:**
  ```swift
    public var all: [Shape] {
        guard let spTree = Slide.existingSpTree(of: part) else { return [] }
        return Self.children(of: spTree, part: part, package: package)
    }
  ```
  and the three accessors built on it:
  ```swift
    public var count: Int { all.count }

    public subscript(index: Int) -> Shape { all[index] }

    public func makeIterator() -> IndexingIterator<[Shape]> {
        all.makeIterator()
    }
  ```
- **Verified:** `grep -n 'cache\|memo\|lazy var\|stored' Sources/Rostrum/Presentation/Shapes.swift` → `# (no matches)`
- **Do:** Cache the built array on `ShapeCollection` and invalidate it in `part.markDirty()`, or make `count`/`subscript` read the `p:spTree` children directly instead of materialising every `Shape` facade. At minimum, document that `subscript` is O(n) so callers reach for `all` once.
- **Why:** `subscript(index:)` looks like an array access and costs a full tree walk plus a facade allocation per shape, so the ordinary `for i in 0..<shapes.count` shape is quadratic. No call site in this repo does that today — this is a public-API trap rather than a live regression — but the library is the product, and its callers are not in this repo.
- **Effort:** S · **Impact:** M

One item. Four other Performance candidates were dropped — see *Dropped during verification*.

## Functionality

### 1. The lossless round-trip has a hole, and a test holds it open

- **Location:** `Sources/Rostrum/XML/XML.swift:485`
- **Proof:**
  ```swift
        // Comments and processing instructions are intentionally dropped:
        // no `foundComment` / `foundProcessingInstruction` handling.
  ```
  and the behaviour is pinned, at `Tests/RostrumTests/XMLTests.swift:60`:
  ```swift
    @Test func commentsAreDropped() throws {
        let root = try parse("<a><!-- nope --><b/></a>")
        #expect(root.serialized() == "<a><b/></a>")
    }
  ```
- **Verified:** `grep -n -i 'lossless\|round-trip' CLAUDE.md` →
  ```
  19:- **Lossless round-trip is sacred.** Opening a file and saving it must never
  ```
- **Do:** Either carry comments and processing instructions through the DOM as
  opaque nodes so they survive a save, or amend the invariant in `CLAUDE.md` and
  the README to state the exception plainly. Do not leave the two disagreeing.
- **Why:** The project's most-stated promise is that opening and saving a deck
  never drops XML it does not model. A comment is exactly that, it is dropped,
  and a test enforces the dropping — so a deck from a producer that annotates its
  XML loses those annotations silently on any save. Whichever way this is
  resolved, the current state means the headline guarantee is not quite true.
- **Effort:** M · **Impact:** M

One item.

## Stability

**Zero items survived verification.** Every candidate was a force unwrap, `try!`
or `precondition` that turned out to be provably unreachable — the same result as
the 2026-08-09 audit, which is itself the finding. The specific drops are listed
in *Dropped during verification*; three of them were re-checked from scratch this
run rather than carried over, and all three failed again.

## Reliability

### 1. A broken layout relationship collapses inheritance in silence

- **Location:** `Sources/Rostrum/Presentation/SVGRenderer.swift:70`
- **Proof:**
  ```swift
    private func inheritanceChain() -> (layout: Part?, master: Part?) {
        guard let rel = slidePart.rels.first(ofType: RelType.slideLayout),
              let layout = try? package.part(
                at: PackURI.resolve(target: rel.target, relativeTo: slidePart.uri.baseURI))
        else { return (nil, nil) }
        guard let masterRel = layout.rels.first(ofType: RelType.slideMaster),
              let master = try? package.part(
                at: PackURI.resolve(target: masterRel.target, relativeTo: layout.uri.baseURI))
        else { return (layout, nil) }
        return (layout, master)
    }
  ```
- **Verified:** `grep -n 'warning\|warnings\|unmeasured' Sources/Rostrum/Presentation/SVGRenderer.swift` → `# (no matches)`
- **Do:** Return the reason alongside the chain and surface it the way
  `renderSVG` already surfaces `unmeasuredFonts` — a named list of what could not
  be resolved — so a caller can say "this deck's layout is missing" instead of
  showing an unstyled picture.
- **Why:** A deck whose layout relationship is damaged still renders, with every
  inherited background, placeholder position and theme colour quietly gone. It
  looks like Rostrum rendered the deck wrong rather than like the deck is broken,
  and the renderer already has a vocabulary for degraded output it declines to
  use here.
- **Effort:** S · **Impact:** M

One item.

## Security

**Zero items survived verification.** This is the third pass over these parsers
and every proposed hardening was already present: the decompression budget, the
`<!DOCTYPE>` rejection that closes billion-laughs, the XML depth cap, the
bounded-integer attribute helpers, and per-record skipping in the font name
table. The verbatim greps are in *Dropped during verification*. For a library
whose whole job is parsing hostile files, an empty Security section earned by
checking is the strongest thing this report says.

## Usability

### 1. Three ways to add a slide, two of them nearly the same name

- **Location:** `Sources/Rostrum/Presentation/Layouts.swift:60` and `:84`
- **Proof:**
  ```swift
    @discardableResult
    public func add(layout: SlideLayout) throws -> Slide {
  ```
  ```swift
    @discardableResult
    func add(boundTo layout: SlideLayout) throws -> Slide {
  ```
- **Verified:** `grep -n 'func add(layout\|func add(boundTo\|public func add()' Sources/Rostrum/Presentation/Layouts.swift Sources/Rostrum/Presentation/Slides.swift` →
  ```
  Sources/Rostrum/Presentation/Layouts.swift:60:    public func add(layout: SlideLayout) throws -> Slide {
  Sources/Rostrum/Presentation/Layouts.swift:84:    func add(boundTo layout: SlideLayout) throws -> Slide {
  Sources/Rostrum/Presentation/Slides.swift:69:    public func add() throws -> Slide {
  ```
- **Do:** Name the difference rather than hiding it in a preposition:
  `add(clonedFrom:)` versus `add(bound​To:)`, or one method with an explicit
  `placeholders: .cloned | .none`. If `add(boundTo:)` is to stay internal, say so
  in its doc comment.
- **Why:** `add(layout:)` clones the layout's placeholder shapes; `add(boundTo:)`
  binds the relationship and clones nothing. Those produce very different decks,
  and the names differ by one word that does not suggest which. The second was
  added this week for the title-placeholder fix, so the confusion is new and cheap
  to correct now.
- **Effort:** S · **Impact:** S

One item.

## Attractiveness / Sexiness

Anchor: **python-pptx**. For a library this is API elegance, documentation, and
whether the emitted XML looks like something PowerPoint itself would write.

### 1. The docs promise a verification the CI does not perform

- **Location:** `Lectern/README.md:172` against `.github/workflows/ci.yml:91`
- **Proof:**
  ```
  **Verified:** the app compiles under **Swift 6 complete strict-concurrency**,
  ```
  and what CI actually runs:
  ```
        - name: Build the Lectern app (compiled by nothing else)
  ```
- **Verified:** `grep -n 'name:\|xcodebuild' .github/workflows/ci.yml` →
  ```
  86:      - name: Test Rostrum (Darwin XML branch)
  88:      - name: Test LecternCore (CoreText/CoreGraphics half included)
  91:      - name: Build the Lectern app (compiled by nothing else)
  ```
- **Do:** Either add the app-target test step to the macOS job or reword the
  claim to say it is verified locally. The repo's own instruction is that macOS
  CI stays cheap, so rewording is the likely right answer.
- **Why:** A reader arriving at this project judges it on whether its stated
  guarantees hold. "Verified" next to something CI never runs is the one kind of
  documentation error that costs trust everywhere else in the README.
- **Effort:** S · **Impact:** S

One item.

---

## First move

**The lossless round-trip has a hole, and a test holds it open** (from Functionality)

Ship this first because it is the only item on this list that touches what the
project says about itself. Rostrum's pitch — the reason to choose it over writing
XML by hand — is that opening and saving a file cannot damage what it does not
understand. `CLAUDE.md` calls that sacred. But comments and processing
instructions are dropped on parse, and `commentsAreDropped` asserts it, so the
guarantee has a documented, tested exception nobody reading the pitch would
expect. Every other item here makes a working thing better; this one decides
whether a headline claim is true. It is also cheap either way: carrying comments
as opaque nodes is a contained change to one file, and if the team decides the
exception is correct, amending two sentences costs nothing and the invariant
becomes honest. Doing it first means the next audit measures the library against
a promise it actually keeps.

## Dropped during verification

- **`FontMetrics` re-parses the whole font on every registration** — already in place: `grep -n 'cache\|memo\|\[String: FontMetrics\]' Sources/Rostrum/Fonts/FontLibrary.swift` → `13:    private var byName: [String: FontMetrics] = [:]`. `FontLibrary` memoises by family name.
- **`XML.textContent` is quadratic in text length** — cited code does something else: the parser coalesces chunks before materialising (`let text = pendingText.count == 1 ? pendingText[0] : pendingText.joined()`), so the pathological case is handled at parse time.
- **`addTextBox` force-unwraps `p:spPr`** — cited code does something else: the element comes from `makeSp` two lines above, which constructs it; the unwrap cannot fail on a shape this function just built.
- **`try!` in the DEFLATE fixed tables** (`Inflate.swift:299-300`) — cited code does something else: the lengths are RFC 1951 constants, not input-derived. Re-checked this run; unchanged.
- **`PackURI.init` traps on a malformed path** — cited code does something else: both package-read call sites prepend `/` before constructing, so the precondition is unreachable from file data. Carried from 2026-08-09 and re-verified.
- **Zip decompression is unbounded** — already in place: `Inflate.swift:92-97` caps the reservation at `Swift.min(size, 1 << 20)` and `ZipReader.Limits` budgets total output.
- **XML is open to billion-laughs** — already in place: `XML.swift:271-278` rejects `<!DOCTYPE` outright.
- **Hostile XML can exhaust the stack** — already in place: `XML.swift:400-414` caps depth and calls `parser.abortParsing()`.
- **Chart point caches allocate on attacker-controlled counts** — already in place: `ChartReader.swift:349-355` bounds `count` against a limit before allocating.
- **Font name-table corruption sinks the whole font** — already in place: `FontMetrics.swift:141-163` guards each record and `continue`s past bad ones.
- **`GraphicDataURI` has no test coverage** — mislocated as a defect: it is a namespace of four URI string constants used by `ShapeKind`, which is itself covered; a test asserting a constant equals itself would prove nothing.

## Deferred

- **Effective-frame inheritance matches layout→master by reduced type** (`Slide.swift:216-246`) — real asymmetry, but no observed deck hits it and the fix needs the full placeholder-matching table.
- **`OPCPackage` multi-pass serialisation** — measured in milliseconds against a whole-deck save; below the noise floor.
- **`RostrumError` carries prose, not structured cases** — real API ergonomics gap, low leverage while the consumer set is this small.
- **Text measurement ignores kerning, ligatures and shaping** (`FontMetrics.swift:12-16`) — documented behaviour, and fixing it means a shaping engine, which is out of scope for a zero-dependency library.
