//
//  OnboardingWindowController.swift
//  FnScribe
//
//  Created by Codex on 2026-05-01.
//

import Cocoa
import SwiftUI

@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private init() {}

    func showWindowIfNeeded() {
        guard !AppDependencies.shared.settingsStore.hasCompletedOnboarding else {
            closeWindow()
            return
        }

        showWindow()
    }

    func closeWindow() {
        window?.close()
        window = nil
    }

    private func showWindow() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let dependencies = AppDependencies.shared
        let onboardingView = OnboardingView {
            OnboardingWindowController.shared.closeWindow()
        }
        .environmentObject(dependencies.settingsStore)
        .environmentObject(dependencies.permissionsManager)
        .environmentObject(dependencies.modelManager)
        .environmentObject(dependencies.speechRecognizer)
        .environmentObject(dependencies.hotkeyManager)
        .environmentObject(dependencies.sessionManager)
        .environmentObject(dependencies.textInjectionService)
        .environmentObject(dependencies.dictionaryManager)
        .environmentObject(dependencies.inputFieldDetector)
        .environmentObject(dependencies.snippetManager)
        .environmentObject(dependencies.taskManager)

        let hostingController = NSHostingController(rootView: onboardingView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = AppBranding.onboardingWindowTitle
        newWindow.identifier = NSUserInterfaceItemIdentifier("onboarding")
        newWindow.styleMask = [.titled, .closable, .miniaturizable]
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.setContentSize(NSSize(width: 500, height: 450))
        newWindow.isReleasedWhenClosed = false
        newWindow.center()

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
