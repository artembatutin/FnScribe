//
//  AppBreakdownView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

struct AppBreakdownView: View {
    let apps: [UsageMetrics.AppMetric]

    private var totalWords: Int {
        apps.reduce(0) { $0 + $1.words }
    }

    private var totalSessions: Int {
        apps.reduce(0) { $0 + $1.sessions }
    }

    var body: some View {
        DashboardSurface {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top apps")
                        .font(.headline)
                        .foregroundStyle(DashboardPalette.textPrimary)

                    Text(apps.isEmpty ? "Usage will appear here once dictation lands in apps." : "\(totalSessions) sessions across \(apps.count) apps")
                        .font(.caption)
                        .foregroundStyle(DashboardPalette.textSecondary)
                }

                if apps.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 10) {
                        ForEach(apps) { app in
                            appRow(app)
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.badge")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DashboardPalette.textSecondary)

            Text("No app breakdown yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DashboardPalette.textPrimary)

            Text("Run a few dictation sessions to see where voice work is landing.")
                .font(.caption)
                .foregroundStyle(DashboardPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private func appRow(_ app: UsageMetrics.AppMetric) -> some View {
        let share = percentage(for: app)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DashboardPalette.surfaceSecondary)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: appIcon(for: app.appName))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DashboardPalette.textSecondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.appName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DashboardPalette.textPrimary)

                    Text("\(formatNumber(app.words)) words · \(app.sessions) sessions")
                        .font(.caption)
                        .foregroundStyle(DashboardPalette.textSecondary)
                }

                Spacer(minLength: 12)

                Text("\(share)%")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DashboardPalette.textPrimary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(DashboardPalette.gridLine)

                    Capsule(style: .continuous)
                        .fill(DashboardPalette.accentBlue.opacity(0.58))
                        .frame(width: max(10, proxy.size.width * CGFloat(share) / 100))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DashboardPalette.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
                )
        }
    }

    private func percentage(for app: UsageMetrics.AppMetric) -> Int {
        guard totalWords > 0 else { return 0 }
        let percent = (Double(app.words) / Double(totalWords)) * 100
        return Int(percent.rounded())
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func appIcon(for appName: String) -> String {
        let lowercased = appName.lowercased()

        if lowercased.contains("cursor") || lowercased.contains("windsurf") || lowercased.contains("code") {
            return "chevron.left.forwardslash.chevron.right"
        } else if lowercased.contains("xcode") {
            return "hammer"
        } else if lowercased.contains("safari") {
            return "safari"
        } else if lowercased.contains("chrome") {
            return "globe"
        } else if lowercased.contains("slack") || lowercased.contains("discord") || lowercased.contains("teams") {
            return "message"
        } else if lowercased.contains("mail") || lowercased.contains("outlook") {
            return "envelope"
        } else if lowercased.contains("notes") {
            return "note.text"
        } else if lowercased.contains("pages") || lowercased.contains("word") {
            return "doc.text"
        } else if lowercased.contains("terminal") || lowercased.contains("iterm") {
            return "terminal"
        } else if lowercased.contains("finder") {
            return "folder"
        }

        return "app"
    }
}

#Preview {
    let sampleApps: [UsageMetrics.AppMetric] = [
        UsageMetrics.AppMetric(bundleId: "com.cursor", appName: "Cursor", sessions: 45, words: 2500),
        UsageMetrics.AppMetric(bundleId: "com.slack", appName: "Slack", sessions: 20, words: 800),
        UsageMetrics.AppMetric(bundleId: "com.apple.mail", appName: "Mail", sessions: 15, words: 600),
    ]

    AppBreakdownView(apps: sampleApps)
        .padding()
        .background(DashboardPalette.background)
        .frame(width: 600)
}
