//
//  TextInjector.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import AppKit
import Carbon.HIToolbox

/// Errors that can occur during text injection
enum TextInjectionError: LocalizedError {
    case accessibilityNotGranted
    case inputMonitoringNotGranted
    case clipboardOperationFailed
    case keystrokeSimulationFailed
    case noFrontmostApplication
    case injectionTimeout
    
    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required for text injection"
        case .inputMonitoringNotGranted:
            return "Input Monitoring permission is required for keystroke simulation"
        case .clipboardOperationFailed:
            return "Failed to access clipboard"
        case .keystrokeSimulationFailed:
            return "Failed to simulate keystrokes"
        case .noFrontmostApplication:
            return "No frontmost application detected"
        case .injectionTimeout:
            return "Text injection timed out"
        }
    }
}

/// Result of a text injection operation
struct InjectionResult {
    let success: Bool
    let charactersInjected: Int
    let method: InjectionMode
    let targetApp: String?
    let duration: TimeInterval
}

/// Handles text injection into any application using various methods
class TextInjector {
    
    // MARK: - Configuration
    
    /// Threshold for hybrid mode - text shorter than this uses keystrokes
    var hybridThreshold: Int = 50
    
    /// Delay between keystrokes in seconds
    var keystrokeDelay: TimeInterval = 0.01
    
    /// Delay before paste operation to allow focus
    var focusDelay: TimeInterval = 0.05
    
    /// Whether to preserve clipboard contents
    var preserveClipboard: Bool = true
    
    // MARK: - Private Properties
    
    private var savedClipboardContents: [NSPasteboard.PasteboardType: Data]?
    
    // MARK: - Keycode Mapping
    
