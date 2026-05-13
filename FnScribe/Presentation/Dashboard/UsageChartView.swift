//
//  UsageChartView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI
import Charts

struct UsageChartView: View {
    let data: [UsageMetrics.DailyMetric]
    let metric: ChartMetric

    enum ChartMetric: String, CaseIterable, Identifiable {
        case words = "Words"
        case sessions = "Sessions"
        case timeSaved = "Time Saved"

        var id: String { rawValue }

        var accent: Color {
            switch self {
            case .words:
                return DashboardPalette.accentBlue
            case .sessions:
                return DashboardPalette.accentCyan
            case .timeSaved:
                return DashboardPalette.accentAmber
            }
        }
    }

    private var chartPoints: [(metric: UsageMetrics.DailyMetric, value: Double)] {
        data.map { ($0, value(for: $0)) }
    }

    private var hasData: Bool {
        chartPoints.contains { $0.value > 0 }
    }

    private var averageValue: Double {
        let populatedPoints = chartPoints.filter { $0.value > 0 }
        guard !populatedPoints.isEmpty else { return 0 }
        return populatedPoints.reduce(0) { $0 + $1.value } / Double(populatedPoints.count)
    }

    private var peakPoint: (metric: UsageMetrics.DailyMetric, value: Double)? {
        chartPoints.max(by: { $0.value < $1.value })
    }

    var body: some View {
        Group {
            if hasData {
                chartView
            } else {
                emptyStateView
            }
        }
    }

    private var emptyStateView: some View {
        DashboardControlSurface(height: 268, padding: 20, radius: 14) {
            VStack(spacing: 10) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(metric.accent)

                Text("No chart data yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DashboardPalette.textPrimary)

                Text("Start dictating to see \(metric.rawValue.lowercased()) here.")
                    .font(.caption)
                    .foregroundStyle(DashboardPalette.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var chartView: some View {
        Chart {
            ForEach(chartPoints, id: \.metric.id) { point in
                AreaMark(
                    x: .value("Date", point.metric.displayDate),
                    y: .value(metric.rawValue, point.value)
                )
                .foregroundStyle(metric.accent.opacity(0.10))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.metric.displayDate),
                    y: .value(metric.rawValue, point.value)
                )
                .foregroundStyle(metric.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.metric.displayDate),
                    y: .value(metric.rawValue, point.value)
                )
                .foregroundStyle(metric.accent)
                .symbolSize(point.value == peakPoint?.value ? 42 : 18)
            }

            if averageValue > 0 {
                RuleMark(y: .value("Average", averageValue))
                    .foregroundStyle(DashboardPalette.textMuted)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("Avg \(formattedValue(averageValue))")
                            .font(.caption2)
                            .foregroundStyle(DashboardPalette.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(DashboardPalette.surfaceSecondary)
                            .clipShape(Capsule(style: .continuous))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                AxisTick(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel {
                    if let dateStr = value.as(String.self) {
                        Text(dateStr)
                            .font(.caption2)
                            .foregroundStyle(DashboardPalette.textMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(DashboardPalette.gridLine)
                AxisTick(stroke: StrokeStyle(lineWidth: 0))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formattedAxisValue(doubleValue))
                            .font(.caption2)
                            .foregroundStyle(DashboardPalette.textMuted)
                    } else if let intValue = value.as(Int.self) {
                        Text(formattedAxisValue(Double(intValue)))
                            .font(.caption2)
                            .foregroundStyle(DashboardPalette.textMuted)
                    }
                }
            }
        }
        .chartPlotStyle { plotContent in
            plotContent
                .padding(.top, 4)
                .padding(.trailing, 4)
        }
        .frame(height: 272)
    }

    private func value(for metric: UsageMetrics.DailyMetric) -> Double {
        switch self.metric {
        case .words:
            return Double(metric.words)
        case .sessions:
            return Double(metric.sessions)
        case .timeSaved:
            return metric.timeSaved / 60
        }
    }

    private func formattedAxisValue(_ value: Double) -> String {
        switch metric {
        case .words:
            if value >= 1000 {
                return "\(Int(value) / 1000)k"
            }
            return "\(Int(value))"
        case .sessions:
            return "\(Int(value))"
        case .timeSaved:
            return "\(Int(value))m"
        }
    }

    private func formattedValue(_ value: Double) -> String {
        switch metric {
        case .words:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
        case .sessions:
            return "\(Int(value))"
        case .timeSaved:
            return "\(Int(value))m"
        }
    }
}

#Preview {
    let sampleData: [UsageMetrics.DailyMetric] = [
        UsageMetrics.DailyMetric(dateString: "2026-01-21", sessions: 5, words: 150),
        UsageMetrics.DailyMetric(dateString: "2026-01-22", sessions: 8, words: 280),
        UsageMetrics.DailyMetric(dateString: "2026-01-23", sessions: 3, words: 90),
        UsageMetrics.DailyMetric(dateString: "2026-01-24", sessions: 12, words: 450),
        UsageMetrics.DailyMetric(dateString: "2026-01-25", sessions: 6, words: 200),
        UsageMetrics.DailyMetric(dateString: "2026-01-26", sessions: 9, words: 320),
        UsageMetrics.DailyMetric(dateString: "2026-01-27", sessions: 4, words: 180),
    ]

    DashboardSurface {
        UsageChartView(data: sampleData, metric: .words)
    }
    .padding()
    .background(DashboardPalette.background)
    .frame(width: 780)
}
