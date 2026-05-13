//
//  SnippetManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine
import AppKit

@MainActor
class SnippetManager: ObservableObject {
    
    @Published private(set) var snippets: [Snippet] = []
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var searchText: String = ""
    @Published var selectedCategory: Snippet.Category?
    
    private let store: SnippetStore
    private let placeholderResolver: PlaceholderResolver
    
    var filteredSnippets: [Snippet] {
        var result = snippets
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(search) ||
                $0.trigger.lowercased().contains(search) ||
                $0.content.lowercased().contains(search)
            }
        }
        
        return result.sorted { $0.useCount > $1.useCount }
    }
    
    var snippetsByCategory: [Snippet.Category: [Snippet]] {
        Dictionary(grouping: snippets, by: { $0.category })
    }
    
    var totalSnippets: Int { snippets.count }
    var enabledCount: Int { snippets.filter { $0.isEnabled }.count }
    var disabledCount: Int { snippets.filter { !$0.isEnabled }.count }
    
    init(store: SnippetStore = SnippetStore()) {
        self.store = store
        self.placeholderResolver = PlaceholderResolver()
    }
    
    func load() async {
        guard !isLoaded else { return }
        isLoading = true
        
        do {
            snippets = try await store.load()
            isLoaded = true
        } catch {
            print("Failed to load snippets: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - CRUD Operations
    
    func addSnippet(_ snippet: Snippet) {
        guard !snippets.contains(where: { $0.trigger == snippet.trigger }) else {
            return
        }
        
        snippets.append(snippet)
        
        Task {
            try? await store.save(snippets)
        }
    }
    
    func addSnippet(name: String, trigger: String, content: String, category: Snippet.Category = .custom, appRestrictions: [String]? = nil) {
        let snippet = Snippet(
            name: name,
            trigger: trigger,
            content: content,
            category: category,
            appRestrictions: appRestrictions
        )
        addSnippet(snippet)
    }
    
    func removeSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        
        Task {
            try? await store.save(snippets)
        }
    }
    
    func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            
            Task {
                try? await store.save(snippets)
            }
        }
    }
    
    func duplicateSnippet(id: UUID) {
        guard let original = snippets.first(where: { $0.id == id }) else { return }
        
        var duplicated = original
        duplicated = Snippet(
            name: "\(original.name) (Copy)",
            trigger: "\(original.trigger) copy",
            content: original.content,
            category: original.category,
            appRestrictions: original.appRestrictions,
            isEnabled: original.isEnabled
        )
        
        addSnippet(duplicated)
    }
    
    func toggleEnabled(id: UUID) {
        if let index = snippets.firstIndex(where: { $0.id == id }) {
            snippets[index].isEnabled.toggle()
            
            Task {
                try? await store.save(snippets)
            }
        }
    }
    
    // MARK: - Trigger Detection
    
    func findSnippet(for trigger: String, in bundleId: String? = nil) -> Snippet? {
        let normalized = trigger.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return snippets.first { snippet in
            guard snippet.isEnabled else { return false }
            guard snippet.trigger == normalized else { return false }
            
            // Check app restrictions if present
            if let restrictions = snippet.appRestrictions, !restrictions.isEmpty {
                guard let bundleId = bundleId else { return false }
                return restrictions.contains(bundleId)
            }
            
            return true
        }
    }
    
    func findSnippetInText(_ text: String, bundleId: String? = nil) -> (snippet: Snippet, range: Range<String.Index>)? {
        let lowercasedText = text.lowercased()
        
        // Sort by trigger length (longest first) to match longer triggers first
        let sortedSnippets = snippets
            .filter { $0.isEnabled }
            .sorted { $0.trigger.count > $1.trigger.count }
        
        for snippet in sortedSnippets {
            // Check app restrictions
            if let restrictions = snippet.appRestrictions, !restrictions.isEmpty {
                guard let bundleId = bundleId else { continue }
                guard restrictions.contains(bundleId) else { continue }
            }
            
            // Look for whole word match of trigger
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: snippet.trigger))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let nsRange = NSRange(lowercasedText.startIndex..., in: lowercasedText)
            if let match = regex.firstMatch(in: lowercasedText, options: [], range: nsRange),
               let range = Range(match.range, in: lowercasedText) {
                // Convert to range in original text
                let originalRange = text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound))..<text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound))
                return (snippet, originalRange)
            }
        }
        
        return nil
    }
    
    // MARK: - Content Resolution
    
    func resolveContent(_ snippet: Snippet, context: PlaceholderResolver.ResolutionContext? = nil) -> PlaceholderResolver.ResolvedContent {
        let ctx = context ?? PlaceholderResolver.ResolutionContext(
            date: Date(),
            appName: NSWorkspace.shared.frontmostApplication?.localizedName,
            clipboard: NSPasteboard.general.string(forType: .string),
            selectedText: nil
        )
        
        return placeholderResolver.resolve(snippet.content, context: ctx)
    }
    
    func processText(_ text: String, bundleId: String? = nil) -> String {
        guard let match = findSnippetInText(text, bundleId: bundleId) else {
            return text
        }
        
        let resolved = resolveContent(match.snippet)
        var result = text
        result.replaceSubrange(match.range, with: resolved.text)
        
        // Record usage
        recordUsage(for: match.snippet.id)
        
        return result
    }
    
    func recordUsage(for snippetId: UUID) {
        if let index = snippets.firstIndex(where: { $0.id == snippetId }) {
            snippets[index].incrementUseCount()
            
            Task {
                try? await store.save(snippets)
            }
        }
    }
    
    // MARK: - Import/Export
    
    func importSnippets(from url: URL) async throws -> Int {
        let count = try await store.importFromURL(url, merge: true)
        snippets = try await store.load()
        return count
    }
    
    func exportSnippets(to url: URL) async throws {
        try await store.exportToURL(url)
    }
    
    // MARK: - Built-in Snippets
    
    func loadBuiltInSnippets() {
        let builtInSnippets = BuiltInSnippets.snippets
        
        for snippet in builtInSnippets {
            if !snippets.contains(where: { $0.trigger == snippet.trigger }) {
                snippets.append(snippet)
            }
        }
        
        Task {
            try? await store.save(snippets)
        }
    }
    
    // MARK: - Clear
    
    func clearAll() {
        snippets.removeAll()
        
        Task {
            try? await store.save(snippets)
        }
    }
}

