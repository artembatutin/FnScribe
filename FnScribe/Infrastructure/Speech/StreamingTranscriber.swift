//
//  StreamingTranscriber.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AVFoundation
import Combine
import WhisperKit

/// Delegate protocol for receiving streaming audio samples
protocol AudioStreamDelegate: AnyObject {
    func audioEngine(_ engine: Any, didCaptureSamples samples: [Float])
}

/// Handles real-time streaming transcription using WhisperKit
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
    
    private var whisperKit: WhisperKit?
    private var audioBuffer: [Float] = []
    private var processingTask: Task<Void, Never>?
    private var chunkProcessingTask: Task<Void, Never>?
    
    private let chunkDuration: TimeInterval = 1.0
    private let sampleRate: Double = 16000.0
    private var lastProcessedIndex: Int = 0
    private var isProcessingChunk: Bool = false
    private var streamingStartTime: Date?
    
    private let minAudioLengthForProcessing: Int = 8000
    private let overlapSamples: Int = 3200
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Set the WhisperKit instance to use for transcription
    func setWhisperKit(_ whisperKit: WhisperKit?) {
        self.whisperKit = whisperKit
    }
    
    /// Start streaming transcription
    func startStreaming() async throws {
        guard whisperKit != nil else {
            throw SpeechRecognizerError.modelNotLoaded
        }
        
        guard !isStreaming else { return }
        
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
    func stopStreaming() async -> String {
        guard isStreaming else { return streamingState.displayText }
        
        isStreaming = false
        chunkProcessingTask?.cancel()
        chunkProcessingTask = nil
        
        if !audioBuffer.isEmpty && audioBuffer.count > minAudioLengthForProcessing {
            await processFinalChunk()
        }
        
        let finalText = streamingState.finalize()
        
        audioBuffer.removeAll()
        lastProcessedIndex = 0
        confirmedText = ""
        pendingText = ""
        streamingText = ""
        
        return finalText
    }
    
    /// Cancel streaming without finalizing
    func cancelStreaming() {
        isStreaming = false
        chunkProcessingTask?.cancel()
        chunkProcessingTask = nil
        processingTask?.cancel()
        processingTask = nil
        
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
                
                guard self.isStreaming else { break }
                
                await self.processChunk()
            }
        }
    }
    
    private func processChunk() async {
        guard !isProcessingChunk else { return }
        guard audioBuffer.count > minAudioLengthForProcessing else { return }
        guard let whisperKit = whisperKit else { return }
        
        isProcessingChunk = true
        defer { isProcessingChunk = false }
        
        let startIndex = max(0, lastProcessedIndex - overlapSamples)
        let endIndex = audioBuffer.count
        
        guard endIndex > startIndex else { return }
        
        let chunkAudio = Array(audioBuffer[startIndex..<endIndex])
        
        do {
            let decodingOptions = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: "en",
                withoutTimestamps: true,
                wordTimestamps: false,
                suppressBlank: true
            )
            
            let results = try await whisperKit.transcribe(
                audioArray: chunkAudio,
                decodeOptions: decodingOptions
            )
            
            let newText = TranscriptionSanitizer.sanitize(
                results.map { $0.text }.joined(separator: " ")
            )
            
            await MainActor.run {
                self.updateStreamingText(newText)
            }
            
            lastProcessedIndex = endIndex
            
        } catch {
            // Silently handle transcription errors during streaming
        }
    }
    
    private func processFinalChunk() async {
        guard let whisperKit = whisperKit else { return }
        guard audioBuffer.count > minAudioLengthForProcessing else { return }
        
        do {
            let decodingOptions = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: "en",
                withoutTimestamps: true,
                wordTimestamps: false,
                suppressBlank: true
            )
            
            let results = try await whisperKit.transcribe(
                audioArray: audioBuffer,
                decodeOptions: decodingOptions
            )
            
            let finalText = TranscriptionSanitizer.sanitize(
                results.map { $0.text }.joined(separator: " ")
            )
            
            streamingState.confirmedText = finalText
            streamingState.pendingText = ""
            confirmedText = finalText
            pendingText = ""
            streamingText = finalText
            
        } catch {
            streamingState.confirm(pendingText)
            confirmedText = streamingState.confirmedText
            pendingText = ""
        }
    }
    
    private func updateStreamingText(_ newText: String) {
        guard !newText.isEmpty else { return }
        
        let (confirmed, pending) = mergeTranscription(newText, with: confirmedText)
        
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
    
    private func mergeTranscription(_ new: String, with existing: String) -> (confirmed: String, pending: String) {
        guard !existing.isEmpty else {
            return ("", new)
        }
        
        let existingWords = existing.split(separator: " ").map(String.init)
        let newWords = new.split(separator: " ").map(String.init)
        
        guard !newWords.isEmpty else {
            return (existing, "")
        }
        
        var overlapStart = -1
        let searchWindow = min(5, existingWords.count)
        
        for i in max(0, existingWords.count - searchWindow)..<existingWords.count {
            let existingWord = existingWords[i].lowercased()
            if let firstNewWord = newWords.first?.lowercased(),
               existingWord == firstNewWord || levenshteinDistance(existingWord, firstNewWord) <= 2 {
                overlapStart = i
                break
            }
        }
        
        if overlapStart >= 0 {
            let confirmedPart = existingWords[0..<overlapStart].joined(separator: " ")
            let pendingPart = newWords.joined(separator: " ")
            return (confirmedPart.isEmpty ? "" : confirmedPart + " ", pendingPart)
        }
        
        let confirmedPart = existing
        let pendingPart = newWords.suffix(max(1, newWords.count - existingWords.count)).joined(separator: " ")
        
        if pendingPart.isEmpty {
            return (confirmedPart, "")
        }
        
        return (confirmedPart, pendingPart)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[m][n]
    }
}
