//
//  MenuBarView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var didCopyLastCapture = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            quickInfoRow
            statsRow
            lastCaptureCard
            actionRow
            footer
        }
        .padding(14)
        .frame(width: 318)
        .background(DashboardPalette.background)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: appState.recordingState.iconName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: appState.recordingState == .listening)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(statusColor.opacity(0.14))
                )
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.18), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(AppBranding.displayName)
                    .font(.title3.weight(.semibold))

                Text(headerDetailText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DashboardPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            statusBadge
        }
        .padding(12)
        .menuCardBackground(emphasized: true)
    }

    private var quickInfoRow: some View {
        HStack(spacing: 8) {
            compactInfoPill(title: "Model", value: settingsStore.selectedModel)
            compactInfoPill(title: "Hotkey", value: hotkeyManager.currentKeyCombo.displayName)
        }
    }

    private func compactInfoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DashboardPalette.textMuted)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardPalette.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .menuCardBackground()
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            metricTile(title: "Open Tasks", value: "\(openTaskCount)")
            metricTile(title: "Captures", value: "\(sessionManager.sessions.count)")
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DashboardPalette.textMuted)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(DashboardPalette.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .menuCardBackground()
    }

    private var lastCaptureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last Capture")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DashboardPalette.textMuted)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    copyLastCapture()
                } label: {
                    Label(didCopyLastCapture ? "Copied" : "Copy", systemImage: didCopyLastCapture ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(lastCaptureText == nil)
            }

            Text(lastCaptureText ?? "No captures yet")
                .font(.callout.weight(.medium))
                .foregroundStyle(lastCaptureText == nil ? DashboardPalette.textSecondary : DashboardPalette.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .menuCardBackground()
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                dismissMenu {
                    DashboardWindowController.shared.showWindow()
                }
            } label: {
                actionLabel(title: "Dashboard", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.plain)

            Button {
                dismissMenu {
                    SettingsWindowController.shared.showWindow()
                }
            } label: {
                actionLabel(title: "Settings", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)

            Text(title)
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(DashboardPalette.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .menuCardBackground()
    }

    private var footer: some View {
        HStack {
            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.medium))
            .foregroundStyle(DashboardPalette.textSecondary)
        }
        .padding(.top, 2)
    }

    private var statusBadge: some View {
        Text(statusBadgeText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(statusColor.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(statusColor.opacity(0.22), lineWidth: 1)
                    )
            }
    }

    private var statusBadgeText: String {
        switch appState.recordingState {
        case .idle:
            return "Idle"
        case .listening, .processing:
            return "Active"
        case .error:
            return "Error"
        }
    }

    private var headerDetailText: String {
        switch appState.recordingState {
        case .idle:
            return "Press \(hotkeyManager.currentKeyCombo.displayName) to start"
        case .listening:
            return "Listening for your next capture"
        case .processing:
            return "Processing the latest capture"
        case .error(let message):
            return message
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle:
            return .secondary
        case .listening:
            return .red
        case .processing:
            return .orange
        case .error:
            return .red
        }
    }

    private var openTaskCount: Int {
        taskManager.tasks.filter { $0.status != .done }.count
    }

    private var lastCaptureText: String? {
        if let last = appState.lastTranscription?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            return last
        }

        if let last = sessionManager.recentSessions.first?.transcription.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            return last
        }

        return nil
    }

    private func copyLastCapture() {
        guard let text = lastCaptureText else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        didCopyLastCapture = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopyLastCapture = false
        }
    }

    private func dismissMenu(then action: @escaping () -> Void) {
        let menuWindow = NSApp.keyWindow
        menuWindow?.close()

        DispatchQueue.main.async {
            action()
        }
    }
}

private extension View {
    func menuCardBackground(emphasized: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(emphasized ? DashboardPalette.surfaceTertiary.opacity(0.26) : DashboardPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
                )
        )
    }
}

#Preview {
    let settingsStore = SettingsStore()
    return MenuBarView()
        .environmentObject(AppState())
        .environmentObject(settingsStore)
        .environmentObject(HotkeyManager(settingsStore: settingsStore))
        .environmentObject(SessionManager(settingsStore: settingsStore))
        .environmentObject(TaskManager())
}
