//
//  HotkeyManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine
import Carbon
import HotKey
import AppKit

struct KeyCombo: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32
    
    static let fnKey = KeyCombo(keyCode: UInt32(kVK_Function), modifiers: 0)
    static let controlSpace = KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(NSEvent.ModifierFlags.control.rawValue))
    static let optionSpace = KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(NSEvent.ModifierFlags.option.rawValue))
    static let commandShiftV = KeyCombo(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue))
    
    var displayName: String {
        var parts: [String] = []
        
        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if modifierFlags.contains(.control) { parts.append("⌃") }
        if modifierFlags.contains(.option) { parts.append("⌥") }
        if modifierFlags.contains(.shift) { parts.append("⇧") }
        if modifierFlags.contains(.command) { parts.append("⌘") }
        
        let keyName = keyCodeToString(Int(keyCode))
        parts.append(keyName)
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: Int) -> String {
        switch keyCode {
        case kVK_Function: return "Fn"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return "Key \(keyCode)"
        }
    }
}

enum HotkeyPreset: String, CaseIterable, Identifiable {
    case fn = "fn"
    case controlSpace = "ctrl_space"
    case optionSpace = "opt_space"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fn: return "Fn (Function Key)"
        case .controlSpace: return "Control + Space"
        case .optionSpace: return "Option + Space"
        case .custom: return "Custom"
        }
    }
    
    var keyCombo: KeyCombo? {
        switch self {
        case .fn: return .fnKey
        case .controlSpace: return .controlSpace
        case .optionSpace: return .optionSpace
        case .custom: return nil
        }
    }
}

