//
//  AudioStreamDelegateAdapter.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

/// Adapter that bridges AudioEngine with StreamingTranscriber
/// Forwards audio samples from the audio engine to the streaming transcriber
@MainActor
class AudioStreamDelegateAdapter: AudioStreamDelegate {
    
    private weak var transcriber: StreamingTranscriber?
    
    init(transcriber: StreamingTranscriber) {
        self.transcriber = transcriber
    }
    
    func audioEngine(_ engine: Any, didCaptureSamples samples: [Float]) {
        transcriber?.appendAudio(samples)
    }
}
