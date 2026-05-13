//
//  CorrectionLearner.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AppKit
import Combine

@MainActor
class CorrectionLearner: ObservableObject {
    
    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var recentCorrections: [CorrectionPair] = []
    
    private var lastInjectedText: String?
    private var lastInjectionTime: Date?
    private var clipboardMonitorTask: Task<Void, Never>?
    private var previousClipboardContent: String?
    
    private let correctionTimeWindow: TimeInterval = 30.0
    private let minimumConfidence: Double = 0.5
    
    weak var dictionaryManager: DictionaryManager?
    
    struct CorrectionPair: Identifiable, Equatable {
        let id: UUID
        let original: String
        let corrected: String
        let confidence: Double
        let detectedAt: Date
        
        init(original: String, corrected: String, confidence: Double) {
            self.id = UUID()
            self.original = original
            self.corrected = corrected
            self.confidence = confidence
            self.detectedAt = Date()
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        previousClipboardContent = NSPasteboard.general.string(forType: .string)
        
        clipboardMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5 seconds
                await self?.checkClipboardForCorrections()
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        clipboardMonitorTask?.cancel()
        clipboardMonitorTask = nil
    }
    
    func recordInjection(_ text: String) {
        lastInjectedText = text
        lastInjectionTime = Date()
    }
    
    private func checkClipboardForCorrections() {
        guard let lastText = lastInjectedText,
              let lastTime = lastInjectionTime,
              Date().timeIntervalSince(lastTime) < correctionTimeWindow else {
            return
        }
        
        guard let currentClipboard = NSPasteboard.general.string(forType: .string),
              currentClipboard != previousClipboardContent else {
            return
        }
        
        previousClipboardContent = currentClipboard
        
        if let correction = detectCorrection(original: lastText, edited: currentClipboard) {
            if correction.confidence >= minimumConfidence {
                learn(from: correction)
            }
        }
    }
    
    func detectCorrection(original: String, edited: String) -> CorrectionPair? {
        let originalWords = original.split(separator: " ").map(String.init)
        let editedWords = edited.split(separator: " ").map(String.init)
        
        guard originalWords.count == editedWords.count else {
            return nil
        }
        
        var corrections: [(original: String, corrected: String)] = []
        
        for (origWord, editWord) in zip(originalWords, editedWords) {
            if origWord.lowercased() != editWord.lowercased() {
                let similarity = stringSimilarity(origWord.lowercased(), editWord.lowercased())
                if similarity > 0.3 && similarity < 1.0 {
                    corrections.append((origWord, editWord))
                }
            }
        }
        
        guard corrections.count == 1,
              let correction = corrections.first else {
            return nil
        }
        
        let confidence = calculateConfidence(
            original: correction.original,
            corrected: correction.corrected,
            contextLength: originalWords.count
        )
        
        return CorrectionPair(
            original: correction.original,
            corrected: correction.corrected,
            confidence: confidence
        )
    }
    
    func learn(from correction: CorrectionPair) {
        recentCorrections.insert(correction, at: 0)
        
        if recentCorrections.count > 50 {
            recentCorrections = Array(recentCorrections.prefix(50))
        }
        
        dictionaryManager?.learnFromCorrection(
            original: correction.original,
            corrected: correction.corrected
        )
    }
    
    private func stringSimilarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count >= s2.count ? s1 : s2
        let shorter = s1.count < s2.count ? s1 : s2
        
        if longer.isEmpty {
            return 1.0
        }
        
        let distance = levenshteinDistance(longer, shorter)
        return Double(longer.count - distance) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)
        
        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    private func calculateConfidence(original: String, corrected: String, contextLength: Int) -> Double {
        var confidence = 0.5
        
        let similarity = stringSimilarity(original.lowercased(), corrected.lowercased())
        if similarity > 0.5 {
            confidence += 0.2
        }
        
        if contextLength > 3 {
            confidence += 0.1
        }
        
        if corrected.first?.isUppercase == true && original.first?.isLowercase == true {
            confidence += 0.1
        }
        
        return min(1.0, confidence)
    }
    
    func clearRecentCorrections() {
        recentCorrections.removeAll()
    }
}
