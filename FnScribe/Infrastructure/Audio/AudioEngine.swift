//
//  AudioEngine.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AVFoundation
import Combine
import CoreAudio

enum AudioEngineError: LocalizedError {
    case permissionDenied
    case engineStartFailed(Error)
    case noInputNode
    case formatConversionFailed
    case recordingInProgress
    case notRecording
    case maxDurationReached
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .noInputNode:
            return "No audio input device available"
        case .formatConversionFailed:
            return "Failed to convert audio format"
        case .recordingInProgress:
            return "Recording is already in progress"
        case .notRecording:
            return "Not currently recording"
        case .maxDurationReached:
            return "Maximum recording duration reached"
        }
    }
}

/// Configuration for the audio engine
struct AudioEngineConfiguration {
    /// Sample rate for Whisper (16kHz)
    let sampleRate: Double = 16000.0
    /// Mono channel for Whisper
    let channelCount: AVAudioChannelCount = 1
    /// Maximum recording duration in seconds
    var maxRecordingDuration: TimeInterval = 120.0
    /// Enable silence detection
    var silenceDetectionEnabled: Bool = false
    /// Silence threshold (0.0 - 1.0)
    var silenceThreshold: Float = 0.01
    /// Duration of silence before auto-stop (seconds)
    var silenceDuration: TimeInterval = 2.0

    nonisolated init(
        maxRecordingDuration: TimeInterval = 120.0,
        silenceDetectionEnabled: Bool = false,
        silenceThreshold: Float = 0.01,
        silenceDuration: TimeInterval = 2.0
    ) {
        self.maxRecordingDuration = maxRecordingDuration
        self.silenceDetectionEnabled = silenceDetectionEnabled
        self.silenceThreshold = silenceThreshold
        self.silenceDuration = silenceDuration
    }
}

