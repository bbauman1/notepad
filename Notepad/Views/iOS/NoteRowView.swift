//
//  NoteRowView.swift
//  Convex
//
//  Created by Brett Bauman on 12/27/25.
//

import SwiftUI

struct NoteRowView: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.content.isEmpty ? "Empty note" : note.content)
                .font(.body)
                .lineLimit(1)

            Text(relativeTimeString(from: note.updatedTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func relativeTimeString(from timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000) // Convert from milliseconds
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date, to: now)

        // Check if it's today
        if calendar.isDateInToday(date) {
            if let minutes = components.minute, minutes < 1 {
                return "Updated <1m ago"
            } else if let minutes = components.minute, minutes < 60 {
                return "Updated \(minutes)m ago"
            } else if let hours = components.hour {
                return "Updated \(hours)h ago"
            }
        }

        // Check if it's yesterday
        if calendar.isDateInYesterday(date) {
            return "Updated yesterday"
        }

        // Check if it's within the last 7 days
        if let days = components.day, days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return "Updated on \(formatter.string(from: date))"
        }

        // 7 or more days ago
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "Updated \(formatter.string(from: date))"
    }
}
