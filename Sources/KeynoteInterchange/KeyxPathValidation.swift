import Foundation

enum KeyxPathValidation {
    /// Validate SVG command arity and finite operands without normalizing the
    /// original path. Keynote drops shapes with unusable path strings.
    static func isUsable(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        let arity: [UInt8: Int] = [77: 2, 76: 2, 72: 1, 86: 1, 67: 6, 83: 4, 81: 4, 84: 2, 65: 7, 90: 0]
        var offset = 0, command: UInt8?, operands = 0
        var afterComma = false
        func upper(_ byte: UInt8) -> UInt8 { (97...122).contains(byte) ? byte - 32 : byte }
        func complete() -> Bool {
            guard let command, let count = arity[command] else { return false }
            return count == 0 ? operands == 0 : operands > 0 && operands % count == 0
        }
        while offset < bytes.count {
            if [9, 10, 13, 32].contains(bytes[offset]) { offset += 1; continue }
            if bytes[offset] == 44 {
                guard operands > 0, command != 90, !afterComma else { return false }
                afterComma = true; offset += 1; continue
            }
            let byte = upper(bytes[offset])
            if arity[byte] != nil {
                guard !afterComma else { return false }
                if command == nil {
                    guard byte == 77 else { return false }
                } else if !complete() { return false }
                command = byte; operands = 0; offset += 1
                continue
            }
            guard let command, let count = arity[command], count > 0 else { return false }
            afterComma = false
            if command == 65, [3, 4].contains(operands % 7) {
                // SVG arc flags are single characters, not numbers. Adjacent
                // flags and a following coordinate may legally have no space.
                guard bytes[offset] == 48 || bytes[offset] == 49 else { return false }
                offset += 1; operands += 1; continue
            }
            let start = offset
            if offset < bytes.count, bytes[offset] == 43 || bytes[offset] == 45 { offset += 1 }
            var digits = 0
            while offset < bytes.count, (48...57).contains(bytes[offset]) { digits += 1; offset += 1 }
            if offset < bytes.count, bytes[offset] == 46 {
                offset += 1
                while offset < bytes.count, (48...57).contains(bytes[offset]) { digits += 1; offset += 1 }
            }
            guard digits > 0 else { return false }
            if offset < bytes.count, bytes[offset] == 101 || bytes[offset] == 69 {
                offset += 1
                if offset < bytes.count, bytes[offset] == 43 || bytes[offset] == 45 { offset += 1 }
                let begin = offset
                while offset < bytes.count, (48...57).contains(bytes[offset]) { offset += 1 }
                guard offset > begin else { return false }
            }
            guard let value = Double(String(decoding: bytes[start..<offset], as: UTF8.self)), value.isFinite else { return false }
            if command == 65 {
                if operands % 7 < 2, value < 0 { return false }
            }
            operands += 1
        }
        return !afterComma && complete()
    }
}
