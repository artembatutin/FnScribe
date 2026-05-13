//
//  HistoryView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var textInjectionService: TextInjectionService

    @State private var showClearConfirmation = false
    @State private var showExportSheet = false
    @State private var selectedCaptureKind: CaptureKind?

    var body: some View {
        VStack(spacing: DashboardMetrics.sectionSpacing) {
            header
            toolbar

            if displayedSessions.isEmpty {
                emptyStateView
            } else {
                sessionStream
            }
        }
        .alert("Clear History", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                sessionManager.clearHistory()
            }
        } message: {
            Text("Are you sure you want to delete all transcription history? This cannot be undone.")
        }
        .sheet(isPresented: $showExportSheet) {
            ExportHistoryView()
        }
    }

    private var header: some View {
        DashboardSectionHeader(
            title: "History",
            subtitle: "Inspect captures and move useful text back into the active app."
        ) {
            HStack(spacing: 8) {
                Button("Export") {
                    showExportSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(sessionManager.sessions.isEmpty)

                Button("Clear") {
                    showClearConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(sessionManager.sessions.isEmpty)
            }
        }
    }

    private var toolbar: some View {
        DashboardToolbar {
            HStack(spacing: DashboardMetrics.controlGap) {
                DashboardPillPicker(
                    options: [Optional<CaptureKind>.none] + CaptureKind.allCases.map(Optional.some),
                    selection: $selectedCaptureKind
                ) { kind, _ in
                    Text(kind?.displayName ?? "All")
                        .font(.caption.weight(.medium))
                }
                .frame(width: 230, alignment: .leading)

                DashboardSearchField(
                    placeholder: "Search transcriptions",
                    text: $sessionManager.searchQuery
                )
                .frame(maxWidth: .infinity)

                DashboardStatBadge(
                    title: "Sessions",
                    value: "\(displayedSessions.count)",
                    accent: DashboardPalette.accentBlue
                )
                .frame(width: 108)
            }
        }
    }

    private var emptyStateView: some View {
        DashboardSurface(padding: 24, radius: DashboardMetrics.surfaceRadius) {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DashboardPalette.textSecondary)

                Text(sessionManager.searchQuery.isEmpty ? "No transcription history yet" : "No sessions match your search")
                    .font(.headline)
                    .foregroundStyle(DashboardPalette.textPrimary)

                Text(sessionManager.searchQuery.isEmpty ? "Captured sessions will appear here once dictation starts." : "Try a broader phrase or switch the capture filter.")
                    .font(.caption)
                    .foregroundStyle(DashboardPalette.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var sessionStream: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(displayedSessions) { session in
                    SessionRowView(
                        session: session,
                        onCopy: {
                            sessionManager.copyToClipboard(session)
                        },
                        onReinject: {
                            Task {
                                try? await textInjectionService.inject(text: session.transcription)
                            }
                        },
                        onDelete: {
                            sessionManager.deleteSession(session)
                        }
                    )
                }
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
    }

    private var displayedSessions: [TranscriptionSession] {
        let sessions = sessionManager.filteredSessions
        guard let selectedCaptureKind else { return sessions }
        return sessions.filter { $0.captureKind == selectedCaptureKind }
    }
}

struct SessionRowView: View {
    let session: TranscriptionSession
    let onCopy: () -> Void
    let onReinject: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isExpanded = false

    var body: some View {
        DashboardSurface(padding: 12, radius: DashboardMetrics.surfaceRadius, secondary: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.formattedTimestamp)
                            .font(.caption)
                            .foregroundStyle(DashboardPalette.textMuted)

                        HStack(spacing: 5) {
                            DashboardMetaBadge(
                                text: session.captureKind.displayName,
                                tint: session.captureKind == .task ? DashboardPalette.accentAmber : DashboardPalette.accentBlue,
                                compact: true
                            )
                            DashboardMetaBadge(text: session.formattedDuration, tint: DashboardPalette.accentCyan, compact: true)
                            DashboardMetaBadge(text: "\(session.wordCount) words", tint: DashboardPalette.accentRose, compact: true)

                            if let app = session.targetApp {
                                DashboardMetaBadge(text: app, tint: DashboardPalette.textSecondary, compact: true)
                            }
                        }
                    }

                    Spacer(minLength: 16)

                    HStack(spacing: 6) {
                        DashboardIconActionButton(systemName: "doc.on.doc", action: onCopy)

                        if session.captureKind == .dictation {
                            DashboardIconActionButton(systemName: "text.cursor", action: onReinject)
                        }

                        DashboardIconActionButton(systemName: "trash", role: .destructive, action: onDelete)
                    }
                    .opacity(isHovering ? 1 : 0.82)
                }

                Text(isExpanded ? session.transcription : session.truncatedTranscription)
                    .font(.body)
                    .foregroundStyle(DashboardPalette.textPrimary)
                    .lineSpacing(3)
                    .lineLimit(isExpanded ? nil : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    if session.transcription.count > 100 {
                        Button(isExpanded ? "Show less" : "Show more") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DashboardPalette.accentBlue)
                        .font(.caption.weight(.medium))
                    }

                    Spacer()

                    DashboardMetaBadge(text: session.modelUsed, tint: DashboardPalette.textSecondary, compact: true)
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct ExportHistoryView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss

    @State private var exportFormat: ExportFormat = .text

    enum ExportFormat: String, CaseIterable {
        case text = "Plain Text"
        case json = "JSON"
    }

    var body: some View {
        ZStack {
            DashboardSceneBackground()

            DashboardPanel {
                VStack(spacing: 20) {
                    Text("Export History")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DashboardPalette.textPrimary)

                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)

                        Button("Export") {
                            exportHistory()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 360, height: 240)
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat == .json ? [.json] : [.plainText]
        panel.nameFieldStringValue = "\(AppBranding.historyExportFileName).\(exportFormat == .json ? "json" : "txt")"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    if exportFormat == .json {
                        if let data = sessionManager.exportSessionsAsJSON() {
                            try data.write(to: url)
                        }
                    } else {
                        let text = sessionManager.exportSessionsAsText()
                        try text.write(to: url, atomically: true, encoding: .utf8)
                    }
                } catch {
                    print("Export failed: \(error)")
                }
            }
            dismiss()
        }
    }
}

#Preview {
    HistoryView()
}
