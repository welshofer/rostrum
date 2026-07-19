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

    public init(id: String, sectionId: String? = nil, layout: String,
                title: String? = nil, body: Body? = nil, notes: String? = nil) {
        self.id = id; self.sectionId = sectionId; self.layout = layout
        self.title = title; self.body = body; self.notes = notes
    }

    /// The parsed layout, or `.unknown(raw)`.
    public var kind: SlideLayoutKind { SlideLayoutKind(layout) }
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

    public init(subtitle: String? = nil, items: [String]? = nil, kicker: String? = nil,
                bullets: [Bullet]? = nil, left: Column? = nil, right: Column? = nil,
                quote: String? = nil, attribution: String? = nil, value: String? = nil,
                label: String? = nil, callToAction: String? = nil, contact: String? = nil) {
        self.subtitle = subtitle; self.items = items; self.kicker = kicker
        self.bullets = bullets; self.left = left; self.right = right
        self.quote = quote; self.attribution = attribution; self.value = value
        self.label = label; self.callToAction = callToAction; self.contact = contact
    }
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
        default: self = .unknown(raw)
        }
    }
}
