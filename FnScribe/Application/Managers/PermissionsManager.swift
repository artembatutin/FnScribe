//
//  PermissionsManager.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Foundation
import Combine
import AVFoundation
import Speech
import Cocoa

@MainActor
class PermissionsManager: ObservableObject {
    
    @Published private(set) var microphoneGranted: Bool = false
    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var inputMonitoringGranted: Bool = false
    @Published private(set) var speechRecognitionGranted: Bool = false
    
    var allPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted && inputMonitoringGranted
    }
    
    var criticalPermissionsGranted: Bool {
        microphoneGranted && accessibilityGranted
    }
    
    init() {
        refreshAllPermissions()
    }
    
    // MARK: - Refresh All Permissions
    
    func refreshAllPermissions() {
        checkMicrophoneAccess()
        checkAccessibilityAccess()
        checkInputMonitoringAccess()
        checkSpeechRecognitionAccess()
    }
    
    // MARK: - Microphone Access
    
    private func checkMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined, .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }
    
    func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            microphoneGranted = true
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneGranted = granted
            return granted
        case .denied, .restricted:
            microphoneGranted = false
            return false
        @unknown default:
            microphoneGranted = false
            return false
        }
    }
    
    // MARK: - Accessibility Access
    
    private func checkAccessibilityAccess() {
        accessibilityGranted = AXIsProcessTrusted()
    }
    
    func checkAccessibilityAccess(prompt: Bool) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = trusted
        return trusted
    }
    
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Input Monitoring Access
    
    private func checkInputMonitoringAccess() {
        // Input Monitoring is checked via IOHIDRequestAccess or by attempting to create an event tap
        // For now, we'll use a simple check - if we can create a passive event tap, we have access
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        if let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, _ in Unmanaged.passRetained(event) },
            userInfo: nil
        ) {
            // We have access - clean up the test tap
            CFMachPortInvalidate(eventTap)
            inputMonitoringGranted = true
        } else {
            inputMonitoringGranted = false
        }
    }
    
    func checkInputMonitoringAccess(prompt: Bool) -> Bool {
        if prompt {
            // Trigger the system prompt by attempting to create an event tap
            let eventMask = (1 << CGEventType.keyDown.rawValue)
            if let eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { _, _, event, _ in Unmanaged.passRetained(event) },
                userInfo: nil
            ) {
                CFMachPortInvalidate(eventTap)
                inputMonitoringGranted = true
                return true
            } else {
                inputMonitoringGranted = false
                return false
            }
        } else {
            checkInputMonitoringAccess()
            return inputMonitoringGranted
        }
    }
    
    func openInputMonitoringSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Speech Recognition Access
    
    private func checkSpeechRecognitionAccess() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionGranted = true
        case .notDetermined, .denied, .restricted:
            speechRecognitionGranted = false
        @unknown default:
            speechRecognitionGranted = false
        }
    }
    
    func requestSpeechRecognition() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    switch status {
                    case .authorized:
                        self.speechRecognitionGranted = true
                        continuation.resume(returning: true)
                    case .denied, .restricted, .notDetermined:
                        self.speechRecognitionGranted = false
                        continuation.resume(returning: false)
                    @unknown default:
                        self.speechRecognitionGranted = false
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
}
