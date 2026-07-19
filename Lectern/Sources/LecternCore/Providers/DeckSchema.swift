import Foundation

/// The JSON Schema handed to a provider as a tool `input_schema`, mirroring
/// `DeckIR` (§7.2). Forcing tool-use with this schema makes the model emit a deck
/// that decodes on the first try — no more "couldn't parse". Kept in sync with
/// `DeckIR` by construction (same field names).
enum DeckSchema {
    static func inputSchema() -> [String: Any] {
        func str(_ desc: String? = nil) -> [String: Any] {
            desc.map { ["type": "string", "description": $0] } ?? ["type": "string"]
        }
        let strings: [String: Any] = ["type": "array", "items": ["type": "string"]]

        let bullet: [String: Any] = [
            "type": "object",
            "properties": ["text": str(), "subBullets": strings],
            "required": ["text"],
        ]
        let column: [String: Any] = [
            "type": "object",
            "properties": ["heading": str(), "bullets": strings],
            "required": ["heading", "bullets"],
        ]
        let series: [String: Any] = [
            "type": "object",
            "properties": ["name": str(), "values": ["type": "array", "items": ["type": "number"]]],
            "required": ["name", "values"],
        ]
        let chart: [String: Any] = [
            "type": "object",
            "description": "chart layout — real quantitative data, not decoration",
            "properties": [
                "kind": ["type": "string", "enum": ["bar", "line", "pie"]],
                "categories": strings,
                "series": ["type": "array", "items": series,
                           "description": "each series' values align 1:1 with categories"],
            ],
            "required": ["kind", "categories", "series"],
        ]
        let stat: [String: Any] = [
            "type": "object",
            "properties": ["value": str("the number, e.g. 218% or $1.5B"), "label": str("what it measures")],
            "required": ["value", "label"],
        ]
        let body: [String: Any] = [
            "type": "object",
            "description": "Only include the fields the slide's layout uses.",
            "properties": [
                "subtitle": str("title layout"),
                "items": strings,                                   // agenda
                "kicker": str("sectionHeader eyebrow"),
                "bullets": ["type": "array", "items": bullet],      // bullets
                "left": column, "right": column,                    // twoColumn / comparison
                "quote": str(), "attribution": str(),               // quote
                "value": str("bigNumber — the number itself, e.g. 218%"),
                "label": str("bigNumber caption"),
                "callToAction": str(), "contact": str(),            // closing
                "chart": chart,                                     // chart
                "stats": ["type": "array", "items": stat,           // metrics (2–4 numbers)
                          "description": "metrics layout — 2 to 4 headline numbers"],
            ],
        ]
        let image: [String: Any] = [
            "type": "object",
            "description": "OPTIONAL. Add only when a photographic/illustrative visual materially strengthens the slide — never on dense bullet or comparison slides. Describe the subject only; do not mention colors, fonts, or text.",
            "properties": [
                "prompt": str("the subject/scene to depict, e.g. 'a lighthouse on a rocky coast at dawn'"),
                "aspect": ["type": "string", "enum": ["16:9", "4:3", "1:1", "3:4", "9:16"]],
            ],
            "required": ["prompt"],
        ]
        let slide: [String: Any] = [
            "type": "object",
            "properties": [
                "id": str("stable unique id, e.g. s1"),
                "sectionId": str(),
                "layout": [
                    "type": "string",
                    "enum": ["title", "agenda", "sectionHeader", "bullets",
                             "twoColumn", "comparison", "quote", "bigNumber", "closing",
                             "chart", "metrics"],
                ],
                "title": str(),
                "body": body,
                "notes": str("what the presenter SAYS — 2–4 conversational sentences"),
                "image": image,
            ],
            "required": ["id", "layout"],
        ]
        let section: [String: Any] = [
            "type": "object",
            "properties": ["id": str(), "title": str(), "slideIds": strings],
            "required": ["id", "slideIds"],
        ]
        let meta: [String: Any] = [
            "type": "object",
            "properties": [
                "title": str(), "subtitle": str(), "audience": str(),
                "goal": str("inform | persuade | entertain | inspire"), "language": str(),
            ],
            "required": ["title"],
        ]
        return [
            "type": "object",
            "properties": [
                "meta": meta,
                "sections": ["type": "array", "items": section],
                "slides": ["type": "array", "items": slide],
            ],
            "required": ["meta", "slides"],
        ]
    }
}
