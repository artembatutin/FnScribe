//
//  Snippet.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

struct Snippet: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var trigger: String              // Voice trigger phrase
    var content: String              // Full text with placeholders
    var category: Category
    var appRestrictions: [String]?   // Bundle IDs where this works (nil = all)
    var isEnabled: Bool
    var useCount: Int
    var createdAt: Date
    var lastUsedAt: Date?
    
    enum Category: String, Codable, CaseIterable {
        case email
        case code
        case meeting
        case personal
        case work
        case custom
        
        var displayName: String {
            switch self {
            case .email:
                return "Email"
            case .code:
                return "Code"
            case .meeting:
                return "Meeting"
            case .personal:
                return "Personal"
            case .work:
                return "Work"
            case .custom:
                return "Custom"
            }
        }
        
        var icon: String {
            switch self {
            case .email:
                return "envelope.fill"
            case .code:
                return "chevron.left.forwardslash.chevron.right"
            case .meeting:
                return "person.3.fill"
            case .personal:
                return "person.fill"
            case .work:
                return "briefcase.fill"
            case .custom:
                return "star.fill"
            }
        }
    }
    
    // Available placeholders
    static let placeholders: [(key: String, description: String)] = [
        ("{date}", "Current date"),
        ("{time}", "Current time"),
        ("{datetime}", "Date and time"),
        ("{clipboard}", "Clipboard content"),
        ("{app}", "Current app name"),
        ("{cursor}", "Cursor position"),
        ("{selected}", "Selected text"),
    ]
    
    init(
        id: UUID = UUID(),
        name: String,
        trigger: String,
        content: String,
        category: Category = .custom,
        appRestrictions: [String]? = nil,
        isEnabled: Bool = true,
        useCount: Int = 0,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.trigger = trigger.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = content
        self.category = category
        self.appRestrictions = appRestrictions
        self.isEnabled = isEnabled
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
    
    var containsPlaceholders: Bool {
        Self.placeholders.contains { content.contains($0.key) }
    }
    
    var placeholdersList: [String] {
        Self.placeholders.compactMap { content.contains($0.key) ? $0.key : nil }
    }
}
