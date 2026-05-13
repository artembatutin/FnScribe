//
//  TerminalAdapter.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-28.
//

import Foundation

/// Adapter for Terminal applications (Terminal.app, iTerm2)
final class TerminalAdapter: TargetAdapter {
    
    // MARK: - TargetAdapter Properties
    
    let bundleIdentifiers: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "io.alacritty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        "net.kovidgoyal.kitty"
    ]
    
    let displayName: String = "Terminal"
    
    var priority: Int { 10 }
    
    var preferredMode: InjectionMode { .clipboardPaste }
    
    // MARK: - Configuration

    /// Delay before paste in terminal (terminals may need slightly longer)
    var terminalPasteDelay: TimeInterval = 0.08
    
    // MARK: - TargetAdapter Methods
    
    func inject(text: String, using injector: TextInjector) async throws -> InjectionResult {
        let preparedText = prepareText(text)
        
        // Save original settings
        let originalDelay = injector.focusDelay
        injector.focusDelay = terminalPasteDelay
        
        defer {
            injector.focusDelay = originalDelay
        }
        
        return try await injector.inject(text: preparedText, mode: preferredMode)
    }
    
}
