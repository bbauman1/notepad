//
//  ConvexService.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import ConvexMobile
import Foundation
import Combine

@MainActor
class ConvexService: ObservableObject {
    private var client: ConvexClientWithAuth<BetterAuthProvider.AuthResult>

    /// True when successfully authenticated with Convex
    @Published var isAuthenticated: Bool = false

    /// Incremented each time we re-authenticate to trigger subscription restarts
    @Published var authVersion: Int = 0

    init(authService: AuthService) {
        let provider = BetterAuthProvider(authService: authService)
        self.client = ConvexClientWithAuth(
            deploymentUrl: Config.convexDeploymentURL,
            authProvider: provider
        )
    }

    var shared: ConvexClientWithAuth<BetterAuthProvider.AuthResult> {
        return client
    }

    /// Login to Convex with credentials from BetterAuth
    func login() async throws {
        Logger.sync.info("Convex login called")

        let result = await client.login()
        switch result {
        case .success:
            Logger.sync.info("Convex login successful")
            isAuthenticated = true
            authVersion += 1
            Logger.sync.info("authVersion now: \(self.authVersion)")
        case .failure(let error):
            Logger.sync.error("Convex login failed: \(error.localizedDescription)")
            isAuthenticated = false
            throw error
        }
    }

    enum ConvexServiceError: LocalizedError {
        case notInitialized

        var errorDescription: String? {
            switch self {
            case .notInitialized:
                return "ConvexService not initialized"
            }
        }
    }
}

// MARK: - Note Operations
extension ConvexService {
    /// Create a new note with the given content
    func createNote(content: String = "") async throws {
        try await shared.mutation(
            "notes:create",
            with: ["content": content]
        )
    }

    /// Delete a note by ID
    func deleteNote(id: String) async throws {
        try await shared.mutation(
            "notes:deleteNote",
            with: ["id": id]
        )
    }

    /// Update a note's content
    func updateNote(id: String, content: String) async throws {
        try await shared.mutation(
            "notes:update",
            with: ["id": id, "content": content]
        )
    }

    /// Duplicate a note by creating a new one with the same content
    func duplicateNote(content: String) async throws {
        try await createNote(content: content)
    }
}
