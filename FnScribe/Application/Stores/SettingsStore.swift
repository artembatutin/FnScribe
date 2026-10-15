//
//  SettingsStore.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine
import SwiftUI

enum CodeSymbolsMode: String, CaseIterable, Codable {
    case off = "off"
    case contextual = "contextual"
    case always = "always"
    
    var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .contextual:
            return "Contextual"
        case .always:
            return "Always"
        }
    }
    
    var description: String {
        switch self {
        case .off:
            return "Never convert words like 'and'/'not' into symbols"
        case .contextual:
            return "Only in code contexts (IDEs/terminals)"
        case .always:
            return "Always convert common operators (e.g. and -> &&, not -> !)"
        }
    }
}

enum InjectionMode: String, CaseIterable, Codable {
    case clipboardPaste = "clipboard"
    case keystrokeSimulation = "keystrokes"
    case hybrid = "hybrid"
    
    var displayName: String {
        switch self {
        case .clipboardPaste:
            return "Clipboard Paste"
        case .keystrokeSimulation:
            return "Keystroke Simulation"
        case .hybrid:
            return "Hybrid"
        }
    }
    
    var description: String {
        switch self {
        case .clipboardPaste:
            return "Fastest method, temporarily uses clipboard"
        case .keystrokeSimulation:
            return "Simulates typing, preserves clipboard"
        case .hybrid:
            return "Paste for long text, keystrokes for short"
        }
    }
}

enum TriggerMode: String, CaseIterable, Codable {
    case pushToTalk = "push"
    case toggle = "toggle"
    
    var displayName: String {
        switch self {
        case .pushToTalk:
            return "Push to Talk"
        case .toggle:
            return "Toggle"
        }
    }
    
    var description: String {
        switch self {
        case .pushToTalk:
            return "Hold key to record, release to transcribe"
        case .toggle:
            return "Press to start/stop recording"
        }
    }
}

@MainActor
class SettingsStore: ObservableObject {
    
    // MARK: - Hotkey Settings
    
    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 63 // Fn key
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0
    @AppStorage("triggerMode") private var triggerModeRaw: String = TriggerMode.pushToTalk.rawValue
    
    var triggerMode: TriggerMode {
        get { TriggerMode(rawValue: triggerModeRaw) ?? .pushToTalk }
        set { triggerModeRaw = newValue.rawValue }
    }
    
    // MARK: - Model Settings
    
    @AppStorage("selectedModel") var selectedModel: String = "base.en"
    @AppStorage("language") var language: String = "en"
    
    // MARK: - Injection Settings
    
    @AppStorage("autoInject") var autoInject: Bool = true
    @AppStorage("injectionModeRaw") private var injectionModeRaw: String = InjectionMode.clipboardPaste.rawValue
    @AppStorage("preserveClipboard") var preserveClipboard: Bool = true
    @AppStorage("typingDelay") var typingDelay: Double = 0.01
    
    var injectionMode: InjectionMode {
        get { InjectionMode(rawValue: injectionModeRaw) ?? .clipboardPaste }
        set { injectionModeRaw = newValue.rawValue }
    }
    
    // MARK: - Overlay Settings
    
    @AppStorage("showOverlay") var showOverlay: Bool = true
    @AppStorage("overlayPosition") var overlayPosition: String = OverlayPosition.nearNotch.rawValue
    @AppStorage("overlayOpacity") var overlayOpacity: Double = 0.9
    @AppStorage("overlaySize") var overlaySize: Double = 1.0 // Scale factor 0.8 - 1.5
    @AppStorage("overlayAutoHideDelay") var overlayAutoHideDelay: Double = 2.0 // seconds
    
    // MARK: - Audio Settings
    
    @AppStorage("playFeedbackSounds") var playFeedbackSounds: Bool = true
    @AppStorage("maxRecordingDuration") var maxRecordingDuration: Double = 120.0 // seconds
    
    // MARK: - History Settings
    
    @AppStorage("saveHistory") var saveHistory: Bool = true
    @AppStorage("maxHistoryItems") var maxHistoryItems: Int = 100
    
    // MARK: - Launch Settings
    
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    // MARK: - Dictionary Settings
    
    @AppStorage("dictionaryEnabled") var dictionaryEnabled: Bool = true
    @AppStorage("autoLearnCorrections") var autoLearnCorrections: Bool = true
    
    @AppStorage("detectUnusualWords") var detectUnusualWords: Bool = true
    @AppStorage("sentenceRefinementEnabled") var sentenceRefinementEnabled: Bool = false

    // MARK: - Syntax Transformation Settings
    
    @AppStorage("syntaxTransformEnabled") var syntaxTransformEnabled: Bool = true
    @AppStorage("caseTransformationsEnabled") var caseTransformationsEnabled: Bool = true
    @AppStorage("cliPatternsEnabled") var cliPatternsEnabled: Bool = true
    @AppStorage("codeSymbolsMode") private var codeSymbolsModeRaw: String = CodeSymbolsMode.off.rawValue
    @AppStorage("codeSymbolsEnabled") private var legacyCodeSymbolsEnabled: Bool = false
    
    var codeSymbolsMode: CodeSymbolsMode {
        get { CodeSymbolsMode(rawValue: codeSymbolsModeRaw) ?? .off }
        set { codeSymbolsModeRaw = newValue.rawValue }
    }
    
    // MARK: - File Tagging Settings
    
    @AppStorage("fileTaggingEnabled") var fileTaggingEnabled: Bool = true
    @AppStorage("autoScanWorkspace") var autoScanWorkspace: Bool = true
    @AppStorage("fileTaggingMinScore") var fileTaggingMinScore: Double = 0.5
    
    // MARK: - Snippets Settings
    
    @AppStorage("snippetsEnabled") var snippetsEnabled: Bool = true
    
    // MARK: - Streaming Transcription Settings
    
    @AppStorage("streamingTranscriptionEnabled") var streamingTranscriptionEnabled: Bool = true
    @AppStorage("streamingChunkDuration") var streamingChunkDuration: Double = 1.0

    init() {
        migrateCodeSymbolsModeIfNeeded()
    }

    private func migrateCodeSymbolsModeIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "codeSymbolsMode") != nil {
            return
        }
        
        if defaults.object(forKey: "codeSymbolsEnabled") != nil {
            codeSymbolsMode = legacyCodeSymbolsEnabled ? .always : .off
        }
    }
    
    // MARK: - Methods
    
    func resetToDefaults() {
        hotkeyKeyCode = 63
        hotkeyModifiers = 0
        triggerModeRaw = TriggerMode.pushToTalk.rawValue
        selectedModel = "base.en"
        language = "en"
        autoInject = true
        injectionModeRaw = InjectionMode.clipboardPaste.rawValue
        preserveClipboard = true
        typingDelay = 0.01
        showOverlay = true
        overlayPosition = OverlayPosition.nearNotch.rawValue
        overlayOpacity = 0.9
        overlaySize = 1.0
        overlayAutoHideDelay = 2.0
        playFeedbackSounds = true
        maxRecordingDuration = 120.0
        saveHistory = true
        maxHistoryItems = 100
        launchAtLogin = false
        dictionaryEnabled = true
        autoLearnCorrections = true
        detectUnusualWords = true
        sentenceRefinementEnabled = false
        syntaxTransformEnabled = true
        caseTransformationsEnabled = true
        cliPatternsEnabled = true
        codeSymbolsMode = .off
        fileTaggingEnabled = true
        autoScanWorkspace = true
        fileTaggingMinScore = 0.5
        snippetsEnabled = true
        streamingTranscriptionEnabled = true
        streamingChunkDuration = 1.0
    }
}
