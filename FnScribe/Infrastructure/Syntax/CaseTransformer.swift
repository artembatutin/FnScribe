//
//  CaseTransformer.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

/// Transforms text between different case styles (camelCase, snake_case, etc.)
struct CaseTransformer {
    
    /// Supported case types
    enum CaseType: String, CaseIterable {
        case camelCase = "camelCase"
        case snakeCase = "snake_case"
        case pascalCase = "PascalCase"
        case kebabCase = "kebab-case"
        case constantCase = "CONSTANT_CASE"
        case upperCase = "UPPERCASE"
        case lowerCase = "lowercase"
        case titleCase = "Title Case"
    }
    
    // MARK: - Case Transformations
    
    /// Converts words to camelCase
    /// - Parameter words: Array of words to transform
    /// - Returns: camelCase string (e.g., "userProfileManager")
    static func toCamelCase(_ words: [String]) -> String {
        guard !words.isEmpty else { return "" }
        let cleaned = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return "" }
        
        let first = cleaned[0]
        let rest = cleaned.dropFirst().map { $0.capitalized }
        return first + rest.joined()
    }
    
    /// Converts words to snake_case
    /// - Parameter words: Array of words to transform
    /// - Returns: snake_case string (e.g., "user_profile_manager")
    static func toSnakeCase(_ words: [String]) -> String {
        let cleaned = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.joined(separator: "_")
    }
    
    /// Converts words to PascalCase
    /// - Parameter words: Array of words to transform
    /// - Returns: PascalCase string (e.g., "UserProfileManager")
    static func toPascalCase(_ words: [String]) -> String {
        let cleaned = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.map { $0.capitalized }.joined()
    }
    
    /// Converts words to kebab-case
    /// - Parameter words: Array of words to transform
    /// - Returns: kebab-case string (e.g., "user-profile-manager")
    static func toKebabCase(_ words: [String]) -> String {
        let cleaned = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.joined(separator: "-")
    }
    
    /// Converts words to CONSTANT_CASE (UPPER_SNAKE)
    /// - Parameter words: Array of words to transform
    /// - Returns: CONSTANT_CASE string (e.g., "MAX_RETRY_COUNT")
    static func toConstantCase(_ words: [String]) -> String {
        let cleaned = words.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.joined(separator: "_")
    }
    
    /// Converts words to UPPERCASE
    /// - Parameter words: Array of words to transform
    /// - Returns: UPPERCASE string (e.g., "USER PROFILE MANAGER")
    static func toUpperCase(_ words: [String]) -> String {
        let cleaned = words.map { $0.uppercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.joined(separator: " ")
    }
    
    /// Converts words to lowercase
    /// - Parameter words: Array of words to transform
    /// - Returns: lowercase string (e.g., "user profile manager")
    static func toLowerCase(_ words: [String]) -> String {
        let cleaned = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.joined(separator: " ")
    }
    
    /// Converts words to Title Case
    /// - Parameter words: Array of words to transform
    /// - Returns: Title Case string (e.g., "User Profile Manager")
    static func toTitleCase(_ words: [String]) -> String {
        let cleaned = words.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return cleaned.map { $0.capitalized }.joined(separator: " ")
    }
    
    /// Transforms words to the specified case type
    /// - Parameters:
    ///   - words: Array of words to transform
    ///   - caseType: The target case type
    /// - Returns: Transformed string
    static func transform(_ words: [String], to caseType: CaseType) -> String {
        switch caseType {
        case .camelCase:
            return toCamelCase(words)
        case .snakeCase:
            return toSnakeCase(words)
        case .pascalCase:
            return toPascalCase(words)
        case .kebabCase:
            return toKebabCase(words)
        case .constantCase:
            return toConstantCase(words)
        case .upperCase:
            return toUpperCase(words)
        case .lowerCase:
            return toLowerCase(words)
        case .titleCase:
            return toTitleCase(words)
        }
    }
    
    // MARK: - Case Detection
    
    /// Detects the case type of a given string
    /// - Parameter text: The text to analyze
    /// - Returns: The detected case type, or nil if unknown
    static func detectCase(_ text: String) -> CaseType? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        // Check for CONSTANT_CASE (all uppercase with underscores)
        if trimmed.contains("_") && trimmed == trimmed.uppercased() && trimmed.rangeOfCharacter(from: .lowercaseLetters) == nil {
            return .constantCase
        }
        
        // Check for snake_case (lowercase with underscores)
        if trimmed.contains("_") && trimmed == trimmed.lowercased() {
            return .snakeCase
        }
        
        // Check for kebab-case (lowercase with hyphens)
        if trimmed.contains("-") && trimmed == trimmed.lowercased() {
            return .kebabCase
        }
        
        // Check for UPPERCASE (all caps, no special separators)
        if trimmed == trimmed.uppercased() && !trimmed.contains("_") && !trimmed.contains("-") {
            return .upperCase
        }
        
        // Check for lowercase (all lowercase, no special separators)
        if trimmed == trimmed.lowercased() && !trimmed.contains("_") && !trimmed.contains("-") {
            return .lowerCase
        }
        
        // Check for PascalCase vs camelCase
        let hasUppercase = trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = trimmed.rangeOfCharacter(from: .lowercaseLetters) != nil
        
        if hasUppercase && hasLowercase && !trimmed.contains(" ") && !trimmed.contains("_") && !trimmed.contains("-") {
            // Check first character
            if let first = trimmed.first, first.isUppercase {
                return .pascalCase
            } else {
                return .camelCase
            }
        }
        
        // Check for Title Case (capitalized words with spaces)
        if trimmed.contains(" ") {
            let words = trimmed.split(separator: " ")
            let allCapitalized = words.allSatisfy { word in
                guard let first = word.first else { return false }
                return first.isUppercase
            }
            if allCapitalized {
                return .titleCase
            }
        }
        
        return nil
    }
    
    // MARK: - Word Splitting
    
    /// Splits a string into words based on its case type
    /// - Parameter text: The text to split
    /// - Returns: Array of lowercase words
    static func splitIntoWords(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        
        // Handle snake_case and CONSTANT_CASE
        if trimmed.contains("_") {
            return trimmed.split(separator: "_").map { String($0).lowercased() }
        }
        
        // Handle kebab-case
        if trimmed.contains("-") {
            return trimmed.split(separator: "-").map { String($0).lowercased() }
        }
        
        // Handle space-separated
        if trimmed.contains(" ") {
            return trimmed.split(separator: " ").map { String($0).lowercased() }
        }
        
        // Handle camelCase and PascalCase
        var words: [String] = []
        var currentWord = ""
        
        for char in trimmed {
            if char.isUppercase && !currentWord.isEmpty {
                words.append(currentWord.lowercased())
                currentWord = String(char)
            } else {
                currentWord.append(char)
            }
        }
        
        if !currentWord.isEmpty {
            words.append(currentWord.lowercased())
        }
        
        return words
    }
    
    /// Converts text from one case to another
    /// - Parameters:
    ///   - text: The source text
    ///   - targetCase: The target case type
    /// - Returns: Transformed text
    static func convert(_ text: String, to targetCase: CaseType) -> String {
        let words = splitIntoWords(text)
        return transform(words, to: targetCase)
    }
}
