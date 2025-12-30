//
//  Config.swift
//  Notepad
//
//  Centralized configuration for development and production environments.
//

import Foundation

enum Config {
    #if DEBUG
    static let authServerURL = "https://notepad-auth.up.railway.app"
    static let convexDeploymentURL = "https://silent-wildebeest-16.convex.cloud"
    #else
    static let authServerURL = "https://notepad-auth.up.railway.app"
    static let convexDeploymentURL = "https://bright-hippopotamus-700.convex.cloud"
    #endif

    static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
