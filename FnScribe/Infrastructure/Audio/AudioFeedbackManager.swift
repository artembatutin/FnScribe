//
//  AudioFeedbackManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AVFoundation
import AppKit
import Combine

/// Manages audio feedback sounds for recording start/stop
@MainActor
class AudioFeedbackManager: ObservableObject {
    
    // MARK: - Sound Types
    
    enum SoundType {
        case startRecording
        case stopRecording
        case error
        case success
        
        var systemSoundName: String {
            switch self {
            case .startRecording:
                return "Tink"
            case .stopRecording:
                return "Pop"
            case .error:
                return "Basso"
            case .success:
                return "Glass"
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var isEnabled: Bool = true
    
    private var soundPlayers: [SoundType: NSSound] = [:]
    
    // MARK: - Initialization
    
    init() {
        preloadSounds()
    }
    
    // MARK: - Public Methods
    
    /// Play a feedback sound
    func play(_ type: SoundType) {
        guard isEnabled else { return }
        
        if let sound = soundPlayers[type] {
            sound.stop()
            sound.play()
        } else {
            // Fallback to system sound
            NSSound(named: type.systemSoundName)?.play()
        }
    }
    
    /// Play start recording sound
    func playStartSound() {
        play(.startRecording)
    }
    
    /// Play stop recording sound
    func playStopSound() {
        play(.stopRecording)
    }
    
    /// Play error sound
    func playErrorSound() {
        play(.error)
    }
    
    /// Play success sound
    func playSuccessSound() {
        play(.success)
    }
    
    // MARK: - Private Methods
    
    private func preloadSounds() {
        for type in [SoundType.startRecording, .stopRecording, .error, .success] {
            if let sound = NSSound(named: type.systemSoundName) {
                soundPlayers[type] = sound
            }
        }
    }
}
