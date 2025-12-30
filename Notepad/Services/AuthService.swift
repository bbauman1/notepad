//
//  AuthService.swift
//  Notepad
//
//  Created by Claude on 12/28/25.
//

import Foundation
import AuthenticationServices
import BetterAuth

@MainActor
class AuthService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var authState: AuthState = .loading
    @Published var user: User?
    @Published var errorMessage: String?

    // MARK: - Auth State

    enum AuthState {
        case loading
        case authenticated
        case unauthenticated
    }

    // MARK: - Private Properties

    private let betterAuthClient: BetterAuthClient
    private let keychainTokenKey = "com.notepad.authToken"
    private let keychainSessionTokenKey = "com.notepad.sessionToken"
    private var isRefreshing = false

    static let appScheme = "bbauman-notepad://" // URL scheme for OAuth callbacks

    // MARK: - Initialization

    override init() {
        // Initialize BetterAuth client
        self.betterAuthClient = BetterAuthClient(
            baseURL: URL(string: Config.authServerURL)!,
            scheme: AuthService.appScheme
        )
        super.init()

        // Log cookie storage info for debugging
        if let cookies = HTTPCookieStorage.shared.cookies {
            Logger.auth.info("Found \(cookies.count) stored cookies")
        } else {
            Logger.auth.info("No cookies found in storage")
        }
    }

    // MARK: - Session Management

    func refreshSession() async {
        Logger.auth.info("refreshSession called")

        // Prevent concurrent refresh attempts
        guard !isRefreshing else {
            Logger.auth.info("Refresh already in progress, skipping")
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        // Check if we have a stored JWT token
        guard retrieveToken() != nil else {
            Logger.auth.info("No stored JWT token found")
            await MainActor.run {
                self.authState = .unauthenticated
            }
            return
        }

        Logger.auth.info("Found stored JWT token, attempting to use it directly...")

        // First check if we already have a valid session (cookies still work)
        if let existingSession = betterAuthClient.session.data {
            Logger.auth.info("Already have valid BetterAuth session, user: \(existingSession.user.email)")
            await MainActor.run {
                self.user = User(sessionUser: existingSession.user)
                self.authState = .authenticated
            }
            return
        }

        // On macOS, cookies don't persist, so we can't refresh the session
        // But we still have the JWT in keychain, which Convex can use
        // If the JWT is expired, Convex will reject it and we'll need to re-authenticate
        Logger.auth.info("No active BetterAuth session (cookies missing), but JWT exists in keychain")
        Logger.auth.info("Marking as authenticated - Convex will validate the JWT")

        await MainActor.run {
            // Mark as authenticated with the stored JWT
            // If JWT is invalid/expired, Convex login will fail and user will need to sign in
            self.authState = .authenticated
        }
    }

    func signOut() async {
        do {
            _ = try await betterAuthClient.signOut()
        } catch {
            Logger.auth.error("Sign out error: \(error.localizedDescription)")
        }

        // Clear local state regardless of server response
        clearToken()
        clearSessionToken()
        await MainActor.run {
            self.user = nil
            self.authState = .unauthenticated
            self.errorMessage = nil
        }
    }

    // MARK: - Apple Sign In

    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        // Request user's name and email
        request.requestedScopes = [.fullName, .email]
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                await MainActor.run {
                    self.errorMessage = "Invalid Apple credentials"
                }
                return
            }

            await signInWithApple(credential: appleIDCredential)

        case .failure(let error):
            let errorCode = (error as NSError).code
            // Don't show error if user cancelled
            if errorCode != ASAuthorizationError.canceled.rawValue {
                await MainActor.run {
                    self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            await MainActor.run {
                self.errorMessage = "Unable to process Apple credentials"
            }
            return
        }

        do {
            // Use BetterAuthSwift's built-in social sign-in method
            let response = try await betterAuthClient.signIn.social(
                with: .init(
                    provider: "apple",
                    idToken: .init(token: tokenString)
                )
            )
            
            let responseUser = response.data.user
            let sessionToken = response.data.token

            // Get JWT token from /api/auth/token endpoint
            guard let jwt = try? await fetchJWTToken(sessionToken: sessionToken) else {
                await MainActor.run {
                    self.errorMessage = "Failed to get JWT token"
                }
                return
            }

            storeToken(jwt)
            storeSessionToken(sessionToken)

            await MainActor.run {
                self.user = User(
                    id: responseUser.id,
                    email: responseUser.email,
                    name: responseUser.name,
                    emailVerified: responseUser.emailVerified,
                    createdAt: responseUser.createdAt,
                    updatedAt: responseUser.updatedAt
                )
                self.authState = .authenticated
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Authentication failed: \(error.localizedDescription). Make sure the BetterAuth server is configured."
            }
            Logger.auth.error("Apple Sign In error: \(error.localizedDescription)")
        }
    }

    // MARK: - JWT Token Management

    private func fetchJWTToken(sessionToken: String? = nil) async throws -> String {
        // Use provided session token, or get from BetterAuth client session
        let token: String
        if let providedToken = sessionToken {
            token = providedToken
        } else {
            guard let sessionData = betterAuthClient.session.data else {
                throw AuthError.invalidCredentials
            }
            token = sessionData.session.token
        }

        let url = URL(string: "\(Config.authServerURL)/api/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.serverError
        }

        struct TokenResponse: Codable {
            let token: String
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResponse.token
    }

    // MARK: - Keychain Helpers

    private func storeToken(_ token: String) {
        let data = token.data(using: .utf8)!

        #if os(macOS)
        let synchronizable = false // Don't sync to iCloud on macOS
        #else
        let synchronizable = true
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: synchronizable
        ]

        // Delete any existing token first
        SecItemDelete(query as CFDictionary)

        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.auth.error("Keychain store failed: \(status)")
        } else {
            Logger.auth.info("Token stored successfully in keychain")
        }
    }

    private func retrieveToken() -> String? {
        #if os(macOS)
        let synchronizable = false
        #else
        let synchronizable = true
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTokenKey,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: synchronizable
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            Logger.auth.info("Failed to retrieve token from keychain: \(status)")
            return nil
        }

        Logger.auth.info("Token retrieved successfully from keychain")
        return token
    }

    private func clearToken() {
        #if os(macOS)
        let synchronizable = false
        #else
        let synchronizable = true
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainTokenKey,
            kSecAttrSynchronizable as String: synchronizable
        ]

        let status = SecItemDelete(query as CFDictionary)
        Logger.auth.info("Token cleared from keychain: \(status)")
    }

    // MARK: - Session Token Keychain Helpers

    private func storeSessionToken(_ token: String) {
        let data = token.data(using: .utf8)!

        #if os(macOS)
        let synchronizable = false
        #else
        let synchronizable = true
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainSessionTokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: synchronizable
        ]

        // Delete any existing token first
        SecItemDelete(query as CFDictionary)

        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.auth.error("Keychain session token store failed: \(status)")
        } else {
            Logger.auth.info("Session token stored successfully in keychain")
        }
    }

    private func retrieveSessionToken() -> String? {
        #if os(macOS)
        let synchronizable = false
        #else
        let synchronizable = true
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainSessionTokenKey,
            kSecReturnData as String: true,
            kSecAttrSynchronizable as String: synchronizable
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            Logger.auth.info("Failed to retrieve session token from keychain: \(status)")
            return nil
        }

        Logger.auth.info("Session token retrieved successfully from keychain")
        return token
    }

    private func clearSessionToken() {
        #if os(macOS)
        let synchronizable = false
        #else
        let synchronizable = true
        #endif

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainSessionTokenKey,
            kSecAttrSynchronizable as String: synchronizable
        ]

        let status = SecItemDelete(query as CFDictionary)
        Logger.auth.info("Session token cleared from keychain: \(status)")
    }

    // Expose token retrieval for ConvexService integration
    func getStoredToken() -> String? {
        return retrieveToken()
    }

    /// Attempt to refresh the JWT using the stored session token
    /// Call this after successful Convex login to extend the JWT expiration
    func refreshJWTInBackground() async {
        Logger.auth.info("Attempting to refresh JWT in background...")

        guard let storedSessionToken = retrieveSessionToken() else {
            Logger.auth.info("No session token available for refresh")
            return
        }

        do {
            let jwt = try await fetchJWTToken(sessionToken: storedSessionToken)
            storeToken(jwt)
            Logger.auth.info("JWT refreshed successfully - extended expiration by 7 days")
        } catch {
            Logger.auth.error("JWT refresh failed: \(error.localizedDescription)")
            // If session token is invalid, clear it
            if (error as NSError).code != NSURLErrorCancelled {
                Logger.auth.info("Session token appears invalid, clearing it")
                clearSessionToken()
            }
        }
    }

    // MARK: - Helper Types

    struct TimeoutError: Error, LocalizedError {
        var errorDescription: String? { "Operation timed out" }
    }

    enum AuthError: LocalizedError {
        case serverError
        case invalidCredentials

        var errorDescription: String? {
            switch self {
            case .serverError:
                return "Server error occurred"
            case .invalidCredentials:
                return "Invalid credentials"
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            await handleAppleSignInCompletion(.success(authorization))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            await handleAppleSignInCompletion(.failure(error))
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(macOS)
        return MainActor.assumeIsolated {
            NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSApplication.shared.windows.first!
        }
        #else
        return MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first!
        }
        #endif
    }
}