@MainActor
class AudioEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevel: Float = 0.0
    @Published private(set) var recordingDuration: TimeInterval = 0.0
    @Published private(set) var error: AudioEngineError?
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private var captureQueue: AudioCaptureQueue?
    private var drainCapturedAudio: (() -> Void)?
    private var restartTask: Task<Void, Never>?
    private var configuration: AudioEngineConfiguration
    
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var silenceStartTime: Date?
    
    private var levelUpdateTask: Task<Void, Never>?
    private var audioDeviceListener: AudioObjectPropertyListenerBlock?
    private var engineConfigurationObserver: NSObjectProtocol?
    private var isRestartingEngine: Bool = false
    
    // Callback for when max duration or silence auto-stop triggers
    var onAutoStop: (() -> Void)?
    
    // Delegate for streaming audio samples
    weak var streamDelegate: AudioStreamDelegate?
    
    // MARK: - Initialization
    
    init(configuration: AudioEngineConfiguration = AudioEngineConfiguration()) {
        self.configuration = configuration
        setupNotifications()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
    
    // MARK: - Public Methods
    
    /// Request microphone permission
    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    /// Start recording audio
    func startRecording() throws {
        guard !isRecording else {
            throw AudioEngineError.recordingInProgress
        }
        
        // Check permission
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .authorized else {
            throw AudioEngineError.permissionDenied
        }
        
        // Initialize engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        self.inputNode = inputNode
        
        // Get the native format and configure converter
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        
        guard nativeFormat.sampleRate > 0 else {
            throw AudioEngineError.noInputNode
        }
        
        // Target format for Whisper: 16kHz, mono, Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: configuration.sampleRate,
            channels: configuration.channelCount,
            interleaved: false
        ) else {
            throw AudioEngineError.formatConversionFailed
        }
        
        // Create format converter if needed
        let converter: AVAudioConverter?
        if nativeFormat.sampleRate != configuration.sampleRate || nativeFormat.channelCount != configuration.channelCount {
            guard let formatConverter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
                throw AudioEngineError.formatConversionFailed
            }
            converter = formatConverter
        } else {
            converter = nil
        }
        
        // Clear previous buffers
        audioBuffers.removeAll()
        error = nil
        
        installCaptureTap(on: inputNode, nativeFormat: nativeFormat,
                          converter: converter, targetFormat: targetFormat)

        // Prepare and start engine
        engine.prepare()
        
        do {
            try engine.start()
        } catch {
            cleanup()
            throw AudioEngineError.engineStartFailed(error)
        }
        
        // Update state
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0.0
        silenceStartTime = nil
        
        // Start duration timer
        startDurationTimer()
    }
    
    /// Stop recording and return accumulated audio buffer
    func stopRecording() throws -> AVAudioPCMBuffer? {
        guard isRecording else {
            throw AudioEngineError.notRecording
        }
        
        // Stop timer
        stopDurationTimer()
        
        // Remove tap and stop engine
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        // Include buffers captured before stop, even if their UI task has not run.
        finishCaptureTap()
        restartTask?.cancel()
        restartTask = nil
        isRestartingEngine = false

        // Update state
        isRecording = false
        audioLevel = 0.0
        
        // Combine all buffers into one
        let combinedBuffer = combineBuffers()
        
        // Cleanup
        audioBuffers.removeAll()
        audioEngine = nil
        inputNode = nil
        
        return combinedBuffer
    }
    
    /// Update configuration
    func updateConfiguration(_ config: AudioEngineConfiguration) {
        self.configuration = config
    }
    
    // MARK: - Private Methods
    
    private func installCaptureTap(on node: AVAudioInputNode, nativeFormat: AVAudioFormat,
                                   converter: AVAudioConverter?, targetFormat: AVAudioFormat) {
        let queue = AudioCaptureQueue()
        captureQueue = queue
        drainCapturedAudio = { [weak self] in
            guard let self else { return }
            for buffer in queue.drain() {
                self.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
            }
        }
        node.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, _ in
            // The tap owns `buffer` only for this callback. Copy before hopping actors.
            guard queue.appendCopy(of: buffer) else { return }
            Task { @MainActor [weak self] in
                guard let self, self.captureQueue === queue else { return }
                self.drainCapturedAudio?()
            }
        }
    }

    private func finishCaptureTap() {
        captureQueue?.close()
        drainCapturedAudio?()
        drainCapturedAudio = nil
        captureQueue = nil
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, targetFormat: AVAudioFormat) {
        guard isRecording else { return }
        
        guard let processedBuffer = AudioBufferConverter.convert(buffer, using: converter, to: targetFormat),
              processedBuffer.frameLength > 0 else { return }

        // Store buffer
        audioBuffers.append(processedBuffer)
        
        // Forward samples to stream delegate for real-time transcription
        if let samples = processedBuffer.toFloatArray() {
            streamDelegate?.audioEngine(self, didCaptureSamples: samples)
        }
        
        // Calculate audio level
        updateAudioLevel(from: processedBuffer)
        
        // Check silence detection
        if configuration.silenceDetectionEnabled {
            checkSilence()
        }
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0
        
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        // Convert to 0-1 range with some scaling for better visualization
        let normalizedLevel = min(1.0, rms * 5.0)
        
        // Smooth the level update
        audioLevel = audioLevel * 0.7 + normalizedLevel * 0.3
    }
    
    private func checkSilence() {
        if audioLevel < configuration.silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let start = silenceStartTime,
                      Date().timeIntervalSince(start) >= configuration.silenceDuration {
                // Auto-stop due to silence
                Task { @MainActor in
                    onAutoStop?()
                }
            }
        } else {
            silenceStartTime = nil
        }
    }
    
    private func startDurationTimer() {
        durationTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                
                self.recordingDuration = Date().timeIntervalSince(startTime)
                
                // Check max duration
                if self.recordingDuration >= self.configuration.maxRecordingDuration {
                    self.error = .maxDurationReached
                    self.onAutoStop?()
                }
            }
        }
        if let durationTimer { RunLoop.main.add(durationTimer, forMode: .common) }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    private func combineBuffers() -> AVAudioPCMBuffer? {
        guard !audioBuffers.isEmpty else { return nil }
        
        // Calculate total frame count
        let totalFrames = audioBuffers.reduce(0) { $0 + $1.frameLength }
        
        guard totalFrames > 0,
              let format = audioBuffers.first?.format,
              let combinedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            return nil
        }
        
        combinedBuffer.frameLength = totalFrames
        
        guard let destinationPointer = combinedBuffer.floatChannelData?[0] else {
            return nil
        }
        
        var offset: AVAudioFrameCount = 0
        
        for buffer in audioBuffers {
            guard let sourcePointer = buffer.floatChannelData?[0] else { continue }
            
            let frameCount = buffer.frameLength
            destinationPointer.advanced(by: Int(offset)).update(from: sourcePointer, count: Int(frameCount))
            offset += frameCount
        }
        
        return combinedBuffer
    }
    
    private func cleanup() {
        stopDurationTimer()
        levelUpdateTask?.cancel()
        restartTask?.cancel()
        restartTask = nil
        captureQueue?.close()
        captureQueue = nil
        drainCapturedAudio = nil
        removeCoreAudioDeviceListener()
        removeNotifications()
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        audioBuffers.removeAll()
        audioEngine = nil
        inputNode = nil
        isRecording = false
        audioLevel = 0.0
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        // On macOS, we listen for audio engine configuration changes
        // which occur when audio devices are connected/disconnected
        engineConfigurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let changedEngine = notification.object as? AVAudioEngine
            Task { @MainActor [weak self] in
                guard let self, changedEngine === self.audioEngine else { return }
                self.handleConfigurationChange()
            }
        }
        
        // Listen for default input device changes via CoreAudio
        setupCoreAudioDeviceListener()
    }
    
    private func handleConfigurationChange() {
        // Handle audio device changes - the engine configuration changed
        // Automatically restart with the new default input device
        if isRecording {
            restartRecordingWithNewDevice()
        }
    }
    
    private func handleDeviceChange() {
        // Handle audio device changes (e.g., microphone switched when docking/undocking)
        if isRecording {
            restartRecordingWithNewDevice()
        }
    }
    
    private func restartRecordingWithNewDevice() {
        guard isRecording, !isRestartingEngine else { return }
        isRestartingEngine = true
        
        // Tear down current engine but preserve recording state and collected buffers
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        
        finishCaptureTap()

        // Brief delay to let the system settle on the new audio device
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            guard !Task.isCancelled, let self, self.isRecording else { return }
            
            do {
                let engine = AVAudioEngine()
                self.audioEngine = engine
                
                let newInputNode = engine.inputNode
                self.inputNode = newInputNode
                
                let nativeFormat = newInputNode.outputFormat(forBus: 0)
                
                guard nativeFormat.sampleRate > 0 else {
                    throw AudioEngineError.noInputNode
                }
                
                guard let targetFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: self.configuration.sampleRate,
                    channels: self.configuration.channelCount,
                    interleaved: false
                ) else {
                    throw AudioEngineError.formatConversionFailed
                }
                
                let converter: AVAudioConverter?
                if nativeFormat.sampleRate != self.configuration.sampleRate || nativeFormat.channelCount != self.configuration.channelCount {
                    guard let formatConverter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
                        throw AudioEngineError.formatConversionFailed
                    }
                    converter = formatConverter
                } else {
                    converter = nil
                }
                
                self.installCaptureTap(on: newInputNode, nativeFormat: nativeFormat,
                                       converter: converter, targetFormat: targetFormat)

                engine.prepare()
                try engine.start()
                
                self.isRestartingEngine = false
                
            } catch {
                // Keep captured audio and recording state until the normal stop path
                // drains it and transcribes what was said before the device disappeared.
                self.error = .engineStartFailed(error)
                self.isRestartingEngine = false
                self.onAutoStop?()
            }
        }
    }
    
    private func setupCoreAudioDeviceListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleDeviceChange()
            }
        }
        audioDeviceListener = listener
        
        _ = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listener
        )
    }
    
    private func removeCoreAudioDeviceListener() {
        guard let listener = audioDeviceListener else { return }
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listener
        )
        audioDeviceListener = nil
    }

    private func removeNotifications() {
        guard let engineConfigurationObserver else { return }
        NotificationCenter.default.removeObserver(engineConfigurationObserver)
        self.engineConfigurationObserver = nil
    }
}

// MARK: - Audio Buffer Extension

extension AVAudioPCMBuffer {
    /// Convert buffer to Float array for Whisper processing
    func toFloatArray() -> [Float]? {
        guard let channelData = floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: channelData, count: Int(frameLength)))
    }
}
