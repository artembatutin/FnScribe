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
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                self?.checkClipboardForCorrections()
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        clipboardMonitorTask?.cancel()
        clipboardMonitorTask = nil
        lastInjectedText = nil
        lastInjectionTime = nil
    }
    
    func recordInjection(_ text: String) {
        lastInjectedText = text
        lastInjectionTime = Date()
        previousClipboardContent = NSPasteboard.general.string(forType: .string)
        startMonitoring()
    }
    
    private func checkClipboardForCorrections() {
        guard let lastText = lastInjectedText,
              let lastTime = lastInjectionTime,
              Date().timeIntervalSince(lastTime) < correctionTimeWindow else {
            stopMonitoring()
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
                // Consume the observation; copying again must not learn it twice.
                stopMonitoring()
            }
        }
    }
    
    func detectCorrection(original: String, edited: String) -> CorrectionPair? {
        guard let change = CorrectionDetector.detect(original: original, edited: edited) else { return nil }
        return CorrectionPair(original: change.original, corrected: change.corrected, confidence: change.confidence)
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
    
    func clearRecentCorrections() {
        recentCorrections.removeAll()
    }
}
