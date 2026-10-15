import Foundation

/// Matches against the original transcript so a replacement cannot trigger another entry.
nonisolated enum DictionaryMatcher {
    struct Result {
        let text: String
        let usedEntryIDs: Set<UUID>
    }

    static func key(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    static func apply(_ text: String, entries: [DictionaryEntry]) -> Result {
        var byPhrase: [String: DictionaryEntry] = [:]
        for entry in entries where !key(entry.spokenForm).isEmpty && !entry.writtenForm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let phrase = key(entry.spokenForm)
            if byPhrase[phrase] == nil { byPhrase[phrase] = entry }
        }
        let phrases = byPhrase.keys.sorted { $0.count == $1.count ? $0 < $1 : $0.count > $1.count }
        guard !phrases.isEmpty else { return Result(text: text, usedEntryIDs: []) }
        let alternatives = phrases.map { phrase in
            phrase.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+")
        }.joined(separator: "|")
        let pattern = "(?<![\\p{L}\\p{M}\\p{N}_])(?:\(alternatives))(?![\\p{L}\\p{M}\\p{N}_])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return Result(text: text, usedEntryIDs: [])
        }
        let original = text as NSString
        let result = NSMutableString(string: text)
        var used: Set<UUID> = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: original.length)).reversed() {
            guard let entry = byPhrase[key(original.substring(with: match.range))] else { continue }
            // replaceCharacters treats dollar signs and backslashes as literal text.
            result.replaceCharacters(in: match.range, with: entry.writtenForm)
            used.insert(entry.id)
        }
        return Result(text: result as String, usedEntryIDs: used)
    }
}
