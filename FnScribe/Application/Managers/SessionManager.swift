//
//  SessionManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine
import AppKit

@MainActor
class SessionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var sessions: [TranscriptionSession] = []
    @Published private(set) var statistics: UsageStatistics = UsageStatistics()
    @Published private(set) var currentSessionStartTime: Date?
    @Published var searchQuery: String = ""
    
    // MARK: - Computed Properties
    
    var filteredSessions: [TranscriptionSession] {
        if searchQuery.isEmpty {
            return sessions
        }
        let query = searchQuery.lowercased()
        return sessions.filter { session in
            session.transcription.lowercased().contains(query) ||
            (session.targetApp?.lowercased().contains(query) ?? false)
        }
    }
    
    var recentSessions: [TranscriptionSession] {
        Array(sessions.prefix(10))
    }
    
    // MARK: - Dependencies
    
    private let settingsStore: SettingsStore
    private let fileManager = FileManager.default
    private let customSessionsFileURL: URL?
    private let customStatisticsFileURL: URL?
    
    // MARK: - File Paths
    
    private var sessionsFileURL: URL {
        if let customSessionsFileURL {
            return customSessionsFileURL
        }

        return (try? AppSupportPaths.fileURL("sessions.json", fileManager: fileManager)) ??
            fileManager.temporaryDirectory.appendingPathComponent("sessions.json")
    }
    
    private var statisticsFileURL: URL {
        if let customStatisticsFileURL {
            return customStatisticsFileURL
        }

        return (try? AppSupportPaths.fileURL("statistics.json", fileManager: fileManager)) ??
            fileManager.temporaryDirectory.appendingPathComponent("statistics.json")
    }
    
    // MARK: - Initialization
    
    init(
        settingsStore: SettingsStore,
        sessionsFileURL: URL? = nil,
        statisticsFileURL: URL? = nil
    ) {
        self.settingsStore = settingsStore
        self.customSessionsFileURL = sessionsFileURL
        self.customStatisticsFileURL = statisticsFileURL
        loadSessions()
        loadStatistics()
        refreshDailyStats()
    }
    
    // MARK: - Session Management
    
    func startSession() {
        currentSessionStartTime = Date()
    }
    
    func endSession(
        transcription: String,
        modelUsed: String,
        targetApp: String? = nil,
        captureKind: CaptureKind = .dictation,
        linkedTaskID: UUID? = nil
    ) {
        guard settingsStore.saveHistory else {
            currentSessionStartTime = nil
            return
        }
        
        let startTime = currentSessionStartTime ?? Date()
        let duration = Date().timeIntervalSince(startTime)
        
        // Get frontmost app if not provided
        let app = targetApp ?? getFrontmostAppName()
        
        let session = TranscriptionSession(
            transcription: transcription,
            targetApp: app,
            duration: duration,
            modelUsed: modelUsed,
            captureKind: captureKind,
            linkedTaskID: linkedTaskID
        )
        
        // Add to beginning of list
        sessions.insert(session, at: 0)
        
        // Update statistics
        statistics.updateForNewSession(session)
        
        // Enforce history limit
        enforceHistoryLimit()
        
        // Persist
        saveSessions()
        saveStatistics()
        
        currentSessionStartTime = nil
    }
    
    func deleteSession(_ session: TranscriptionSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            let removedSession = sessions.remove(at: index)
            statistics.removeSession(removedSession)
            saveSessions()
            saveStatistics()
        }
    }
    
    func deleteSessions(at offsets: IndexSet) {
        let sessionsToDelete = offsets.map { filteredSessions[$0] }
        for session in sessionsToDelete {
            deleteSession(session)
        }
    }
    
    func clearHistory() {
        sessions.removeAll()
        saveSessions()
    }
    
    func resetStatistics() {
        statistics.reset()
        saveStatistics()
    }
    
    // MARK: - Clipboard & Re-injection
    
    func copyToClipboard(_ session: TranscriptionSession) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(session.transcription, forType: .string)
    }
    
    // MARK: - Persistence
    
    private func loadSessions() {
        guard fileManager.fileExists(atPath: sessionsFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: sessionsFileURL)
            let decoder = JSONDecoder()
            sessions = try decoder.decode([TranscriptionSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    private func saveSessions() {
        do {
            try fileManager.createDirectory(
                at: sessionsFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessions)
            try data.write(to: sessionsFileURL, options: .atomic)
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    private func loadStatistics() {
        guard fileManager.fileExists(atPath: statisticsFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: statisticsFileURL)
            let decoder = JSONDecoder()
            statistics = try decoder.decode(UsageStatistics.self, from: data)
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }
    
    private func saveStatistics() {
        do {
            try fileManager.createDirectory(
                at: statisticsFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(statistics)
            try data.write(to: statisticsFileURL, options: .atomic)
        } catch {
            print("Failed to save statistics: \(error)")
        }
    }
    
    // MARK: - History Limit
    
    private func enforceHistoryLimit() {
        let maxItems = max(0, settingsStore.maxHistoryItems)
        if sessions.count > maxItems {
            let sessionsToRemove = sessions.suffix(from: maxItems)
            for session in sessionsToRemove {
                statistics.removeSession(session)
            }
            sessions = Array(sessions.prefix(maxItems))
        }
    }
    
    // MARK: - Daily Stats Refresh
    
    private func refreshDailyStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = statistics.lastSessionDate,
           !calendar.isDate(lastDate, inSameDayAs: today) {
            // Reset daily stats if last session was not today
            statistics.sessionsToday = 0
            statistics.wordsToday = 0
            
            // Recalculate today's stats from sessions
            for session in sessions {
                if calendar.isDate(session.timestamp, inSameDayAs: today) {
                    statistics.sessionsToday += 1
                    statistics.wordsToday += session.wordCount
                }
            }
            
            saveStatistics()
        }
    }
    
    // MARK: - Helpers
    
    private func getFrontmostAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }
    
    // MARK: - Export
    
    func exportSessionsAsText() -> String {
        var output = "\(AppBranding.displayName) Transcription History\n"
        output += "Exported: \(Date().formatted())\n"
        output += "Total Sessions: \(sessions.count)\n"
        output += String(repeating: "=", count: 50) + "\n\n"
        
        for session in sessions {
            output += "Date: \(session.formattedTimestamp)\n"
            output += "Duration: \(session.formattedDuration)\n"
            output += "Model: \(session.modelUsed)\n"
            if let app = session.targetApp {
                output += "App: \(app)\n"
            }
            output += "Transcription:\n\(session.transcription)\n"
            output += String(repeating: "-", count: 50) + "\n\n"
        }
        
        return output
    }
    
    func exportSessionsAsJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(sessions)
    }
}
