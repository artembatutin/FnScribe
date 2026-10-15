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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didCopyLastCapture = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(16)

            Divider()
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 14) {
                modelRow
                lastCaptureCard
                statsRow
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 2) {
                MenuActionRow(title: "Dashboard", systemImage: "square.grid.2x2") {
                    dismissMenu { DashboardWindowController.shared.showWindow() }
                }

                MenuActionRow(title: "Settings…", systemImage: "gearshape", shortcut: "⌘,") {
                    dismissMenu { SettingsWindowController.shared.showWindow() }
                }
                .keyboardShortcut(",", modifiers: .command)

                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                MenuActionRow(title: "Quit \(AppBranding.displayName)", systemImage: "power", shortcut: "⌘Q", secondary: true) {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(8)
        }
        .font(.system(size: 13))
        .foregroundStyle(DashboardPalette.textPrimary)
        .frame(width: 328)
        .fixedSize(horizontal: false, vertical: true)
        .background(DashboardPalette.background)
        .onChange(of: lastCaptureText) {
            didCopyLastCapture = false
        }
        .task(id: didCopyLastCapture) {
            guard didCopyLastCapture else { return }
            do {
                try await Task.sleep(for: .seconds(1.5))
                didCopyLastCapture = false
            } catch {
                // A changed capture or a dismissed menu cancels the feedback timer.
            }
        }
        .onDisappear { didCopyLastCapture = false }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: appState.recordingState.menuBarSymbolName)
                    .font(.system(size: 18, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: appState.recordingState == .listening && !reduceMotion)
                    .frame(width: 36, height: 36)
                    .background(statusColor.opacity(0.10), in: RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppBranding.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    Text(appState.recordingState.menuStatusTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardPalette.textSecondary)
                }
                Spacer(minLength: 0)

                if appState.recordingState == .processing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Processing capture")
                }
            }

            if case .error(let message) = appState.recordingState {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardPalette.destructive)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .help(message)
            } else if appState.recordingState == .processing {
                Text("Finishing your capture…")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardPalette.textSecondary)
            } else {
                HStack(spacing: 6) {
                    Text(shortcutPrefix)
                    Text(hotkeyManager.currentKeyCombo.displayName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DashboardPalette.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DashboardPalette.surface, in: RoundedRectangle(cornerRadius: 4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
                        }
                    Text(shortcutSuffix)
                }
                .font(.system(size: 12))
                .foregroundStyle(DashboardPalette.textSecondary)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var modelRow: some View {
        HStack(spacing: 8) {
            Label("Model", systemImage: "cpu")
                .foregroundStyle(DashboardPalette.textSecondary)
            Spacer(minLength: 8)
            Text(settingsStore.selectedModel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(settingsStore.selectedModel)
        }
        .font(.system(size: 12))
        .accessibilityElement(children: .combine)
    }

    private var lastCaptureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last capture")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DashboardPalette.textSecondary)
                Spacer(minLength: 8)
                Button(action: copyLastCapture) {
                    Label(didCopyLastCapture ? "Copied" : "Copy", systemImage: didCopyLastCapture ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .frame(minWidth: 52, minHeight: 20)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(lastCaptureText == nil)
                .accessibilityLabel(didCopyLastCapture ? "Capture copied" : "Copy last capture")
                .help("Copy the full capture to the clipboard")
            }

            Text(lastCaptureText ?? "Your next capture will appear here.")
                .font(.system(size: 13))
                .foregroundStyle(lastCaptureText == nil ? DashboardPalette.textMuted : DashboardPalette.textPrimary)
                .lineSpacing(3)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(DashboardPalette.surface, in: RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: DashboardMetrics.controlRadius)
                .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            metricLabel(title: "Open tasks", value: openTaskCount, systemImage: "checklist")
            Rectangle()
                .fill(DashboardPalette.outlineSoft)
                .frame(width: 1, height: 14)
                .accessibilityHidden(true)
            metricLabel(title: "Captures", value: sessionManager.sessions.count, systemImage: "text.bubble")
        }
    }

    private func metricLabel(title: String, value: Int, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(title)
            Spacer(minLength: 2)
            Text(value, format: .number)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(DashboardPalette.textPrimary)
        }
        .font(.system(size: 11))
        .foregroundStyle(DashboardPalette.textSecondary)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }

    private var shortcutPrefix: String {
        if appState.recordingState == .listening {
            return settingsStore.triggerMode == .pushToTalk ? "Release" : "Press"
        }
        return settingsStore.triggerMode == .pushToTalk ? "Hold" : "Press"
    }

    private var shortcutSuffix: String {
        switch appState.recordingState {
        case .listening:
            return "to finish"
        case .processing:
            return "for your next capture"
        case .idle, .error:
            return "to dictate"
        }
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .idle:
            return DashboardPalette.accentBlue
        case .listening, .error:
            return DashboardPalette.destructive
        case .processing:
            return DashboardPalette.accentAmber
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
        didCopyLastCapture = pasteboard.setString(text, forType: .string)
    }

    private func dismissMenu(then action: @escaping () -> Void) {
        NSApp.keyWindow?.close()
        DispatchQueue.main.async { action() }
    }
}

/// Shared by the status item and its popover so each state has one visual identity.
extension RecordingState {
    var menuBarSymbolName: String {
        switch self {
        case .idle: return "mic"
        case .listening: return "waveform"
        case .processing: return "ellipsis"
        case .error: return "exclamationmark.triangle"
        }
    }

    var menuStatusTitle: String {
        switch self {
        case .idle: return "Ready to dictate"
        case .listening: return "Listening…"
        case .processing: return "Transcribing…"
        case .error: return "Needs attention"
        }
    }
}

private struct MenuActionRow: View {
    let title: String
    let systemImage: String
    var shortcut: String? = nil
    var secondary = false
    let action: () -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardPalette.textSecondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(secondary ? DashboardPalette.textSecondary : DashboardPalette.textPrimary)
                Spacer(minLength: 8)
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardPalette.textMuted)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(DashboardPalette.textMuted)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: DashboardMetrics.controlHeight)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering || isFocused ? DashboardPalette.surfaceTertiary.opacity(0.5) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isFocused ? DashboardPalette.accentBlue : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovering = $0 }
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
