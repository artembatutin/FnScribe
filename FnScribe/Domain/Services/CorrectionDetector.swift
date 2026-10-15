import Foundation

nonisolated enum CorrectionDetector {
    struct Change { let original: String; let corrected: String; let confidence: Double }

    static func detect(original: String, edited: String) -> Change? {
        let before = original.split(whereSeparator: \.isWhitespace).map(String.init)
        let after = edited.split(whereSeparator: \.isWhitespace).map(String.init)
        guard before.count >= 4, after.count >= 4, max(before.count, after.count) <= 1000 else { return nil }
        func key(_ word: String) -> String { word.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        if before.count == after.count, zip(before, after).allSatisfy({ key($0) == key($1) }) {
            let differences = zip(before, after).filter { $0 != $1 }
            guard differences.count == 1, let pair = differences.first,
                  pair.1.dropFirst().contains(where: \.isUppercase) else { return nil }
            return Change(original: pair.0.trimmingCharacters(in: .punctuationCharacters),
                          corrected: pair.1.trimmingCharacters(in: .punctuationCharacters), confidence: 0.9)
        }
        var prefix = 0
        while prefix < min(before.count, after.count), key(before[prefix]) == key(after[prefix]) { prefix += 1 }
        var suffix = 0
        while suffix < min(before.count, after.count) - prefix,
              key(before[before.count - 1 - suffix]) == key(after[after.count - 1 - suffix]) { suffix += 1 }
        let beforeEnd = before.count - suffix
        let afterEnd = after.count - suffix
        guard beforeEnd > prefix, afterEnd > prefix,
              beforeEnd - prefix <= 3, afterEnd - prefix <= 3,
              prefix + suffix >= 3,
              Double(prefix + suffix) / Double(max(before.count, after.count)) >= 0.65 else { return nil }
        let old = before[prefix..<beforeEnd].joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
        let new = after[prefix..<afterEnd].joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
        guard !old.isEmpty, !new.isEmpty, old.lowercased() != new.lowercased(),
              old.contains(where: \.isLetter), new.contains(where: \.isLetter),
              !old.contains(where: \.isNumber), !new.contains(where: \.isNumber) else { return nil }
        let a = old.lowercased().filter(\.isLetter)
        let b = new.lowercased().filter(\.isLetter)
        guard !a.isEmpty, !b.isEmpty, a.count <= 80, b.count <= 80 else { return nil }
        var row = Array(0...b.count)
        let target = Array(b)
        for (i, letter) in a.enumerated() {
            var next = [i + 1] + Array(repeating: 0, count: target.count)
            for j in target.indices { next[j + 1] = min(next[j] + 1, row[j + 1] + 1, row[j] + (letter == target[j] ? 0 : 1)) }
            row = next
        }
        let similarity = 1 - Double(row.last!) / Double(max(a.count, b.count))
        // Shared context and a related spelling distinguish a correction from an unrelated copy.
        guard similarity >= 0.5 else { return nil }
        return Change(original: old, corrected: new, confidence: min(0.98, 0.65 + similarity * 0.3))
    }
}
