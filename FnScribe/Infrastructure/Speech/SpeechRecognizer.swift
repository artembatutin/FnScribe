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
import FluidAudio

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
    
    /// Shared by final dictation and the live preview.
    private(set) var backend: (any SpeechTranscribing)?
    private var transcriptionTask: Task<String, Error>?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Model Loading
    
    func loadModel(name: String, modelPath: String) async throws {
        guard !isLoading else { throw SpeechRecognizerError.alreadyLoading }
        if isModelLoaded && currentModelName == name { return }
        
        isLoading = true
        isModelLoaded = false
        currentModelName = nil
        backend = nil
        loadingProgress = 0.0
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let modelBackend = SpeechModel.model(forName: name)?.backend ?? .whisperKit
            if let version = modelBackend.parakeetVersion {
                let directory = URL(fileURLWithPath: modelPath, isDirectory: true)
                // Loading is strictly local and can take seconds; keep it off the UI actor.
                let models = try await Task.detached(priority: .userInitiated) {
                    try AsrModels.loadLocal(from: directory, version: version)
                }.value
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                backend = SpeechRecognitionBackend.parakeet(manager)
            } else {
                let config = WhisperKitConfig(
                    model: name,
                    downloadBase: try? AppSupportPaths.modelsDirectory(),
                    modelFolder: modelPath,
                    verbose: false,
                    prewarm: false,
                    load: true,
                    download: false
                )
                backend = SpeechRecognitionBackend.whisper(try await WhisperKit(config))
            }

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
        backend = nil
        isModelLoaded = false
        currentModelName = nil
        loadingProgress = 0.0
        error = nil
    }
    
    // MARK: - Transcription
    
    func transcribe(audioBuffer: AVAudioPCMBuffer, options: TranscriptionOptions = .default) async throws -> TranscriptionResult {
        guard audioBuffer.format.sampleRate == 16000, audioBuffer.format.channelCount == 1 else {
            throw SpeechRecognizerError.invalidAudioFormat
        }
        guard let samples = audioBuffer.toFloatArray() else { throw SpeechRecognizerError.invalidAudioFormat }
        return try await transcribe(audioData: samples, options: options)
    }

    /// Samples must be mono Float32 PCM at 16 kHz, matching AudioEngine's output.
    func transcribe(audioData: [Float], options: TranscriptionOptions = .default) async throws -> TranscriptionResult {
        guard isModelLoaded, let backend else { throw SpeechRecognizerError.modelNotLoaded }
        guard !isTranscribing else { throw SpeechRecognizerError.alreadyTranscribing }
        guard !audioData.isEmpty else { throw SpeechRecognizerError.noAudioData }
        isTranscribing = true
        error = nil
        defer { isTranscribing = false }
        do {
            let result = try await backend.transcribe(audioData: audioData, options: options, isPreview: false)
            lastTranscription = result.text
            return result
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
