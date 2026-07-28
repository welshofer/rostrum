import Foundation
import Testing
@testable import Rostrum

/// The fixture directory as it lands in the test bundle. Kept separate from
/// `realDeckDirectory` because the packaging check below must look here even
/// when an override has pointed the gate somewhere else.
private let bundledRealDeckDirectory: URL =
    (Bundle.module.resourceURL ?? Bundle.module.bundleURL)
    .appendingPathComponent("Fixtures/RealDecks", isDirectory: true)

/// Where the corpus lives.
///
/// `ROSTRUM_REAL_DECKS` replaces the checked-in directory for a run, so a deck
/// that can't go in a public repo can still gate a local build:
///
///     ROSTRUM_REAL_DECKS=~/private-decks swift test --filter RealDeckCorpusTests
///
/// Nothing is copied and nothing is staged — the invariants below are the same
/// either way.
private let realDeckDirectory: URL = {
    let raw = ProcessInfo.processInfo.environment["ROSTRUM_REAL_DECKS"] ?? ""
    let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if path.isEmpty { return bundledRealDeckDirectory }
    return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
}()

/// Every enrolled deck, sorted so failures name the same file run to run.
///
/// `~$…` are Office lock files — a few bytes of user name wearing a `.pptx`
/// extension, left behind whenever the author has the deck open — and dotfiles
/// are the platform's own litter. Neither is a deck, and feeding either to the
/// gate produces a failure about Rostrum that is really about the directory.
private let realDecks: [URL] = {
    let files =
        (try? FileManager.default.contentsOfDirectory(
            at: realDeckDirectory, includingPropertiesForKeys: nil)) ?? []
    return
        files
        .filter { url in
            let name = url.lastPathComponent
            return !name.hasPrefix("~$") && !name.hasPrefix(".")
                && ["pptx", "potx"].contains(url.pathExtension.lowercased())
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}()

// Relationship parts and the content-types stream used to be exempt here —
// they were parsed into models and rebuilt on save. They are pristine now,
// so the gate covers every zip entry with no exceptions.

/// The lossless-round-trip hard rule, proven against decks Rostrum did **not**
/// write: authored in PowerPoint, Keynote and Google Slides and checked in as
/// fixtures. Rostrum-generated corpora can't exercise foreign XML habits —
/// attribute order, exotic parts, vendor extensions, namespace prefixes nobody
/// else picks — so this gate is only as strong as the fixture set.
///
/// One test case per deck: a deck that fails names itself, and the others still
/// run rather than being cut short by the first failure.
@Suite struct RealDeckCorpusTests {

    // MARK: - The corpus itself

    /// The fixture resources reached the test bundle.
    ///
    /// This suite spent days reporting green while iterating **zero** decks:
    /// the directory listing failed open, so a packaging problem and a
    /// genuinely empty directory were the same observation. `README.md` is
    /// checked in beside the decks, so it is in the bundle whenever resources
    /// are copied at all — which makes the two distinguishable.
    @Test func fixtureResourcesReachTheTestBundle() {
        let readme = bundledRealDeckDirectory.appendingPathComponent("README.md")
        #expect(
            FileManager.default.fileExists(atPath: readme.path),
            """
            \(readme.path) is missing, so the test bundle carries no fixture resources. \
            An empty corpus would then be a packaging failure rather than a fact about \
            the repository — check the testTarget's `resources:` rule in Package.swift.
            """)
    }

    /// The gate is actually gating something.
    ///
    /// Every test below is parameterized over `realDecks`; an empty corpus
    /// turns all of them into zero test cases and the suite passes having
    /// proven nothing. This is the one assertion that can't.
    @Test func corpusIsPopulated() {
        #expect(
            !realDecks.isEmpty,
            """
            No decks found in \(realDeckDirectory.path), so the lossless-round-trip gate \
            is not being exercised at all. See Fixtures/RealDecks/README.md.
            """)
    }

    // MARK: - Invariant 1: byte-identical round trip

    /// Compares at the zip-entry level, not through `package.parts`, so nothing
    /// the reader chooses not to model can silently escape the gate. Every
    /// entry's **decompressed bytes** must come back identical after an open →
    /// save with no edits, including `.rels` parts and `[Content_Types].xml`.
    ///
    /// Decompressed, not stored: `data(forEntry:)` inflates. The *encoding* of
    /// an entry is outside this gate — compression method, DEFLATE level, the
    /// data-descriptor bit, extra fields, entry order. That is not hypothetical
    /// slack. Rostrum picks STORE or DEFLATE from the file extension alone
    /// (`OPCPackage.storedExtensions`), so it re-emits ten entries in this
    /// corpus STORED that Keynote and Google Slides had DEFLATEd, and Google
    /// Slides' data descriptors on all 86 of its entries are not reproduced
    /// either. Those files are byte-different from what their authors wrote and
    /// this test passes them, correctly: they carry identical payloads under
    /// identical names, which is the promise Rostrum makes. Preserving an
    /// untouched entry's original encoding is a real improvement, tracked in
    /// ROADMAP — it is simply not what this asserts.
    ///
    /// Entry *order* is deliberately not asserted either. Rostrum sorts part
    /// order for determinism, which is a different promise from preserving
    /// whatever order the authoring application happened to emit.
    @Test(arguments: realDecks)
    func untouchedForeignDeckSurvivesByteIdentically(_ url: URL) throws {
        let deck = url.lastPathComponent
        let original = try Data(contentsOf: url)
        let resaved = try Presentation(data: original).serializedData()

        let before = try ZipReader(data: original)
        let after = try ZipReader(data: resaved)
        let beforeNames = Set(before.entryNames)
        let afterNames = Set(after.entryNames)

        // Entries gained are as much a fidelity loss as entries dropped: a part
        // we invented is a part the authoring application did not ask for, and
        // it travels to every downstream consumer of the resaved file.
        let invented = afterNames.subtracting(beforeNames).sorted()
        let dropped = beforeNames.subtracting(afterNames).sorted()
        #expect(invented.isEmpty, "\(deck): resave invented \(invented.count) entries: \(invented)")
        #expect(dropped.isEmpty, "\(deck): resave dropped \(dropped.count) entries: \(dropped)")

        // Collected rather than asserted per entry: a deck with 1300 parts that
        // regresses wholesale should report one legible failure, not 1300.
        var changed: [String] = []
        for name in before.entryNames where afterNames.contains(name) {
            let old = try before.data(forEntry: name)
            let new = try after.data(forEntry: name)
            if old != new { changed.append(name) }
        }
        let sample = changed.prefix(10).joined(separator: ", ")
        let ellipsis = changed.count > 10 ? ", …" : ""
        #expect(
            changed.isEmpty,
            """
            \(deck): \(changed.count) of \(beforeNames.count) entries changed on resave: \
            \(sample)\(ellipsis)
            """)
    }

    // MARK: - Invariant 2: determinism on foreign input

    @Test(arguments: realDecks)
    func foreignDeckResaveIsAFixedPoint(_ url: URL) throws {
        let original = try Data(contentsOf: url)
        let once = try Presentation(data: original).serializedData()
        let twice = try Presentation(data: once).serializedData()
        #expect(once == twice, "\(url.lastPathComponent): resave is not a fixed point")
    }

    // MARK: - Invariant 3: the whole shape tree enumerates without trapping

    /// Walks every shape on every slide, **including shapes nested inside
    /// groups**, touching the reads whose arithmetic runs on numbers that came
    /// straight out of a file. Those are the sites where a trapping `Int(…)`
    /// conversion or a force-unwrap kills the process rather than throwing, and
    /// a foreign deck is the only thing that reaches the odd ones.
    @Test(arguments: realDecks)
    func foreignDeckShapeTreeEnumeratesWithoutTrapping(_ url: URL) throws {
        let name = url.lastPathComponent
        let deck = try Presentation(data: try Data(contentsOf: url))

        var visited = 0
        var walked = 0
        for slide in deck.slides {
            walked += 1
            // Iterative rather than recursive: nesting depth is the deck's
            // choice, and a test that overflows its own stack reports a crash
            // where the library is fine.
            var worklist = Array(slide.shapes)
            while let shape = worklist.popLast() {
                visited += 1
                guard visited <= 200_000 else {
                    Issue.record("\(name): shape walk exceeded 200000 nodes; aborting")
                    return
                }

                _ = shape.kind
                _ = shape.name
                _ = shape.shapeID
                _ = shape.frame
                _ = shape.rotation

                if let group = shape as? GroupShape {
                    let children = group.shapes
                    // Child frames live in the group's own coordinate space;
                    // mapping them out is the arithmetic that has to survive a
                    // degenerate or absurd `a:chOff`/`a:chExt`.
                    for child in children { _ = group.convertToParentSpace(child.frame) }
                    worklist.append(contentsOf: children)
                }
            }
        }

        // `Slides.makeIterator()` resolves each `p:sldId` with `try?` and drops
        // the ones that fail, so iterating is fail-open exactly the way this
        // suite's own directory listing was. Without this, 184 of a 185-slide
        // deck could vanish from the walk and `visited > 0` would still hold.
        #expect(
            walked == deck.slides.count,
            """
            \(name): the iterator yielded \(walked) of \(deck.slides.count) slides — \
            \(deck.slides.count - walked) did not resolve and were skipped silently.
            """)
        #expect(
            visited > 0,
            """
            \(name): the walk found no shapes at all, which means the slides came back \
            empty rather than that the deck is.
            """)
    }
}
