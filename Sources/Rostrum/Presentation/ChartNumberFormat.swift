import Foundation

/// Compiles the bounded numeric subset of DrawingML/Excel format codes once
/// per axis or label style. Quoted/escaped percent signs are literals, whereas
/// bare percent signs scale the value. Unsupported formats use General and are
/// reported by the renderer rather than silently changing the unit.
struct ChartNumberFormat {
    private struct Section {
        let formatter: NumberFormatter?
        let literal: String
        let multiplier: Double
    }
    private let sections: [Section]
    let isSupported: Bool

    init(_ code: String) {
        if let parsed = Self.parse(code) {
            sections = parsed
            isSupported = true
        } else {
            sections = Self.general()
            isSupported = false
        }
    }

    func string(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        let index = value == 0 && sections.count >= 3 ? 2 : value < 0 && sections.count >= 2 ? 1 : 0
        let section = sections[index]
        guard let formatter = section.formatter else { return section.literal }
        let number = (index == 1 ? abs(value) : value) * section.multiplier
        guard number.isFinite else { return String(value) }
        return formatter.string(from: NSNumber(value: number)) ?? String(value)
    }

    private static func decimal() -> NumberFormatter {
        let result = NumberFormatter()
        result.locale = Locale(identifier: "en_US_POSIX")
        result.numberStyle = .decimal
        result.usesGroupingSeparator = false
        return result
    }

    private static func general() -> [Section] {
        let formatter = decimal()
        formatter.maximumFractionDigits = 6
        formatter.roundingIncrement = 0.000001
        formatter.roundingMode = .halfUp
        return [Section(formatter: formatter, literal: "", multiplier: 1)]
    }

    private static func parse(_ code: String) -> [Section]? {
        if code.isEmpty || code.lowercased() == "general" { return general() }
        guard code.utf8.count <= 1024 else { return nil }
        // Each token retains whether it was quoted or escaped. Splitting on
        // semicolons before tokenization would corrupt literal suffixes.
        var parts: [[(Character, Bool)]] = [[]]
        var quoted = false, escaped = false
        for c in code {
            if escaped { parts[parts.count - 1].append((c, true)); escaped = false }
            else if c == "\\" { escaped = true }
            else if c == "\"" { quoted.toggle() }
            else if c == ";" && !quoted { parts.append([]) }
            else { parts[parts.count - 1].append((c, quoted)) }
        }
        guard !quoted, !escaped, parts.count <= 4 else { return nil }
        var result: [Section] = []
        for tokens in parts.prefix(3) {
            // Conditions, colors, dates, exponent/fraction formats and spacing
            // directives require a richer formatter. Never guess their meaning.
            if tokens.contains(where: { !$0.1 && ("[]_*?@/".contains($0.0) || $0.0.isLetter) }) { return nil }
            let digits = tokens.indices.filter { !tokens[$0].1 && "0#".contains(tokens[$0].0) }
            guard let first = digits.first, let last = digits.last else {
                if tokens.contains(where: { !$0.1 && ".,%".contains($0.0) }) { return nil }
                result.append(Section(formatter: nil, literal: String(tokens.map(\.0)), multiplier: 1))
                continue
            }
            let numeric = tokens[first...last]
            guard numeric.allSatisfy({ !$0.1 && "0#.,".contains($0.0) }) else { return nil }
            let pattern = String(numeric.map(\.0)).split(separator: ".", omittingEmptySubsequences: false)
            guard pattern.count <= 2 else { return nil }
            let integer = pattern[0], fraction = pattern.count == 2 ? String(pattern[1]) : ""
            guard !fraction.contains(","), fraction.count <= 12 else { return nil }
            let prefix = tokens[..<first]
            var suffix = Array(tokens[(last + 1)...])
            var scale = 1.0
            while let next = suffix.first, next.0 == "," && !next.1 {
                scale /= 1000; suffix.removeFirst()
            }
            guard !(Array(prefix) + suffix).contains(where: { !$0.1 && "0#.,".contains($0.0) }) else { return nil }
            let percentCount = tokens.filter { !$0.1 && $0.0 == "%" }.count
            guard percentCount <= 2 else { return nil }
            scale *= pow(100, Double(percentCount))
            let formatter = decimal()
            formatter.usesGroupingSeparator = integer.contains(",")
            formatter.groupingSize = 3
            formatter.minimumIntegerDigits = max(1, min(18, integer.filter { $0 == "0" }.count))
            formatter.minimumFractionDigits = fraction.filter { $0 == "0" }.count
            formatter.maximumFractionDigits = fraction.count
            // swift-corelibs Foundation may ignore maximumFractionDigits
            // without an explicit increment. Keep Apple/Linux rounding equal.
            formatter.roundingIncrement = NSNumber(value: pow(10, -Double(fraction.count)))
            formatter.roundingMode = .halfUp
            formatter.positivePrefix = String(prefix.map(\.0))
            formatter.negativePrefix = "-" + formatter.positivePrefix
            formatter.positiveSuffix = String(suffix.map(\.0))
            formatter.negativeSuffix = formatter.positiveSuffix
            result.append(Section(formatter: formatter, literal: "", multiplier: scale))
        }
        return result
    }
}
