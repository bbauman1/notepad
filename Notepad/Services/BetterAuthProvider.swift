//
//  BetterAuthProvider.swift
//  Notepad
//
//  Created by Claude on 12/28/25.
//

import Foundation
import ConvexMobile

/// Custom AuthProvider that integrates BetterAuth with ConvexClientWithAuth
class BetterAuthProvider: AuthProvider {
    typealias T = AuthResult

    // Reference to AuthService for token management
    private weak var authService: AuthService?

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - AuthProvider Protocol

    /// Trigger a login flow
    /// Note: The actual login UI is handled by AuthService/LoginView
    /// This method just returns the cached token if available
    func login() async throws -> AuthResult {
        guard let token = await authService?.getStoredToken() else {
            throw AuthProviderError.notAuthenticated
        }
        return AuthResult(token: token)
    }

    /// Trigger a logout flow
    func logout() async throws {
        // AuthService handles the actual logout
        await authService?.signOut()
    }

    /// Attempt cached re-authentication using stored credentials
    func loginFromCache() async throws -> AuthResult {
        guard let token = await authService?.getStoredToken() else {
            throw AuthProviderError.noCachedCredentials
        }
        return AuthResult(token: token)
    }

    /// Extract the JWT ID token from the authentication result
    func extractIdToken(from authResult: AuthResult) -> String {
        return authResult.token
    }

    // MARK: - Helper Types

    struct AuthResult {
        let token: String
    }

    enum AuthProviderError: LocalizedError {
        case notAuthenticated
        case noCachedCredentials

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "User is not authenticated"
            case .noCachedCredentials:
                return "No cached credentials available"
            }
        }
    }
}
