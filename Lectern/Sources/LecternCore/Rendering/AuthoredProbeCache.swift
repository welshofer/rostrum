import Foundation

/// Decisions for one authored pagination operation. The renderer owns the
/// presentation, fonts, styles and measurement policy throughout that operation;
/// none may change while this scratch cache is alive. Never retain it on an actor
/// or use it for an imported template or a later render.
final class AuthoredProbeCache {
    enum Outcome {
        case fits(usage: Double?)
        case rejected(String)
    }

    private struct Key: Hashable {
        // Data equality preserves the exact Unicode sequence. Swift String/IR
        // equality alone would conflate canonically equivalent source text.
        let input: Data
        let hasImage: Bool
    }
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private var outcomes: [Key: Outcome] = [:]
    private(set) var retainedBytes = 0
    var count: Int { outcomes.count }

    func evaluate(_ input: IRSlide, hasImage: Bool, needsUsage: Bool,
                  create: () throws -> Outcome) throws -> Outcome {
        try Task.checkCancellation()
        // Some programmatic IR carries unused, non-JSON numeric fields (for
        // example a chart payload on a bullet slide). Key construction must
        // never reject content the ordinary renderer would accept.
        guard let data = try? encoder.encode(input) else {
            let result = try create()
            try Task.checkCancellation()
            return result
        }
        let key = Key(input: data, hasImage: hasImage)
        if let cached = outcomes[key] {
            switch cached {
            case .rejected: return cached
            case .fits(let usage) where !needsUsage || usage != nil: return cached
            default: break
            }
        }
        let result = try create()
        try Task.checkCancellation()
        let bytes = key.input.count + result.messageBytes
        // Retain no slide/XML objects. Large bodies and excess entries use the
        // ordinary path, so a large deck cannot grow this scratch space forever.
        if key.input.count <= 65_536 {
            if let previous = outcomes[key] {
                let previousBytes = key.input.count + previous.messageBytes
                if bytes <= 262_144 - (retainedBytes - previousBytes) {
                    outcomes[key] = result
                    retainedBytes += bytes - previousBytes
                }
            } else if outcomes.count < 64, bytes <= 262_144 - retainedBytes {
                outcomes[key] = result
                retainedBytes += bytes
            }
        }
        return result
    }
}

private extension AuthoredProbeCache.Outcome {
    var messageBytes: Int {
        if case .rejected(let message) = self { return message.utf8.count }
        return 0
    }
}
