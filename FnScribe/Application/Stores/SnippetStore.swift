//
//  SnippetStore.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

actor SnippetStore {
    
    private let fileURL: URL
    private var cachedSnippets: [Snippet]?
    
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? (try? AppSupportPaths.fileURL("snippets.json")) ??
            FileManager.default.temporaryDirectory.appendingPathComponent("snippets.json")
    }
    
    func load() async throws -> [Snippet] {
        if let cached = cachedSnippets {
            return cached
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedSnippets = []
            return []
        }
        
        let data = try Data(contentsOf: fileURL)
        let snippets = try JSONDecoder().decode([Snippet].self, from: data)
        cachedSnippets = snippets
        return snippets
    }
    
    func save(_ snippets: [Snippet]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snippets)
        try data.write(to: fileURL, options: .atomic)
        cachedSnippets = snippets
    }
    
    func add(_ snippet: Snippet) async throws {
        var snippets = try await load()
        snippets.append(snippet)
        try await save(snippets)
    }
    
    func update(_ snippet: Snippet) async throws {
        var snippets = try await load()
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            try await save(snippets)
        }
    }
    
    func remove(id: UUID) async throws {
        var snippets = try await load()
        snippets.removeAll { $0.id == id }
        try await save(snippets)
    }
    
    func removeAll() async throws {
        try await save([])
    }
    
    func exportToURL(_ url: URL) async throws {
        let snippets = try await load()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snippets)
        try data.write(to: url, options: .atomic)
    }
    
    func importFromURL(_ url: URL, merge: Bool = true) async throws -> Int {
        let data = try Data(contentsOf: url)
        let importedSnippets = try JSONDecoder().decode([Snippet].self, from: data)
        
        if merge {
            var snippets = try await load()
            var addedCount = 0
            
            for imported in importedSnippets {
                // Check if snippet with same trigger already exists
                if !snippets.contains(where: { $0.trigger == imported.trigger }) {
                    snippets.append(imported)
                    addedCount += 1
                }
            }
            
            try await save(snippets)
            return addedCount
        } else {
            try await save(importedSnippets)
            return importedSnippets.count
        }
    }
}
