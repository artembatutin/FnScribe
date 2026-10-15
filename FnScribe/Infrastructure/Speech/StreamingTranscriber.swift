//
//  StreamingTranscriber.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AVFoundation
import Combine

/// Delegate protocol for receiving streaming audio samples
@MainActor
protocol AudioStreamDelegate: AnyObject {
    func audioEngine(_ engine: Any, didCaptureSamples samples: [Float])
}

/// Handles real-time streaming transcription using the selected speech model
@MainActor
class StreamingTranscriber: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var streamingText: String = ""
    @Published private(set) var confirmedText: String = ""
    @Published private(set) var pendingText: String = ""
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var segments: [StreamSegment] = []
    @Published private(set) var streamingState: StreamingState = StreamingState()
    
    // MARK: - Private Properties
    
    private var backend: (any SpeechTranscribing)?
    private var audioBuffer: [Float] = []
    private var chunkProcessingTask: Task<Void, Never>?
    
    private let chunkDuration: TimeInterval = 1.0
    private var lastProcessedIndex: Int = 0
    private var isProcessingChunk: Bool = false
    private var streamingStartTime: Date?
    private var sessionID = UUID()
    private var isFinalizing = false
    
    private let minAudioLengthForProcessing: Int = 8000
    private let overlapSamples: Int = 3200
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Set the loaded backend to use for transcription.
    func setBackend(_ backend: (any SpeechTranscribing)?) {
        self.backend = backend
    }
    
    /// Start streaming transcription
    func startStreaming() async throws {
        guard backend != nil else {
            throw SpeechRecognizerError.modelNotLoaded
        }
        
        guard !isStreaming, !isFinalizing else { return }
        sessionID = UUID()
        
        audioBuffer.removeAll()
        lastProcessedIndex = 0
        isStreaming = true
        streamingState.start()
        streamingStartTime = Date()
        confirmedText = ""
        pendingText = ""
        streamingText = ""
        segments.removeAll()
        
        startChunkProcessing()
    }
    
    /// Stop streaming and return the final transcription
    func stopStreaming(shouldProcessFinalChunk: Bool = true) async -> String {
        guard isStreaming || chunkProcessingTask != nil else { return streamingState.displayText }
        
        guard !isFinalizing else { return streamingState.displayText }
        isFinalizing = true
        defer { isFinalizing = false }
        let stoppingSession = sessionID
        isStreaming = false
        let activeChunkTask = chunkProcessingTask
        activeChunkTask?.cancel()
        chunkProcessingTask = nil

        await activeChunkTask?.value
        guard sessionID == stoppingSession else { return "" }
        
        if shouldProcessFinalChunk && !audioBuffer.isEmpty && audioBuffer.count >= minAudioLengthForProcessing {
            await processFinalChunk()
        }
        
        guard sessionID == stoppingSession else { return "" }
        let finalText = streamingState.finalize()
        
        backend = nil
        audioBuffer.removeAll()
        lastProcessedIndex = 0
        confirmedText = ""
        pendingText = ""
        streamingText = ""
        
        return finalText
    }
    
    /// Cancel streaming without finalizing
    func cancelStreaming() {
        sessionID = UUID()
        isStreaming = false
        chunkProcessingTask?.cancel()
        chunkProcessingTask = nil
        backend = nil
        
        audioBuffer.removeAll()
        lastProcessedIndex = 0
        streamingState.reset()
        confirmedText = ""
        pendingText = ""
        streamingText = ""
        segments.removeAll()
    }
    
    /// Append audio samples to the buffer
    func appendAudio(_ samples: [Float]) {
        guard isStreaming else { return }
        audioBuffer.append(contentsOf: samples)
        
        if let startTime = streamingStartTime {
            streamingState.duration = Date().timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Private Methods
    
    private func startChunkProcessing() {
        chunkProcessingTask = Task { [weak self] in
            while let self = self, self.isStreaming {
                try? await Task.sleep(nanoseconds: UInt64(self.chunkDuration * 1_000_000_000))
                
                guard !Task.isCancelled, self.isStreaming else { break }
                
                await self.processChunk()
            }
        }
    }
    
    private func processChunk() async {
        guard !Task.isCancelled else { return }
        guard !isProcessingChunk else { return }
        guard audioBuffer.count - lastProcessedIndex >= minAudioLengthForProcessing else { return }
        guard let backend else { return }
        
        isProcessingChunk = true
        defer { isProcessingChunk = false }
        
        let processingSession = sessionID
        let startIndex = max(0, lastProcessedIndex - overlapSamples)
        let endIndex = audioBuffer.count
        
        guard endIndex > startIndex else { return }
        
        let chunkAudio = Array(audioBuffer[startIndex..<endIndex])
        
        do {
            let result = try await backend.transcribe(
                audioData: chunkAudio, options: .default, isPreview: true
            )

            guard !Task.isCancelled, sessionID == processingSession, isStreaming else { return }
            
            let newText = TranscriptionSanitizer.sanitize(
                result.text
            )
            
            updateStreamingText(newText)
            
            lastProcessedIndex = endIndex
            
        } catch {
            // Silently handle transcription errors during streaming
        }
    }
    
    private func processFinalChunk() async {
        guard let backend else { return }
        guard audioBuffer.count >= minAudioLengthForProcessing else { return }
        
        let finalizingSession = sessionID
        do {
            let result = try await backend.transcribe(
                audioData: audioBuffer, options: .default, isPreview: false
            )

            guard sessionID == finalizingSession else { return }
            let finalText = TranscriptionSanitizer.sanitize(
                result.text
            )
            
            streamingState.confirmedText = finalText
            streamingState.pendingText = ""
            confirmedText = finalText
            pendingText = ""
            streamingText = finalText
            
        } catch {
            guard sessionID == finalizingSession else { return }
            streamingState.confirm(pendingText)
            confirmedText = streamingState.confirmedText
            pendingText = ""
        }
    }
    
    private func updateStreamingText(_ newText: String) {
        guard !newText.isEmpty else { return }
        
        let (confirmed, pending) = StreamingTranscript.merge(newText, after: streamingText)
        
        confirmedText = confirmed
        pendingText = pending
        streamingText = confirmed + pending
        
        streamingState.confirmedText = confirmed
        streamingState.updatePending(pending, confidence: 0.8)
        
        let segment = StreamSegment(
            text: pending,
            confidence: 0.8,
            isConfirmed: false
        )
        
        if segments.last?.text != pending {
            segments.append(segment)
            if segments.count > 50 {
                segments.removeFirst(segments.count - 50)
            }
        }
    }
    
}
