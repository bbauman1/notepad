//
//  ConvexApp.swift
//  Convex
//
//  Created by Brett Bauman on 12/26/25.
//

import SwiftUI

@main
struct NotepadApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @StateObject private var authService = AuthService()
    @StateObject private var convexService: ConvexService

    init() {
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        _convexService = StateObject(wrappedValue: ConvexService(authService: auth))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.authState {
                case .loading:
                    LoadingView(shouldRefreshSession: false)
                case .authenticated:
                    // Only show notes view after both BetterAuth AND Convex authentication complete
                    if convexService.isAuthenticated {
                        #if os(macOS)
                        MacNotesView()
                            .frame(minWidth: 400, idealWidth: 500, maxWidth: 650, minHeight: 264)
                        #else
                        NotesListView()
                        #endif
                    } else {
                        // Waiting for Convex auth - don't refresh session
                        LoadingView(shouldRefreshSession: false)
                    }
                case .unauthenticated:
                    LoginView()
                }
            }
            .environmentObject(authService)
            .environmentObject(convexService)
            .task {
                // Refresh session once at app launch
                // Using .task on the root view ensures it won't get cancelled by view changes
                await authService.refreshSession()
            }
            .onChange(of: authService.authState) { oldState, newState in
                Logger.app.info("Auth state changed: \(String(describing: oldState)) → \(String(describing: newState))")

                if newState == .authenticated && oldState != .authenticated {
                    // Login to Convex when user becomes authenticated
                    Logger.app.info("Triggering Convex login")
                    Task { @MainActor in
                        do {
                            try await convexService.login()
                            Logger.app.info("Convex login successful")

                            // Refresh JWT in background to extend expiration
                            // This uses the stored session token to get a fresh 7-day JWT
                            await authService.refreshJWTInBackground()
                        } catch {
                            Logger.app.error("Convex login failed: \(error.localizedDescription)")
                            // If Convex login fails, the stored JWT is invalid
                            // Sign out to clear invalid tokens and prompt user to re-authenticate
                            Logger.app.info("JWT appears invalid, signing out to clear tokens")
                            await authService.signOut()
                        }
                    }
                } else if newState == .unauthenticated {
                    // Reset Convex authentication when user signs out
                    Logger.app.info("User signed out, resetting Convex auth")
                    convexService.isAuthenticated = false
                }
            }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                // WORKAROUND: Re-authenticate with Convex when window gains focus
                // ConvexMobile has a limitation where the WebSocket connection drops when the window
                // loses focus, and when it reconnects, it doesn't automatically re-send the auth token.
                // This causes "Unauthenticated" errors until we manually call loginFromCache() again.
                // The token is still in the keychain - we're just re-establishing the authenticated connection.
                // This should ideally be fixed in ConvexMobile to auto-reauth on reconnection.
                Logger.app.info("Window became key - authState: \(String(describing: authService.authState))")
                if authService.authState == .authenticated {
                    Logger.app.info("Re-authenticating with Convex...")
                    Task { @MainActor in
                        do {
                            try await convexService.login()
                            Logger.app.info("Convex re-authentication successful")
                        } catch {
                            Logger.app.error("Convex re-authentication failed: \(error.localizedDescription)")
                        }
                    }
                } else {
                    Logger.app.info("Skipping re-auth - not authenticated")
                }
            }
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 500, height: 600)
        .commands {
            TextEditingCommands()
        }
        #endif
    }
}
