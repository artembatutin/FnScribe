import XCTest
import AVFoundation

@MainActor
final class TranscriptionAndAnalyticsTests: XCTestCase {
    func testCaptureOwnsSamplesBeforeTapBufferIsReused() throws {
        let queue = AudioCaptureQueue()
        let buffer = try makeAudioBuffer(samples: [0.1, 0.2, 0.3, 0.4])
        XCTAssertTrue(queue.appendCopy(of: buffer))
        buffer.floatChannelData![0][0] = 0.9
        let captured = try XCTUnwrap(queue.drain().first)
        XCTAssertEqual(captured.floatChannelData![0][0], 0.1)
        XCTAssertEqual(captured.frameLength, 4)
        XCTAssertTrue(queue.drain().isEmpty)
    }

    func testStoppingDrainsTailWithoutWaitingForMainActorDelivery() throws {
        let queue = AudioCaptureQueue()
        XCTAssertTrue(queue.appendCopy(of: try makeAudioBuffer(samples: [1, 2])))
        XCTAssertFalse(queue.appendCopy(of: try makeAudioBuffer(samples: [3, 4])))
        queue.close()
        XCTAssertFalse(queue.appendCopy(of: try makeAudioBuffer(samples: [5, 6])))
        let samples = queue.drain().flatMap { buffer in
            Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        }
        XCTAssertEqual(samples, [1, 2, 3, 4])
        XCTAssertTrue(queue.drain().isEmpty)
        let nextSession = AudioCaptureQueue()
        XCTAssertTrue(nextSession.appendCopy(of: try makeAudioBuffer(samples: [7])))
        XCTAssertTrue(queue.drain().isEmpty)
    }

    func testCaptureSchedulesAnotherDrainAfterPreviousBatch() throws {
        let queue = AudioCaptureQueue()
        XCTAssertTrue(queue.appendCopy(of: try makeAudioBuffer(samples: [1])))
        _ = queue.drain()
        XCTAssertTrue(queue.appendCopy(of: try makeAudioBuffer(samples: [2])))
        let captured = try XCTUnwrap(queue.drain().first)
        XCTAssertEqual(captured.floatChannelData![0][0], 2)
    }