    /// Maps characters to their virtual keycodes
    private static let keycodeMap: [Character: (keycode: CGKeyCode, shift: Bool)] = {
        var map: [Character: (CGKeyCode, Bool)] = [:]
        
        // Letters (lowercase)
        let letters: [(Character, CGKeyCode)] = [
            ("a", CGKeyCode(kVK_ANSI_A)), ("b", CGKeyCode(kVK_ANSI_B)), ("c", CGKeyCode(kVK_ANSI_C)),
            ("d", CGKeyCode(kVK_ANSI_D)), ("e", CGKeyCode(kVK_ANSI_E)), ("f", CGKeyCode(kVK_ANSI_F)),
            ("g", CGKeyCode(kVK_ANSI_G)), ("h", CGKeyCode(kVK_ANSI_H)), ("i", CGKeyCode(kVK_ANSI_I)),
            ("j", CGKeyCode(kVK_ANSI_J)), ("k", CGKeyCode(kVK_ANSI_K)), ("l", CGKeyCode(kVK_ANSI_L)),
            ("m", CGKeyCode(kVK_ANSI_M)), ("n", CGKeyCode(kVK_ANSI_N)), ("o", CGKeyCode(kVK_ANSI_O)),
            ("p", CGKeyCode(kVK_ANSI_P)), ("q", CGKeyCode(kVK_ANSI_Q)), ("r", CGKeyCode(kVK_ANSI_R)),
            ("s", CGKeyCode(kVK_ANSI_S)), ("t", CGKeyCode(kVK_ANSI_T)), ("u", CGKeyCode(kVK_ANSI_U)),
            ("v", CGKeyCode(kVK_ANSI_V)), ("w", CGKeyCode(kVK_ANSI_W)), ("x", CGKeyCode(kVK_ANSI_X)),
            ("y", CGKeyCode(kVK_ANSI_Y)), ("z", CGKeyCode(kVK_ANSI_Z))
        ]
        
        for (char, keycode) in letters {
            map[char] = (keycode, false)
            map[Character(char.uppercased())] = (keycode, true)
        }
        
        // Numbers
        let numbers: [(Character, CGKeyCode)] = [
            ("1", CGKeyCode(kVK_ANSI_1)), ("2", CGKeyCode(kVK_ANSI_2)), ("3", CGKeyCode(kVK_ANSI_3)),
            ("4", CGKeyCode(kVK_ANSI_4)), ("5", CGKeyCode(kVK_ANSI_5)), ("6", CGKeyCode(kVK_ANSI_6)),
            ("7", CGKeyCode(kVK_ANSI_7)), ("8", CGKeyCode(kVK_ANSI_8)), ("9", CGKeyCode(kVK_ANSI_9)),
            ("0", CGKeyCode(kVK_ANSI_0))
        ]
        
        for (char, keycode) in numbers {
            map[char] = (keycode, false)
        }
        
        // Shifted number symbols
        let shiftedNumbers: [(Character, CGKeyCode)] = [
            ("!", CGKeyCode(kVK_ANSI_1)), ("@", CGKeyCode(kVK_ANSI_2)), ("#", CGKeyCode(kVK_ANSI_3)),
            ("$", CGKeyCode(kVK_ANSI_4)), ("%", CGKeyCode(kVK_ANSI_5)), ("^", CGKeyCode(kVK_ANSI_6)),
            ("&", CGKeyCode(kVK_ANSI_7)), ("*", CGKeyCode(kVK_ANSI_8)), ("(", CGKeyCode(kVK_ANSI_9)),
            (")", CGKeyCode(kVK_ANSI_0))
        ]
        
        for (char, keycode) in shiftedNumbers {
            map[char] = (keycode, true)
        }
        
        // Punctuation and symbols (unshifted)
        let punctuation: [(Character, CGKeyCode)] = [
            ("-", CGKeyCode(kVK_ANSI_Minus)), ("=", CGKeyCode(kVK_ANSI_Equal)),
            ("[", CGKeyCode(kVK_ANSI_LeftBracket)), ("]", CGKeyCode(kVK_ANSI_RightBracket)),
            ("\\", CGKeyCode(kVK_ANSI_Backslash)), (";", CGKeyCode(kVK_ANSI_Semicolon)),
            ("'", CGKeyCode(kVK_ANSI_Quote)), ("`", CGKeyCode(kVK_ANSI_Grave)),
            (",", CGKeyCode(kVK_ANSI_Comma)), (".", CGKeyCode(kVK_ANSI_Period)),
            ("/", CGKeyCode(kVK_ANSI_Slash))
        ]
        
        for (char, keycode) in punctuation {
            map[char] = (keycode, false)
        }
        
        // Shifted punctuation
        let shiftedPunctuation: [(Character, CGKeyCode)] = [
            ("_", CGKeyCode(kVK_ANSI_Minus)), ("+", CGKeyCode(kVK_ANSI_Equal)),
            ("{", CGKeyCode(kVK_ANSI_LeftBracket)), ("}", CGKeyCode(kVK_ANSI_RightBracket)),
            ("|", CGKeyCode(kVK_ANSI_Backslash)), (":", CGKeyCode(kVK_ANSI_Semicolon)),
            ("\"", CGKeyCode(kVK_ANSI_Quote)), ("~", CGKeyCode(kVK_ANSI_Grave)),
            ("<", CGKeyCode(kVK_ANSI_Comma)), (">", CGKeyCode(kVK_ANSI_Period)),
            ("?", CGKeyCode(kVK_ANSI_Slash))
        ]
        
        for (char, keycode) in shiftedPunctuation {
            map[char] = (keycode, true)
        }
        
        // Special keys
        map[" "] = (CGKeyCode(kVK_Space), false)
        map["\t"] = (CGKeyCode(kVK_Tab), false)
        map["\n"] = (CGKeyCode(kVK_Return), false)
        map["\r"] = (CGKeyCode(kVK_Return), false)
        
        return map
    }()
    
    // MARK: - Public Methods
    
