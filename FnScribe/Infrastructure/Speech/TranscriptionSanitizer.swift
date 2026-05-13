//
//  TranscriptionSanitizer.swift
//  FnScribe
//
//  Created by Codex on 2026-04-22.
//

import Foundation

enum TranscriptionSanitizer {
    private static let artifactRegex = try! NSRegularExpression(
        pattern: #"\[\s*(?:BLANK(?:[_ -]+AUDIO)?|SILENCE|LAUGH(?:TER)?|BREATH(?:ING)?|COUGH(?:ING)?|SNEEZE|SNIFF(?:LE|ING)?|SIGH|GASP|APPLAUSE|MUSIC|NOISE|BACKGROUND(?:[_ -]+NOISE|[_ -]+SOUNDS?)|CLEAR(?:ING)?[_ -]+THROAT|THROAT[_ -]+CLEARING|INAUDIBLE|UNINTELLIGIBLE)\s*\]"#,
        options: [.caseInsensitive]
    )
    private static let punctuationSpacingRegex = try! NSRegularExpression(
        pattern: #"\s+([,.;:!?])"#,
        options: []
    )
    private static let whitespaceRegex = try! NSRegularExpression(
        pattern: #"\s+"#,
        options: []
    )
    private static let leadingPunctuationRegex = try! NSRegularExpression(
        pattern: #"^[,.;:!?]+\s*"#,
        options: []
    )
    
    static func sanitize(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        var sanitized = replacingMatches(in: text, using: artifactRegex, with: " ")
        sanitized = replacingMatches(in: sanitized, using: punctuationSpacingRegex, with: "$1")
        sanitized = replacingMatches(in: sanitized, using: whitespaceRegex, with: " ")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = replacingMatches(in: sanitized, using: leadingPunctuationRegex, with: "")
        
        if sanitized.unicodeScalars.allSatisfy({ CharacterSet.punctuationCharacters.contains($0) || CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return ""
        }
        
        return sanitized
    }
    
    private static func replacingMatches(
        in text: String,
        using regex: NSRegularExpression,
        with template: String
    ) -> String {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
