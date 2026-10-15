import Foundation

actor VocabularySuggestionStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? (try? AppSupportPaths.fileURL("dictionary_suggestions.json")) ??
            FileManager.default.temporaryDirectory.appendingPathComponent("fnscribe-dictionary-suggestions.json")
    }

    func load() throws -> VocabularySuggestionState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .init() }
        return try JSONDecoder().decode(VocabularySuggestionState.self, from: Data(contentsOf: fileURL))
    }

    func save(_ state: VocabularySuggestionState) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
    }
}
