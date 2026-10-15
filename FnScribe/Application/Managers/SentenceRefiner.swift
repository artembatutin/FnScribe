import Foundation
import Combine

@MainActor
final class SentenceRefiner: ObservableObject {
    @Published private(set) var isRefining = false
    @Published private(set) var lastStatus: String?
    @Published private(set) var modelAvailability = ""
    private let grammar: any GrammarCorrecting
    private let rewriter: any SentenceRewriting
    private let timeoutNanoseconds: UInt64

    init(grammar: (any GrammarCorrecting)? = nil,
         rewriter: (any SentenceRewriting)? = nil, timeoutNanoseconds: UInt64 = 15_000_000_000) {
        self.grammar = grammar ?? SystemGrammarCorrector()
        self.rewriter = rewriter ?? AppleSentenceRewriter()
        self.timeoutNanoseconds = timeoutNanoseconds
        refreshAvailability()
    }

    func refreshAvailability() {
        modelAvailability = rewriter.unavailableReason.map { "macOS grammar correction is available. \($0)" }
            ?? "macOS grammar correction and Apple Intelligence rewriting are available. Text stays on this Mac."
    }

    func refine(_ text: String, enabled: Bool, protectedTerms: [String] = []) async -> String {
        guard enabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        isRefining = true
        defer { isRefining = false }
        refreshAvailability()
        let corrected = grammar.correct(text, protectedTerms: protectedTerms)
        let fallback = SentenceRefinementPolicy.accepts(corrected, original: text, protectedTerms: protectedTerms) ? corrected : text
        guard rewriter.unavailableReason == nil, text.count <= 6000 else {
            lastStatus = "Used macOS grammar correction."
            return fallback
        }
        do {
            let rewriter = self.rewriter
            let timeout = timeoutNanoseconds
            let candidate = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask { @MainActor in try await rewriter.rewrite(fallback, protectedTerms: protectedTerms) }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeout)
                    throw RefinementError.timedOut
                }
                defer { group.cancelAll() }
                return try await group.next() ?? fallback
            }.trimmingCharacters(in: .whitespacesAndNewlines)
            guard SentenceRefinementPolicy.accepts(candidate, original: text, protectedTerms: protectedTerms) else {
                lastStatus = "Kept macOS grammar correction because rewriting changed protected content."
                return fallback
            }
            lastStatus = "Used Apple Intelligence sentence refinement."
            return candidate
        } catch {
            lastStatus = "Used macOS grammar correction because sentence rewriting was unavailable."
            return fallback
        }
    }

    private enum RefinementError: Error { case timedOut }
}
