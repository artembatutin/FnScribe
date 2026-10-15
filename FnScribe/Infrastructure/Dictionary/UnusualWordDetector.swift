import AppKit
import NaturalLanguage

@MainActor
protocol VocabularyDetecting {
    func detect(in text: String, language: String?, knownTerms: [String]) -> [VocabularySuggestion]
}

@MainActor
final class UnusualWordDetector: VocabularyDetecting {
    func detect(in text: String, language: String?, knownTerms: [String]) -> [VocabularySuggestion] {
        let checker = NSSpellChecker.shared
        let detectedLanguage = language ?? NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "en"
        guard let spellingLanguage = checker.availableLanguages.first(where: {
            $0.replacingOccurrences(of: "-", with: "_").split(separator: "_").first.map(String.init) == detectedLanguage.split(separator: "-").first.map(String.init)
        }) else { return [] }
        let known = Set(knownTerms.flatMap { term in
            [DictionaryMatcher.key(term)] + Self.words(in: term).map { DictionaryMatcher.key($0.word) }
        })
        let source = text as NSString
        let excluded = Self.excludedRanges(in: text)
        let document = NSSpellChecker.uniqueSpellDocumentTag()
        defer { checker.closeSpellDocument(withTag: document) }
        var suggestions: [String: VocabularySuggestion] = [:]
        for token in Self.words(in: text).prefix(600) {
            guard token.word.filter(\.isLetter).count >= 3,
                  !known.contains(DictionaryMatcher.key(token.word)),
                  !excluded.contains(where: { NSIntersectionRange($0, token.range).length > 0 }) else { continue }
            let misspelled = checker.checkSpelling(of: token.word, startingAt: 0, language: spellingLanguage,
                                                  wrap: false, inSpellDocumentWithTag: document, wordCount: nil)
            guard misspelled.location != NSNotFound, misspelled.length > 0 else { continue }
            let guesses = checker.guesses(forWordRange: NSRange(location: 0, length: (token.word as NSString).length),
                                         in: token.word, language: spellingLanguage, inSpellDocumentWithTag: document) ?? []
            let start = max(0, token.range.location - 60)
            let contextRange = source.rangeOfComposedCharacterSequences(for: NSRange(location: start, length: min(source.length - start, 160)))
            let key = DictionaryMatcher.key(token.word)
            if var existing = suggestions[key] {
                existing.occurrences += 1
                suggestions[key] = existing
            } else {
                suggestions[key] = .init(word: token.word, alternatives: Array(guesses.prefix(3)),
                                         context: source.substring(with: contextRange), occurrences: 1, lastSeen: Date())
            }
        }
        return suggestions.values.sorted { $0.id < $1.id }
    }

    nonisolated static func words(in text: String) -> [(word: String, range: NSRange)] {
        let regex = try! NSRegularExpression(pattern: "[\\p{L}][\\p{L}\\p{M}\\p{N}_]*(?:['’+-][\\p{L}\\p{M}\\p{N}_]+)*")
        let source = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: source.length)).map {
            (source.substring(with: $0.range), $0.range)
        }
    }

    nonisolated static func excludedRanges(in text: String) -> [NSRange] {
        let pattern = "`[^`]*`|(?:https?://|www\\.)[^\\s]+|[\\w.+-]+@[\\w.-]+\\.[\\p{L}]{2,}|(?:[/~][\\w./-]+)|\\b[\\w-]+\\.[\\w.]+\\b"
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }
}
