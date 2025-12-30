//
//  Logger.swift
//  Notepad
//
//  Centralized logging utility using Apple's native OSLog framework.
//  Provides categorized logging with automatic debug-only compilation.
//

import Foundation
import os

enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "notepad"

    static let auth = os.Logger(subsystem: subsystem, category: "auth")
    static let sync = os.Logger(subsystem: subsystem, category: "sync")
    static let ui = os.Logger(subsystem: subsystem, category: "ui")
    static let app = os.Logger(subsystem: subsystem, category: "app")
    static let general = os.Logger(subsystem: subsystem, category: "general")
}