    /// Injects text using the specified mode
    /// - Parameters:
    ///   - text: The text to inject
    ///   - mode: The injection mode to use
    /// - Returns: Result of the injection operation
    func inject(text: String, mode: InjectionMode) async throws -> InjectionResult {
        guard !text.isEmpty else {
            return InjectionResult(
                success: true,
                charactersInjected: 0,
                method: mode,
                targetApp: getFrontmostAppName(),
                duration: 0
            )
        }
        
        let startTime = Date()
        let targetApp = getFrontmostAppName()
        
        // Verify accessibility permission
        guard AXIsProcessTrusted() else {
            throw TextInjectionError.accessibilityNotGranted
        }
        
        switch mode {
        case .clipboardPaste:
            try await injectViaClipboard(text: text)
        case .keystrokeSimulation:
            try await injectViaKeystrokes(text: text)
        case .hybrid:
            if text.count <= hybridThreshold {
                try await injectViaKeystrokes(text: text)
            } else {
                try await injectViaClipboard(text: text)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return InjectionResult(
            success: true,
            charactersInjected: text.count,
            method: mode,
            targetApp: targetApp,
            duration: duration
        )
    }
    
    // MARK: - Clipboard Methods
    
    /// Saves the current clipboard contents
    func saveClipboard() -> [NSPasteboard.PasteboardType: Data]? {
        let pasteboard = NSPasteboard.general
        var contents: [NSPasteboard.PasteboardType: Data] = [:]
        
        guard let types = pasteboard.types else { return nil }
        
        for type in types {
            if let data = pasteboard.data(forType: type) {
                contents[type] = data
            }
        }
        
        return contents.isEmpty ? nil : contents
    }
    
    /// Restores previously saved clipboard contents
    func restoreClipboard(_ contents: [NSPasteboard.PasteboardType: Data]?) {
        guard let contents = contents, !contents.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        for (type, data) in contents {
            pasteboard.setData(data, forType: type)
        }
    }
    
    /// Copies text to the clipboard
    private func copyToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
    
    // MARK: - Injection Methods
    
    /// Injects text via clipboard paste (Cmd+V)
    private func injectViaClipboard(text: String) async throws {
        // Save clipboard if needed
        if preserveClipboard {
            savedClipboardContents = saveClipboard()
        }
        
        // Copy text to clipboard
        guard copyToClipboard(text) else {
            throw TextInjectionError.clipboardOperationFailed
        }
        
        // Small delay to ensure clipboard is ready
        try await Task.sleep(nanoseconds: UInt64(focusDelay * 1_000_000_000))
        
        // Simulate Cmd+V
        simulatePaste()
        
        // Small delay to ensure paste completes
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Restore clipboard if needed
        if preserveClipboard {
            restoreClipboard(savedClipboardContents)
            savedClipboardContents = nil
        }
    }
    
    /// Simulates Cmd+V keystroke
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down with Command modifier
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        // Key up with Command modifier
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
    
    /// Injects text via keystroke simulation
    private func injectViaKeystrokes(text: String) async throws {
        for char in text {
            try await simulateKeystroke(for: char)
            
            if keystrokeDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(keystrokeDelay * 1_000_000_000))
            }
        }
    }
    
    /// Simulates a keystroke for a single character
    private func simulateKeystroke(for character: Character) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Check if we have a direct keycode mapping
        if let mapping = Self.keycodeMap[character] {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: mapping.keycode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: mapping.keycode, keyDown: false)
            
            if mapping.shift {
                keyDown?.flags = .maskShift
                keyUp?.flags = .maskShift
            }
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        } else {
            // For Unicode characters not in our map, use the Unicode input method
            try await simulateUnicodeInput(for: character)
        }
    }
    
    /// Simulates Unicode character input using CGEvent's Unicode support
    private func simulateUnicodeInput(for character: Character) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Convert character to UTF-16 code units
        let utf16 = Array(String(character).utf16)
        
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            throw TextInjectionError.keystrokeSimulationFailed
        }
        
        // Set the Unicode string
        event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        event.post(tap: .cghidEventTap)
        
        // Key up event
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Target Application
    
    /// Gets the name of the frontmost application
    func getFrontmostAppName() -> String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }
    
    /// Gets the bundle identifier of the frontmost application
    func getFrontmostAppBundleId() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    /// Checks if a specific application is frontmost
    func isAppFrontmost(bundleId: String) -> Bool {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleId
    }
    
    /// Gets the frontmost application
    func getFrontmostApp() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }
    
    /// Activates (brings to front) a specific application
    /// - Parameter app: The application to activate
    /// - Returns: True if activation was successful
    @discardableResult
    func activateApp(_ app: NSRunningApplication) -> Bool {
        return app.activate(options: [.activateIgnoringOtherApps])
    }
    
    /// Activates an application by bundle identifier
    /// - Parameter bundleId: The bundle identifier of the app to activate
    /// - Returns: True if activation was successful
    @discardableResult
    func activateApp(bundleId: String) -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
            return false
        }
        return activateApp(app)
    }
}
