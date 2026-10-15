import Foundation
import WhisperKit
import FluidAudio

extension SpeechModel.Backend {
    var parakeetVersion: AsrModelVersion? {
        switch self {
        case .whisperKit: return nil
        case .parakeetV3: return .v3
        case .parakeetUltra: return .ultra
        }
    }
}

@MainActor
enum SpeechRecognitionBackend: SpeechTranscribing {
    case whisper(WhisperKit)
    case parakeet(AsrManager)

    func transcribe(audioData: [Float], options: TranscriptionOptions, isPreview: Bool) async throws -> TranscriptionResult {
        let started = Date()
        switch self {
        case .whisper(let kit):
            var decoding = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: options.language,
                withoutTimestamps: options.withoutTimestamps,
                wordTimestamps: options.wordTimestamps,
                suppressBlank: options.suppressBlank
            )
            if isPreview {
                decoding.temperatureFallbackCount = 0
                decoding.sampleLength = 128
            }
            let results = try await kit.transcribe(audioArray: audioData, decodeOptions: decoding)
            let segments = results.flatMap(\.segments).compactMap { segment -> TranscriptionResult.TranscriptionSegment? in
                let text = TranscriptionSanitizer.sanitize(segment.text)
                guard !text.isEmpty else { return nil }
                return .init(text: text, start: TimeInterval(segment.start), end: TimeInterval(segment.end))
            }
            return TranscriptionResult(
                text: TranscriptionSanitizer.sanitize(results.map(\.text).joined(separator: " ")),
                language: results.first?.language,
                duration: Date().timeIntervalSince(started),
                segments: segments
            )
        case .parakeet(let manager):
            // Each preview window and final recording starts with fresh decoder state.
            // Leave the language hint unset: Parakeet detects its 25 supported languages.
            var decoderState = try TdtDecoderState()
            let result = try await manager.transcribe(audioData, decoderState: &decoderState)
            let text = TranscriptionSanitizer.sanitize(result.text)
            return TranscriptionResult(
                text: text,
                language: nil,
                duration: Date().timeIntervalSince(started),
                segments: text.isEmpty ? [] : [.init(text: text, start: 0, end: Double(audioData.count) / 16000)]
            )
        }
    }
}
