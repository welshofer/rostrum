import Foundation

// The `lectern.deck/1` intermediate representation — the versioned contract
// between every provider and the renderer, and the ONLY thing the renderer
// accepts (invariant I3). Codable is authoritative; the JSON Schema handed to
// providers is generated from it.

public struct DeckIR: Codable, Sendable, Equatable {
    public static let currentVersion = "lectern.deck/1"

    public var irVersion: String
    public var meta: Meta
    public var sections: [IRSection]?
    public var slides: [IRSlide]

    public init(irVersion: String = DeckIR.currentVersion, meta: Meta,
                sections: [IRSection]? = nil, slides: [IRSlide]) {
        self.irVersion = irVersion
        self.meta = meta
        self.sections = sections
        self.slides = slides
    }

    enum CodingKeys: String, CodingKey { case irVersion, meta, sections, slides }

    /// Tolerant decode: a real model often omits `irVersion` (or names the whole
    /// thing differently) — default it rather than reject an otherwise-valid deck.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.irVersion = (try? c.decodeIfPresent(String.self, forKey: .irVersion)) ?? DeckIR.currentVersion
        self.meta = try c.decode(Meta.self, forKey: .meta)
        self.sections = (try? c.decodeIfPresent([IRSection].self, forKey: .sections)) ?? nil
        self.slides = try c.decode([IRSlide].self, forKey: .slides)
    }
}

public struct Meta: Codable, Sendable, Equatable {
    public var title: String
    public var subtitle: String?
    public var audience: String?
    public var goal: String?          // inform | persuade | entertain | inspire
    public var language: String?

    public init(title: String, subtitle: String? = nil, audience: String? = nil,
                goal: String? = nil, language: String? = nil) {
        self.title = title; self.subtitle = subtitle; self.audience = audience
        self.goal = goal; self.language = language
    }
}

public struct IRSection: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String?
    public var slideIds: [String]

    public init(id: String, title: String? = nil, slideIds: [String]) {
        self.id = id; self.title = title; self.slideIds = slideIds
    }
}

public struct IRSlide: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var sectionId: String?
    public var layout: String
    public var title: String?
    public var body: Body?
    public var notes: String?
    public var image: ImageBrief?          // populated by the model only when a visual helps

    public init(id: String, sectionId: String? = nil, layout: String,
                title: String? = nil, body: Body? = nil, notes: String? = nil,
                image: ImageBrief? = nil) {
        self.id = id; self.sectionId = sectionId; self.layout = layout
        self.title = title; self.body = body; self.notes = notes; self.image = image
    }

    /// The parsed layout, or `.unknown(raw)`.
    public var kind: SlideLayoutKind { SlideLayoutKind(layout) }
}

/// A request for a generated illustration on a slide (§image grounding). Only
/// present when the deck model decided a visual materially helps. `prompt` is the
/// subject to depict; art direction (palette/vibe) is added from `design.md` at
/// generation time so imagery stays on-brand.
public struct ImageBrief: Codable, Sendable, Equatable {
    public var prompt: String
    public var aspect: String?             // "16:9" | "4:3" | "1:1" | "3:4" | "9:16"

    public init(prompt: String, aspect: String? = nil) {
        self.prompt = prompt; self.aspect = aspect
    }
}

/// The `body` payload — a superset covering every layout's shape (§8.2). Which
/// fields are required is enforced per-layout by validation.
public struct Body: Codable, Sendable, Equatable {
    public var subtitle: String?              // title
    public var items: [String]?               // agenda
    public var kicker: String?                // sectionHeader
    public var bullets: [Bullet]?             // bullets
    public var left: Column?                  // twoColumn / comparison
    public var right: Column?
    public var quote: String?                 // quote
    public var attribution: String?
    public var value: String?                 // bigNumber
    public var label: String?
    public var callToAction: String?          // closing
    public var contact: String?
    public var chart: IRChart?                // chart
    public var stats: [IRStat]?               // metrics (2–4 headline numbers)

    public init(subtitle: String? = nil, items: [String]? = nil, kicker: String? = nil,
                bullets: [Bullet]? = nil, left: Column? = nil, right: Column? = nil,
                quote: String? = nil, attribution: String? = nil, value: String? = nil,
                label: String? = nil, callToAction: String? = nil, contact: String? = nil,
                chart: IRChart? = nil, stats: [IRStat]? = nil) {
        self.subtitle = subtitle; self.items = items; self.kicker = kicker
        self.bullets = bullets; self.left = left; self.right = right
        self.quote = quote; self.attribution = attribution; self.value = value
        self.label = label; self.callToAction = callToAction; self.contact = contact
        self.chart = chart; self.stats = stats
    }
}

/// A chart on a `chart` slide. `kind` is bar | line | pie; `series[i].values`
/// align to `categories`.
public struct IRChart: Codable, Sendable, Equatable {
    public var kind: String
    public var categories: [String]
    public var series: [IRSeries]
    public init(kind: String, categories: [String], series: [IRSeries]) {
        self.kind = kind; self.categories = categories; self.series = series
    }
}

public struct IRSeries: Codable, Sendable, Equatable {
    public var name: String
    public var values: [Double]
    public init(name: String, values: [Double]) { self.name = name; self.values = values }
}

/// One headline metric on a `metrics` slide.
public struct IRStat: Codable, Sendable, Equatable {
    public var value: String
    public var label: String
    public init(value: String, label: String) { self.value = value; self.label = label }
}

public struct Bullet: Codable, Sendable, Equatable {
    public var text: String
    public var subBullets: [String]?
    public init(text: String, subBullets: [String]? = nil) { self.text = text; self.subBullets = subBullets }
}

public struct Column: Codable, Sendable, Equatable {
    public var heading: String
    public var bullets: [String]
    public init(heading: String, bullets: [String]) { self.heading = heading; self.bullets = bullets }
}

/// The known layout vocabulary (§8.2), plus `.unknown` for forward-compat.
public enum SlideLayoutKind: Sendable, Equatable {
    case title, agenda, sectionHeader, bullets, twoColumn, comparison, quote, bigNumber, closing
    case chart, metrics, bands
    case unknown(String)

    public init(_ raw: String) {
        switch raw {
        case "title": self = .title
        case "agenda": self = .agenda
        case "sectionHeader": self = .sectionHeader
        case "bullets": self = .bullets
        case "twoColumn": self = .twoColumn
        case "comparison": self = .comparison
        case "quote": self = .quote
        case "bigNumber": self = .bigNumber
        case "closing": self = .closing
        case "chart": self = .chart
        case "metrics": self = .metrics
        case "bands": self = .bands
        default: self = .unknown(raw)
        }
    }

    /// How a generated image is placed on this layout — chosen so imagery never
    /// clips or crowds text.
    public var imagePlacement: ImagePlacement {
        switch self {
        case .title, .bigNumber, .quote, .closing: return .fullBleed   // sparse, centered/large text
        case .sectionHeader: return .sidePanel                          // title left, image right
        case .agenda, .bullets, .twoColumn, .comparison, .chart, .metrics, .bands, .unknown: return .none
        }
    }
}

/// Where a slide's generated image goes.
public enum ImagePlacement: Sendable, Equatable {
    case none        // don't place an image (text-dense layout)
    case sidePanel   // a framed panel on the right
    case fullBleed   // a scrimmed, edge-to-edge background behind the text
}
