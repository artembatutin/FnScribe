import XCTest
import FluidAudio
import AVFoundation

@MainActor
final class ParakeetSupportTests: XCTestCase {
    func testModelIdentitiesKeepWhisperSelectionsCompatible() throws {
        XCTAssertEqual(SpeechModel.model(forName: "base.en")?.id, "openai_whisper-base.en")
        XCTAssertEqual(SpeechModel.model(forName: "base.en")?.backend, .whisperKit)
        XCTAssertEqual(SpeechModel.model(forName: "parakeet-tdt-0.6b-v3")?.backend, .parakeetV3)
        XCTAssertEqual(SpeechModel.model(forName: "parakeet-ultra")?.backend, .parakeetUltra)
        XCTAssertNil(SpeechModel.repositoryModel(forId: "FluidInference/parakeet-ultra-coreml"))
        let community = try XCTUnwrap(SpeechModel.repositoryModel(forId: "distil-whisper_distil-large-v3"))
        XCTAssertEqual(community.backend, .whisperKit)
    }

    func testParakeetCachePathsMatchRuntimeRepositoryFolders() throws {
        let storage = temporaryDirectory()
        let v3 = try XCTUnwrap(SpeechModel.model(forName: "parakeet-tdt-0.6b-v3"))
        let ultra = try XCTUnwrap(SpeechModel.model(forName: "parakeet-ultra"))
        XCTAssertEqual(v3.parakeetDirectory(in: storage).lastPathComponent, Repo.parakeetV3.folderName)
        XCTAssertEqual(ultra.parakeetDirectory(in: storage).lastPathComponent, Repo.parakeetUltra.folderName)
    }

