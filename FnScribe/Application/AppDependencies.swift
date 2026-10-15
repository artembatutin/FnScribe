//
//  AppDependencies.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AppKit
import Combine

@MainActor
class AppDependencies {
    static let shared = AppDependencies()
    
    let settingsStore: SettingsStore
    let permissionsManager: PermissionsManager
    let appState: AppState
    let audioEngine: AudioEngine
    let audioFeedbackManager: AudioFeedbackManager
    let modelManager: ModelManager
    let speechRecognizer: SpeechRecognizer
    let textInjector: TextInjector
    let adapterRegistry: AdapterRegistry
    let textInjectionService: TextInjectionService
    let inputFieldDetector: InputFieldDetector
    let hotkeyManager: HotkeyManager
    let overlayWindowController: OverlayWindowController
    let sessionManager: SessionManager
    let dictionaryManager: DictionaryManager
    let correctionLearner: CorrectionLearner
    let syntaxTransformer: SyntaxTransformer
    let workspaceScanner: WorkspaceScanner
    let fileTagger: FileTagger
    let snippetManager: SnippetManager
    let streamingTranscriber: StreamingTranscriber
    let analyticsManager: AnalyticsManager
    let taskManager: TaskManager
    let taskCaptureService: TaskCaptureService
    private var cancellables = Set<AnyCancellable>()
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    
    /// The target application to inject text into (captured when recording starts)
    private var targetApp: NSRunningApplication?
    private var activeRecordingID: UUID?
    private var isProcessingCapture = false
    private var dictationActivity: NSObjectProtocol?

    private static func shouldEnableCodeSymbols(
        settingsStore: SettingsStore,
        adapterRegistry: AdapterRegistry,
        bundleId: String?
    ) -> Bool {
        switch settingsStore.codeSymbolsMode {
        case .off:
            return false
        case .always:
            return true
        case .contextual:
            guard let bundleId else { return false }
            let adapter = adapterRegistry.getAdapter(for: bundleId)
            return adapter is IDEAdapter || adapter is TerminalAdapter || adapter is ClaudeCodeAdapter
        }
    }

    private func shouldEnableCodeSymbols(for bundleId: String?) -> Bool {
        Self.shouldEnableCodeSymbols(
            settingsStore: settingsStore,
            adapterRegistry: adapterRegistry,
            bundleId: bundleId
        )
    }
    
    private init() {
        self.settingsStore = SettingsStore()
        self.permissionsManager = PermissionsManager()
        self.appState = AppState()
        
        // Configure audio engine with settings
        var audioConfig = AudioEngineConfiguration()
        audioConfig.maxRecordingDuration = settingsStore.maxRecordingDuration
        self.audioEngine = AudioEngine(configuration: audioConfig)
        
        self.audioFeedbackManager = AudioFeedbackManager()
        self.audioFeedbackManager.isEnabled = settingsStore.playFeedbackSounds
        
        // Initialize model manager and speech recognizer
        self.modelManager = ModelManager()
        self.speechRecognizer = SpeechRecognizer()
        
        // Initialize text injection with adapter registry
        self.textInjector = TextInjector()
        self.adapterRegistry = AdapterRegistry()
        self.inputFieldDetector = InputFieldDetector()
        self.textInjectionService = TextInjectionService(
            textInjector: textInjector,
            settingsStore: settingsStore,
            permissionsManager: permissionsManager,
            adapterRegistry: adapterRegistry,
            inputFieldDetector: inputFieldDetector
        )
        
        // Initialize hotkey manager
        self.hotkeyManager = HotkeyManager(settingsStore: settingsStore)
        
        // Initialize overlay window controller
        self.overlayWindowController = OverlayWindowController(
            appState: appState,
            settingsStore: settingsStore
        )
        
        // Initialize session manager
        self.sessionManager = SessionManager(settingsStore: settingsStore)
        
        // Initialize dictionary system
        self.dictionaryManager = DictionaryManager()
        self.correctionLearner = CorrectionLearner()
        self.correctionLearner.dictionaryManager = dictionaryManager
        
        // Initialize syntax transformer
        self.syntaxTransformer = SyntaxTransformer()
        self.syntaxTransformer.caseTransformationsEnabled = settingsStore.caseTransformationsEnabled
        self.syntaxTransformer.cliPatternsEnabled = settingsStore.cliPatternsEnabled
        self.syntaxTransformer.codeSymbolsEnabled = Self.shouldEnableCodeSymbols(
            settingsStore: settingsStore,
            adapterRegistry: adapterRegistry,
            bundleId: nil
        )
        
        // Initialize file tagging system
        self.workspaceScanner = WorkspaceScanner()
        self.fileTagger = FileTagger(workspaceScanner: workspaceScanner)
        self.fileTagger.isEnabled = settingsStore.fileTaggingEnabled
        
        // Initialize snippet manager
        self.snippetManager = SnippetManager()
        
        // Initialize streaming transcriber
        self.streamingTranscriber = StreamingTranscriber()
        
        // Initialize analytics manager
        self.analyticsManager = AnalyticsManager()

        // Initialize task system
        self.taskManager = TaskManager()
        self.taskCaptureService = TaskCaptureService(taskManager: taskManager)
        
        // Set initial model selection from settings
        modelManager.selectModel(byName: settingsStore.selectedModel)
        
        guard !isRunningTests else { return }

        // Set up audio engine callbacks
        setupAudioEngineCallbacks()
        
        // Set up hotkey callbacks
        setupHotkeyCallbacks()
        
        // Set up streaming transcriber with overlay
        overlayWindowController.setStreamingTranscriber(streamingTranscriber)
        
        // Set up audio engine streaming delegate
        setupStreamingDelegate()
    }
    
