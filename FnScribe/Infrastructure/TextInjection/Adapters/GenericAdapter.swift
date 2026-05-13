//
//  GenericAdapter.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-28.
//

import Foundation

/// Generic fallback adapter for any application not handled by specific adapters
final class GenericAdapter: TargetAdapter {
    
    // MARK: - TargetAdapter Properties
    
    /// Empty - this adapter handles any app not matched by others
    let bundleIdentifiers: [String] = []
    
    let displayName: String = "Generic"
    
    var priority: Int { -1 }  // Lowest priority - fallback
    
    var preferredMode: InjectionMode { .clipboardPaste }
    
    // MARK: - TargetAdapter Methods
    
    func canHandle(bundleId: String) -> Bool {
        // Generic adapter can handle any application
        true
    }
    
    func prepareText(_ text: String) -> String {
        text
    }
}
