//
//  AnalyticsManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine

@MainActor
class AnalyticsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var metrics: UsageMetrics = UsageMetrics()
    @Published private(set) var isLoaded: Bool = false
    
    // MARK: - Constants
    
    private let averageTypingSpeed: Double = 40
    private let averageDictationSpeed: Double = 150
    
    // MARK: - File Management
    
    private let fileManager: FileManager
    private let customMetricsFileURL: URL?
    
    private var metricsFileURL: URL {
        if let customMetricsFileURL {
            return customMetricsFileURL
        }
        return (try? AppSupportPaths.fileURL("usage_metrics.json", fileManager: fileManager)) ??
            fileManager.temporaryDirectory.appendingPathComponent("usage_metrics.json")
    }
    
    // MARK: - Initialization
    
    init(fileManager: FileManager = .default, metricsFileURL: URL? = nil) {
        self.fileManager = fileManager
        self.customMetricsFileURL = metricsFileURL
        loadMetrics()
    }
    
    // MARK: - Recording
    
    func recordSession(_ session: TranscriptionSession) {
        guard session.captureKind == .dictation else { return }

        let timeSaved = calculateTimeSaved(wordCount: session.wordCount)
        
        metrics.recordSession(
            wordCount: session.wordCount,
            characterCount: session.characterCount,
            duration: session.duration,
            timeSaved: timeSaved,
            appBundleId: session.targetApp,
            appName: session.targetApp
        )
        
        saveMetrics()
    }
    
    func recordSession(
        wordCount: Int,
        characterCount: Int,
        duration: TimeInterval,
        appBundleId: String?,
        appName: String?
    ) {
        let timeSaved = calculateTimeSaved(wordCount: wordCount)
        
        metrics.recordSession(
            wordCount: wordCount,
            characterCount: characterCount,
            duration: duration,
            timeSaved: timeSaved,
            appBundleId: appBundleId,
            appName: appName
        )
        
        saveMetrics()
    }
    
    // MARK: - Time Saved Calculation
    
    func calculateTimeSaved(wordCount: Int) -> TimeInterval {
        let typingTime = Double(wordCount) / averageTypingSpeed * 60
        let dictationTime = Double(wordCount) / averageDictationSpeed * 60
        return max(0, typingTime - dictationTime)
    }
    
    // MARK: - Queries
    
    var todayMetrics: UsageMetrics.DailyMetric {
        metrics.getTodayMetrics()
    }
    
    var weekMetrics: [UsageMetrics.DailyMetric] {
        metrics.getWeekMetrics()
    }
    
    var monthMetrics: [UsageMetrics.DailyMetric] {
        metrics.getMonthMetrics()
    }
    
    var topApps: [UsageMetrics.AppMetric] {
        metrics.getTopApps()
    }
    
    func getMetrics(for period: Period) -> [UsageMetrics.DailyMetric] {
        switch period {
        case .today:
            return [metrics.getTodayMetrics()]
        case .week:
            return metrics.getWeekMetrics()
        case .month:
            return metrics.getMonthMetrics()
        case .allTime:
            return metrics.dailyMetrics
        }
    }
    
    func getTotals(for period: Period) -> (sessions: Int, words: Int, timeSaved: TimeInterval) {
        switch period {
        case .today:
            let today = todayMetrics
            return (today.sessions, today.words, today.timeSaved)
        case .week:
            return metrics.getWeeklyTotals()
        case .month:
            return metrics.getMonthlyTotals()
        case .allTime:
            return (metrics.totalSessions, metrics.totalWords, metrics.totalTimeSaved)
        }
    }
    
    func getTopApps(limit: Int = 5) -> [UsageMetrics.AppMetric] {
        metrics.getTopApps(limit: limit)
    }
    
    // MARK: - Trend Calculation
    
    func calculateTrend(for period: Period) -> Trend {
        let currentPeriodMetrics = getMetrics(for: period)
        let currentTotal = currentPeriodMetrics.reduce(0) { $0 + $1.words }
        
        guard currentTotal > 0 else { return .neutral }
        
        let days = period.days
        let previousMetrics = metrics.getMetrics(for: days * 2).prefix(days)
        let previousTotal = previousMetrics.reduce(0) { $0 + $1.words }
        
        guard previousTotal > 0 else { return .up(percent: 100) }
        
        let changePercent = Int(((Double(currentTotal) - Double(previousTotal)) / Double(previousTotal)) * 100)
        
        if changePercent > 0 {
            return .up(percent: changePercent)
        } else if changePercent < 0 {
            return .down(percent: abs(changePercent))
        } else {
            return .neutral
        }
    }
    
    // MARK: - Reset
    
    func resetMetrics() {
        metrics.reset()
        saveMetrics()
    }
    
    // MARK: - Persistence
    
    private func loadMetrics() {
        guard fileManager.fileExists(atPath: metricsFileURL.path) else {
            isLoaded = true
            return
        }
        
        do {
            let data = try Data(contentsOf: metricsFileURL)
            let decoder = JSONDecoder()
            metrics = try decoder.decode(UsageMetrics.self, from: data)
            isLoaded = true
        } catch {
            print("Failed to load usage metrics: \(error)")
            isLoaded = true
        }
    }
    
    private func saveMetrics() {
        do {
            try fileManager.createDirectory(
                at: metricsFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(metrics)
            try data.write(to: metricsFileURL, options: .atomic)
        } catch {
            print("Failed to save usage metrics: \(error)")
        }
    }
    
    // MARK: - Period Enum
    
    enum Period: String, CaseIterable, Identifiable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"
        
        var id: String { rawValue }
        
        var days: Int {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .allTime: return 365
            }
        }
    }
    
    // MARK: - Trend Enum
    
    enum Trend: Equatable {
        case up(percent: Int)
        case down(percent: Int)
        case neutral
        
        var isPositive: Bool {
            switch self {
            case .up: return true
            case .down: return false
            case .neutral: return true
            }
        }
        
        var displayText: String {
            switch self {
            case .up(let percent):
                return "+\(percent)%"
            case .down(let percent):
                return "-\(percent)%"
            case .neutral:
                return "—"
            }
        }
    }
}