@MainActor
class HotkeyManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isHotkeyPressed: Bool = false
    @Published private(set) var currentKeyCombo: KeyCombo = .fnKey
    @Published private(set) var isRecordingHotkey: Bool = false
    @Published var lastError: String?
    
    // MARK: - Callbacks
    
    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    var onToggleActivated: (() -> Void)?
    
    // MARK: - Private Properties
    
    private var hotKey: HotKey?
    private var flagsMonitor: Any?
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var hotkeyRecordingCompletion: ((KeyCombo) -> Void)?
    
    private let settingsStore: SettingsStore
    private var triggerMode: TriggerMode { settingsStore.triggerMode }
    
    // For toggle mode state tracking
    private var isToggleActive: Bool = false
    
    // MARK: - Initialization
    
    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        loadSavedKeyCombo()
    }
    
    deinit {
        Task { @MainActor in
            stopListening()
        }
    }
    
    // MARK: - Public Methods
    
    func startListening() {
        guard !isListening else { return }
        
        // For Fn key, we need to use flags changed monitoring
        if currentKeyCombo.keyCode == UInt32(kVK_Function) {
            setupFnKeyMonitoring()
        } else {
            setupHotKeyMonitoring()
        }
        
        isListening = true
    }
    
    func stopListening() {
        hotKey = nil
        
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        
        isListening = false
        isHotkeyPressed = false
        isToggleActive = false
    }
    
    func registerHotkey(_ keyCombo: KeyCombo) {
        stopListening()
        currentKeyCombo = keyCombo
        saveKeyCombo(keyCombo)
        startListening()
    }
    
    func registerPreset(_ preset: HotkeyPreset) {
        guard let keyCombo = preset.keyCombo else { return }
        registerHotkey(keyCombo)
    }
    
    func startRecordingHotkey(completion: @escaping (KeyCombo) -> Void) {
        isRecordingHotkey = true
        hotkeyRecordingCompletion = completion
        
        // Stop current hotkey listening while recording
        stopListening()
        
        // Set up temporary monitors to capture the new hotkey
        setupHotkeyRecording()
    }
    
    func cancelRecordingHotkey() {
        cleanupHotkeyRecording()
        isRecordingHotkey = false
        hotkeyRecordingCompletion = nil
        
        // Resume normal listening
        startListening()
    }
    
    // MARK: - Private Methods - Fn Key Monitoring
    
    private func setupFnKeyMonitoring() {
        // Monitor flags changed events for Fn key
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event)
            }
        }
        
        // Also add local monitor for when app is focused
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleFlagsChanged(event)
            }
            return event
        }
        
        // Store local monitor reference (we'll use keyDownMonitor for this)
        keyDownMonitor = localMonitor
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let fnKeyPressed = event.modifierFlags.contains(.function)
        
        if fnKeyPressed && !isHotkeyPressed {
            // Fn key pressed
            isHotkeyPressed = true
            handleHotkeyDown()
        } else if !fnKeyPressed && isHotkeyPressed {
            // Fn key released
            isHotkeyPressed = false
            handleHotkeyUp()
        }
    }
    
    // MARK: - Private Methods - HotKey Package Monitoring
    
    private func setupHotKeyMonitoring() {
        guard let key = Key(carbonKeyCode: currentKeyCombo.keyCode) else {
            lastError = "Invalid key code"
            return
        }
        
        var modifiers: NSEvent.ModifierFlags = []
        let modifierValue = UInt(currentKeyCombo.modifiers)
        
        if NSEvent.ModifierFlags(rawValue: modifierValue).contains(.control) {
            modifiers.insert(.control)
        }
        if NSEvent.ModifierFlags(rawValue: modifierValue).contains(.option) {
            modifiers.insert(.option)
        }
        if NSEvent.ModifierFlags(rawValue: modifierValue).contains(.shift) {
            modifiers.insert(.shift)
        }
        if NSEvent.ModifierFlags(rawValue: modifierValue).contains(.command) {
            modifiers.insert(.command)
        }
        
        hotKey = HotKey(key: key, modifiers: modifiers)
        
        hotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isHotkeyPressed = true
                self?.handleHotkeyDown()
            }
        }
        
        hotKey?.keyUpHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isHotkeyPressed = false
                self?.handleHotkeyUp()
            }
        }
    }
    
    // MARK: - Private Methods - Trigger Mode Handling
    
    private func handleHotkeyDown() {
        switch triggerMode {
        case .pushToTalk:
            // Start recording immediately on key down
            onHotkeyPressed?()
            
        case .toggle:
            // Toggle state on key down
            isToggleActive.toggle()
            onToggleActivated?()
            
            if isToggleActive {
                onHotkeyPressed?()
            } else {
                onHotkeyReleased?()
            }
        }
    }
    
    private func handleHotkeyUp() {
        switch triggerMode {
        case .pushToTalk:
            // Stop recording on key release
            onHotkeyReleased?()
            
        case .toggle:
            // Do nothing on key up for toggle mode
            break
        }
    }
    
    // MARK: - Private Methods - Hotkey Recording
    
    private func setupHotkeyRecording() {
        // Monitor for key events to capture new hotkey
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleRecordedKey(event)
            }
            return nil // Consume the event
        }
        
        // Also monitor flags for Fn key
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                // Check if only Fn is pressed (no other modifiers)
                if event.modifierFlags.contains(.function) &&
                   !event.modifierFlags.contains(.control) &&
                   !event.modifierFlags.contains(.option) &&
                   !event.modifierFlags.contains(.shift) &&
                   !event.modifierFlags.contains(.command) {
                    self?.finishRecordingHotkey(.fnKey)
                }
            }
            return event
        }
    }
    
    private func handleRecordedKey(_ event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        var modifiers: UInt32 = 0
        
        if event.modifierFlags.contains(.control) {
            modifiers |= UInt32(NSEvent.ModifierFlags.control.rawValue)
        }
        if event.modifierFlags.contains(.option) {
            modifiers |= UInt32(NSEvent.ModifierFlags.option.rawValue)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers |= UInt32(NSEvent.ModifierFlags.shift.rawValue)
        }
        if event.modifierFlags.contains(.command) {
            modifiers |= UInt32(NSEvent.ModifierFlags.command.rawValue)
        }
        
        // Require at least one modifier for non-function keys (except Escape to cancel)
        if keyCode == UInt32(kVK_Escape) {
            cancelRecordingHotkey()
            return
        }
        
        // For regular keys, require a modifier
        if modifiers == 0 && keyCode != UInt32(kVK_Function) {
            lastError = "Please use a modifier key (Ctrl, Option, Shift, or Cmd) with your hotkey"
            return
        }
        
        let keyCombo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        finishRecordingHotkey(keyCombo)
    }
    
    private func finishRecordingHotkey(_ keyCombo: KeyCombo) {
        cleanupHotkeyRecording()
        isRecordingHotkey = false
        
        hotkeyRecordingCompletion?(keyCombo)
        hotkeyRecordingCompletion = nil
        
        registerHotkey(keyCombo)
    }
    
    private func cleanupHotkeyRecording() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
    }
    
    // MARK: - Private Methods - Persistence
    
    private func loadSavedKeyCombo() {
        let keyCode = UInt32(settingsStore.hotkeyKeyCode)
        let modifiers = UInt32(settingsStore.hotkeyModifiers)
        currentKeyCombo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }
    
    private func saveKeyCombo(_ keyCombo: KeyCombo) {
        settingsStore.hotkeyKeyCode = Int(keyCombo.keyCode)
        settingsStore.hotkeyModifiers = Int(keyCombo.modifiers)
    }
    
    // MARK: - Conflict Detection
    
    func checkForConflicts(with keyCombo: KeyCombo) -> Bool {
        // Check common system shortcuts
        let systemShortcuts: [KeyCombo] = [
            KeyCombo(keyCode: UInt32(kVK_Space), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)), // Spotlight
            KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)), // Copy
            KeyCombo(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)), // Paste
            KeyCombo(keyCode: UInt32(kVK_ANSI_X), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)), // Cut
            KeyCombo(keyCode: UInt32(kVK_ANSI_Z), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)), // Undo
            KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)), // Select All
            KeyCombo(keyCode: UInt32(kVK_Tab), modifiers: UInt32(NSEvent.ModifierFlags.command.rawValue)), // App Switcher
        ]
        
        return systemShortcuts.contains(keyCombo)
    }
}
