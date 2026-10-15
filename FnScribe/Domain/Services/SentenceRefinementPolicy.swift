import Foundation
import NaturalLanguage

nonisolated enum SentenceRefinementPolicy {
    static func protectedRanges(in text: String, terms: [String]) -> [NSRange] {
        var ranges = UnusualWordDetector.excludedRanges(in: text)
        let source = text as NSString
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if tag == .personalName || tag == .organizationName || tag == .placeName {
                ranges.append(NSRange(range, in: text))
            }
            return true
        }
        let tokenPattern = #"\b[\p{L}\p{N}_]*\d[\p{L}\p{N}_.%-]*\b|\b[\p{Ll}]+[\p{Lu}][\p{L}\p{N}_]*\b|\b[\p{L}]+_[\p{L}\p{N}_]+\b|\b[\p{Lu}]{2,}\b"#
        if let regex = try? NSRegularExpression(pattern: tokenPattern) {
            ranges += regex.matches(in: text, range: NSRange(location: 0, length: source.length)).map(\.range)
        }
        for term in terms where !term.isEmpty {
            let pattern = "(?<![\\p{L}\\p{N}_])\(NSRegularExpression.escapedPattern(for: term))(?![\\p{L}\\p{N}_])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            ranges += regex.matches(in: text, range: NSRange(location: 0, length: source.length)).map(\.range)
        }
        return ranges
    }

    static func intersectsProtected(_ range: NSRange, in text: String, terms: [String]) -> Bool {
        protectedRanges(in: text, terms: terms).contains { NSIntersectionRange(range, $0).length > 0 }
    }

    static func accepts(_ candidate: String, original: String, protectedTerms: [String]) -> Bool {
        let candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.count <= max(120, original.count * 2),
              candidate.count >= original.count / 2 else { return false }
        let source = original as NSString
        let literals = Set(protectedRanges(in: original, terms: protectedTerms).map { source.substring(with: $0) })
        for literal in literals {
            guard count(literal, in: candidate) == count(literal, in: original) else { return false }
        }
        // A grammar pass must not add/remove negation or factual quantities.
        let critical = #"\b(?:not|never|no|without|cannot|can't|don't|doesn't|didn't|won't|wouldn't|shouldn't|isn't|aren't|today|tomorrow|yesterday|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b|\d+(?:[.,]\d+)*"#
        guard matches(critical, in: candidate) == matches(critical, in: original) else { return false }
        let originalWords = Set(UnusualWordDetector.words(in: original).map { $0.word.lowercased() })
        let candidateWords = Set(UnusualWordDetector.words(in: candidate).map { $0.word.lowercased() })
        let overlap = originalWords.intersection(candidateWords).count
        guard originalWords.isEmpty || Double(overlap) / Double(originalWords.count) >= 0.5 else { return false }
        return true
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let normalized = text.replacingOccurrences(of: "’", with: "'")
        let source = normalized as NSString
        return regex.matches(in: normalized, range: NSRange(location: 0, length: source.length)).map {
            source.substring(with: $0.range).lowercased().replacingOccurrences(of: "’", with: "'")
        }
    }

    private static func count(_ literal: String, in text: String) -> Int {
        guard !literal.isEmpty else { return 0 }
        return text.components(separatedBy: literal).count - 1
    }
}
