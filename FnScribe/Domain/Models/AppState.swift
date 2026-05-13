//
//  AppState.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine

enum RecordingState: Equatable {
    case idle
    case listening
    case processing
    case error(String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var iconName: String {
        switch self {
        case .idle:
            return "mic.circle"
        case .listening:
            return "mic.circle.fill"
        case .processing:
            return "ellipsis.circle"
        case .error:
            return "exclamationmark.circle"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .listening, .processing:
            return true
        case .idle, .error:
            return false
        }
    }
}

@MainActor
class AppState: ObservableObject {
    
    @Published var recordingState: RecordingState = .idle
    @Published var lastTranscription: String?
    @Published var audioLevel: Float = 0.0
    @Published var isModelLoaded: Bool = false
    @Published var modelLoadingProgress: Double = 0.0
    
    func setListening() {
        recordingState = .listening
    }
    
    func setProcessing() {
        recordingState = .processing
    }
    
    func setIdle() {
        recordingState = .idle
        audioLevel = 0.0
    }
    
    func setError(_ message: String) {
        recordingState = .error(message)
    }
    
    func updateTranscription(_ text: String) {
        lastTranscription = text
    }
    
    func updateAudioLevel(_ level: Float) {
        audioLevel = level
    }
}
