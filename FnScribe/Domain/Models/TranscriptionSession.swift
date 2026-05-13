//
//  TranscriptionSession.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation

enum CaptureKind: String, Codable, CaseIterable, Identifiable {
    case dictation
    case task

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dictation:
            return "Dictation"
        case .task:
            return "Task"
        }
    }
}

struct TranscriptionSession: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let timestamp: Date
    let transcription: String
    let targetApp: String?
    let duration: TimeInterval
    let modelUsed: String
    let captureKind: CaptureKind
    let linkedTaskID: UUID?
    let wordCount: Int
    let characterCount: Int
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        transcription: String,
        targetApp: String? = nil,
        duration: TimeInterval,
        modelUsed: String,
        captureKind: CaptureKind = .dictation,
        linkedTaskID: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transcription = transcription
        self.targetApp = targetApp
        self.duration = duration
        self.modelUsed = modelUsed
        self.captureKind = captureKind
        self.linkedTaskID = linkedTaskID
        self.wordCount = transcription.split(separator: " ").count
        self.characterCount = transcription.count
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDuration: String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }
    
    var truncatedTranscription: String {
        if transcription.count > 100 {
            return String(transcription.prefix(100)) + "..."
        }
        return transcription
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case transcription
        case targetApp
        case duration
        case modelUsed
        case captureKind
        case linkedTaskID
        case wordCount
        case characterCount
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        transcription = try container.decode(String.self, forKey: .transcription)
        targetApp = try container.decodeIfPresent(String.self, forKey: .targetApp)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        modelUsed = try container.decodeIfPresent(String.self, forKey: .modelUsed) ?? "Unknown"
        captureKind = try container.decodeIfPresent(CaptureKind.self, forKey: .captureKind) ?? .dictation
        linkedTaskID = try container.decodeIfPresent(UUID.self, forKey: .linkedTaskID)
        let computedWordCount = transcription.split(separator: " ").count
        let computedCharacterCount = transcription.count
        wordCount = max(0, try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? computedWordCount)
        characterCount = max(0, try container.decodeIfPresent(Int.self, forKey: .characterCount) ?? computedCharacterCount)
    }
}

// MARK: - Usage Statistics

struct UsageStatistics: Codable, Equatable {
    var totalSessions: Int
    var totalWords: Int
    var totalCharacters: Int
    var totalDuration: TimeInterval
    var sessionsToday: Int
    var wordsToday: Int
    var lastSessionDate: Date?
    
    init() {
        self.totalSessions = 0
        self.totalWords = 0
        self.totalCharacters = 0
        self.totalDuration = 0
        self.sessionsToday = 0
        self.wordsToday = 0
        self.lastSessionDate = nil
    }
    
    var formattedTotalDuration: String {
        let totalSeconds = Int(totalDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var estimatedTimeSaved: String {
        // Estimate: typing at 40 WPM vs speaking at 150 WPM
        // Time saved = characters / 5 (avg word length) * (1/40 - 1/150) minutes
        let wordsTyped = Double(totalCharacters) / 5.0
        let typingTime = wordsTyped / 40.0 // minutes at 40 WPM
        let speakingTime = wordsTyped / 150.0 // minutes at 150 WPM
        let timeSavedMinutes = max(0, typingTime - speakingTime)
        
        if timeSavedMinutes >= 60 {
            let hours = Int(timeSavedMinutes / 60)
            let minutes = Int(timeSavedMinutes.truncatingRemainder(dividingBy: 60))
            return "\(hours)h \(minutes)m"
        } else {
            return "\(Int(timeSavedMinutes))m"
        }
    }
    
    mutating func updateForNewSession(_ session: TranscriptionSession) {
        totalSessions += 1
        totalWords += session.wordCount
        totalCharacters += session.characterCount
        totalDuration += session.duration
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastSessionDate, calendar.isDate(lastDate, inSameDayAs: today) {
            sessionsToday += 1
            wordsToday += session.wordCount
        } else {
            // Reset daily stats
            sessionsToday = 1
            wordsToday = session.wordCount
        }
        
        lastSessionDate = session.timestamp
    }
    
    mutating func removeSession(_ session: TranscriptionSession) {
        totalSessions = max(0, totalSessions - 1)
        totalWords = max(0, totalWords - session.wordCount)
        totalCharacters = max(0, totalCharacters - session.characterCount)
        totalDuration = max(0, totalDuration - session.duration)
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if calendar.isDate(session.timestamp, inSameDayAs: today) {
            sessionsToday = max(0, sessionsToday - 1)
            wordsToday = max(0, wordsToday - session.wordCount)
        }
    }
    
    mutating func reset() {
        self = UsageStatistics()
    }
}
