//
//  MetricCardView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

struct MetricCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let accent: Color
    let trend: AnalyticsManager.Trend?

    init(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        accent: Color = DashboardPalette.accentBlue,
        trend: AnalyticsManager.Trend? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.trend = trend
    }

    var body: some View {
        DashboardSurface(padding: 12, radius: DashboardMetrics.surfaceRadius, secondary: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Text(title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DashboardPalette.textMuted)

                    Spacer(minLength: 8)

                    if let trend {
                        trendBadge(trend)
                    } else {
                        Image(systemName: icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent.opacity(0.82))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(DashboardPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DashboardPalette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        }
    }

    private func trendBadge(_ trend: AnalyticsManager.Trend) -> some View {
        Text(trend.displayText)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(trendColor(trend))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(trendColor(trend).opacity(0.10))
            .clipShape(Capsule(style: .continuous))
    }

    private func trendColor(_ trend: AnalyticsManager.Trend) -> Color {
        switch trend {
        case .up:
            return DashboardPalette.accentGreen
        case .down:
            return DashboardPalette.destructive
        case .neutral:
            return DashboardPalette.textSecondary
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        MetricCardView(
            title: "Words",
            value: "1,408",
            subtitle: "this week",
            icon: "text.word.spacing",
            trend: .up(percent: 12)
        )

        MetricCardView(
            title: "Sessions",
            value: "46",
            subtitle: "captured",
            icon: "waveform.badge.mic",
            accent: DashboardPalette.accentCyan
        )
    }
    .padding()
    .background(DashboardPalette.background)
}
