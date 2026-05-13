//
//  CodePatterns.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

/// Handles code-specific symbol and pattern replacements
struct CodePatterns {
    
    /// Symbol mappings from spoken form to written form
    static let symbols: [String: String] = [
        // Comparison operators
        "equals": "=",
        "double equals": "==",
        "triple equals": "===",
        "not equals": "!=",
        "strict not equals": "!==",
        "greater than or equal": ">=",
        "less than or equal": "<=",
        "greater than": ">",
        "less than": "<",
        "spaceship": "<=>",
        
        // Arithmetic operators
        "plus": "+",
        "minus": "-",
        "asterisk": "*",
        "star": "*",
        "slash": "/",
        "forward slash": "/",
        "backslash": "\\",
        "modulo": "%",
        "percent": "%",
        "power": "**",
        "double star": "**",
        
        // Assignment operators
        "plus equals": "+=",
        "minus equals": "-=",
        "times equals": "*=",
        "divide equals": "/=",
        "modulo equals": "%=",
        
        // Logical operators
        "and": "&&",
        "double ampersand": "&&",
        "or": "||",
        "double pipe": "||",
        "not": "!",
        "bang": "!",
        "exclamation": "!",
        
        // Bitwise operators
        "bitwise and": "&",
        "ampersand": "&",
        "bitwise or": "|",
        "pipe": "|",
        "bitwise xor": "^",
        "caret": "^",
        "bitwise not": "~",
        "tilde": "~",
        "left shift": "<<",
        "right shift": ">>",
        
        // Arrow operators
        "arrow": "->",
        "fat arrow": "=>",
        "double arrow": "=>",
        "lambda": "=>",
        
        // Brackets and braces
        "open paren": "(",
        "close paren": ")",
        "left paren": "(",
        "right paren": ")",
        "open bracket": "[",
        "close bracket": "]",
        "left bracket": "[",
        "right bracket": "]",
        "open brace": "{",
        "close brace": "}",
        "left brace": "{",
        "right brace": "}",
        "open angle": "<",
        "close angle": ">",
        
        // Punctuation
        "semicolon": ";",
        "colon": ":",
        "double colon": "::",
        "comma": ",",
        "dot": ".",
        "period": ".",
        "ellipsis": "...",
        "spread": "...",
        "range": "..",
        "question mark": "?",
        "optional chaining": "?.",
        "null coalescing": "??",
        "double question": "??",
        
        // Special symbols
        "at sign": "@",
        "at": "@",
        "hash": "#",
        "hashtag": "#",
        "pound": "#",
        "dollar": "$",
        "dollar sign": "$",
        "underscore": "_",
        "backtick": "`",
        "grave": "`",
        "single quote": "'",
        "double quote": "\"",
        "quote": "\"",
        
        // String interpolation
        "string interpolation": "${",
        "template literal": "`",
        "interpolation start": "\\(",
        "interpolation end": ")",
        
        // Comments
        "line comment": "//",
        "double slash": "//",
        "block comment start": "/*",
        "block comment end": "*/",
        "doc comment": "///",
        "triple slash": "///",
        
        // Common code patterns
        "null": "null",
        "nil": "nil",
        "undefined": "undefined",
        "true": "true",
        "false": "false",
        "self": "self",
        "this": "this",
        "super": "super",
        "return": "return",
        "void": "void",
        "async": "async",
        "await": "await",
        "const": "const",
        "let": "let",
        "var": "var",
        "function": "function",
        "class": "class",
        "struct": "struct",
        "enum": "enum",
        "interface": "interface",
        "protocol": "protocol",
        "import": "import",
        "export": "export",
        "default": "default",
        "public": "public",
        "private": "private",
        "protected": "protected",
        "static": "static",
        "final": "final",
        "override": "override",
        "throws": "throws",
        "try": "try",
        "catch": "catch",
        "finally": "finally",
        "if": "if",
        "else": "else",
        "else if": "else if",
        "switch": "switch",
        "case": "case",
        "break": "break",
        "continue": "continue",
        "for": "for",
        "while": "while",
        "do": "do",
        "in": "in",
        "of": "of",
        "new": "new",
        "delete": "delete",
        "typeof": "typeof",
        "instanceof": "instanceof",
        "extends": "extends",
        "implements": "implements",
    ]
    
    /// Symbols sorted by key length (longest first) for greedy matching
    private static let sortedSymbols: [(key: String, value: String)] = {
        symbols.sorted { $0.key.count > $1.key.count }
    }()
    
    // MARK: - Symbol Application
    
    /// Applies symbol replacements to the given text
    /// - Parameter text: The input text with spoken symbols
    /// - Returns: Text with symbols replaced
    static func applySymbols(_ text: String) -> String {
        var result = text
        
        // Apply replacements in order (longest first)
        for (spoken, written) in sortedSymbols {
            // Use word boundary matching to avoid partial replacements
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: spoken))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: written
                )
            }
        }
        
        return result
    }
    
    /// Applies only operator symbols (not keywords)
    /// - Parameter text: The input text
    /// - Returns: Text with operator symbols replaced
    static func applyOperatorSymbols(_ text: String) -> String {
        let operatorSymbols = sortedSymbols.filter { (key, value) in
            // Filter to only include actual symbols, not keywords
            let symbolChars = CharacterSet(charactersIn: "=!<>+-*/%&|^~?.:;,()[]{}@#$_`'\"\\")
            return value.unicodeScalars.allSatisfy { symbolChars.contains($0) }
        }
        
        var result = text
        
        for (spoken, written) in operatorSymbols {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: spoken))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: written
                )
            }
        }
        
        return result
    }
    
    /// Checks if text contains any code pattern triggers
    /// - Parameter text: The text to check
    /// - Returns: True if code patterns are detected
    static func containsCodePatterns(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return symbols.keys.contains { lowercased.contains($0) }
    }
    
    /// Gets the symbol for a spoken phrase
    /// - Parameter spoken: The spoken phrase
    /// - Returns: The corresponding symbol, or nil if not found
    static func symbol(for spoken: String) -> String? {
        symbols[spoken.lowercased()]
    }
}
