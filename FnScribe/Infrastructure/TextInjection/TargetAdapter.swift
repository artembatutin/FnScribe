//
//  TargetAdapter.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-28.
//

import Foundation
import AppKit

/// Protocol defining a target-specific text injection adapter
protocol TargetAdapter {
    /// Bundle identifier(s) this adapter handles
    var bundleIdentifiers: [String] { get }
    
    /// Display name for this adapter
    var displayName: String { get }
    
    /// Priority for adapter selection (higher = preferred)
    var priority: Int { get }
    
    /// Injects text into the target application
    /// - Parameters:
    ///   - text: The text to inject
    ///   - injector: The base text injector to use for injection
    /// - Returns: The result of the injection
    func inject(text: String, using injector: TextInjector) async throws -> InjectionResult
    
    /// Checks if this adapter can handle the given bundle identifier
    func canHandle(bundleId: String) -> Bool
    
    /// Checks if the target application is currently active
    func isActive() -> Bool
    
    /// Prepares text for injection (e.g., escaping, formatting)
    func prepareText(_ text: String) -> String
    
    /// Preferred injection mode for this adapter
    var preferredMode: InjectionMode { get }
}

/// Default implementations for TargetAdapter
extension TargetAdapter {
    func inject(text: String, using injector: TextInjector) async throws -> InjectionResult {
        try await injector.inject(text: prepareText(text), mode: preferredMode)
    }

    func canHandle(bundleId: String) -> Bool {
        bundleIdentifiers.contains(bundleId)
    }
    
    func isActive() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            return false
        }
        return canHandle(bundleId: bundleId)
    }
    
    func prepareText(_ text: String) -> String {
        text
    }
    
    var priority: Int { 0 }
    
    var preferredMode: InjectionMode { .clipboardPaste }
}

/// Configuration for per-app injection settings
struct AppInjectionConfig: Codable, Identifiable {
    var id: String { bundleId }
    let bundleId: String
    var displayName: String
    var injectionMode: InjectionMode
    var enabled: Bool
    var customDelay: TimeInterval?
    var useMultilinePaste: Bool
    
    init(bundleId: String, displayName: String, injectionMode: InjectionMode = .clipboardPaste, enabled: Bool = true, customDelay: TimeInterval? = nil, useMultilinePaste: Bool = false) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.injectionMode = injectionMode
        self.enabled = enabled
        self.customDelay = customDelay
        self.useMultilinePaste = useMultilinePaste
    }
}
