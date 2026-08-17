import Foundation
import Rostrum

/// What a deck's card knows that a directory listing does not.
///
/// Just the slide count now: the cover comes from Quick Look, which has
/// already rendered these files for Finder and cached the result, so nothing
/// here needs to open a presentation to draw one.
public struct DeckCard: Sendable, Equatable, Codable {
    public let slideCount: Int

    public init(slideCount: Int) {
        self.slideCount = slideCount
    }
}

/// Reads `DeckCard`s and remembers them.
///
/// Keyed on path, size and modification date together: a deck rewritten in
/// place gets a new key and is re-read, one that has not changed is never
/// opened twice. The on-disk half survives relaunch, which is what makes a
/// library of ninety-megabyte decks browsable at all.
///
/// An actor because the map is shared by every visible card, and the expensive
/// part must not run on the main actor.
public actor DeckCardIndex {
    public static let shared = DeckCardIndex()

    /// The same ceiling the inspector uses. These are the user's own decks, but
    /// this path opens whatever is sitting in the decks folder.
    static let readLimit = 1 << 30

    private var memory: [String: DeckCard] = [:]
    private var inFlight: [String: Task<DeckCard?, Never>] = [:]
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = caches.appendingPathComponent("Lectern/DeckCards", isDirectory: true)
        }
    }

    /// The card for `deck` — memory, then disk, then the file itself.
    ///
    /// Concurrent callers for the same deck share one read rather than each
    /// opening their own copy: a grid scrolled quickly asks for the same card
    /// several times before the first answer lands.
    public func card(for deck: DeckFile) async -> DeckCard? {
        let key = Self.key(for: deck)
        if let cached = memory[key] { return cached }
        if let running = inFlight[key] { return await running.value }

        let directory = self.directory
        let url = deck.url
        // Reading a card means opening the whole package, and a real library
        // holds ninety-megabyte decks. Twelve visible cards opening at once
        // measured 183s and 2GB peak — eleven times *slower* than doing them
        // one after another, because the machine spent the difference swapping.
        // The gate is what keeps a grid from doing that to itself.
        await acquire()
        let task = Task<DeckCard?, Never>.detached(priority: .utility) {
            if let onDisk = Self.read(key: key, in: directory) { return onDisk }
            guard let built = Self.build(from: url) else { return nil }
            Self.write(built, key: key, in: directory)
            return built
        }
        inFlight[key] = task

        let value = await task.value
        release()
        inFlight[key] = nil
        if let value { memory[key] = value }
        return value
    }

    // MARK: - Parse gate

    /// How many packages may be open at once. Two rather than one so a small
    /// deck is never stuck behind a large one, and never so many that the
    /// resident set is the bottleneck.
    private static let maxConcurrentParses = 2
    private var activeParses = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    private func acquire() async {
        if activeParses < Self.maxConcurrentParses {
            activeParses += 1
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty {
            activeParses -= 1
        } else {
            // Hand the slot straight to the next waiter rather than releasing
            // and re-taking it, which would let a newcomer jump the queue.
            waiting.removeFirst().resume()
        }
    }

    /// Forget everything. Cards are derived data; dropping them costs a re-read
    /// and nothing else.
    public func removeAll() {
        memory.removeAll()
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        try? fileManager.removeItem(at: directory)
    }

    // MARK: - Extraction

    /// Slide count without opening the presentation.
    ///
    /// A deck is a zip, and the slide list lives in one small part of it. So
    /// this memory-maps the file (no ninety-megabyte copy), inflates
    /// `ppt/presentation.xml` alone, and counts the entries in `p:sldIdLst`.
    /// Opening the whole package to learn one number is what made a grid of
    /// real decks take three minutes.
    static func build(from url: URL) -> DeckCard? {
        // `.mappedIfSafe` so a 96 MB deck costs address space, not resident
        // memory — the zip reader only touches the directory and one entry.
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), !data.isEmpty,
              let zip = try? ZipReader(data: data,
                                       limits: .init(totalUncompressedBytes: readLimit)),
              let partName = Self.presentationPartName(in: zip),
              let part = try? zip.data(forEntry: partName),
              let root = try? XML.parse(part)
        else { return nil }

        let list = root.firstChild(named: "p:sldIdLst")
        let slideCount = list?.children(named: "p:sldId").count ?? 0
        return DeckCard(slideCount: slideCount)
    }

    /// Almost always `ppt/presentation.xml`, but the part name is a convention
    /// rather than a rule, so fall back to finding it.
    static func presentationPartName(in zip: ZipReader) -> String? {
        if zip.contains("ppt/presentation.xml") { return "ppt/presentation.xml" }
        return zip.entryNames.first {
            $0.hasSuffix("/presentation.xml") || $0 == "presentation.xml"
        }
    }

    /// Rec. 601 luma — enough to decide which way a label should contrast.
    ///
    /// Public because the cover art has to make the same decision about the
    /// same hex the card was built from, and two implementations of "is this
    /// light" would eventually disagree.
    public static func isLight(_ hex: String) -> Bool {
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return true }
        let r = Double((value >> 16) & 0xFF)
        let g = Double((value >> 8) & 0xFF)
        let b = Double(value & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.55
    }

    // MARK: - Disk

    /// Path, size and modification date together. Any of the three changing
    /// means the card is stale.
    static func key(for deck: DeckFile) -> String {
        let seed = "\(deck.url.path)|\(deck.byteCount)|\(deck.modified.timeIntervalSince1970)"
        return String(fnv1a(seed), radix: 16)
    }

    /// FNV-1a: stable across launches, which `Hasher` deliberately is not.
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x1000_0000_01b3
        }
        return hash
    }

    static func read(key: String, in directory: URL) -> DeckCard? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("\(key).json"))
        else { return nil }
        return try? JSONDecoder().decode(DeckCard.self, from: data)
    }

    /// Writes go through `FileManager.default` rather than the injected one:
    /// this runs off the actor, and `FileManager` is not `Sendable`.
    static func write(_ card: DeckCard, key: String, in directory: URL) {
        guard let data = try? JSONEncoder().encode(card) else { return }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("\(key).json"), options: .atomic)
    }
}
