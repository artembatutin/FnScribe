//
//  AppDelegate.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let urlScheme = "fnscribe"

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }

        // Hide from Dock - app runs as menu bar only
        NSApp.setActivationPolicy(.accessory)
        
        // Start hotkey listening after a short delay to ensure permissions are checked
        Task { @MainActor in
            // Load the selected model
            await AppDependencies.shared.loadSelectedModel()

            // The onboarding window is AppKit-owned so it only appears until setup is complete.
            OnboardingWindowController.shared.showWindowIfNeeded()
            
            // Start listening for hotkeys if permissions are granted
            AppDependencies.shared.startHotkeyListening()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        guard !isRunningTests else { return }

        // Stop hotkey listening
        Task { @MainActor in
            AppDependencies.shared.stopHotkeyListening()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running even when all windows are closed (menu bar app)
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == urlScheme }) else { return }

        Task { @MainActor in
            AppDependencies.shared.taskManager.reloadWorkspace()
            DashboardWindowController.shared.showWindow(createNewTask: urls.contains(where: isNewTaskURL))
        }
    }

    private func isNewTaskURL(_ url: URL) -> Bool {
        url.scheme == urlScheme &&
            url.host == "tasks" &&
            url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "new"
    }
}
