//
//  SyntaxTransformer.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Combine
import Foundation

/// Service that transforms spoken text into proper code formatting
/// Handles case transformations, CLI commands, and code-specific patterns
@MainActor
class SyntaxTransformer: ObservableObject {
    
    // MARK: - Voice Commands
    
    /// Voice commands that trigger case transformations
    enum VoiceCommand: String, CaseIterable {
        case camelCase = "camel case"
        case snakeCase = "snake case"
        case pascalCase = "pascal case"
        case kebabCase = "kebab case"
        case upperCase = "upper case"
        case lowerCase = "lower case"
        case constantCase = "constant case"
        case titleCase = "title case"
        case allCaps = "all caps"
        case noCaps = "no caps"
        
        /// The corresponding case type for transformation
        var caseType: CaseTransformer.CaseType {
            switch self {
            case .camelCase: return .camelCase
            case .snakeCase: return .snakeCase
            case .pascalCase: return .pascalCase
            case .kebabCase: return .kebabCase
            case .upperCase, .allCaps: return .upperCase
            case .lowerCase, .noCaps: return .lowerCase
            case .constantCase: return .constantCase
            case .titleCase: return .titleCase
            }
        }
        
        /// Alternative spoken forms for this command
        var alternatives: [String] {
            switch self {
            case .camelCase: return ["camelcase", "camel"]
            case .snakeCase: return ["snakecase", "snake"]
            case .pascalCase: return ["pascalcase", "pascal", "capital case"]
            case .kebabCase: return ["kebabcase", "kebab", "dash case"]
            case .upperCase: return ["uppercase", "caps", "all capitals"]
            case .lowerCase: return ["lowercase", "no capitals"]
            case .constantCase: return ["constantcase", "screaming snake", "upper snake"]
            case .titleCase: return ["titlecase", "title"]
            case .allCaps: return ["capitals"]
            case .noCaps: return []
            }
        }
    }
    
    // MARK: - Settings
    
    /// Whether case transformations are enabled
    @Published var caseTransformationsEnabled: Bool = true
    
    /// Whether CLI pattern matching is enabled
    @Published var cliPatternsEnabled: Bool = true
    
    /// Whether code symbol replacements are enabled
    @Published var codeSymbolsEnabled: Bool = true
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Main Transformation
    
    /// Transforms text based on detected voice commands and patterns
    /// - Parameter text: The transcribed text to transform
    /// - Returns: Transformed text with proper code formatting
    func transform(_ text: String) -> String {
        var result = text
        
        // Apply case transformations first (they consume the command words)
        if caseTransformationsEnabled {
            result = applyCaseTransformations(result)
        }
        
        // Apply CLI patterns
        if cliPatternsEnabled {
            result = formatCLICommands(result)
        }
        
        // Apply code symbol patterns
        if codeSymbolsEnabled {
            result = applyCodePatterns(result)
        }
        
        return result
    }
    
    // MARK: - Case Transformations
    
    /// Detects and applies case transformation commands in text
    /// - Parameter text: The input text
    /// - Returns: Text with case transformations applied
    func applyCaseTransformations(_ text: String) -> String {
        var result = text
        
        // Process each voice command
        for command in VoiceCommand.allCases {
            result = processCommand(command, in: result)
            
            // Also check alternatives
            for alternative in command.alternatives {
                result = processAlternativeCommand(alternative, caseType: command.caseType, in: result)
            }
        }
        
        return result
    }
    
    /// Processes a specific voice command in the text
    private func processCommand(_ command: VoiceCommand, in text: String) -> String {
        let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: command.rawValue))\\s+(.+?)(?=\\s*(?:\(VoiceCommand.allCases.map { NSRegularExpression.escapedPattern(for: $0.rawValue) }.joined(separator: "|"))|[.!?,;:]|$)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        var result = text
        let nsRange = NSRange(result.startIndex..., in: result)
        
        // Find all matches (process from end to start to preserve indices)
        let matches = regex.matches(in: result, options: [], range: nsRange).reversed()
        
        for match in matches {
            guard match.numberOfRanges >= 2,
                  let fullRange = Range(match.range, in: result),
                  let wordsRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            
            let words = String(result[wordsRange])
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            let transformed = CaseTransformer.transform(words, to: command.caseType)
            result.replaceSubrange(fullRange, with: transformed)
        }
        
        return result
    }
    
    /// Processes an alternative command form
    private func processAlternativeCommand(_ alternative: String, caseType: CaseTransformer.CaseType, in text: String) -> String {
        let pattern = "(?i)\\b\(NSRegularExpression.escapedPattern(for: alternative))\\s+(.+?)(?=\\s*(?:\(VoiceCommand.allCases.map { NSRegularExpression.escapedPattern(for: $0.rawValue) }.joined(separator: "|"))|[.!?,;:]|$)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        var result = text
        let nsRange = NSRange(result.startIndex..., in: result)
        
        let matches = regex.matches(in: result, options: [], range: nsRange).reversed()
        
        for match in matches {
            guard match.numberOfRanges >= 2,
                  let fullRange = Range(match.range, in: result),
                  let wordsRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            
            let words = String(result[wordsRange])
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            let transformed = CaseTransformer.transform(words, to: caseType)
            result.replaceSubrange(fullRange, with: transformed)
        }
        
        return result
    }
    
    // MARK: - CLI Commands
    
    /// Formats CLI commands in the text
    /// - Parameter text: The input text
    /// - Returns: Text with CLI commands properly formatted
    func formatCLICommands(_ text: String) -> String {
        return CLIPatternMatcher.matchWithBoundaries(text)
    }
    
    // MARK: - Code Patterns
    
    /// Applies code-specific patterns and symbol replacements
    /// - Parameter text: The input text
    /// - Returns: Text with code patterns applied
    func applyCodePatterns(_ text: String) -> String {
        return CodePatterns.applySymbols(text)
    }
    
    // MARK: - Utility Methods
    
    /// Checks if the text contains any syntax transformation triggers
    /// - Parameter text: The text to check
    /// - Returns: True if transformations would be applied
    func containsTransformationTriggers(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Check for case commands
        for command in VoiceCommand.allCases {
            if lowercased.contains(command.rawValue) {
                return true
            }
            for alternative in command.alternatives {
                if lowercased.contains(alternative) {
                    return true
                }
            }
        }
        
        // Check for CLI patterns
        if CLIPatternMatcher.containsCLIPatterns(text) {
            return true
        }
        
        // Check for code patterns
        if CodePatterns.containsCodePatterns(text) {
            return true
        }
        
        return false
    }
    
    /// Gets a preview of what transformations would be applied
    /// - Parameter text: The input text
    /// - Returns: Array of transformation descriptions
    func getTransformationPreview(_ text: String) -> [String] {
        var previews: [String] = []
        let lowercased = text.lowercased()
        
        for command in VoiceCommand.allCases {
            if lowercased.contains(command.rawValue) {
                previews.append("Case: \(command.rawValue) → \(command.caseType.rawValue)")
            }
        }
        
        if CLIPatternMatcher.containsCLIPatterns(text) {
            previews.append("CLI: Command patterns detected")
        }
        
        if CodePatterns.containsCodePatterns(text) {
            previews.append("Code: Symbol patterns detected")
        }
        
        return previews
    }
}
