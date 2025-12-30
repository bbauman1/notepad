//
//  User.swift
//  Notepad
//
//  Created by Claude on 12/28/25.
//

import Foundation
import BetterAuth

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let emailVerified: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case emailVerified
        case createdAt
        case updatedAt
    }
}

extension User {
    
    init(sessionUser: SessionUser) {
        self.id = sessionUser.id
        self.email = sessionUser.email
        self.name = sessionUser.name
        self.emailVerified = sessionUser.emailVerified
        self.createdAt = sessionUser.createdAt
        self.updatedAt = sessionUser.updatedAt
    }
}
