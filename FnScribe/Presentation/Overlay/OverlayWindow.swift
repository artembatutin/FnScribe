//
//  OverlayWindow.swift
//  FnScribe
//
//  Created by Artem Batutin on 2026-01-27.
//

import Cocoa
import SwiftUI

/// Overlay position options
enum OverlayPosition: String, CaseIterable, Codable {
    case cursor = "cursor"
    case topRight = "topRight"
    case topLeft = "topLeft"
    case bottomRight = "bottomRight"
    case bottomLeft = "bottomLeft"
    case nearNotch = "nearNotch"
    
    var displayName: String {
        switch self {
        case .cursor:
            return "Near Cursor"
        case .topRight:
            return "Top Right"
        case .topLeft:
            return "Top Left"
        case .bottomRight:
            return "Bottom Right"
        case .bottomLeft:
            return "Bottom Left"
        case .nearNotch:
            return "Near Notch"
        }
    }
}

/// A floating, non-activating panel for displaying transcription overlay
class OverlayWindow: NSPanel {
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 100),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
    }
    
    private func configureWindow() {
        // Window behavior
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        // Non-activating behavior
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        
        // Ignore mouse events for click-through (optional, can be toggled)
        ignoresMouseEvents = false
        
        // Title bar
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Animation
        animationBehavior = .utilityWindow
    }
    
    /// Position the overlay based on the selected position option
    func position(at position: OverlayPosition, offset: CGPoint = .zero) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = frame.size
        let padding: CGFloat = 20
        
        var newOrigin: CGPoint
        
        switch position {
        case .cursor:
            let mouseLocation = NSEvent.mouseLocation
            // Position above and to the right of cursor
            newOrigin = CGPoint(
                x: mouseLocation.x + 20,
                y: mouseLocation.y + 20
            )
            // Ensure window stays on screen
            newOrigin = constrainToScreen(origin: newOrigin, windowSize: windowSize, screenFrame: screenFrame)
            
        case .topRight:
            newOrigin = CGPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
            
        case .topLeft:
            newOrigin = CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.maxY - windowSize.height - padding
            )
            
        case .bottomRight:
            newOrigin = CGPoint(
                x: screenFrame.maxX - windowSize.width - padding,
                y: screenFrame.minY + padding
            )
            
        case .bottomLeft:
            newOrigin = CGPoint(
                x: screenFrame.minX + padding,
                y: screenFrame.minY + padding
            )
            
        case .nearNotch:
            // Position near the top center (where notch would be on notched Macs)
            let fullScreenFrame = screen.frame
            newOrigin = CGPoint(
                x: fullScreenFrame.midX - windowSize.width / 2,
                y: fullScreenFrame.maxY - windowSize.height - 50
            )
        }
        
        // Apply offset
        newOrigin.x += offset.x
        newOrigin.y += offset.y
        
        setFrameOrigin(newOrigin)
    }
    
    private func constrainToScreen(origin: CGPoint, windowSize: CGSize, screenFrame: NSRect) -> CGPoint {
        var constrained = origin
        
        // Keep within horizontal bounds
        if constrained.x + windowSize.width > screenFrame.maxX {
            constrained.x = screenFrame.maxX - windowSize.width - 10
        }
        if constrained.x < screenFrame.minX {
            constrained.x = screenFrame.minX + 10
        }
        
        // Keep within vertical bounds
        if constrained.y + windowSize.height > screenFrame.maxY {
            constrained.y = screenFrame.maxY - windowSize.height - 10
        }
        if constrained.y < screenFrame.minY {
            constrained.y = screenFrame.minY + 10
        }
        
        return constrained
    }
    
    /// Show the overlay with animation
    func showOverlay() {
        alphaValue = 0
        orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1.0
        }
    }
    
    /// Hide the overlay with animation
    func hideOverlay(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            completion?()
        })
    }
}
