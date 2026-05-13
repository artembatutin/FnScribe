//
//  FileMatchEngine.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-02-02.
//

import Foundation

/// Result of a file match operation
struct FileMatchResult {
    let file: WorkspaceFile
    let score: Double
    let matchedVariant: String
}

/// Engine for fuzzy matching spoken text to workspace files
struct FileMatchEngine {
    
    /// Minimum score threshold for a match to be considered valid
    static let minimumMatchScore: Double = 0.5
    
    /// Finds the best matching file for spoken text
    /// - Parameters:
    ///   - spokenText: The spoken text to match
    ///   - files: The workspace files to search
    /// - Returns: The best matching result, if any
    static func findMatch(for spokenText: String, in files: [WorkspaceFile]) -> FileMatchResult? {
        let normalizedQuery = spokenText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else { return nil }
        
        var bestMatch: FileMatchResult?
        var bestScore: Double = 0
        
        for file in files {
            // Check against all spoken variants
            for variant in file.spokenVariants {
                let score = fuzzyScore(normalizedQuery, variant)
                
                if score > bestScore && score >= minimumMatchScore {
                    bestScore = score
                    bestMatch = FileMatchResult(file: file, score: score, matchedVariant: variant)
                }
            }
            
            // Also check against the file name directly
            let nameScore = fuzzyScore(normalizedQuery, file.name.lowercased())
            if nameScore > bestScore && nameScore >= minimumMatchScore {
                bestScore = nameScore
                bestMatch = FileMatchResult(file: file, score: nameScore, matchedVariant: file.name)
            }
            
            // Check against name without extension
            let noExtScore = fuzzyScore(normalizedQuery, file.nameWithoutExtension.lowercased())
            if noExtScore > bestScore && noExtScore >= minimumMatchScore {
                bestScore = noExtScore
                bestMatch = FileMatchResult(file: file, score: noExtScore, matchedVariant: file.nameWithoutExtension)
            }
        }
        
        return bestMatch
    }
    
    /// Finds all matching files above the threshold
    /// - Parameters:
    ///   - spokenText: The spoken text to match
    ///   - files: The workspace files to search
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of matching results, sorted by score
    static func findMatches(for spokenText: String, in files: [WorkspaceFile], limit: Int = 5) -> [FileMatchResult] {
        let normalizedQuery = spokenText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalizedQuery.isEmpty else { return [] }
        
        var results: [FileMatchResult] = []
        
        for file in files {
            var bestFileScore: Double = 0
            var bestVariant: String = file.name
            
            // Check against all spoken variants
            for variant in file.spokenVariants {
                let score = fuzzyScore(normalizedQuery, variant)
                if score > bestFileScore {
                    bestFileScore = score
                    bestVariant = variant
                }
            }
            
            // Also check direct name matches
            let nameScore = fuzzyScore(normalizedQuery, file.name.lowercased())
            if nameScore > bestFileScore {
                bestFileScore = nameScore
                bestVariant = file.name
            }
            
            if bestFileScore >= minimumMatchScore {
                results.append(FileMatchResult(file: file, score: bestFileScore, matchedVariant: bestVariant))
            }
        }
        
        // Sort by score descending and limit results
        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Calculates a fuzzy match score between query and target
    /// - Parameters:
    ///   - query: The search query
    ///   - target: The target string to match against
    /// - Returns: Score from 0.0 (no match) to 1.0 (perfect match)
    static func fuzzyScore(_ query: String, _ target: String) -> Double {
        // Exact match
        if query == target {
            return 1.0
        }
        
        // Contains match
        if target.contains(query) {
            let ratio = Double(query.count) / Double(target.count)
            return 0.8 + (ratio * 0.15)
        }
        
        // Prefix match
        if target.hasPrefix(query) {
            let ratio = Double(query.count) / Double(target.count)
            return 0.75 + (ratio * 0.2)
        }
        
        // Word-based matching
        let queryWords = query.split(separator: " ").map(String.init)
        let targetWords = target.split(separator: " ").map(String.init)
        
        if !queryWords.isEmpty && !targetWords.isEmpty {
            var matchedWords = 0
            var partialMatches: Double = 0
            
            for queryWord in queryWords {
                for targetWord in targetWords {
                    if targetWord == queryWord {
                        matchedWords += 1
                        break
                    } else if targetWord.hasPrefix(queryWord) || queryWord.hasPrefix(targetWord) {
                        partialMatches += 0.5
                        break
                    } else if targetWord.contains(queryWord) || queryWord.contains(targetWord) {
                        partialMatches += 0.3
                        break
                    }
                }
            }
            
            let wordScore = (Double(matchedWords) + partialMatches) / Double(max(queryWords.count, targetWords.count))
            if wordScore > 0 {
                return min(wordScore * 0.9, 0.95)
            }
        }
        
        // Levenshtein distance based score
        let distance = levenshteinDistance(query, target)
        let maxLength = max(query.count, target.count)
        let normalizedDistance = Double(distance) / Double(maxLength)
        let distanceScore = 1.0 - normalizedDistance
        
        // Only return distance-based score if it's reasonable
        return distanceScore > 0.4 ? distanceScore * 0.7 : 0
    }
    
    /// Calculates the Levenshtein distance between two strings
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var previousRow = Array(0...n)
        var currentRow = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            currentRow[0] = i

            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                currentRow[j] = min(
                    previousRow[j] + 1,
                    currentRow[j - 1] + 1,
                    previousRow[j - 1] + cost
                )
            }

            swap(&previousRow, &currentRow)
        }
        
        return previousRow[n]
    }
    
    /// Generates phonetic variants for text (for handling speech recognition variations)
    /// - Parameter text: The text to generate variants for
    /// - Returns: Array of phonetic variants
    static func phoneticVariants(for text: String) -> [String] {
        var variants: [String] = [text.lowercased()]
        
        // Common speech recognition substitutions
        let substitutions: [(String, String)] = [
            ("swift", "shift"),
            ("js", "jazz"),
            ("ts", "teas"),
            ("tsx", "t s x"),
            ("jsx", "j s x"),
            ("vue", "view"),
            ("py", "pie"),
            ("rb", "ruby"),
            ("yml", "yaml"),
            ("config", "configure"),
            ("util", "utility"),
            ("utils", "utilities"),
            ("src", "source"),
            ("lib", "library"),
            ("pkg", "package"),
            ("impl", "implementation"),
            ("spec", "specification"),
            ("test", "tests"),
            ("index", "indexes"),
        ]
        
        let lowercased = text.lowercased()
        for (original, replacement) in substitutions {
            if lowercased.contains(original) {
                variants.append(lowercased.replacingOccurrences(of: original, with: replacement))
            }
            if lowercased.contains(replacement) {
                variants.append(lowercased.replacingOccurrences(of: replacement, with: original))
            }
        }
        
        return Array(Set(variants))
    }
}
