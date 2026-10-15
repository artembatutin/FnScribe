//
//  OverlayView.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import SwiftUI

/// Main overlay view displaying recording status, audio level, and live transcription preview
struct OverlayView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var streamingTranscriber: StreamingTranscriber
    let opacity: Double
    let streamingEnabled: Bool
    
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Header
            HStack(spacing: 10) {
                statusIndicator
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(statusSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if appState.recordingState == .listening {
                    audioLevelIndicator
                }
            }
            
            // Live streaming transcription (when streaming is enabled and active)
            if streamingEnabled && appState.recordingState == .listening && streamingTranscriber.isStreaming {
                streamingTranscriptionPreview
            }
            
            // Final transcription preview (when available)
            if let transcription = appState.lastTranscription,
               !transcription.isEmpty,
               appState.recordingState == .processing || appState.recordingState == .idle {
                transcriptionPreview(transcription)
            }
        }
        .padding(16)
        .frame(minWidth: 240, maxWidth: 320)
        .background(overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .onAppear {
            pulseAnimation = true
        }
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 36, height: 36)
            
            // Pulse animation for listening state
            if appState.recordingState == .listening {
                Circle()
                    .stroke(statusColor.opacity(0.5), lineWidth: 2)
                    .frame(width: 36, height: 36)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                    .opacity(pulseAnimation ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: pulseAnimation
                    )
            }
            
            // Icon
            if appState.recordingState == .processing {
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
                    .symbolEffect(.pulse, isActive: true)
            } else {
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
            }
        }
    }
    
    private var statusColor: Color {
        switch appState.recordingState {
        case .idle:
            return .green
        case .listening:
            return .orange
        case .processing:
            return .orange
        case .error:
            return .red
        }
    }
    
    private var statusIcon: String {
        switch appState.recordingState {
        case .idle:
            return "checkmark"
        case .listening:
            return "mic.fill"
        case .processing:
            return "waveform"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusTitle: String {
        switch appState.recordingState {
        case .idle:
            return "Done"
        case .listening:
            return "Listening"
        case .processing:
            return "Processing"
        case .error:
            return "Error"
        }
    }
    
    private var statusSubtitle: String {
        switch appState.recordingState {
        case .idle:
            return "Text injected"
        case .listening:
            return "Speak now..."
        case .processing:
            return "Mic stopped. Transcribing..."
        case .error(let message):
            return message
        }
    }
    
    // MARK: - Audio Level Indicator
    
    private var audioLevelIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: displayAudioLevel)
            }
        }
        .frame(height: 24)
    }

    private var displayAudioLevel: Float {
        let clamped = max(0, appState.audioLevel)
        let boosted = pow(clamped, 0.5) * 1.2
        return min(1, boosted)
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / 5.0
        if displayAudioLevel > threshold {
            if index >= 4 {
                return .red
            } else if index >= 3 {
                return .orange
            } else {
                return .green
            }
        }
        return Color.gray.opacity(0.3)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 20
        let threshold = Float(index) / 5.0
        
        if displayAudioLevel > threshold {
            return baseHeight + CGFloat(index + 1) * 3
        }
        return baseHeight + CGFloat(index) * 2
    }
    
    // MARK: - Streaming Transcription Preview
    
    private var streamingTranscriptionPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 0) {
                Text(streamingTranscriber.confirmedText)
                    .foregroundColor(.primary.opacity(0.9))
                
                Text(streamingTranscriber.pendingText)
                    .foregroundColor(.secondary.opacity(0.7))
                    .animation(.easeInOut(duration: 0.15), value: streamingTranscriber.pendingText)
                
                if streamingTranscriber.confirmedText.isEmpty && streamingTranscriber.pendingText.isEmpty {
                    TypingIndicator()
                        .padding(.leading, 4)
                }
            }
            .font(.system(size: 12))
            .lineLimit(3)
            .truncationMode(.head)
        }
    }
    
    // MARK: - Transcription Preview
    
    private func transcriptionPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 4)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.9))
                .lineLimit(3)
                .truncationMode(.tail)
        }
    }
    
    // MARK: - Background
    
    private var overlayBackground: some View {
        ZStack {
            // Blur effect
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            
            // Tint overlay for better contrast
            Color.primary.opacity(0.05)
        }
        .opacity(opacity)
    }
}

/// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    let appState = AppState()
    appState.recordingState = .listening
    appState.audioLevel = 0.6
    let streamingTranscriber = StreamingTranscriber()
    
    return OverlayView(
        appState: appState,
        streamingTranscriber: streamingTranscriber,
        opacity: 0.9,
        streamingEnabled: true
    )
    .frame(width: 300, height: 120)
    .padding()
}
