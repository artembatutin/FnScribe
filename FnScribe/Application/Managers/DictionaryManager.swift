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
    
    init(store: DictionaryStore = DictionaryStore()) {
        self.store = store
    }
    
    func load() async {
        guard !isLoaded else { return }
        isLoading = true
        
        do {
            entries = try await store.load()
            isLoaded = true
        } catch {
            print("Failed to load dictionary: \(error)")
        }
        
        isLoading = false
    }
    
    func addEntry(_ entry: DictionaryEntry) {
        guard !entries.contains(where: { $0.spokenForm == entry.spokenForm }) else {
            return
        }
        
        entries.append(entry)
        
        Task {
            try? await store.save(entries)
        }
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
        
        Task {
            try? await store.save(entries)
        }
    }
    
    func updateEntry(_ entry: DictionaryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            
            Task {
                try? await store.save(entries)
            }
        }
    }
    
    func findMatch(for spokenText: String) -> DictionaryEntry? {
        let normalized = spokenText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.first { $0.spokenForm == normalized }
    }
    
    func recordUsage(for entryId: UUID) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].incrementUseCount()
            
            Task {
                try? await store.save(entries)
            }
        }
    }
    
    func learnFromCorrection(original: String, corrected: String) {
        let normalizedOriginal = original.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCorrected = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !normalizedOriginal.isEmpty,
              !normalizedCorrected.isEmpty,
              normalizedOriginal != normalizedCorrected.lowercased() else {
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
        var result = text
        
        let sortedEntries = entries.sorted { $0.spokenForm.count > $1.spokenForm.count }
        
        for entry in sortedEntries {
            let previous = result
            result = replaceWholeWord(in: result, target: entry.spokenForm, replacement: entry.writtenForm)
            
            if result != previous {
                Task { @MainActor in
                    self.recordUsage(for: entry.id)
                }
            }
        }
        
        return result
    }
    
    private func replaceWholeWord(in text: String, target: String, replacement: String) -> String {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: target))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
    
    func importEntries(from url: URL) async throws -> Int {
        let count = try await store.importFromURL(url, merge: true)
        entries = try await store.load()
        return count
    }
    
    func exportEntries(to url: URL) async throws {
        try await store.exportToURL(url)
    }
    
    func loadDeveloperTerms() {
        let developerTerms = DeveloperTermsDatabase.terms
        
        for term in developerTerms {
            if !entries.contains(where: { $0.spokenForm == term.spokenForm }) {
                entries.append(term)
            }
        }
        
        Task {
            try? await store.save(entries)
        }
    }
    
    func clearAutoLearned() {
        entries.removeAll { $0.isAutoLearned }
        
        Task {
            try? await store.save(entries)
        }
    }
    
    func clearAll() {
        entries.removeAll()
        
        Task {
            try? await store.save(entries)
        }
    }
}
