import XCTest

@MainActor
final class DictionaryAndRefinementTests: XCTestCase {
    func testDictionaryUsesLiteralLongestMatchesWithoutCascading() {
        let entries = [
            DictionaryEntry(spokenForm: "super", writtenForm: "great"),
            DictionaryEntry(spokenForm: "super base", writtenForm: "Supabase"),
            DictionaryEntry(spokenForm: "supabase", writtenForm: "Wrong cascade"),
            DictionaryEntry(spokenForm: "C++", writtenForm: "C plus plus"),
            DictionaryEntry(spokenForm: "dollar value", writtenForm: #"$value\path"#),
            DictionaryEntry(spokenForm: "dot net", writtenForm: ".NET")
        ]
        let result = DictionaryMatcher.apply("SUPER base, C++ and dollar value use dot net, not superhero.", entries: entries)
        XCTAssertEqual(result.text, #"Supabase, C plus plus and $value\path use .NET, not superhero."#)
        XCTAssertEqual(result.usedEntryIDs.count, 4)
    }

    func testDictionaryUnicodeBoundariesAndWhitespace() {
        let entries = [DictionaryEntry(spokenForm: "café", writtenForm: "Café"),
                       DictionaryEntry(spokenForm: "next js", writtenForm: "Next.js")]
        XCTAssertEqual(DictionaryMatcher.apply("caféteria café and next  js", entries: entries).text,
                       "caféteria Café and Next.js")
    }

    func testSuggestionsPersistAcceptIgnoreAndDoNotChangeTextWithoutApproval() async throws {
        let folder = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DictionaryStore(fileURL: folder.appendingPathComponent("dictionary.json"))
        let suggestions = VocabularySuggestionStore(fileURL: folder.appendingPathComponent("suggestions.json"))
        let detector = MockVocabularyDetector()
        detector.words = [VocabularySuggestion(word: "Kuberneties", alternatives: ["Kubernetes"], context: "deploy to Kuberneties", occurrences: 1, lastSeen: Date())]
        let manager = DictionaryManager(store: store, suggestionStore: suggestions, detector: detector)
        await manager.load()
        await manager.observeTranscript("deploy to Kuberneties")
        await manager.observeTranscript("deploy to Kuberneties")
        XCTAssertEqual(manager.suggestions.first?.occurrences, 2)
        XCTAssertEqual(manager.applyDictionary(to: "deploy to Kuberneties"), "deploy to Kuberneties")
        await manager.flush()
        let reloaded = DictionaryManager(store: DictionaryStore(fileURL: folder.appendingPathComponent("dictionary.json")),
                                         suggestionStore: suggestions, detector: detector)
        await reloaded.load()
        XCTAssertEqual(reloaded.suggestions.first?.occurrences, 2)
        let candidate = try XCTUnwrap(reloaded.suggestions.first)
        reloaded.acceptSuggestion(candidate, writtenForm: "Kubernetes")
        XCTAssertEqual(reloaded.applyDictionary(to: "deploy to Kuberneties"), "deploy to Kubernetes")
        XCTAssertTrue(reloaded.suggestions.isEmpty)
        await reloaded.flush()
        let saved = try await DictionaryStore(fileURL: folder.appendingPathComponent("dictionary.json")).load()
        XCTAssertEqual(saved.first?.writtenForm, "Kubernetes")
        XCTAssertEqual(saved.first?.useCount, 1)
        reloaded.ignoreSuggestion(candidate)
        await reloaded.flush()
        let ignoredState = try await suggestions.load()
        XCTAssertTrue(ignoredState.ignoredWords.contains(candidate.id))
    }

    func testCorrectionDetectionHandlesWordJoinsAndRejectsUnrelatedCopies() {
        let change = CorrectionDetector.detect(original: "please use super base for the new project", edited: "please use Supabase for the new project")
        XCTAssertEqual(change?.original, "super base")
        XCTAssertEqual(change?.corrected, "Supabase")
        XCTAssertNil(CorrectionDetector.detect(original: "please deploy the server now", edited: "please delete the server now"))
        XCTAssertNil(CorrectionDetector.detect(original: "hello brave world here", edited: "unrelated copied text here"))
        XCTAssertNil(CorrectionDetector.detect(original: "send 10 dollars to them", edited: "send 20 dollars to them"))
    }

    func testCapitalizationCorrectionsLearnTechnicalSpellingsOnly() {
        let technical = CorrectionDetector.detect(original: "please use javascript for this project", edited: "please use JavaScript for this project")
        XCTAssertEqual(technical?.corrected, "JavaScript")
        XCTAssertNil(CorrectionDetector.detect(original: "hello this is a sentence", edited: "Hello this is a sentence"))
    }

    func testNativeRefinementLayerWorksWithCurrentSystemAvailability() async {
        let refiner = SentenceRefiner()
        let result = await refiner.refine("I has a server that would can toggled in settings.", enabled: true)
        XCTAssertTrue(result.contains("have"))
        XCTAssertFalse(result.contains("would can"))
        XCTAssertNotNil(refiner.lastStatus)
    }

    func testBrokenDictionaryFileIsPreservedWhenLoadingFails() async throws {
        let folder = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent("dictionary.json")
        let malformed = Data("not a dictionary".utf8)
        try malformed.write(to: path)
        let manager = DictionaryManager(store: DictionaryStore(fileURL: path),
            suggestionStore: VocabularySuggestionStore(fileURL: folder.appendingPathComponent("suggestions.json")),
            detector: MockVocabularyDetector())
        await manager.load()
        XCTAssertFalse(manager.isLoaded)
        XCTAssertNotNil(manager.lastError)
        manager.addEntry(spokenForm: "example", writtenForm: "Example")
        await manager.observeTranscript("example")
        await manager.flush()
        XCTAssertEqual(try Data(contentsOf: path), malformed)
    }

    func testDisabledRefinementIsExactAndNeverCallsEitherEngine() async {
        let grammar = MockGrammarCorrector()
        let rewrite = MockSentenceRewriter()
        let refiner = SentenceRefiner(grammar: grammar, rewriter: rewrite)
        let original = "  i has a broken sentence\n"
        let result = await refiner.refine(original, enabled: false)
        XCTAssertEqual(result, original)
        XCTAssertEqual(grammar.calls, 0)
        XCTAssertEqual(rewrite.calls, 0)
    }

    func testRefinementUsesGrammarWhenAppleIntelligenceIsUnavailable() async {
        let grammar = MockGrammarCorrector()
        grammar.result = "I have a broken sentence."
        let rewrite = MockSentenceRewriter()
        rewrite.unavailableReason = "Apple Intelligence is off."
        let refiner = SentenceRefiner(grammar: grammar, rewriter: rewrite)
        let result = await refiner.refine("I has a broken sentence.", enabled: true)
        XCTAssertEqual(result, "I have a broken sentence.")
        XCTAssertEqual(rewrite.calls, 0)
    }

    func testRefinementRewritesBrokenSentenceAndFallsBackOnFailure() async {
        let grammar = MockGrammarCorrector()
        let rewrite = MockSentenceRewriter()
        rewrite.result = "The dictionary can be toggled in settings."
        let refiner = SentenceRefiner(grammar: grammar, rewriter: rewrite)
        let result = await refiner.refine("The dictionary that would can toggled in settings.", enabled: true)
        XCTAssertEqual(result, rewrite.result)
        rewrite.shouldFail = true
        let original = "I have a message to send."
        let fallback = await refiner.refine(original, enabled: true)
        XCTAssertEqual(fallback, original)
    }

    func testRewritingCannotChangeNamesNumbersCodeOrNegation() {
        let original = "Do not send Artem 12 files from AppDelegate.swift at https://example.com."
        XCTAssertFalse(SentenceRefinementPolicy.accepts(original.replacingOccurrences(of: "12", with: "20"), original: original, protectedTerms: ["Artem"]))
        XCTAssertFalse(SentenceRefinementPolicy.accepts(original.replacingOccurrences(of: "not ", with: ""), original: original, protectedTerms: ["Artem"]))
        XCTAssertFalse(SentenceRefinementPolicy.accepts(original.replacingOccurrences(of: "Artem", with: "Adam"), original: original, protectedTerms: ["Artem"]))
        XCTAssertFalse(SentenceRefinementPolicy.accepts(original.replacingOccurrences(of: "AppDelegate.swift", with: "App.swift"), original: original, protectedTerms: ["Artem"]))
        XCTAssertFalse(SentenceRefinementPolicy.accepts("", original: original, protectedTerms: []))
        XCTAssertFalse(SentenceRefinementPolicy.accepts("Send it.", original: "Don’t send it.", protectedTerms: []))
    }

    func testUnsafeModelOutputKeepsGrammarResult() async {
        let grammar = MockGrammarCorrector()
        grammar.result = "I have 12 messages for Artem."
        let rewrite = MockSentenceRewriter()
        rewrite.result = "I have 20 messages for Adam."
        let result = await SentenceRefiner(grammar: grammar, rewriter: rewrite).refine("I has 12 messages for Artem.", enabled: true, protectedTerms: ["Artem"])
        XCTAssertEqual(result, grammar.result)
    }

    func testRewriteTimeoutFallsBackWithoutHoldingDictation() async {
        let rewrite = MockSentenceRewriter()
        rewrite.delay = 1_000_000_000
        let original = "This is already a sentence."
        let result = await SentenceRefiner(grammar: MockGrammarCorrector(), rewriter: rewrite,
                                          timeoutNanoseconds: 5_000_000).refine(original, enabled: true)
        XCTAssertEqual(result, original)
    }

    func testSystemGrammarCorrectsAgreementDisfluencyAndKeepsTechnicalTerms() {
        let grammar = SystemGrammarCorrector()
        XCTAssertEqual(grammar.correct("I has a problem and we is ready.", protectedTerms: []), "I have a problem and we are ready.")
        XCTAssertEqual(grammar.correct("I I need the the server that would can toggled.", protectedTerms: []), "I need the server that could be toggled.")
        XCTAssertEqual(grammar.correct("I has code `i is` and AppDelegate.swift.", protectedTerms: []), "I have code `i is` and AppDelegate.swift.")
        XCTAssertEqual(grammar.correct("I has a project named I Has.", protectedTerms: ["I Has"]), "I has a project named I Has.")
    }

    func testDictionaryAndNativeRefinementWorkTogetherWithToggleOffBypass() async throws {
        let folder = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let manager = DictionaryManager(store: DictionaryStore(fileURL: folder.appendingPathComponent("dictionary.json")),
            suggestionStore: VocabularySuggestionStore(fileURL: folder.appendingPathComponent("suggestions.json")))
        await manager.load()
        manager.addEntry(spokenForm: "super base", writtenForm: "Supabase")
        let raw = "I has a super base project that would can toggled in settings."
        await manager.observeTranscript(raw, language: "en")
        let substituted = manager.applyDictionary(to: raw)
        let refiner = SentenceRefiner()
        let refined = await refiner.refine(substituted, enabled: true, protectedTerms: manager.protectedTerms(in: substituted))
        XCTAssertTrue(refined.contains("I have"))
        XCTAssertTrue(refined.contains("Supabase"))
        XCTAssertTrue(refined.contains("could be toggled"))
        let bypassed = await refiner.refine(substituted, enabled: false, protectedTerms: manager.protectedTerms(in: substituted))
        XCTAssertEqual(bypassed, substituted)
        await manager.flush()
    }

    func testNativeUnusualWordDetectionUsesSpellingAndSkipsKnownTermsAndURLs() {
        let detector = UnusualWordDetector()
        let detected = detector.detect(in: "We deploy to Kuberneties and open https://quuxproject.test/config.", language: "en", knownTerms: [])
        XCTAssertTrue(detected.contains { $0.word == "Kuberneties" })
        XCTAssertFalse(detected.contains { $0.word.contains("quux") })
        let known = detector.detect(in: "We deploy to Kuberneties today.", language: "en", knownTerms: ["Kuberneties"])
        XCTAssertFalse(known.contains { $0.word == "Kuberneties" })
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("dictionary-test-\(UUID().uuidString)")
    }
}

@MainActor
private final class MockVocabularyDetector: VocabularyDetecting {
    var words: [VocabularySuggestion] = []
    func detect(in text: String, language: String?, knownTerms: [String]) -> [VocabularySuggestion] {
        words.filter { candidate in !knownTerms.contains(where: { DictionaryMatcher.key($0) == candidate.id }) }
    }
}

@MainActor
private final class MockGrammarCorrector: GrammarCorrecting {
    var result: String?
    var calls = 0
    func correct(_ text: String, protectedTerms: [String]) -> String { calls += 1; return result ?? text }
}

@MainActor
private final class MockSentenceRewriter: SentenceRewriting {
    var unavailableReason: String?
    var result = ""
    var calls = 0
    var shouldFail = false
    var delay: UInt64 = 0
    func rewrite(_ text: String, protectedTerms: [String]) async throws -> String {
        calls += 1
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        if shouldFail { throw NSError(domain: "TestRewrite", code: 1) }
        return result
    }
}
