//
//  Note.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import Foundation

struct Note: Decodable, Identifiable, Equatable {
    let _id: String
    let content: String
    let createdTime: Double
    let updatedTime: Double
    let userId: String

    var id: String { _id }

    var title: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled Note" }

        let lines = trimmed.components(separatedBy: .newlines)
        let firstLine = lines.first ?? ""
        return firstLine.isEmpty ? "Untitled Note" : firstLine
    }

    var updatedDate: Date {
        Date(timeIntervalSince1970: updatedTime / 1000)
    }
}