    func testResamplingDoesNotReplayInputToFillOutput() throws {
        let input = try makeAudioBuffer(samples: Array(repeating: 0.25, count: 48000), rate: 48000)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let converter = try XCTUnwrap(AVAudioConverter(from: input.format, to: format))
        let output = try XCTUnwrap(AudioBufferConverter.convert(input, using: converter, to: format))
        XCTAssertEqual(output.format.sampleRate, 16000)
        XCTAssertGreaterThan(output.frameLength, 15900)
        XCTAssertLessThanOrEqual(output.frameLength, 16000)
        XCTAssertEqual(output.floatChannelData![0][100], 0.25, accuracy: 0.001)

        // Flush the converter to expose any input it buffered internally. Feeding
        // the same input repeatedly can look correct in the first output buffer.
        let tail = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000))
        var conversionError: NSError?
        let status = converter.convert(to: tail, error: &conversionError) { _, state in
            state.pointee = .endOfStream
            return nil
        }
        XCTAssertNotEqual(status, .error)
        XCTAssertNil(conversionError)
        XCTAssertEqual(Double(output.frameLength + tail.frameLength), 16000, accuracy: 1)
    }

    func testStreamingPreviewKeepsEarlierPhrasesAndRemovesOverlap() {
        let first = StreamingTranscript.merge("open the settings", after: "")
        let second = StreamingTranscript.merge("the settings and select audio", after: first.confirmed + first.pending)
        let third = StreamingTranscript.merge("audio then save", after: second.confirmed + second.pending)
        XCTAssertEqual(third.confirmed + third.pending, "open the settings and select audio then save")
    }

    func testStreamingPreviewDoesNotEraseSimilarUnrelatedWords() {
        let result = StreamingTranscript.merge("can run faster", after: "the cat")
        XCTAssertEqual(result.confirmed + result.pending, "the cat can run faster")
        let normalized = StreamingTranscript.merge("Audio is ready", after: "select audio.")
        XCTAssertEqual(normalized.confirmed + normalized.pending, "select Audio is ready")
    }

    private func makeAudioBuffer(samples: [Float], rate: Double = 16000) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (index, sample) in samples.enumerated() { buffer.floatChannelData![0][index] = sample }
        return buffer
    }

    func testModelDetectionUsesExactFolderAndCompleteFiles() throws {
        let storage = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storage) }
        let modelFolder = storage
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml", isDirectory: true)
            .appendingPathComponent("openai_whisper-base.en", isDirectory: true)
        try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)

        let englishID = "openai_whisper-base.en"
        let multilingualID = "openai_whisper-base"
        XCTAssertNil(AppSupportPaths.completeModelPath(id: englishID, name: "base.en", in: storage))
        XCTAssertNil(AppSupportPaths.completeModelPath(id: multilingualID, name: "base", in: storage))

        for name in ["MelSpectrogram", "AudioEncoder", "TextDecoder"] {
            try FileManager.default.createDirectory(
                at: modelFolder.appendingPathComponent("\(name).mlmodelc"),
                withIntermediateDirectories: true
            )
        }
        XCTAssertEqual(
            AppSupportPaths.completeModelPath(id: englishID, name: "base.en", in: storage),
            modelFolder
        )
        XCTAssertNil(AppSupportPaths.completeModelPath(id: multilingualID, name: "base", in: storage))
    }

    func testTranscriptionSanitizerRemovesBracketedNonSpeechArtifacts() {
        XCTAssertEqual(
            TranscriptionSanitizer.sanitize("hello [ silence ] world [ laugh ]"),
            "hello world"
        )
        XCTAssertEqual(
            TranscriptionSanitizer.sanitize("[ background noise ] [ cough ]"),
            ""
        )
    }

    func testTranscriptionSanitizerPreservesNormalBracketedText() {
        XCTAssertEqual(
            TranscriptionSanitizer.sanitize("please keep [TODO] in the draft"),
            "please keep [TODO] in the draft"
        )
    }

    func testLegacyAndTypedTranscriptionSessionsDecode() throws {
        let json = """
        [
          {
            "id": "11111111-1111-1111-1111-111111111111",
            "timestamp": "2026-04-22T12:00:00Z",
            "transcription": "legacy session",
            "duration": 2.0,
            "modelUsed": "base.en",
            "wordCount": 2,
            "characterCount": 14
          },
          {
            "id": "22222222-2222-2222-2222-222222222222",
            "timestamp": "2026-04-22T12:05:00Z",
            "transcription": "typed task",
            "duration": 1.0,
            "modelUsed": "base.en",
            "captureKind": "task",
            "linkedTaskID": "33333333-3333-3333-3333-333333333333",
            "wordCount": 2,
            "characterCount": 10
          }
        ]
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let sessions = try decoder.decode([TranscriptionSession].self, from: Data(json.utf8))

        XCTAssertEqual(sessions[0].captureKind, .dictation)
        XCTAssertNil(sessions[0].linkedTaskID)
        XCTAssertEqual(sessions[1].captureKind, .task)
        XCTAssertEqual(sessions[1].linkedTaskID, UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
    }

    func testDecodedTranscriptionSessionCountersCannotBeNegative() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "timestamp": "2026-04-22T12:00:00Z",
          "transcription": "safe decoded session",
          "duration": 2.0,
          "modelUsed": "base.en",
          "wordCount": -12,
          "characterCount": -50
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let session = try decoder.decode(TranscriptionSession.self, from: Data(json.utf8))

        XCTAssertEqual(session.wordCount, 0)
        XCTAssertEqual(session.characterCount, 0)
    }

    func testAnalyticsIgnoreTaskSessions() throws {
        let analytics = AnalyticsManager(metricsFileURL: temporaryURL())

        analytics.recordSession(TranscriptionSession(
            transcription: "task capture",
            duration: 1.0,
            modelUsed: "base.en",
            captureKind: .task,
            linkedTaskID: UUID()
        ))

        XCTAssertEqual(analytics.metrics.totalSessions, 0)
        XCTAssertEqual(analytics.metrics.totalWords, 0)

        analytics.recordSession(TranscriptionSession(
            transcription: "dictation capture",
            duration: 1.0,
            modelUsed: "base.en",
            captureKind: .dictation
        ))

        XCTAssertEqual(analytics.metrics.totalSessions, 1)
        XCTAssertEqual(analytics.metrics.totalWords, 2)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("usage_metrics.json")
    }
}
