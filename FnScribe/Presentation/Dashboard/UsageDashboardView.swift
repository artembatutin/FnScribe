//
//  UsageDashboardView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

struct UsageDashboardView: View {
    @ObservedObject var analyticsManager: AnalyticsManager
    @State private var selectedPeriod: AnalyticsManager.Period = .week
    @State private var selectedChartMetric: UsageChartView.ChartMetric = .words

    private var totals: (sessions: Int, words: Int, timeSaved: TimeInterval) {
        analyticsManager.getTotals(for: selectedPeriod)
    }

    private var averageWordsPerSession: Int {
        totals.sessions > 0 ? totals.words / totals.sessions : 0
    }

    private var chartData: [UsageMetrics.DailyMetric] {
        analyticsManager.getMetrics(for: selectedPeriod)
    }

    private var periodTrend: AnalyticsManager.Trend {
        analyticsManager.calculateTrend(for: selectedPeriod)
    }

    private var topApp: UsageMetrics.AppMetric? {
        analyticsManager.getTopApps(limit: 1).first
    }

    private var peakDay: UsageMetrics.DailyMetric? {
        chartData.max(by: { metricValue(for: $0, metric: selectedChartMetric) < metricValue(for: $1, metric: selectedChartMetric) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardMetrics.sectionSpacing) {
                header
                summaryStrip

                HStack(alignment: .top, spacing: DashboardMetrics.sectionSpacing) {
                    activitySection
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: DashboardMetrics.stackSpacing) {
                        pulseSection
                        throughputSection
                        streaksSection
                    }
                    .frame(width: 248)
                }

                AppBreakdownView(apps: analyticsManager.topApps)
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    private var header: some View {
        DashboardSectionHeader(
            title: "Dictation",
            subtitle: "Track output, pacing, and where voice work lands."
        ) {
            DashboardPillPicker(options: AnalyticsManager.Period.allCases, selection: $selectedPeriod) { period, _ in
                Text(period.rawValue)
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private var summaryStrip: some View {
        LazyVGrid(columns: summaryColumns, spacing: DashboardMetrics.stackSpacing) {
            MetricCardView(
                title: "Words",
                value: formatNumber(totals.words),
                subtitle: periodSubtitle,
                icon: "text.word.spacing",
                accent: DashboardPalette.accentBlue,
                trend: selectedPeriod == .allTime ? nil : periodTrend
            )

            MetricCardView(
                title: "Sessions",
                value: "\(totals.sessions)",
                subtitle: "captured",
                icon: "waveform.badge.mic",
                accent: DashboardPalette.accentCyan
            )

            MetricCardView(
                title: "Saved",
                value: formatTimeSaved(totals.timeSaved),
                subtitle: "typing avoided",
                icon: "clock.arrow.circlepath",
                accent: DashboardPalette.accentAmber
            )

            MetricCardView(
                title: "Avg / Session",
                value: "\(averageWordsPerSession)",
                subtitle: "words",
                icon: "chart.bar",
                accent: DashboardPalette.accentRose
            )
        }
    }

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 168, maximum: 208), spacing: DashboardMetrics.stackSpacing, alignment: .top)]
    }

    private var activitySection: some View {
        DashboardSurface(padding: 14, radius: DashboardMetrics.surfaceRadius) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity")
                            .font(.headline)
                            .foregroundStyle(DashboardPalette.textPrimary)

                        Text("Compare output, session count, or time returned.")
                            .font(.caption)
                            .foregroundStyle(DashboardPalette.textSecondary)
                    }

                    Spacer(minLength: 10)

                    if let peakDay, metricValue(for: peakDay, metric: selectedChartMetric) > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Peak")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DashboardPalette.textMuted)

                            Text("\(peakDay.displayDate) · \(metricValue(for: peakDay, metric: selectedChartMetric))")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DashboardPalette.textPrimary)
                                .monospacedDigit()
                        }
                    }

                    DashboardPillPicker(options: UsageChartView.ChartMetric.allCases, selection: $selectedChartMetric) { metric, _ in
                        Text(metric.rawValue)
                            .font(.caption2.weight(.medium))
                    }
                }

                UsageChartView(data: chartData, metric: selectedChartMetric)
            }
        }
    }

    private var pulseSection: some View {
        DashboardSurface(padding: 12, radius: DashboardMetrics.surfaceRadius, secondary: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pulse")
                    .font(.headline)
                    .foregroundStyle(DashboardPalette.textPrimary)

                insightRow("Trend", value: periodTrend.displayText, accent: periodTrend.isPositive ? DashboardPalette.accentGreen : DashboardPalette.destructive)
                insightRow("Peak day", value: peakDay?.displayDate ?? "No data", accent: DashboardPalette.accentBlue)
                insightRow("Top app", value: topApp?.appName ?? "Waiting", accent: DashboardPalette.accentAmber)
            }
        }
    }

    private var throughputSection: some View {
        DashboardSurface(padding: 12, radius: DashboardMetrics.surfaceRadius, secondary: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Throughput")
                    .font(.headline)
                    .foregroundStyle(DashboardPalette.textPrimary)

                Text(formatNumber(totals.words))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(DashboardPalette.textPrimary)

                Text("Total words dictated in the selected window.")
                    .font(.caption)
                    .foregroundStyle(DashboardPalette.textSecondary)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(DashboardPalette.gridLine)

                        Capsule(style: .continuous)
                            .fill(DashboardPalette.accentBlue.opacity(0.60))
                            .frame(width: max(16, proxy.size.width * throughputShare))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var throughputShare: CGFloat {
        let total = max(analyticsManager.metrics.totalWords, 1)
        return min(1, CGFloat(Double(totals.words) / Double(total)))
    }

    private var streaksSection: some View {
        DashboardSurface(padding: 12, radius: DashboardMetrics.surfaceRadius, secondary: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Streaks")
                    .font(.headline)
                    .foregroundStyle(DashboardPalette.textPrimary)

                HStack(spacing: 10) {
                    streakMetric(title: "Current", value: analyticsManager.metrics.currentStreak)
                    streakMetric(title: "Best", value: analyticsManager.metrics.longestStreak)
                }

                Text(lastActiveLabel)
                    .font(.caption)
                    .foregroundStyle(DashboardPalette.textSecondary)
            }
        }
    }

    private var lastActiveLabel: String {
        if let lastActive = analyticsManager.metrics.lastActiveDate {
            return "Last active \(formatLastActive(lastActive))"
        }
        return "No activity recorded yet."
    }

    private func streakMetric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DashboardPalette.textMuted)

            Text("\(value)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DashboardPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DashboardPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(DashboardPalette.outlineSoft, lineWidth: 1)
                )
        }
    }

    private func insightRow(_ title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption)
                .foregroundStyle(DashboardPalette.textSecondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardPalette.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metricValue(for metric: UsageMetrics.DailyMetric, metric selectedMetric: UsageChartView.ChartMetric) -> Int {
        switch selectedMetric {
        case .words:
            return metric.words
        case .sessions:
            return metric.sessions
        case .timeSaved:
            return Int(metric.timeSaved / 60)
        }
    }

    private var periodSubtitle: String {
        switch selectedPeriod {
        case .today:
            return "today"
        case .week:
            return "this week"
        case .month:
            return "this month"
        case .allTime:
            return "all time"
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatTimeSaved(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    private func formatLastActive(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}
