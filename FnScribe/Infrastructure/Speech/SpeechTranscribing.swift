import Foundation

enum SpeechRecognizerError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case invalidAudioFormat
    case noAudioData
    case alreadyTranscribing
    case alreadyLoading

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Speech recognition model is not loaded"
        case .modelLoadFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "Invalid audio format for transcription"
        case .noAudioData:
            return "No audio data to transcribe"
        case .alreadyTranscribing:
            return "Transcription is already in progress"
        case .alreadyLoading:
            return "Another model is still loading"
        }
    }
}

struct TranscriptionOptions: Sendable {
    var language: String = "en"
    var task: String = "transcribe"
    var suppressBlank: Bool = true
    var withoutTimestamps: Bool = true
    var wordTimestamps: Bool = false

    nonisolated static let `default` = TranscriptionOptions()
}

struct TranscriptionResult: Sendable {
    let text: String
    let language: String?
    let duration: TimeInterval
    let segments: [TranscriptionSegment]

    struct TranscriptionSegment: Sendable {
        let text: String
        let start: TimeInterval
        let end: TimeInterval
    }
}

@MainActor
protocol SpeechTranscribing {
    func transcribe(audioData: [Float], options: TranscriptionOptions, isPreview: Bool) async throws -> TranscriptionResult
}
