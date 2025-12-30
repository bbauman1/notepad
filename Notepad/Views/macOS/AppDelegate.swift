//
//  AppDelegate.swift
//  Convex
//
//  Created by Brett Bauman on 12/28/25.
//

#if os(macOS)
import SwiftUI
import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var eventHotKeyRef: EventHotKeyRef?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window closes - we're a menu bar app
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Use accessory activation policy (no Dock icon, menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar icon
        setupMenuBar()

        // Register global hotkey (Cmd+Shift+W)
        registerGlobalHotkey()

        // Listen for hotkey events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleWindow),
            name: NSNotification.Name("GlobalHotkeyPressed"),
            object: nil
        )

        // Configure all windows to disable minimize and maximize buttons
        // and add mouse tracking for hover effects
        for window in NSApplication.shared.windows {
            configureWindow(window)
        }

        // Observe new windows
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                self.configureWindow(window)
            }
        }
    }

    private func setupMenuBar() {
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use SF Symbol for the icon
            button.image = NSImage(systemSymbolName: "scribble.variable", accessibilityDescription: "Notepad")
        }

        // Create menu
        let menu = NSMenu()

        let showHideItem = NSMenuItem(title: "Show/Hide", action: #selector(toggleWindow), keyEquivalent: "w")
        showHideItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(showHideItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Sign Out", action: #selector(signOut), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func registerGlobalHotkey() {
        Logger.app.info("Registering global hotkey Cmd+Shift+W")

        // Register Cmd+Shift+W as global hotkey
        var hotKeyID = EventHotKeyID()
        // Use FourCharCode directly instead of deprecated UTGetOSTypeFromString
        hotKeyID.signature = FourCharCode(0x73776174) // 'swat' in hex
        hotKeyID.id = UInt32(1)

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Cmd+Shift+W (key code 13 is 'w')
        let modifiers = UInt32(cmdKey | shiftKey)

        let handlerResult = InstallEventHandler(GetApplicationEventTarget(), { _, inEvent, _ -> OSStatus in
            Logger.app.info("Hotkey pressed!")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("GlobalHotkeyPressed"), object: nil)
            }
            return noErr
        }, 1, &eventType, nil, nil)

        Logger.app.info("InstallEventHandler result: \(handlerResult)")

        let registerResult = RegisterEventHotKey(13, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &eventHotKeyRef)
        Logger.app.info("RegisterEventHotKey result: \(registerResult)")
    }

    @objc private func toggleWindow() {
        Logger.app.info("toggleWindow called")

        // Find the main app window - the first one that can become key
        // (filter out system windows like alerts, panels, etc.)
        let mainWindows = NSApplication.shared.windows.filter { $0.canBecomeKey }

        guard let window = mainWindows.first else {
            Logger.app.info("No main window found")
            Logger.app.info("All windows: \(NSApplication.shared.windows.map { "title='\($0.title)', canBecomeKey=\($0.canBecomeKey)" }.joined(separator: ", "))")
            return
        }

        Logger.app.info("Window - title: '\(window.title)', isVisible: \(window.isVisible)")

        if window.isVisible && window.isKeyWindow {
            Logger.app.info("Hiding window and switching to accessory mode")
            window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        } else {
            Logger.app.info("Showing window and switching to regular mode")
            // Temporarily become a regular app to show the window
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func signOut() {
        NotificationCenter.default.post(name: NSNotification.Name("SignOutRequested"), object: nil)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func configureWindow(_ window: NSWindow) {
        // Set window size constraints
        window.minSize = NSSize(width: 400, height: 324)
        window.maxSize = NSSize(width: 650, height: CGFloat.greatestFiniteMagnitude)

        // Disable minimize and maximize buttons
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        // Add mouse tracking view as a common superview
        guard let hostingView = window.contentView else { return }

        // Create a container view that will be the new content view
        let containerView = NSView(frame: hostingView.frame)
        containerView.autoresizingMask = [.width, .height]

        // Create and add the tracking view to the container
        let trackingView = MouseTrackingView()
        trackingView.targetWindow = window
        trackingView.frame = containerView.bounds
        trackingView.autoresizingMask = [.width, .height]
        containerView.addSubview(trackingView)

        // Move the hosting view to the container
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingView)

        // Set the container as the window's content view
        window.contentView = containerView
    }
}

class MouseTrackingView: NSView {
    weak var targetWindow: NSWindow?

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

    // Make this view completely transparent to all events
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove existing tracking areas
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        // Add new tracking area covering the entire view
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
    }

    override func mouseExited(with event: NSEvent) {
        updateStoplightButtons(alpha: 0.0)
    }

    private func updateStoplightButtons(alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            targetWindow?.standardWindowButton(.closeButton)?.animator().alphaValue = alpha
            targetWindow?.standardWindowButton(.miniaturizeButton)?.animator().alphaValue = alpha
            targetWindow?.standardWindowButton(.zoomButton)?.animator().alphaValue = alpha
        }
    }
}
#endif
