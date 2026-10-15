//
//  DictionaryManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine

@MainActor
class DictionaryManager: ObservableObject {
    
    @Published private(set) var entries: [DictionaryEntry] = []
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var selectedCategory: DictionaryEntry.Category?
    
    @Published private(set) var suggestions: [VocabularySuggestion] = []
    @Published private(set) var lastError: String?
    private var ignoredWords: Set<String> = []
    private let suggestionStore: VocabularySuggestionStore
    private let detector: any VocabularyDetecting
    private var persistenceTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private let store: DictionaryStore
    
    var filteredEntries: [DictionaryEntry] {
        var result = entries
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter {
                $0.spokenForm.lowercased().contains(search) ||
                $0.writtenForm.lowercased().contains(search)
            }
        }
        
        return result.sorted { $0.useCount > $1.useCount }
    }
    
    var entriesByCategory: [DictionaryEntry.Category: [DictionaryEntry]] {
        Dictionary(grouping: entries, by: { $0.category })
    }
    
    var totalEntries: Int { entries.count }
    var autoLearnedCount: Int { entries.filter { $0.isAutoLearned }.count }
    var manualCount: Int { entries.filter { !$0.isAutoLearned }.count }
    
    init(store: DictionaryStore = DictionaryStore(),
         suggestionStore: VocabularySuggestionStore = VocabularySuggestionStore(),
         detector: (any VocabularyDetecting)? = nil) {
        self.store = store
        self.suggestionStore = suggestionStore
        self.detector = detector ?? UnusualWordDetector()
    }

    func load() async {
        if let loadTask { await loadTask.value; return }
        guard !isLoaded else { return }
        isLoading = true
        let task = Task { @MainActor in
            do {
                entries = try await store.load()
                isLoaded = true
                let state = try await suggestionStore.load()
                suggestions = state.suggestions
                ignoredWords = state.ignoredWords
                lastError = nil
            } catch {
                lastError = "Couldn’t load the dictionary: \(error.localizedDescription)"
            }
            isLoading = false
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func persist() {
        guard isLoaded else {
            lastError = "Load the dictionary before making changes. Existing saved entries have been preserved."
            return
        }
        let entries = self.entries
        let state = VocabularySuggestionState(suggestions: suggestions, ignoredWords: ignoredWords)
        let previous = persistenceTask
        persistenceTask = Task { @MainActor in
            await previous?.value
            do {
                try await store.save(entries)
                try await suggestionStore.save(state)
                lastError = nil
            } catch {
                lastError = "Couldn’t save the dictionary: \(error.localizedDescription)"
            }
        }
    }

    func flush() async { await persistenceTask?.value }

    func addEntry(_ entry: DictionaryEntry) {
        guard isLoaded else { return }
        let spoken = DictionaryMatcher.key(entry.spokenForm)
        guard !spoken.isEmpty, !entry.writtenForm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !entries.contains(where: { DictionaryMatcher.key($0.spokenForm) == spoken }) else {
            return
        }
        
        entries.append(entry)
        suggestions.removeAll { $0.id == spoken || $0.id == DictionaryMatcher.key(entry.writtenForm) }
        persist()
    }
    
    func addEntry(spokenForm: String, writtenForm: String, category: DictionaryEntry.Category = .custom) {
        let entry = DictionaryEntry(
            spokenForm: spokenForm,
            writtenForm: writtenForm,
            category: category,
            isAutoLearned: false
        )
        addEntry(entry)
    }
    
    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        
        persist()
    }
    
    func updateEntry(_ entry: DictionaryEntry) {
        guard isLoaded, !DictionaryMatcher.key(entry.spokenForm).isEmpty,
              !entry.writtenForm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !entries.contains(where: { $0.id != entry.id && DictionaryMatcher.key($0.spokenForm) == DictionaryMatcher.key(entry.spokenForm) }) else { return }
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            
            persist()
        }
    }
    
    func findMatch(for spokenText: String) -> DictionaryEntry? {
        let normalized = spokenText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.first { DictionaryMatcher.key($0.spokenForm) == DictionaryMatcher.key(normalized) }
    }
    
    func recordUsage(for entryId: UUID) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].incrementUseCount()
            
            persist()
        }
    }
    
    func learnFromCorrection(original: String, corrected: String) {
        let normalizedOriginal = original.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCorrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedOriginal.isEmpty,
              !normalizedCorrected.isEmpty,
              normalizedOriginal != normalizedCorrected else {
            return
        }
        
        if entries.contains(where: { $0.spokenForm == normalizedOriginal }) {
            return
        }
        
        let entry = DictionaryEntry(
            spokenForm: normalizedOriginal,
            writtenForm: normalizedCorrected,
            category: .correction,
            isAutoLearned: true
        )
        
        addEntry(entry)
    }
    
    func applyDictionary(to text: String) -> String {
        let result = DictionaryMatcher.apply(text, entries: entries)
        for index in entries.indices where result.usedEntryIDs.contains(entries[index].id) {
            entries[index].incrementUseCount()
        }
        if !result.usedEntryIDs.isEmpty { persist() }
        return result.text
    }

    func observeTranscript(_ text: String, language: String? = nil) async {
        await load()
        guard isLoaded else { return }
        let found = detector.detect(in: text, language: language,
                                    knownTerms: entries.flatMap { [$0.spokenForm, $0.writtenForm] } + Array(ignoredWords))
        for candidate in found where !ignoredWords.contains(candidate.id) {
            if let index = suggestions.firstIndex(where: { $0.id == candidate.id }) {
                suggestions[index].occurrences += candidate.occurrences
                suggestions[index].context = candidate.context
                suggestions[index].lastSeen = candidate.lastSeen
                suggestions[index].alternatives = candidate.alternatives
            } else {
                suggestions.append(candidate)
            }
        }
        suggestions.sort { $0.occurrences == $1.occurrences ? $0.lastSeen > $1.lastSeen : $0.occurrences > $1.occurrences }
        suggestions = Array(suggestions.prefix(100))
        if !found.isEmpty { persist() }
    }

    func acceptSuggestion(_ suggestion: VocabularySuggestion, writtenForm: String) {
        guard !writtenForm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        addEntry(spokenForm: suggestion.word, writtenForm: writtenForm)
        suggestions.removeAll { $0.id == suggestion.id }
        persist()
    }

    func ignoreSuggestion(_ suggestion: VocabularySuggestion) {
        ignoredWords.insert(suggestion.id)
        suggestions.removeAll { $0.id == suggestion.id }
        persist()
    }

    func clearSuggestions() {
        suggestions.removeAll()
        ignoredWords.removeAll()
        persist()
    }

    func protectedTerms(in text: String) -> [String] {
        let vocabulary = entries.map(\.writtenForm) + suggestions.map(\.word) + Array(ignoredWords)
        return vocabulary.filter { text.range(of: $0, options: .caseInsensitive) != nil }
    }

    func importEntries(from url: URL) async throws -> Int {
        await flush()
        let count = try await store.importFromURL(url, merge: true)
        entries = try await store.load()
        return count
    }
    
    func exportEntries(to url: URL) async throws {
        await flush()
        try await store.exportToURL(url)
    }
    
    func loadDeveloperTerms() {
        let developerTerms = DeveloperTermsDatabase.terms
        
        for term in developerTerms {
            if !entries.contains(where: { DictionaryMatcher.key($0.spokenForm) == DictionaryMatcher.key(term.spokenForm) }) {
                entries.append(term)
            }
        }
        
        persist()
    }
    
    func clearAutoLearned() {
        entries.removeAll { $0.isAutoLearned }
        
        persist()
    }
    
    func clearAll() {
        entries.removeAll()
        
        persist()
    }
}
