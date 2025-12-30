//
//  WindowMouseTracker.swift
//  Convex
//
//  Created by Brett Bauman on 12/28/25.
//

#if os(macOS)
import SwiftUI
import AppKit

struct WindowMouseTracker: NSViewRepresentable {
    @Binding var isHovering: Bool

    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackingNSView()
        view.onHoverChange = { hovering in
            DispatchQueue.main.async {
                isHovering = hovering
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
}

class MouseTrackingNSView: NSView {
    var onHoverChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }

    private func setupTracking() {
        // Start with not hovering
        updateStoplightButtons(alpha: 0)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove existing tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        // Add new tracking area covering this view's entire bounds
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        updateStoplightButtons(alpha: 1.0)
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        updateStoplightButtons(alpha: 0.0)
        onHoverChange?(false)
    }

    private func updateStoplightButtons(alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            window?.standardWindowButton(.closeButton)?.animator().alphaValue = alpha
            window?.standardWindowButton(.miniaturizeButton)?.animator().alphaValue = alpha
            window?.standardWindowButton(.zoomButton)?.animator().alphaValue = alpha
        }
    }
}
#endif
