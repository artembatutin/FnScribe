//
//  ClaudeCodeAdapter.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-28.
//

import Foundation
import AppKit

/// Adapter for Claude Code terminal sessions
/// Claude Code runs within terminal applications, so we detect it by window title or context
final class ClaudeCodeAdapter: TargetAdapter {
    
    // MARK: - TargetAdapter Properties
    
    /// Claude Code runs in terminals, so we check for terminal bundle IDs
    /// but with additional context detection
    let bundleIdentifiers: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "io.alacritty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        "net.kovidgoyal.kitty"
    ]
    
    let displayName: String = "Claude Code"
    
    var priority: Int { 20 }  // Higher than terminal adapter
    
    var preferredMode: InjectionMode { .clipboardPaste }
    
    // MARK: - Configuration
    
    /// Keywords to detect Claude Code sessions in window titles
    private let claudeCodeIndicators: [String] = [
        "claude",
        "Claude",
        "CLAUDE",
        "claude-code",
        "anthropic"
    ]
    
    // MARK: - TargetAdapter Methods
    
    func canHandle(bundleId: String) -> Bool {
        // First check if it's a terminal
        guard bundleIdentifiers.contains(bundleId) else {
            return false
        }
        
        // Then check if it appears to be a Claude Code session
        return isClaudeCodeSession()
    }
    
    func isActive() -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontmostApp.bundleIdentifier else {
            return false
        }
        return canHandle(bundleId: bundleId)
    }
    
    // MARK: - Claude Code Detection
    
    /// Attempts to detect if the current terminal session is Claude Code
    private func isClaudeCodeSession() -> Bool {
        // Try to get the window title of the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        // Check window titles using Accessibility API
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return false
        }
        
        for window in windows {
            var titleRef: CFTypeRef?
            let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            
            if titleResult == .success, let title = titleRef as? String {
                for indicator in claudeCodeIndicators {
                    if title.contains(indicator) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
}
