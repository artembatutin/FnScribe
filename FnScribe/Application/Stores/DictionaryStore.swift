//
//  DictionaryStore.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

actor DictionaryStore {
    
    private let fileURL: URL
    private var cachedEntries: [DictionaryEntry]?
    
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? (try? AppSupportPaths.fileURL("dictionary.json")) ??
            FileManager.default.temporaryDirectory.appendingPathComponent("dictionary.json")
    }
    
    func load() async throws -> [DictionaryEntry] {
        if let cached = cachedEntries {
            return cached
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedEntries = []
            return []
        }
        
        let data = try Data(contentsOf: fileURL)
        let entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        cachedEntries = entries
        return entries
    }
    
    func save(_ entries: [DictionaryEntry]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
        cachedEntries = entries
    }
    
    func add(_ entry: DictionaryEntry) async throws {
        var entries = try await load()
        entries.append(entry)
        try await save(entries)
    }
    
    func update(_ entry: DictionaryEntry) async throws {
        var entries = try await load()
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            try await save(entries)
        }
    }
    
    func remove(id: UUID) async throws {
        var entries = try await load()
        entries.removeAll { $0.id == id }
        try await save(entries)
    }
    
    func removeAll() async throws {
        try await save([])
    }
    
    func exportToURL(_ url: URL) async throws {
        let entries = try await load()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)
        try data.write(to: url, options: .atomic)
    }
    
    func importFromURL(_ url: URL, merge: Bool = true) async throws -> Int {
        let data = try Data(contentsOf: url)
        let importedEntries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        
        if merge {
            var entries = try await load()
            var addedCount = 0
            
            for imported in importedEntries {
                // Check if entry with same spoken form already exists
                if !entries.contains(where: { $0.spokenForm == imported.spokenForm }) {
                    entries.append(imported)
                    addedCount += 1
                }
            }
            
            try await save(entries)
            return addedCount
        } else {
            try await save(importedEntries)
            return importedEntries.count
        }
    }
}
