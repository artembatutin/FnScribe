import Foundation

enum StreamingTranscript {
    /// Preserve earlier chunks and remove only a matching suffix/prefix overlap.
    /// Fuzzy single-word matches can erase unrelated speech (e.g. "cat"/"can").
    static func merge(_ new: String, after existing: String) -> (confirmed: String, pending: String) {
        let previousWords = existing.split(whereSeparator: \.isWhitespace).map(String.init)
        let newWords = new.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !newWords.isEmpty else { return (existing, "") }
        let limit = min(previousWords.count, newWords.count)
        var overlap = 0
        if limit > 0 {
            for count in stride(from: limit, through: 1, by: -1) {
                let suffix = previousWords.suffix(count).map(normalize)
                let prefix = newWords.prefix(count).map(normalize)
                if suffix == prefix {
                    overlap = count
                    break
                }
            }
        }
        let confirmed = previousWords.dropLast(overlap).joined(separator: " ")
        return (confirmed.isEmpty ? "" : confirmed + " ", newWords.joined(separator: " "))
    }

    private static func normalize(_ word: String) -> String {
        let stripped = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
        return stripped.isEmpty ? word : stripped
    }
}
