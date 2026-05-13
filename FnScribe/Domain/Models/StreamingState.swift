//
//  StreamingState.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

/// Represents a segment of streamed transcription text
struct StreamSegment: Identifiable, Equatable {
    let id: UUID
    let text: String
    let confidence: Double
    let isConfirmed: Bool
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        text: String,
        confidence: Double = 1.0,
        isConfirmed: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.isConfirmed = isConfirmed
        self.timestamp = timestamp
    }
}

/// Manages the state of streaming transcription
struct StreamingState: Equatable {
    
    /// The confirmed (finalized) text that won't change
    var confirmedText: String = ""
    
    /// The pending text that may still change as more audio is processed
    var pendingText: String = ""
    
    /// Confidence level of the current pending text (0.0 - 1.0)
    var confidence: Double = 1.0
    
    /// Total word count of confirmed + pending text
    var wordCount: Int = 0
    
    /// Duration of the streaming session
    var duration: TimeInterval = 0
    
    /// Whether streaming is currently active
    var isActive: Bool = false
    
    /// The complete display text (confirmed + pending)
    var displayText: String {
        confirmedText + pendingText
    }
    
    /// Confirm the pending text, moving it to confirmed
    mutating func confirm(_ text: String) {
        confirmedText += text
        pendingText = ""
        updateWordCount()
    }
    
    /// Update the pending text with new partial transcription
    mutating func updatePending(_ text: String, confidence: Double = 1.0) {
        self.pendingText = text
        self.confidence = confidence
        updateWordCount()
    }
    
    /// Finalize the streaming session and return the complete text
    mutating func finalize() -> String {
        let finalText = displayText
        reset()
        return finalText
    }
    
    /// Reset the streaming state
    mutating func reset() {
        confirmedText = ""
        pendingText = ""
        confidence = 1.0
        wordCount = 0
        duration = 0
        isActive = false
    }
    
    /// Start a new streaming session
    mutating func start() {
        reset()
        isActive = true
    }
    
    /// Stop the streaming session
    mutating func stop() {
        isActive = false
    }
    
    private mutating func updateWordCount() {
        let text = displayText
        wordCount = text.split(separator: " ").count
    }
}
