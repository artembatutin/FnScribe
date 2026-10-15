//
//  FnScribeApp.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

@main
struct FnScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var appState = AppDependencies.shared.appState
    @StateObject private var settingsStore = AppDependencies.shared.settingsStore
    @StateObject private var permissionsManager = AppDependencies.shared.permissionsManager
    @StateObject private var modelManager = AppDependencies.shared.modelManager
    @StateObject private var speechRecognizer = AppDependencies.shared.speechRecognizer
    @StateObject private var hotkeyManager = AppDependencies.shared.hotkeyManager
    @StateObject private var sessionManager = AppDependencies.shared.sessionManager
    @StateObject private var textInjectionService = AppDependencies.shared.textInjectionService
    @StateObject private var dictionaryManager = AppDependencies.shared.dictionaryManager
    @StateObject private var inputFieldDetector = AppDependencies.shared.inputFieldDetector
    @StateObject private var snippetManager = AppDependencies.shared.snippetManager
    @StateObject private var analyticsManager = AppDependencies.shared.analyticsManager
    @StateObject private var taskManager = AppDependencies.shared.taskManager
    
    var body: some Scene {
        // Menu Bar
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
                .environmentObject(permissionsManager)
                .environmentObject(modelManager)
                .environmentObject(speechRecognizer)
                .environmentObject(hotkeyManager)
                .environmentObject(sessionManager)
                .environmentObject(textInjectionService)
                .environmentObject(dictionaryManager)
                .environmentObject(inputFieldDetector)
                .environmentObject(snippetManager)
                .environmentObject(taskManager)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
        
        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .environmentObject(permissionsManager)
                .environmentObject(modelManager)
                .environmentObject(speechRecognizer)
                .environmentObject(hotkeyManager)
                .environmentObject(sessionManager)
                .environmentObject(textInjectionService)
                .environmentObject(dictionaryManager)
                .environmentObject(inputFieldDetector)
                .environmentObject(snippetManager)
                .environmentObject(analyticsManager)
                .environmentObject(taskManager)
                .environmentObject(AppDependencies.shared.workspaceScanner)
                .environmentObject(AppDependencies.shared.fileTagger)
        }
    }
    
    private var menuBarLabel: some View {
        Image(systemName: appState.recordingState.menuBarSymbolName)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 20, height: 18)
            .accessibilityLabel("\(AppBranding.displayName): \(appState.recordingState.menuStatusTitle)")
            .help("\(AppBranding.displayName) — \(appState.recordingState.menuStatusTitle)")
    }
}