// MARK: - Built-in Snippets

struct BuiltInSnippets {
    static let snippets: [Snippet] = [
        // Email
        Snippet(
            name: "Email Signature",
            trigger: "my signature",
            content: """
            Best regards,
            {cursor}
            """,
            category: .email
        ),
        Snippet(
            name: "Thank You Response",
            trigger: "thanks email",
            content: """
            Hi,

            Thank you for reaching out. I appreciate you taking the time to {cursor}.

            Best regards
            """,
            category: .email
        ),
        Snippet(
            name: "Follow Up",
            trigger: "follow up email",
            content: """
            Hi,

            I wanted to follow up on our previous conversation regarding {cursor}.

            Please let me know if you have any questions.

            Best regards
            """,
            category: .email
        ),
        
        // Code - React
        Snippet(
            name: "React Functional Component",
            trigger: "react component",
            content: """
            import React from 'react';

            interface {cursor}Props {
              
            }

            export const {cursor}: React.FC<{cursor}Props> = (props) => {
              return (
                <div>
                  
                </div>
              );
            };
            """,
            category: .code
        ),
        Snippet(
            name: "React useState Hook",
            trigger: "use state",
            content: "const [{cursor}, set{cursor}] = useState();",
            category: .code
        ),
        Snippet(
            name: "React useEffect Hook",
            trigger: "use effect",
            content: """
            useEffect(() => {
              {cursor}
            }, []);
            """,
            category: .code
        ),
        
        // Code - Swift
        Snippet(
            name: "Swift Struct",
            trigger: "swift struct",
            content: """
            struct {cursor}: Codable {
                
            }
            """,
            category: .code
        ),
        Snippet(
            name: "Swift Async Function",
            trigger: "swift async",
            content: """
            func {cursor}() async throws {
                
            }
            """,
            category: .code
        ),
        Snippet(
            name: "SwiftUI View",
            trigger: "swiftui view",
            content: """
            struct {cursor}View: View {
                var body: some View {
                    VStack {
                        
                    }
                }
            }
            """,
            category: .code
        ),
        
        // Code - TypeScript
        Snippet(
            name: "TypeScript Interface",
            trigger: "typescript interface",
            content: """
            interface {cursor} {
              
            }
            """,
            category: .code
        ),
        Snippet(
            name: "TypeScript Function",
            trigger: "typescript function",
            content: """
            function {cursor}(): void {
              
            }
            """,
            category: .code
        ),
        
        // Meeting
        Snippet(
            name: "Meeting Notes Template",
            trigger: "meeting notes",
            content: """
            # Meeting Notes - {date}

            ## Attendees
            - {cursor}

            ## Agenda
            1. 

            ## Action Items
            - [ ] 

            ## Notes

            """,
            category: .meeting
        ),
        Snippet(
            name: "Daily Standup",
            trigger: "standup",
            content: """
            ## Daily Standup - {date}

            ### Yesterday
            - {cursor}

            ### Today
            - 

            ### Blockers
            - None
            """,
            category: .meeting
        ),
        
        // Work
        Snippet(
            name: "Bug Report Template",
            trigger: "bug report",
            content: """
            ## Bug Report

            **Description:**
            {cursor}

            **Steps to Reproduce:**
            1. 

            **Expected Behavior:**


            **Actual Behavior:**


            **Environment:**
            - OS: 
            - Version: 

            **Screenshots:**
            """,
            category: .work
        ),
        Snippet(
            name: "Pull Request Description",
            trigger: "pr description",
            content: """
            ## Summary
            {cursor}

            ## Changes
            - 

            ## Testing
            - [ ] Unit tests added/updated
            - [ ] Manual testing completed

            ## Screenshots (if applicable)

            """,
            category: .work
        ),
        
        // Personal
        Snippet(
            name: "Current Date",
            trigger: "todays date",
            content: "{date}",
            category: .personal
        ),
        Snippet(
            name: "Current Time",
            trigger: "current time",
            content: "{time}",
            category: .personal
        ),
        Snippet(
            name: "Date and Time",
            trigger: "date time",
            content: "{datetime}",
            category: .personal
        ),
    ]
}
