//
//  UsageMetrics.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

struct UsageMetrics: Codable, Equatable {
    
    // MARK: - Daily Aggregates
    
    var dailyMetrics: [DailyMetric] = []
    
    // MARK: - Lifetime Totals
    
    var totalSessions: Int = 0
    var totalWords: Int = 0
    var totalCharacters: Int = 0
    var totalDuration: TimeInterval = 0
    var totalTimeSaved: TimeInterval = 0
    
    // MARK: - Per-App Breakdown
    
    var appUsage: [String: AppMetric] = [:]
    
    // MARK: - Streaks
    
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date?
    
    // MARK: - Daily Metric
    
    struct DailyMetric: Codable, Identifiable, Equatable {
        var id: String { dateString }
        let dateString: String
        var sessions: Int
        var words: Int
        var characters: Int
        var duration: TimeInterval
        var timeSaved: TimeInterval
        
        init(dateString: String, sessions: Int = 0, words: Int = 0, characters: Int = 0, duration: TimeInterval = 0, timeSaved: TimeInterval = 0) {
            self.dateString = dateString
            self.sessions = sessions
            self.words = words
            self.characters = characters
            self.duration = duration
            self.timeSaved = timeSaved
        }
        
        var date: Date? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateString)
        }
        
        var displayDate: String {
            guard let date = date else { return dateString }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        
        var shortDayName: String {
            guard let date = date else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
    
    // MARK: - App Metric
    
    struct AppMetric: Codable, Identifiable, Equatable {
        var id: String { bundleId }
        var bundleId: String
        var appName: String
        var sessions: Int
        var words: Int
        var lastUsed: Date
        
        init(bundleId: String, appName: String, sessions: Int = 0, words: Int = 0, lastUsed: Date = Date()) {
            self.bundleId = bundleId
            self.appName = appName
            self.sessions = sessions
            self.words = words
            self.lastUsed = lastUsed
        }
    }
    
    // MARK: - Computed Properties
    
    var formattedTotalDuration: String {
        formatDuration(totalDuration)
    }
    
    var formattedTimeSaved: String {
        formatDuration(totalTimeSaved)
    }
    
    var averageWordsPerSession: Int {
        guard totalSessions > 0 else { return 0 }
        return totalWords / totalSessions
    }
    
    var averageSessionDuration: TimeInterval {
        guard totalSessions > 0 else { return 0 }
        return totalDuration / Double(totalSessions)
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Mutations
    
    mutating func recordSession(
        wordCount: Int,
        characterCount: Int,
        duration: TimeInterval,
        timeSaved: TimeInterval,
        appBundleId: String?,
        appName: String?
    ) {
        let today = UsageMetrics.dateString(for: Date())
        
        // Update lifetime totals
        totalSessions += 1
        totalWords += wordCount
        totalCharacters += characterCount
        totalDuration += duration
        totalTimeSaved += timeSaved
        
        // Update or create daily metric
        if let index = dailyMetrics.firstIndex(where: { $0.dateString == today }) {
            dailyMetrics[index].sessions += 1
            dailyMetrics[index].words += wordCount
            dailyMetrics[index].characters += characterCount
            dailyMetrics[index].duration += duration
            dailyMetrics[index].timeSaved += timeSaved
        } else {
            let newMetric = DailyMetric(
                dateString: today,
                sessions: 1,
                words: wordCount,
                characters: characterCount,
                duration: duration,
                timeSaved: timeSaved
            )
            dailyMetrics.append(newMetric)
            
            // Keep only last 90 days of daily metrics
            if dailyMetrics.count > 90 {
                dailyMetrics.removeFirst(dailyMetrics.count - 90)
            }
        }
        
        // Update app usage
        if let bundleId = appBundleId {
            let name = appName ?? bundleId
            if var existing = appUsage[bundleId] {
                existing.sessions += 1
                existing.words += wordCount
                existing.lastUsed = Date()
                appUsage[bundleId] = existing
            } else {
                appUsage[bundleId] = AppMetric(
                    bundleId: bundleId,
                    appName: name,
                    sessions: 1,
                    words: wordCount,
                    lastUsed: Date()
                )
            }
        }
        
        // Update streaks
        updateStreak()
    }
    
    private mutating func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastActiveDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDiff == 0 {
                // Same day, streak continues
            } else if daysDiff == 1 {
                // Next day, increment streak
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                // Streak broken
                currentStreak = 1
            }
        } else {
            // First session ever
            currentStreak = 1
            longestStreak = 1
        }
        
        lastActiveDate = Date()
    }
    
    mutating func reset() {
        self = UsageMetrics()
    }
    
    // MARK: - Query Methods
    
    func getMetrics(for days: Int) -> [DailyMetric] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var result: [DailyMetric] = []
        
        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dateStr = UsageMetrics.dateString(for: date)
            
            if let existing = dailyMetrics.first(where: { $0.dateString == dateStr }) {
                result.append(existing)
            } else {
                result.append(DailyMetric(dateString: dateStr))
            }
        }
        
        return result
    }
    
    func getTodayMetrics() -> DailyMetric {
        let today = UsageMetrics.dateString(for: Date())
        return dailyMetrics.first(where: { $0.dateString == today }) ?? DailyMetric(dateString: today)
    }
    
    func getWeekMetrics() -> [DailyMetric] {
        getMetrics(for: 7)
    }
    
    func getMonthMetrics() -> [DailyMetric] {
        getMetrics(for: 30)
    }
    
    func getTopApps(limit: Int = 5) -> [AppMetric] {
        Array(appUsage.values.sorted { $0.sessions > $1.sessions }.prefix(limit))
    }
    
    func getWeeklyTotals() -> (sessions: Int, words: Int, timeSaved: TimeInterval) {
        let weekMetrics = getWeekMetrics()
        let sessions = weekMetrics.reduce(0) { $0 + $1.sessions }
        let words = weekMetrics.reduce(0) { $0 + $1.words }
        let timeSaved = weekMetrics.reduce(0) { $0 + $1.timeSaved }
        return (sessions, words, timeSaved)
    }
    
    func getMonthlyTotals() -> (sessions: Int, words: Int, timeSaved: TimeInterval) {
        let monthMetrics = getMonthMetrics()
        let sessions = monthMetrics.reduce(0) { $0 + $1.sessions }
        let words = monthMetrics.reduce(0) { $0 + $1.words }
        let timeSaved = monthMetrics.reduce(0) { $0 + $1.timeSaved }
        return (sessions, words, timeSaved)
    }
}