    private func setupStreamingDelegate() {
        // Create adapter to bridge AudioEngine with StreamingTranscriber
        let adapter = AudioStreamDelegateAdapter(transcriber: streamingTranscriber)
        audioEngine.streamDelegate = adapter
        
        // Store adapter to prevent deallocation
        streamDelegateAdapter = adapter
    }
    
    private var streamDelegateAdapter: AudioStreamDelegateAdapter?
    
    private func setupAudioEngineCallbacks() {
        // Mirror audio level changes into app state for UI bindings
        audioEngine.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.appState.audioLevel = level
            }
            .store(in: &cancellables)

        // Handle auto-stop events
        audioEngine.onAutoStop = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.audioEngine.isRecording {
                    await self.stopRecordingAndTranscribe()
                }
            }
        }
    }
    
    func loadSelectedModel() async {
        let modelName = settingsStore.selectedModel
        guard let model = modelManager.model(forName: modelName),
              let modelPath = modelManager.getModelPath(for: model) else {
            speechRecognizer.unloadModel()
            appState.isModelLoaded = false
            return
        }
        appState.isModelLoaded = false
        if !speechRecognizer.isLoading {
            do {
                try await speechRecognizer.loadModel(name: modelName, modelPath: modelPath)
                appState.isModelLoaded = true
            } catch {
                appState.isModelLoaded = false
                appState.setError(error.localizedDescription)
            }
        }
    }
    
    private func setupHotkeyCallbacks() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.startRecording()
            }
        }
        
        hotkeyManager.onHotkeyReleased = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.stopRecordingAndTranscribe()
            }
        }
        
    }
    
    private func startRecording() {
        guard !audioEngine.isRecording, !isProcessingCapture else {
            if isProcessingCapture {
                appState.setProcessing()
            }
            return
        }

        guard permissionsManager.microphoneGranted else {
            appState.setError("Microphone permission not granted")
            return
        }
        
        guard appState.isModelLoaded else {
            appState.setError("No model loaded. Please load a model first.")
            return
        }
        
        // Capture the target app BEFORE we start recording
        // This is the app that will receive the transcribed text
        targetApp = textInjector.getFrontmostApp()
        let recordingID = UUID()
        activeRecordingID = recordingID
        
        // Scan workspace if file tagging is enabled and we're in an IDE
        if settingsStore.fileTaggingEnabled && settingsStore.autoScanWorkspace {
            if let bundleId = targetApp?.bundleIdentifier,
               adapterRegistry.getAdapter(for: bundleId).displayName == "IDE" {
                Task {
                    await workspaceScanner.scanFromFrontmostIDE()
                }
            }
        }
        
        do {
            // Menu-bar apps can otherwise enter App Nap as soon as capture stops,
            // delaying inference/injection until the next interaction with the UI.
            dictationActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiated,
                reason: "Recording and transcribing dictation"
            )
            try audioEngine.startRecording()
            appState.setListening()
            audioFeedbackManager.playStartSound()
            sessionManager.startSession()
            
            // Start streaming transcription if enabled
            if settingsStore.streamingTranscriptionEnabled {
                Task {
                    await startStreamingTranscription(for: recordingID)
                }
            }
        } catch {
            activeRecordingID = nil
            endDictationActivity()
            appState.setError("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func startStreamingTranscription(for recordingID: UUID) async {
        guard activeRecordingID == recordingID, audioEngine.isRecording else { return }

        // Ensure WhisperKit is available for streaming
        if let whisperKit = speechRecognizer.whisperKit {
            streamingTranscriber.setWhisperKit(whisperKit)
            do {
                try await streamingTranscriber.startStreaming()
                if activeRecordingID != recordingID || !audioEngine.isRecording {
                    _ = await streamingTranscriber.stopStreaming(shouldProcessFinalChunk: false)
                }
            } catch {
                // Silently fail - streaming is optional enhancement
            }
        }
    }
    
    private func stopRecordingAndTranscribe() async {
        guard audioEngine.isRecording else { return }
        let recordingID = activeRecordingID
        let captureTargetApp = targetApp
        activeRecordingID = nil
        isProcessingCapture = true
        defer {
            isProcessingCapture = false
            endDictationActivity()
        }
        
        do {
            let audioBuffer = try audioEngine.stopRecording()
            appState.setProcessing()
            audioFeedbackManager.playStopSound()

            // Stop the live preview after the microphone is cut. The final
            // transcription below already processes the full captured buffer.
            _ = await streamingTranscriber.stopStreaming(shouldProcessFinalChunk: false)

            guard recordingID != nil else {
                setIdleIfNotRecording()
                return
            }
            
            if let buffer = audioBuffer {
                let result = try await speechRecognizer.transcribe(audioBuffer: buffer)
                var transcription = result.text
                
                // Apply personal dictionary replacements if enabled
                if settingsStore.dictionaryEnabled {
                    transcription = dictionaryManager.applyDictionary(to: transcription)
                }

                if taskCaptureService.isTaskCommand(transcription) {
                    try await handleTaskCapture(transcription, targetApp: captureTargetApp)
                } else {
                    try await handleDictationCapture(transcription, targetApp: captureTargetApp)
                }
            }
            
            setIdleIfNotRecording()
        } catch let error as TaskCaptureError {
            appState.setError(error.localizedDescription)
            setIdleIfNotRecording()
        } catch {
            appState.setError("Transcription failed: \(error.localizedDescription)")
            setIdleIfNotRecording()
        }
    }

    private func setIdleIfNotRecording() {
        guard !audioEngine.isRecording else { return }
        appState.setIdle()
    }

    private func endDictationActivity() {
        guard let dictationActivity else { return }
        ProcessInfo.processInfo.endActivity(dictationActivity)
        self.dictationActivity = nil
    }

    private func handleTaskCapture(_ transcription: String, targetApp: NSRunningApplication?) async throws {
        let task = try taskCaptureService.createTask(from: transcription)
        appState.updateTranscription(task.title)

        sessionManager.endSession(
            transcription: task.title,
            modelUsed: settingsStore.selectedModel,
            targetApp: targetApp?.localizedName,
            captureKind: .task,
            linkedTaskID: task.id
        )
    }

    private func handleDictationCapture(_ transcription: String, targetApp: NSRunningApplication?) async throws {
        var finalText = transcription

        if settingsStore.syntaxTransformEnabled {
            syntaxTransformer.caseTransformationsEnabled = settingsStore.caseTransformationsEnabled
            syntaxTransformer.cliPatternsEnabled = settingsStore.cliPatternsEnabled
            syntaxTransformer.codeSymbolsEnabled = shouldEnableCodeSymbols(for: targetApp?.bundleIdentifier)
            finalText = syntaxTransformer.transform(finalText)
        }

        if settingsStore.fileTaggingEnabled {
            fileTagger.isEnabled = true
            finalText = fileTagger.processFileMentions(finalText)
        }

        if settingsStore.snippetsEnabled {
            let bundleId = targetApp?.bundleIdentifier
            finalText = snippetManager.processText(finalText, bundleId: bundleId)
        }

        appState.updateTranscription(finalText)

        guard !finalText.isEmpty else { return }

        let session = TranscriptionSession(
            transcription: finalText,
            targetApp: targetApp?.localizedName,
            duration: Date().timeIntervalSince(sessionManager.currentSessionStartTime ?? Date()),
            modelUsed: settingsStore.selectedModel,
            captureKind: .dictation
        )

        // Keep the transcript available from the menu even if the target app
        // cannot accept the automatic paste.
        sessionManager.endSession(
            transcription: finalText,
            modelUsed: settingsStore.selectedModel,
            targetApp: targetApp?.localizedName,
            captureKind: .dictation
        )
        analyticsManager.recordSession(session)

        if settingsStore.autoInject {
            if let target = targetApp {
                textInjector.activateApp(target)
                try await Task.sleep(nanoseconds: 100_000_000)
            }

            if inputFieldDetector.autoFocusEnabled {
                let focusSuccess = await inputFieldDetector.scanAndFocus()
                try await Task.sleep(nanoseconds: focusSuccess ? 150_000_000 : 50_000_000)
            }

            try await textInjectionService.inject(text: finalText)

            if settingsStore.autoLearnCorrections {
                correctionLearner.recordInjection(finalText)
            }
        }
    }
    
    func startHotkeyListening() {
        guard permissionsManager.inputMonitoringGranted || permissionsManager.accessibilityGranted else {
            return
        }
        hotkeyManager.startListening()
    }
    
    func stopHotkeyListening() {
        hotkeyManager.stopListening()
    }
}
