//
//  DashboardWindowController.swift
//  FnScribe
//
//  Created by Codex on 2026-04-22.
//

import Cocoa
import Combine
import SwiftUI

@MainActor
final class DashboardNavigation: ObservableObject {
    @Published var section: DashboardSection = .tasks
    @Published private(set) var newTaskRequestID: UUID?

    func showTasks(createNewTask: Bool = false) {
        section = .tasks

        if createNewTask {
            newTaskRequestID = UUID()
        }
    }

    func consumeNewTaskRequest() {
        newTaskRequestID = nil
    }
}

@MainActor
class DashboardWindowController {
    static let shared = DashboardWindowController()

    private var window: NSWindow?
    private let navigation = DashboardNavigation()

    private init() {}

    func showWindow(createNewTask: Bool = false) {
        let dependencies = AppDependencies.shared
        dependencies.taskManager.reloadWorkspace()
        navigation.showTasks(createNewTask: createNewTask)

        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let dashboardView = DashboardView()
            .environmentObject(dependencies.taskManager)
            .environmentObject(dependencies.sessionManager)
            .environmentObject(dependencies.textInjectionService)
            .environmentObject(dependencies.analyticsManager)
            .environmentObject(navigation)

        let hostingController = NSHostingController(rootView: dashboardView)
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = AppBranding.dashboardWindowTitle
        newWindow.identifier = NSUserInterfaceItemIdentifier("dashboard")
        newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        newWindow.setContentSize(NSSize(width: 1180, height: 760))
        newWindow.minSize = NSSize(width: 980, height: 640)
        newWindow.center()
        newWindow.setFrameAutosaveName("DashboardWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.toolbarStyle = .unified

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
