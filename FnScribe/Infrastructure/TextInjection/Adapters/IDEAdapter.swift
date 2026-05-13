//
//  IDEAdapter.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-28.
//

import Foundation

/// Adapter for IDEs (VS Code, Windsurf, Xcode, JetBrains, etc.)
final class IDEAdapter: TargetAdapter {
    
    // MARK: - TargetAdapter Properties
    
    let bundleIdentifiers: [String] = [
        // VS Code variants
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.visualstudio.code.oss",
        "com.todesktop.230313mzl4w4u92",  // Windsurf/Cursor
        "com.cursor.Cursor",
        
        // Xcode
        "com.apple.dt.Xcode",
        
        // JetBrains IDEs
        "com.jetbrains.intellij",
        "com.jetbrains.intellij.ce",
        "com.jetbrains.WebStorm",
        "com.jetbrains.PhpStorm",
        "com.jetbrains.pycharm",
        "com.jetbrains.pycharm.ce",
        "com.jetbrains.CLion",
        "com.jetbrains.AppCode",
        "com.jetbrains.goland",
        "com.jetbrains.rubymine",
        "com.jetbrains.rider",
        "com.jetbrains.datagrip",
        
        // Other IDEs
        "com.github.atom",
        "org.vim.MacVim",
        "com.panic.Nova",
        "com.panic.Coda2"
    ]
    
    let displayName: String = "IDE"
    
    var priority: Int { 15 }
    
    var preferredMode: InjectionMode { .clipboardPaste }
    
    // MARK: - Configuration
    
    /// Whether to add a trailing newline for code blocks
    var addTrailingNewline: Bool = false
    
    // MARK: - TargetAdapter Methods
    
    func prepareText(_ text: String) -> String {
        var result = text
        
        // Optionally add trailing newline for code
        if addTrailingNewline && !result.hasSuffix("\n") {
            result += "\n"
        }
        
        return result
    }
    
}
