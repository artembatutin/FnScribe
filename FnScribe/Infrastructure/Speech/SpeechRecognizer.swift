//
//  SpeechRecognizer.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AVFoundation
import Combine
import WhisperKit

enum SpeechRecognizerError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case invalidAudioFormat
    case noAudioData
    case alreadyTranscribing
    
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
        }
    }
}

struct TranscriptionOptions {
    var language: String = "en"
    var task: String = "transcribe"
    var suppressBlank: Bool = true
    var withoutTimestamps: Bool = true
    var wordTimestamps: Bool = false
    
    nonisolated static let `default` = TranscriptionOptions()
}

struct TranscriptionResult {
    let text: String
    let language: String?
    let duration: TimeInterval
    let segments: [TranscriptionSegment]
    
    struct TranscriptionSegment {
        let text: String
        let start: TimeInterval
        let end: TimeInterval
    }
}

@MainActor
class SpeechRecognizer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isModelLoaded: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isTranscribing: Bool = false
    @Published private(set) var loadingProgress: Double = 0.0
    @Published private(set) var lastTranscription: String?
    @Published private(set) var error: SpeechRecognizerError?
    @Published private(set) var currentModelName: String?
    
    // MARK: - Internal Properties
    
    /// The WhisperKit instance (exposed for streaming transcription)
    private(set) var whisperKit: WhisperKit?
    private var transcriptionTask: Task<String, Error>?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Model Loading
    
    func loadModel(name: String, modelPath: String? = nil) async throws {
        guard !isLoading else { return }
        
        isLoading = true
        loadingProgress = 0.0
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let modelStorageDirectory = (try? AppSupportPaths.modelsDirectory()) ??
                FileManager.default.temporaryDirectory.appendingPathComponent("FnScribeModels", isDirectory: true)
            
            let config = WhisperKitConfig(
                model: name,
                downloadBase: URL(fileURLWithPath: modelStorageDirectory.path),
                verbose: false,
                prewarm: true,
                load: true
            )
            
            whisperKit = try await WhisperKit(config)
            
            isModelLoaded = true
            currentModelName = name
            loadingProgress = 1.0
            
        } catch {
            self.error = .modelLoadFailed(error)
            isModelLoaded = false
            currentModelName = nil
            throw SpeechRecognizerError.modelLoadFailed(error)
        }
    }
    
    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
        currentModelName = nil
        loadingProgress = 0.0
    }
    
    // MARK: - Transcription
    
    func transcribe(audioBuffer: AVAudioPCMBuffer, options: TranscriptionOptions = .default) async throws -> TranscriptionResult {
        guard isModelLoaded, let whisperKit = whisperKit else {
            throw SpeechRecognizerError.modelNotLoaded
        }
        
        guard !isTranscribing else {
            throw SpeechRecognizerError.alreadyTranscribing
        }
        
        guard let audioData = audioBuffer.toFloatArray(), !audioData.isEmpty else {
            throw SpeechRecognizerError.noAudioData
        }
        
        isTranscribing = true
        error = nil
        
        defer {
            isTranscribing = false
        }
        
        let startTime = Date()
        
        do {
            let decodingOptions = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: options.language,
                withoutTimestamps: options.withoutTimestamps,
                wordTimestamps: options.wordTimestamps,
                suppressBlank: options.suppressBlank
            )
            
            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: decodingOptions
            )
            
            let transcribedText = TranscriptionSanitizer.sanitize(
                results.map { $0.text }.joined(separator: " ")
            )
            let duration = Date().timeIntervalSince(startTime)
            
            var segments: [TranscriptionResult.TranscriptionSegment] = []
            for result in results {
                for segment in result.segments {
                    let sanitizedSegmentText = TranscriptionSanitizer.sanitize(segment.text)
                    guard !sanitizedSegmentText.isEmpty else { continue }
                    
                    segments.append(TranscriptionResult.TranscriptionSegment(
                        text: sanitizedSegmentText,
                        start: TimeInterval(segment.start),
                        end: TimeInterval(segment.end)
                    ))
                }
            }
            
            lastTranscription = transcribedText
            
            return TranscriptionResult(
                text: transcribedText,
                language: results.first?.language,
                duration: duration,
                segments: segments
            )
            
        } catch {
            self.error = .transcriptionFailed(error)
            throw SpeechRecognizerError.transcriptionFailed(error)
        }
    }
    
    func transcribe(audioData: [Float], options: TranscriptionOptions = .default) async throws -> TranscriptionResult {
        guard isModelLoaded, let whisperKit = whisperKit else {
            throw SpeechRecognizerError.modelNotLoaded
        }
        
        guard !isTranscribing else {
            throw SpeechRecognizerError.alreadyTranscribing
        }
        
        guard !audioData.isEmpty else {
            throw SpeechRecognizerError.noAudioData
        }
        
        isTranscribing = true
        error = nil
        
        defer {
            isTranscribing = false
        }
        
        let startTime = Date()
        
        do {
            let decodingOptions = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: options.language,
                withoutTimestamps: options.withoutTimestamps,
                wordTimestamps: options.wordTimestamps,
                suppressBlank: options.suppressBlank
            )
            
            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: decodingOptions
            )
            
            let transcribedText = TranscriptionSanitizer.sanitize(
                results.map { $0.text }.joined(separator: " ")
            )
            let duration = Date().timeIntervalSince(startTime)
            
            var segments: [TranscriptionResult.TranscriptionSegment] = []
            for result in results {
                for segment in result.segments {
                    let sanitizedSegmentText = TranscriptionSanitizer.sanitize(segment.text)
                    guard !sanitizedSegmentText.isEmpty else { continue }
                    
                    segments.append(TranscriptionResult.TranscriptionSegment(
                        text: sanitizedSegmentText,
                        start: TimeInterval(segment.start),
                        end: TimeInterval(segment.end)
                    ))
                }
            }
            
            lastTranscription = transcribedText
            
            return TranscriptionResult(
                text: transcribedText,
                language: results.first?.language,
                duration: duration,
                segments: segments
            )
            
        } catch {
            self.error = .transcriptionFailed(error)
            throw SpeechRecognizerError.transcriptionFailed(error)
        }
    }
    
    func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        isTranscribing = false
    }
}
