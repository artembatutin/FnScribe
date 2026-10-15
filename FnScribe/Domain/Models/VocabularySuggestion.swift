import Foundation

nonisolated struct VocabularySuggestion: Codable, Identifiable, Equatable, Sendable {
    var id: String { DictionaryMatcher.key(word) }
    let word: String
    var alternatives: [String]
    var context: String
    var occurrences: Int
    var lastSeen: Date
}

nonisolated struct VocabularySuggestionState: Codable, Sendable {
    var suggestions: [VocabularySuggestion] = []
    var ignoredWords: Set<String> = []
}
