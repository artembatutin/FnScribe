import AppKit
import NaturalLanguage

@MainActor
protocol GrammarCorrecting {
    func correct(_ text: String, protectedTerms: [String]) -> String
}

@MainActor
final class SystemGrammarCorrector: GrammarCorrecting {
    func correct(_ text: String, protectedTerms: [String]) -> String {
        guard !text.isEmpty else { return text }
        let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "en"
        let checker = NSSpellChecker.shared
        let document = NSSpellChecker.uniqueSpellDocumentTag()
        defer { checker.closeSpellDocument(withTag: document) }
        let original = text as NSString
        var replacements: [(NSRange, String)] = []
        var offset = 0
        while offset < original.length {
            var details: NSArray?
            let sentence = checker.checkGrammar(of: text, startingAt: offset, language: language,
                                                wrap: false, inSpellDocumentWithTag: document, details: &details)
            guard sentence.location != NSNotFound, sentence.length > 0 else { break }
            for detail in (details as? [[String: Any]]) ?? [] {
                guard let relative = detail[NSGrammarRange] as? NSValue,
                      let corrections = detail[NSGrammarCorrections] as? [String], corrections.count == 1 else { continue }
                let range = NSRange(location: sentence.location + relative.rangeValue.location, length: relative.rangeValue.length)
                guard NSMaxRange(range) <= original.length,
                      !SentenceRefinementPolicy.intersectsProtected(range, in: text, terms: protectedTerms),
                      !replacements.contains(where: { NSIntersectionRange($0.0, range).length > 0 }) else { continue }
                replacements.append((range, corrections[0]))
            }
            offset = NSMaxRange(sentence)
        }
        let output = NSMutableString(string: text)
        for (range, replacement) in replacements.sorted(by: { $0.0.location > $1.0.location }) {
            output.replaceCharacters(in: range, with: replacement)
        }
        var result = output as String
        if language == "en" {
            // The spelling service reports several agreement errors without supplying a
            // correction. These unambiguous local repairs also handle common ASR stutters.
            let rules: [(String, String)] = [
                (#"\b(I)\s+(?:has)\b"#, "$1 have"),
                (#"\b(I)\s+(?:is|are)\b"#, "$1 am"),
                (#"\b(you|we|they)\s+has\b"#, "$1 have"),
                (#"\b(you|we|they|these|those)\s+is\b"#, "$1 are"),
                (#"\b(he|she|it)\s+have\b"#, "$1 has"),
                (#"\b(he|she|it|this|that)\s+are\b"#, "$1 is"),
                (#"\bwould\s+can\b"#, "could"),
                (#"\b(can|could|should|would|will|must|may|might)\s+(enabled|disabled|toggled|added|removed|opened|closed|saved|updated|changed|done|written|sent)\b"#, "$1 be $2"),
                (#"\b(I|you|we|they|he|she|it|the|a|an|to|of|and|is|are|was|were|can|could|will|would|should)\s+\1\b"#, "$1"),
                (#"\bi\b"#, "I")
            ]
            for (pattern, template) in rules {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
                let source = result as NSString
                let mutable = NSMutableString(string: result)
                for match in regex.matches(in: result, range: NSRange(location: 0, length: source.length)).reversed() {
                    guard !SentenceRefinementPolicy.intersectsProtected(match.range, in: result, terms: protectedTerms) else { continue }
                    let replacement = regex.replacementString(for: match, in: result, offset: 0, template: template)
                    mutable.replaceCharacters(in: match.range, with: replacement)
                }
                result = mutable as String
            }
        }
        return result
    }
}
