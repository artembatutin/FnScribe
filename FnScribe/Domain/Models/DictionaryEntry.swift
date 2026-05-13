//
//  DictionaryEntry.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

struct DictionaryEntry: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var spokenForm: String       // What user says: "super base"
    var writtenForm: String      // What gets typed: "Supabase"
    var category: Category
    var isAutoLearned: Bool
    var useCount: Int
    var createdAt: Date
    var lastUsedAt: Date?
    
    enum Category: String, Codable, CaseIterable {
        case name           // People/company names
        case technical      // Programming terms
        case acronym        // API, SDK, CLI
        case custom         // User-defined
        case correction     // Auto-learned from edits
        
        var displayName: String {
            switch self {
            case .name:
                return "Names"
            case .technical:
                return "Technical"
            case .acronym:
                return "Acronyms"
            case .custom:
                return "Custom"
            case .correction:
                return "Corrections"
            }
        }
        
        var icon: String {
            switch self {
            case .name:
                return "person.fill"
            case .technical:
                return "chevron.left.forwardslash.chevron.right"
            case .acronym:
                return "textformat.abc"
            case .custom:
                return "star.fill"
            case .correction:
                return "arrow.triangle.2.circlepath"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        spokenForm: String,
        writtenForm: String,
        category: Category = .custom,
        isAutoLearned: Bool = false,
        useCount: Int = 0,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.spokenForm = spokenForm.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.writtenForm = writtenForm.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.isAutoLearned = isAutoLearned
        self.useCount = useCount
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
    
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var formattedLastUsedAt: String? {
        guard let lastUsedAt = lastUsedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastUsedAt)
    }
    
    mutating func incrementUseCount() {
        useCount += 1
        lastUsedAt = Date()
    }
}
