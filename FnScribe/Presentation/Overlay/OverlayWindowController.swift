//
//  OverlayWindowController.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Cocoa
import SwiftUI
import Combine

/// Controller managing the overlay window lifecycle and positioning
@MainActor
class OverlayWindowController: ObservableObject {
    
    private var overlayWindow: OverlayWindow?
    private var hostingView: NSHostingView<OverlayView>?
    private var cancellables = Set<AnyCancellable>()
    private var autoHideWorkItem: DispatchWorkItem?
    
    private let appState: AppState
    private let settingsStore: SettingsStore
    private var streamingTranscriber: StreamingTranscriber?
    
    @Published var isVisible: Bool = false
    
    init(appState: AppState, settingsStore: SettingsStore) {
        self.appState = appState
        self.settingsStore = settingsStore
        
        setupObservers()
    }
    
    /// Set the streaming transcriber for real-time transcription display
    func setStreamingTranscriber(_ transcriber: StreamingTranscriber) {
        self.streamingTranscriber = transcriber
        
        // Recreate window if it exists to update the view
        if overlayWindow != nil {
            overlayWindow?.close()
            overlayWindow = nil
            hostingView = nil
        }
    }
    
    private func setupObservers() {
        // Observe recording state changes
        appState.$recordingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
        
        // Observe audio level for position updates when following cursor
        appState.$audioLevel
            .receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updatePositionIfNeeded()
            }
            .store(in: &cancellables)
    }
    
    private func handleStateChange(_ state: RecordingState) {
        guard settingsStore.showOverlay else { return }
        
        switch state {
        case .listening:
            show()
            cancelAutoHide()
            
        case .processing:
            show()
            cancelAutoHide()
            
        case .idle:
            // Show briefly then auto-hide
            scheduleAutoHide(delay: settingsStore.overlayAutoHideDelay)
            
        case .error:
            show()
            scheduleAutoHide(delay: settingsStore.overlayAutoHideDelay + 1.0)
        }
    }
    
    // MARK: - Window Management
    
    func show() {
        guard settingsStore.showOverlay else { return }
        
        if overlayWindow == nil {
            createWindow()
        }
        
        updatePosition()
        overlayWindow?.showOverlay()
        isVisible = true
    }
    
    func hide() {
        overlayWindow?.hideOverlay { [weak self] in
            self?.isVisible = false
        }
    }
    
    private func createWindow() {
        let window = OverlayWindow()
        
        // Use a default streaming transcriber if none is set
        let transcriber = streamingTranscriber ?? StreamingTranscriber()
        
        let overlayView = OverlayView(
            appState: appState,
            streamingTranscriber: transcriber,
            opacity: settingsStore.overlayOpacity,
            streamingEnabled: settingsStore.streamingTranscriptionEnabled
        )
        
        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 18
        hostingView.layer?.masksToBounds = true
        
        window.contentView = hostingView
        
        self.overlayWindow = window
        self.hostingView = hostingView
    }
    
    func updatePosition() {
        guard let window = overlayWindow else { return }
        
        let position = OverlayPosition(rawValue: settingsStore.overlayPosition) ?? .cursor
        window.position(at: position)
    }
    
    private func updatePositionIfNeeded() {
        // Only update position for cursor-following mode during listening
        guard settingsStore.overlayPosition == OverlayPosition.cursor.rawValue,
              appState.recordingState == .listening,
              isVisible else { return }
        
        updatePosition()
    }
    
    // MARK: - Auto-Hide
    
    private func scheduleAutoHide(delay: TimeInterval) {
        cancelAutoHide()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        
        autoHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    private func cancelAutoHide() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        cancelAutoHide()
        overlayWindow?.close()
        overlayWindow = nil
        hostingView = nil
        cancellables.removeAll()
    }
    
    deinit {
        // Note: cleanup() should be called explicitly before deinit on MainActor
    }
}
