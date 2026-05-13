//
//  FileTagger.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-02-02.
//

import Foundation
import Combine

/// Processes transcribed text to detect and tag file mentions
@MainActor
final class FileTagger: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isEnabled: Bool = true
    @Published private(set) var lastTaggedFile: WorkspaceFile?
    @Published private(set) var tagCount: Int = 0
    
    // MARK: - Dependencies
    
    private let workspaceScanner: WorkspaceScanner
    
    // MARK: - Configuration
    
    /// Tag patterns to detect file mentions
    /// Matches: "at [filename]", "@ [filename]", "file [filename]", "tag [filename]"
    private let tagPatterns: [NSRegularExpression] = {
        var patterns: [NSRegularExpression] = []
        
        // "at filename" - most common spoken pattern
        if let pattern = try? NSRegularExpression(
            pattern: "\\bat\\s+([a-zA-Z][a-zA-Z0-9_\\-\\.\\s]{1,50})(?=\\s|$|,|\\.|!|\\?)",
            options: .caseInsensitive
        ) {
            patterns.append(pattern)
        }
        
        // "@ filename" - direct @ mention
        if let pattern = try? NSRegularExpression(
            pattern: "@\\s*([a-zA-Z][a-zA-Z0-9_\\-\\.\\s]{1,50})(?=\\s|$|,|\\.|!|\\?)",
            options: .caseInsensitive
        ) {
            patterns.append(pattern)
        }
        
        // "file filename" - explicit file mention
        if let pattern = try? NSRegularExpression(
            pattern: "\\bfile\\s+([a-zA-Z][a-zA-Z0-9_\\-\\.\\s]{1,50})(?=\\s|$|,|\\.|!|\\?)",
            options: .caseInsensitive
        ) {
            patterns.append(pattern)
        }
        
        // "tag filename" - explicit tag mention
        if let pattern = try? NSRegularExpression(
            pattern: "\\btag\\s+([a-zA-Z][a-zA-Z0-9_\\-\\.\\s]{1,50})(?=\\s|$|,|\\.|!|\\?)",
            options: .caseInsensitive
        ) {
            patterns.append(pattern)
        }
        
        // "mention filename" - explicit mention
        if let pattern = try? NSRegularExpression(
            pattern: "\\bmention\\s+([a-zA-Z][a-zA-Z0-9_\\-\\.\\s]{1,50})(?=\\s|$|,|\\.|!|\\?)",
            options: .caseInsensitive
        ) {
            patterns.append(pattern)
        }
        
        return patterns
    }()
    
    /// Words that should stop the filename capture
    private let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
        "be", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "must", "shall", "can", "need",
        "that", "which", "who", "whom", "this", "these", "those", "it",
        "please", "thanks", "thank", "hello", "hi", "hey"
    ]
    
    // MARK: - Initialization
    
    init(workspaceScanner: WorkspaceScanner) {
        self.workspaceScanner = workspaceScanner
    }
    
    // MARK: - Public Methods
    
    /// Processes file mentions in transcribed text
    /// - Parameter text: The transcribed text to process
    /// - Returns: Text with file mentions replaced with proper tags
    func processFileMentions(_ text: String) -> String {
        guard isEnabled else { return text }
        guard !workspaceScanner.workspaceFiles.isEmpty else { return text }
        
        var result = text
        var replacements: [(range: Range<String.Index>, replacement: String)] = []
        
        // Find all potential file mentions
        for pattern in tagPatterns {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = pattern.matches(in: result, options: [], range: nsRange)
            
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let captureRange = Range(match.range(at: 1), in: result) else {
                    continue
                }
                
                let spokenName = String(result[captureRange])
                let trimmedName = trimToFileName(spokenName)
                
                // Try to find a matching file
                if let matchResult = FileMatchEngine.findMatch(for: trimmedName, in: workspaceScanner.workspaceFiles) {
                    // Get the full match range (including the trigger word)
                    guard let fullRange = Range(match.range, in: result) else { continue }
                    
                    // Create the tag
                    let tag = "@\(matchResult.file.name)"
                    
                    // Store replacement (we'll apply them in reverse order)
                    replacements.append((fullRange, tag))
                    
                    lastTaggedFile = matchResult.file
                    tagCount += 1
                }
            }
        }
        
        // Apply replacements in reverse order to preserve indices
        for replacement in replacements.reversed() {
            result.replaceSubrange(replacement.range, with: replacement.replacement)
        }
        
        return result
    }
    
    /// Checks if text contains potential file mentions
    /// - Parameter text: The text to check
    /// - Returns: True if file mentions are detected
    func containsFileMentions(_ text: String) -> Bool {
        for pattern in tagPatterns {
            let nsRange = NSRange(text.startIndex..., in: text)
            if pattern.firstMatch(in: text, options: [], range: nsRange) != nil {
                return true
            }
        }
        return false
    }
    
    /// Gets suggestions for a partial file name
    /// - Parameter partialName: The partial name to match
    /// - Returns: Array of matching files
    func getSuggestions(for partialName: String) -> [WorkspaceFile] {
        let matches = FileMatchEngine.findMatches(
            for: partialName,
            in: workspaceScanner.workspaceFiles,
            limit: 5
        )
        return matches.map { $0.file }
    }
    
    /// Resets the tag count
    func resetTagCount() {
        tagCount = 0
        lastTaggedFile = nil
    }
    
    // MARK: - Private Methods
    
    /// Trims captured text to extract the likely filename
    private func trimToFileName(_ text: String) -> String {
        var words = text.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ")
            .map(String.init)
        
        // Remove trailing stop words
        while let last = words.last, stopWords.contains(last) {
            words.removeLast()
        }
        
        // Limit to reasonable filename length (max 5 words)
        if words.count > 5 {
            words = Array(words.prefix(5))
        }
        
        return words.joined(separator: " ")
    }
}