    func testIncompleteParakeetDownloadIsNotUsableAndVersionsStaySeparate() throws {
        let storage = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: storage) }
        let v3 = try XCTUnwrap(SpeechModel.model(forName: "parakeet-tdt-0.6b-v3"))
        let ultra = try XCTUnwrap(SpeechModel.model(forName: "parakeet-ultra"))
        XCTAssertNotEqual(v3.parakeetDirectory(in: storage), ultra.parakeetDirectory(in: storage))
        try stageModel(v3, in: storage, includeVocabulary: false)
        XCTAssertNil(v3.completeParakeetPath(in: storage))
        let vocabulary = Dictionary(uniqueKeysWithValues: (0..<8192).map { (String($0), "token") })
        let vocabularyURL = v3.parakeetDirectory(in: storage).appendingPathComponent("parakeet_vocab.json")
        try JSONSerialization.data(withJSONObject: vocabulary).write(to: vocabularyURL)
        XCTAssertEqual(v3.completeParakeetPath(in: storage), v3.parakeetDirectory(in: storage))
        XCTAssertNil(ultra.completeParakeetPath(in: storage))
        try FileManager.default.removeItem(at: v3.parakeetDirectory(in: storage).appendingPathComponent("Encoder.mlmodelc/weights/weight.bin"))
        XCTAssertNil(v3.completeParakeetPath(in: storage))
    }

    func testOfflineCatalogKeepsParakeetAndDeletingOneVariantKeepsTheOther() async throws {
        #if !arch(arm64)
        throw XCTSkip("Parakeet requires Apple Silicon")
        #endif
        let storage = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: storage) }
        for model in SpeechModel.parakeetModels { try stageModel(model, in: storage) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineCatalogProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let manager = ModelManager(storageDirectory: storage, catalogSession: session)
        await manager.refreshCatalog()
        XCTAssertNotNil(manager.catalogError)
        XCTAssertEqual(manager.availableModels.count, 2)
        let v3 = try XCTUnwrap(manager.model(forName: "parakeet-tdt-0.6b-v3"))
        let ultra = try XCTUnwrap(manager.model(forName: "parakeet-ultra"))
        XCTAssertTrue(manager.isModelDownloaded(v3))
        manager.selectModel(ultra)
        try manager.deleteModel(ultra)
        XCTAssertNil(manager.selectedModelName)
        XCTAssertNil(manager.getModelPath(for: ultra))
        XCTAssertNotNil(manager.getModelPath(for: v3))
        XCTAssertFalse(manager.isModelDownloaded(ultra))
        XCTAssertTrue(manager.isModelDownloaded(v3))
    }

    func testStreamingUsesSelectedBackendForFinalAudio() async throws {
        let backend = RecordingBackend()
        let streaming = StreamingTranscriber()
        streaming.setBackend(backend)
        try await streaming.startStreaming()
        streaming.appendAudio(Array(repeating: 0.2, count: 16000))
        let text = await streaming.stopStreaming()
        XCTAssertEqual(text, "bonjour tout le monde")
        XCTAssertEqual(backend.sampleCounts, [16000])
        XCTAssertEqual(backend.previewRequests, [false])
        XCTAssertFalse(streaming.isStreaming)
        XCTAssertEqual(streaming.streamingText, "")
    }

    func testStoppingPreviewDoesNotDecodeFinalRecordingTwice() async throws {
        let backend = RecordingBackend()
        let streaming = StreamingTranscriber()
        streaming.setBackend(backend)
        try await streaming.startStreaming()
        streaming.appendAudio(Array(repeating: 0.2, count: 16000))
        _ = await streaming.stopStreaming(shouldProcessFinalChunk: false)
        XCTAssertTrue(backend.sampleCounts.isEmpty)
    }

    /// Opt-in hardware check. Supply a WAV/AIFF with speech and a cache directory;
    /// the normal suite stays offline and never downloads model weights.
    func testParakeetModelsEndToEnd() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let audioPath = environment["FNSCRIBE_TEST_AUDIO"],
              let cachePath = environment["FNSCRIBE_TEST_MODEL_CACHE"] else {
            throw XCTSkip("Set FNSCRIBE_TEST_AUDIO and FNSCRIBE_TEST_MODEL_CACHE to run the model integration check")
        }
        let samples = try AudioConverter().resampleAudioFile(URL(fileURLWithPath: audioPath))
        let storage = URL(fileURLWithPath: cachePath, isDirectory: true)
        let manager = ModelManager(storageDirectory: storage)
        for model in SpeechModel.supportedParakeetModels {
            if !manager.isModelDownloaded(model) { try await manager.downloadModel(model) }
            let path = try XCTUnwrap(manager.getModelPath(for: model))
            try await verifyOfflineTranscription(model: model, path: path, samples: samples)
        }
    }

    private func verifyOfflineTranscription(model: SpeechModel, path: String, samples: [Float]) async throws {
        let wasOffline = ModelHub.offlineMode
        ModelHub.offlineMode = true
        defer { ModelHub.offlineMode = wasOffline }
        let version = try XCTUnwrap(model.backend.parakeetVersion)
        let models = try await Task.detached {
            try AsrModels.loadLocal(from: URL(fileURLWithPath: path), version: version)
        }.value
        let recognizer = AsrManager(config: .default)
        try await recognizer.loadModels(models)
        let backend = SpeechRecognitionBackend.parakeet(recognizer)
        let result = try await backend.transcribe(audioData: samples, options: .default, isPreview: false)
        XCTAssertGreaterThan(result.text.split(separator: " ").count, 3, model.name)
        XCTAssertNil(result.language, "Do not label automatically detected speech as English")
        print("\(model.displayName): \(result.text)")
        let streaming = StreamingTranscriber()
        streaming.setBackend(backend)
        try await streaming.startStreaming()
        streaming.appendAudio(Array(samples.prefix(64000)))
        try await Task.sleep(nanoseconds: 3_000_000_000)
        XCTAssertFalse(streaming.streamingText.isEmpty, "\(model.name) live preview")
        _ = await streaming.stopStreaming(shouldProcessFinalChunk: false)
    }

    private func stageModel(_ model: SpeechModel, in storage: URL, includeVocabulary: Bool = true) throws {
        let directory = model.parakeetDirectory(in: storage)
        for component in ["Preprocessor", "Encoder", "Decoder", "JointDecisionv3"] {
            for name in ["coremldata.bin", "model.mil", "weights/weight.bin"] {
                let path = directory.appendingPathComponent("\(component).mlmodelc/\(name)")
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data([1]).write(to: path)
            }
        }
        if includeVocabulary {
            let vocabulary = Dictionary(uniqueKeysWithValues: (0..<8192).map { (String($0), "token") })
            try JSONSerialization.data(withJSONObject: vocabulary).write(to: directory.appendingPathComponent("parakeet_vocab.json"))
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private final class OfflineCatalogProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}

@MainActor
private final class RecordingBackend: SpeechTranscribing {
    var sampleCounts: [Int] = []
    var previewRequests: [Bool] = []
    func transcribe(audioData: [Float], options: TranscriptionOptions, isPreview: Bool) async throws -> TranscriptionResult {
        sampleCounts.append(audioData.count)
        previewRequests.append(isPreview)
        return TranscriptionResult(text: "bonjour tout le monde", language: nil, duration: 0.1, segments: [])
    }
}
